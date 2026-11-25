; The BASIC interpreter core: start-up, the command loop, program storage,
; statement dispatch and the control-flow statements.
;
; The structure follows the Dragon ROM's so behaviour matches it closely:
; the same program, variable and stack layouts, the same error checks and
; the same text-pointer conventions (TXTPTR points at the last character
; read; CHRGET advances it).

MEMTOP          EQU $FFF0           ; top of BASIC memory (MEMSIZ at start)

; Error codes: offsets into errtab.
ERR_NF  EQU 0
ERR_SN  EQU 2
ERR_RG  EQU 4
ERR_OD  EQU 6
ERR_FC  EQU 8
ERR_OV  EQU 10
ERR_OM  EQU 12
ERR_UL  EQU 14
ERR_BS  EQU 16
ERR_DD  EQU 18
ERR_DV0 EQU 20
ERR_ID  EQU 22
ERR_TM  EQU 24
ERR_OS  EQU 26
ERR_LS  EQU 28
ERR_ST  EQU 30
ERR_CN  EQU 32
ERR_UF  EQU 34
ERR_FD  EQU 36
ERR_AO  EQU 38
ERR_DN  EQU 40
ERR_IO  EQU 42
ERR_FM  EQU 44
ERR_NO  EQU 46
ERR_IE  EQU 48
ERR_DS  EQU 50
ERR_NE  EQU 52
ERR_DF  EQU 54                      ; DragonDOS: disk full
ERR_FS  EQU 56                      ; DragonDOS: bad file name
ERR_PT  EQU 58                      ; DragonDOS: protected
ERR_FE  EQU 60                      ; DragonDOS: file exists

FORSIZ  EQU 18                      ; bytes in a FOR stack entry
GOSIZ   EQU 5                       ; bytes in a GOSUB stack entry

; SYNCHK t: the current character must be t; skip it, else ?SN ERROR.
    MACRO SYNCHK t
        ld a, t
        call synchr
    ENDM

; ---------------------------------------------------------------------------
cold_start:
        ld sp, BOOT_STACK
        xor a
        ld (kb_head), a
        ld (kb_tail), a
        ld (devnum), a
        ld (trcflg), a
        ld (filein), a
        dec a
        ld (dosfh), a
        ld (kb_last), a
        ld (allock), a
        ld a, 1
        ld (nzlink), a
        call joyset
        call snd_init
        call set_init                   ; D32BASIC.CFG
        call grinit                     ; graphics pages, PCLEAR 4
        call xrrun
        call grnchr
        ei
        ld hl, (GRBASE + 24) << 8       ; a zero byte below TXTTAB
        ld (hl), 0
        inc hl
        ld (txttab), hl
        ld hl, MEMTOP
        ld (endmem), hl
        ld (memsiz), hl
        ld (fretop), hl
        ld de, STRSPC
        or a
        sbc hl, de
        ld (stktop), hl
        ld sp, hl
        ld hl, rnd_seed
        ld de, rndx
        ld bc, 5
        ldir
        call scrtch
        ld hl, msg_banner
        call strout
        jp ready

rnd_seed:       db $80, $4F, $C7, $52, $59

; ---- errors ----------------------------------------------------------------
snerr:  ld e, ERR_SN
        jr error
fcerr:  ld e, ERR_FC
        jr error
omerr:  ld e, ERR_OM
        jr error
tmerr:  ld e, ERR_TM
        jr error
ulerr:  ld e, ERR_UL
        jr error
overr:  ld e, ERR_OV
        jr error
dv0err: ld e, ERR_DV0
        jr error
iderr:  ld e, ERR_ID
        jr error
bserr:  ld e, ERR_BS
        jr error
lserr:  ld e, ERR_LS
        jr error
; Report error E ("?xx ERROR [IN line]") and return to the command level.
error:
        ld a, e
        ld (errnum), a
        call stkini
        xor a
        ld (devnum), a
        call condcr
        call outqst
        ld hl, errtab
        ld a, (errnum)
        ld e, a
        ld d, 0
        add hl, de
        ld a, (hl)
        call chrout
        inc hl
        ld a, (hl)
        call chrout
        ld hl, msg_error
errfin: call strout
        ld hl, (curlin)
        ld a, h
        inc a
        jr z, ready
        call inprt
ready:
        call dos_abort
        call snd_off
        call condcr
        ld hl, msg_ok
        call strout
main:
        call inlin                      ; HL = BUF-1, carry = BREAK
        ld de, $FFFF
        ld (curlin), de
        jr c, main
        ld (txtptr), hl
        call chrget
        jr z, .blank
        jr c, main1                     ; starts with a line number
        ld a, (filein)                  ; a file may hold only numbered lines
        or a
        ld e, ERR_DS
        jp nz, error
        call chkbye                     ; BYE: back to NextZXOS
        call crunch
        jp gone
.blank: ld a, (filein)
        or a
        jr z, main
        ld a, (eofflg)
        or a
        jr z, main
        jp dos_ldend                    ; the end of a file being loaded

; A numbered line: delete any old line with that number, then insert.
main1:
        call linget
edtent: ld hl, (linnum)                 ; (EDIT comes here, TXTPTR = BUF)
        ld a, h                         ; BUFLNM is big-endian
        ld (buflnm), a
        ld a, l
        ld (buflnm + 1), a
        call crunch                     ; BC = length of crunched line
        ld a, c
        call insln
fini:   call runc
        call cheada
        jp main

; Insert the line in BUFLNM/BUF-1 (A = its length + 4, LINNUM = its
; number), replacing any old line with that number. An empty line only
; deletes. The links are left for CHEADA to rebuild.
insln:
        ld (count), a
        call fndlin
        jr c, .nodel
        ; delete the line at HL: move everything above it down over it
        push hl                         ; destination
        ld a, (hl)
        inc hl
        ld l, (hl)
        ld h, a                         ; HL = next line
        ex de, hl
        ld hl, (vartab)
        or a
        sbc hl, de
        ld b, h
        ld c, l                         ; BC = bytes from next line to VARTAB
        ex de, hl                       ; HL = next line
        pop de
        ldir
        ld (vartab), de
.nodel: ld a, (BUF - 1)                 ; empty line? then only delete
        or a
        ret z
        ld hl, (vartab)
        ld (hightr), hl
        ld a, (count)
        ld e, a
        ld d, 0
        add hl, de
        ld (highds), hl
        call bltu                       ; make room at LOWTR
        ld hl, (lowtr)                  ; copy link, number and text in
        ex de, hl
        ld hl, nzlink - 1               ; two dummy link bytes, then BUFLNM
        ld a, (count)
        ld c, a
        ld b, 0
        ldir
        ld hl, (highds)
        ld (vartab), hl
        ret

; HL = big-endian link at (DE); DE preserved.
ld_link:
        ex de, hl
        ld d, (hl)
        inc hl
        ld e, (hl)
        dec hl
        ex de, hl
        ret

; Rebuild every line's link by finding the zero at the end of each line.
cheada:
        ld hl, (txttab)
chead:
        ld a, (hl)
        inc hl
        or (hl)
        dec hl
        ret z                           ; double zero: end of program
        push hl
        inc hl
        inc hl
        inc hl
        inc hl
.z:     ld a, (hl)
        inc hl
        or a
        jr nz, .z
        ex de, hl                       ; DE = next line
        pop hl
        ld (hl), d
        inc hl
        ld (hl), e
        ex de, hl
        jr chead

; Find line LINNUM. Carry clear: HL = that line. Carry set: not found, HL =
; the first line after it (or the end). LOWTR = HL as well.
fndlin:
        ld hl, (txttab)
fndlop:
        ld a, (hl)                      ; end of program?
        inc hl
        or (hl)
        dec hl
        jr z, .notf
        push hl
        inc hl
        inc hl
        ld d, (hl)
        inc hl
        ld e, (hl)                      ; DE = this line's number
        ld hl, (linnum)
        ex de, hl
        or a
        sbc hl, de                      ; this - wanted
        pop hl
        jr z, .found
        jr nc, .notf                    ; gone past it
        ld a, (hl)
        inc hl
        ld l, (hl)
        ld h, a
        jr fndlop
.notf:  scf
.found: ld (lowtr), hl
        ret

; NEW
st_new:
        ret nz
scrtch:
        ld hl, (txttab)
        xor a
        ld (hl), a
        inc hl
        ld (hl), a
        inc hl
        ld (vartab), hl
runc:
        ld hl, (txttab)
        dec hl
        ld (txtptr), hl
clearc:
        ld hl, (memsiz)
        ld (fretop), hl
        call restor
        ld hl, (vartab)
        ld (arytab), hl
        ld (strend), hl
; Reset the stack, string temporaries and CONT. Returns to the caller.
stkini:
        pop de                          ; return address
        ld hl, tempst
        ld (temppt), hl
        ld sp, (stktop)
        xor a
        dec sp                          ; a zero byte so FNDFOR stops
        ld hl, 0
        add hl, sp
        ld (hl), a
        ld (oldtxt), a
        ld (oldtxt + 1), a
        ld (subflg), a
        ex de, hl
        jp (hl)

; ---- statement execution ---------------------------------------------------
newstt:
        ei
        call iscntc
        ld hl, (txtptr)
        ld (txtbeg), hl                ; start of statement, for CONT/INPUT
        ld a, (hl)
        inc hl
        or a
        jr z, .endlin
        cp ':'
        jr z, gone
        jp snerr
.endlin:
        ld a, (hl)                      ; link high byte zero: end
        ld (brkflg), a
        or a
        jp z, endcon
        inc hl
        inc hl
        ld d, (hl)
        inc hl
        ld e, (hl)
        ld (curlin), de
        ld (txtptr), hl
        ld a, (trcflg)
        or a
        jr z, gone
        ld a, '['
        call chrout
        ex de, hl
        call linprt
        ld a, ']'
        call chrout
gone:
        call chrget
        call gone3
        jr newstt

; Execute the statement starting with A (flags from CHRGET).
gone3:
        ret z
        or a
        jp p, st_let
        cp TK_RENUM + 1
        jr nc, .notst
        sub $80
.disp:  add a, a
        ld l, a
        ld h, 0
        ld de, stmdsp
        add hl, de
        ld a, (hl)
        inc hl
        ld h, (hl)
        ld l, a
        call chrget
        jp (hl)
.notst: cp TK_DOSFST
        jp c, snerr
        cp TK_DOSFST + NUM_DOS
        jr nc, .fn
        sub TK_DOSFST - NUM_STM         ; DOS entries follow RENUM's
        jr .disp
.fn:    cp $FF
        jp nz, snerr
        call chrget
        cp FN_MIDS
        jp z, lhmid
        cp FN_TIMER
        jp nz, snerr
; TIMER = ticks (0-65535) sets the 50 Hz tick count.
        call chrget
        ld a, TK_EQUAL
        call synchr
        call evladr
        di
        ld (ticker), de
        ei
        ret

; A statement D32BASIC does not have: ?SN ERROR, or skipped when SETUP
; says to ignore them.
st_unimpl:
        ld a, (setign)
        or a
        jp z, snerr
        jp st_data

; Check for BREAK (and SHIFT-@ pause). Other keys are kept for INKEY$.
iscntc:
        call polcat
        ret z
.tst:   cp 3
        jr z, st_stop
        cp $13
        jr z, .hang
        ld (inkchr), a
        ret
.hang:  call polcat
        jr z, .hang
        jr .tst

; RESTORE
st_restore:
restor:
        ld hl, (txttab)
        dec hl
        ld (datptr), hl
        ret

; END / STOP
st_end:
        call chrgot
        scf                             ; carry clear (Z kept): END
        ccf
        jr ender
st_stop:
        scf
ender:  ret nz                          ; END/STOP must end the statement
        push af
        ld hl, (txtptr)
        ld (txtbeg), hl
        pop af
        ld a, 0
        rra                             ; bit 7 = print BREAK
        ld (brkflg), a
        pop hl                          ; drop the NEWSTT return
endcon:
        ld hl, (curlin)
        ld a, h
        and l
        inc a
        jr z, .direct
        ld (oldlin), hl
        ld hl, (txtbeg)
        ld (oldtxt), hl
.direct:
        xor a
        ld (devnum), a
        ld a, (brkflg)
        or a
        jp p, ready
        ld hl, msg_break
        jp errfin

; CONT
st_cont:
        ret nz
        ld e, ERR_CN
        ld hl, (oldtxt)
        ld a, h
        or l
        jp z, error
        ld (txtptr), hl
        ld hl, (oldlin)
        ld (curlin), hl
        ret

; CLEAR [strings[,memtop]]
st_clear:
        jp z, clearc
        call intid2                     ; DE = string space
        push de
        ld hl, (memsiz)
        call chrgot
        jr z, .cur
        call chkcom
        call evladr                     ; DE = new memory size
        ld a, d                         ; a Dragon RAM address (1536 up)
        cp WORKSPACE >> 8               ; is &H7A00 higher here, as for
        jr nc, .top                     ; PEEK and POKE
        cp $06
        jr nc, .dragon
        ld hl, (memsiz)                 ; below 1536: keep the current top
        jr .cur
.dragon:
        ld hl, $7A00
        add hl, de
        ex de, hl
.top:   dec de
        ld hl, (endmem)
        or a
        sbc hl, de
        jr c, .om
        ex de, hl
.cur:   pop de                          ; HL = memsiz, DE = string space
        push hl
        or a
        sbc hl, de                      ; new stack top
        jr c, .om2
        push hl
        ld de, 2 * NUMLEV
        or a
        sbc hl, de
        jr c, .om3
        ld de, (vartab)
        or a
        sbc hl, de
        jr c, .om3
        pop hl
        ld (stktop), hl
        pop hl
        ld (memsiz), hl
        jp clearc
.om3:   pop hl
.om2:   pop hl
        jp omerr
.om:    pop de
        jp omerr

; RUN [line]
st_run:
        push af
        call xrrun                      ; PLAY and DRAW defaults
        pop af
        jp z, runc
        cp '"'
        jp z, st_runf
        call clearc
        jr runc2

; GO TO / GO SUB
st_go:
        ld b, a
ongo:   call chrget
        ld a, b
        cp TK_TO
        jr z, st_goto
        cp TK_SUB
        jp nz, snerr
gosub:
        ld b, 3
        call getstk
        ld hl, (txtptr)                 ; the entry goes on top of our return
        push hl
        ld hl, (curlin)
        push hl
        dec sp
        ld hl, 0
        add hl, sp
        ld (hl), TK_SUB
runc2:  call st_goto
        jp newstt

st_goto:
        call chrgot
        call linget
        call remn                       ; HL = end of this line
        inc hl
        ex de, hl
        ld hl, (curlin)
        ld bc, (linnum)
        or a
        sbc hl, bc                      ; curlin - target
        ex de, hl
        jr c, .fwd                      ; target after: search from here
        ld hl, (txttab)
.fwd:   call fndlop
        jp c, ulerr
dexptr: dec hl
        ld (txtptr), hl
        ret

; RETURN
st_return:
        ret nz
        ld hl, $FFFF                    ; a FOR variable pointer never matches
        ld (forpnt), hl
        call fndfor
        ld sp, hl
        cp TK_SUB
        jr z, .ok
        ld e, ERR_RG
        jp error
.ok:    inc sp
        pop hl
        ld (curlin), hl
        pop hl
        ld (txtptr), hl
; DATA: skip to the end of the statement.
st_data:
        call datan
        ld (txtptr), hl
        ret
; REM: skip to the end of the line.
st_rem:
        call remn
        ld (txtptr), hl
        ret

; Find the end of the statement (DATAN) or line (REMN) from TXTPTR,
; stepping over quoted text and counting IFs. HL = the terminator, A = it.
datan:  ld c, ':'
        jr remer0
remn:   ld c, 0
remer0: ld b, 0                         ; B = the other terminator
        ld hl, (txtptr)
.loop:  ld a, (hl)
        or a
        ret z
        cp c
        ret z
        inc hl
        cp '"'
        jr nz, .notq
        ld a, b                         ; swap terminators
        ld b, c
        ld c, a
        jr .loop
.notq:  cp $FF
        jr nz, .notfn
        inc hl                          ; skip the function token's 2nd byte
        jr .loop
.notfn: cp TK_IF
        jr nz, .loop
        push hl
        ld hl, ifcnt
        inc (hl)
        pop hl
        jr .loop

; IF expr THEN ... [ELSE ...]
st_if:
        call frmnum
        call chrgot
        cp TK_GO
        jr z, .go
        SYNCHK TK_THEN
.go:    ld a, (facexp)
        or a
        jr nz, docond
        xor a
        ld (ifcnt), a
.skip:  call st_data
        or a
        ret z                           ; end of line: no ELSE
        call chrget
        cp TK_ELSE
        jr nz, .skip
        ld hl, ifcnt
        dec (hl)
        jp p, .skip
        call chrget
docond: call chrgot
        jp c, st_goto
        jp gone3

; ON expr GOTO/GOSUB line,line...
st_on:
        call getbyt                     ; E = value
        ld a, e
        ld (faclo), a
        call chrgot
        SYNCHK TK_GO
        cp TK_SUB
        jr z, .ok
        cp TK_TO
        jp nz, snerr
.ok:    ld b, a
.loop:  ld hl, faclo
        dec (hl)
        jp z, ongo
        push bc
        call chrget
        call linget
        pop bc
        cp ','
        jr z, .loop
        ret

; Read a line number at TXTPTR into LINNUM (0-63999). A = terminator.
linget:
        push af
        ld hl, 0
        ld (linnum), hl
        pop af
.more:  ret nc
        sub '0'
        ld c, a
        ld hl, (linnum)
        ld a, h
        cp 25                           ; must stay below 64000
        jp nc, snerr
        add hl, hl
        ld d, h
        ld e, l
        add hl, hl
        add hl, hl
        add hl, de
        ld b, 0
        add hl, bc
        ld (linnum), hl
        call chrget
        jr .more

; Find a FOR entry on the stack for variable FORPNT (any FOR if FORPNT is
; zero, setting FORPNT). Called directly from a statement routine. Z set:
; found, HL = the entry. Otherwise HL = the first non-FOR entry, A = its
; token.
fndfor:
        ld hl, 4
        add hl, sp
.loop:  ld a, (hl)
        cp TK_FOR
        ret nz
        push hl
        inc hl
        ld e, (hl)
        inc hl
        ld d, (hl)
        ld hl, (forpnt)
        ld a, h
        or l
        jr z, .set
        or a
        sbc hl, de
        jr z, .found
        pop hl
        ld de, FORSIZ
        add hl, de
        jr .loop
.set:   ld (forpnt), de
.found: pop hl
        xor a
        ret

; Make room for B two-byte entries on the stack, else ?OM ERROR.
getstk:
        ld l, b
        ld h, 0
        add hl, hl
        ld de, (strend)
        add hl, de
; HL = an address; ?OM ERROR unless it is NUMLEV*2 bytes below the stack.
reason:
        ld de, 2 * NUMLEV
        add hl, de
        jp c, omerr
        ex de, hl
        ld hl, 4                        ; our return plus the caller's
        add hl, sp
        or a
        sbc hl, de
        ret nc
        jp omerr

; Move LOWTR..HIGHTR up so it ends at HIGHDS. LOWDS = new start of block.
bltu:
        ld hl, (highds)
        call reason
        ld hl, (hightr)
        ld de, (lowtr)
        or a
        sbc hl, de                      ; bytes to move
        ld b, h
        ld c, l
        ld hl, (hightr)
        dec hl
        ld de, (highds)
        dec de
        ld a, b
        or c
        jr z, .none
        lddr
.none:  inc de
        ld (lowds), de
        ret

; FOR var = start TO limit [STEP step]
st_for:
        ld a, $80
        ld (subflg), a
        call st_let
        call fndfor
        pop bc                          ; drop the NEWSTT return
        jr nz, .new
        ld de, FORSIZ                   ; drop the old entry and all after it
        add hl, de
        ld sp, hl
.new:   ld b, 9
        call getstk
        call datan                      ; HL = end of statement
        push hl                         ; text pointer, then line number
        ld hl, (curlin)
        push hl
        SYNCHK TK_TO
        call frmnum                     ; the limit
        ld hl, -5
        add hl, sp
        ld sp, hl
        call movmf                      ; limit, packed
        ld hl, fone
        call movfm
        call chrgot
        cp TK_STEP
        jr nz, .one
        call chrget
        call frmnum
.one:   call sign
        ld b, a                         ; B = sign of step
        ld hl, -6
        add hl, sp
        ld sp, hl
        push hl
        call movmf                      ; step at (SP), sign after it
        pop hl
        ld de, 5
        add hl, de
        ld (hl), b
        ld hl, (forpnt)
        push hl
        dec sp
        ld hl, 0
        add hl, sp
        ld (hl), TK_FOR
        jp newstt

; NEXT [var[,var...]]
st_next:
        ld hl, 0
        jr z, stxfor
getfor: call ptrget
stxfor: ld (forpnt), hl
        call fndfor
        jr z, .have
        ld e, ERR_NF
        jp error
.have:  ld sp, hl
        inc hl
        inc hl
        inc hl
        call movfm                      ; the step
        ld hl, 8
        add hl, sp
        ld a, (hl)
        ld (facsgn), a
        ld hl, (forpnt)
        call fadd
        ld hl, (forpnt)
        call movmf
        ld hl, 9
        add hl, sp
        call fcomp                      ; A = sign(var - limit)
        ld hl, 8
        add hl, sp
        sub (hl)
        jr z, .done
        ld hl, 14
        add hl, sp
        ld e, (hl)
        inc hl
        ld d, (hl)
        inc hl
        ld (curlin), de
        ld e, (hl)
        inc hl
        ld d, (hl)
        ld (txtptr), de
        jp newstt
.done:  ld hl, FORSIZ
        add hl, sp
        ld sp, hl
        call chrgot
        cp ','
        jp nz, newstt
        call chrget
        call getfor                     ; leaves a dummy return address

; TRON / TROFF
st_tron:
        ld a, $FF
        jr st_troff.s
st_troff:
        xor a
.s:     ld (trcflg), a
        ret

; ---- character scanning ----------------------------------------------------

; CHRGET: advance TXTPTR and read the character there, skipping spaces.
; CHRGOT: read the current character again. Z = end of statement (0 or
; ':'), C = a digit. Preserves BC, DE, HL.
chrget:
        push hl
        ld hl, (txtptr)
        inc hl
        jr chrg1
chrgot:
        push hl
        ld hl, (txtptr)
chrg1:  ld a, (hl)
        cp ' '
        jr nz, chrg2
        inc hl
        jr chrg1
chrg2:  ld (txtptr), hl
        pop hl
        cp ':'
        ret nc
        or a
        ret z
        cp '0'
        jr c, .nd
        cp $FF                          ; digit: C set, Z clear
        ret
.nd:    or a
        ret

; The current character must equal A; skip it, else ?SN ERROR.
synchr:
        push hl
        ld hl, (txtptr)
        cp (hl)
        pop hl
        jp nz, snerr
        jr chrget
chkcom: SYNCHK ','
        ret
chkopn: SYNCHK '('
        ret
chkcls: SYNCHK ')'
        ret

; Is A a letter? Carry clear if so.
isletc:
        cp 'A'
        ret c
        cp 'Z' + 1
        ccf
        ret

        INCLUDE "bas_io.asm"
        INCLUDE "bas_crunch.asm"
        INCLUDE "bas_eval.asm"
        INCLUDE "bas_stmt.asm"
        INCLUDE "bas_string.asm"
        INCLUDE "bas_float.asm"
        INCLUDE "bas_fout.asm"
        INCLUDE "bas_trans.asm"
        INCLUDE "bas_edit.asm"
        INCLUDE "bas_using.asm"

; ---- tables and messages ---------------------------------------------------
        INCLUDE "tables_gen.inc"

errtab: db "NFSNRGODFCOVOMULBSDD/0IDTMOSLSSTCNUFFDAODNIOFMNOIEDSNE"
        db "DFFSPTFE"
msg_error:      db " ERROR", 0
msg_in:         db " IN ", 0
msg_ok:         db "OK", 13, 0
msg_break:      db 13, "BREAK", 0
msg_banner:     db "D32BASIC FOR THE SPECTRUM NEXT", 13
                db "DRAGON 32 COMPATIBLE BASIC", 13, 13, 0
