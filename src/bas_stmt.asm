; Statements: LET, PRINT, INPUT, READ, DIM, DEF FN, CLS, and the '&'
; number prefix.

; ---- LET -------------------------------------------------------------------
st_let: call ptrget
        ld (forpnt), hl
        SYNCHK TK_EQUAL
        ld a, (valtyp)
        push af
        call frmevl
        pop af
        ld b, a
        ld a, (valtyp)
        cp b
        jp nz, tmerr
        or a
        jp z, movvf
; Assign the string in the FAC to the variable at FORPNT. Strings in string
; space that belong to another variable are copied; temporaries and text
; in the program are used as they are.
inpcom: ld hl, (facmo)
        ld de, (txttab)             ; a temporary (below the program)?
        or a
        sbc hl, de
        add hl, de
        jr c, .dntcpy
        push hl                     ; a variable: is its text in the program?
        call dscget
        call inprog
        pop hl
        jr nc, .dntcpy
        ld a, (hl)
        call strini
        ld hl, (dscpnt)
        call movins
        ld hl, dsctmp
.dntcpy:
        ld (dscpnt), hl
        call fretms
        ld hl, (dscpnt)
        ld de, (forpnt)
        ld bc, STRSIZ
        ldir
        ret

; ---- PRINT -------------------------------------------------------------------
st_print:
        jp z, crdo
        call .prntdo
        xor a
        ld (devnum), a
        ret
.prntdo:
        cp '@'
        jr nz, .notpat
        call intidx                 ; PRINT @ position
        ld hl, -512
        add hl, de
        jp c, fcerr
        ld hl, SCRADR
        add hl, de
        ld (curadr), hl
        call chrgot
        jp z, crdo
        call chkcom
.notpat:
        cp '#'                      ; PRINT #device
        jr nz, .notdev
        call getdnm
        call opnock
        call chrgot
        jp z, crdo
        call chkcom
.notdev:
        cp TK_USING
        jp z, prtusg
printc: ret z
newchr: cp TK_TAB
        jr z, taber
        cp ','
        jr z, comprt
        cp ';'
        jr z, morscn
        call frmevl
        ld a, (valtyp)
        push af
        or a
        jr nz, .str
        call fout
        call strout
        jr .done
.str:   call strprt
.done:  call devprm
        pop af
        or a
        jr nz, nonnum
        call chrgot
        cp ','
        jr z, comprt
        call outspc
nonnum: call chrgot
        jr nz, newchr
        jp crdo

comprt: call devprm
        ld a, (devlcf)
        ld b, a
        ld a, (devpos)
        cp b
        jr c, .more
        call crdo
        jr morscn
.more:  ld hl, devcfw
.sub:   sub (hl)
        jr nc, .sub
        neg
        ld b, a
        jr bspac

taber:  call gtbytc
        cp ')'
        jp nz, snerr
        call devprm
        ld a, (devpos)
        ld b, a
        ld a, e
        sub b
        jr c, morscn
        jr z, morscn
        ld b, a
bspac:  call outspc
        djnz bspac
morscn: call chrget
        jr printc

; Print the string in the FAC.
strprt: call frefac
        inc b
.lp:    dec b
        ret z
        ld a, (hl)
        inc hl
        call chrout
        jr .lp

; ---- INPUT and READ ----------------------------------------------------------
msg_redo:       db "?REDO", 13, 0
msg_extra:      db "?EXTRA IGNORED", 13, 0

trmnok: ld a, (devnum)              ; bad data in a file
        or a
        ld e, ERR_FD
        jp nz, error
        ld a, (inpflg)
        or a
        jr z, .redo
        ld hl, (datlin)
        ld (curlin), hl
        jp snerr
.redo:  ld hl, msg_redo
        call strout
        ld hl, (txtbeg)
        ld (txtptr), hl
        ret

st_input:
        push af
        ld hl, (curlin)             ; not allowed as a direct command
        ld a, h
        and l
        inc a
        ld e, ERR_ID
        jp z, error
        pop af
        call inptdo
        xor a                       ; back to the screen and keyboard
        ld (devnum), a
        ret
inptdo: call devin                  ; INPUT #device,
        call prompt
        ld a, (devnum)
        or a
        jr z, .kbd
        ld hl, BUF - 1              ; a file: start with nothing read
        ld (hl), 0
        jp inpcon
.kbd:   call qinlin
        ld (hl), ','                ; HL = BUFMIN
        jp inpcon

; An optional "#device," for INPUT and LINE INPUT. A = the next character.
devin:  cp '#'
        ret nz
        call getdnm
        call opnick
        jp chkcom

; An optional "prompt"; for INPUT and LINE INPUT, not shown when reading a
; file.
prompt: cp '"'
        ret nz
        call strtxt
        SYNCHK ';'
        ld a, (devnum)
        or a
        jp z, strprt
        jp frefac

; LINE INPUT ["prompt";] string-var: the whole line, commas and quotes
; included. Entered from LINE with A = the INPUT token.
st_lninp:
        call chrget
        push af
        ld hl, (curlin)             ; not allowed as a direct command
        ld a, h
        and l
        inc a
        ld e, ERR_ID
        jp z, error
        pop af
        call devin
        call prompt
        ld a, (devnum)
        or a
        jr z, .kbd
        call flinln
        jr .got
.kbd:   call inlin
        jr nc, .got
        xor a                       ; BREAK stops
        scf
        jp ender
.got:   call ptrget
        ld (forpnt), hl
        call chkstr
        ld hl, BUF
        xor a
        ld (charac), a
        ld (endchr), a
        call strlit
        call inpcom
        xor a
        ld (devnum), a
        ret

; Print "? " and read a line. HL = BUFMIN. BREAK stops the program.
qinlin: call outqst
        call outspc
        call inlin
        ret nc
        pop hl                      ; drop our return: BREAK stops
        xor a
        scf
        jp ender

st_read:
        ld hl, (datptr)
        ld a, 1
        jr inpfl
inpcon: xor a
inpfl:  ld (inpflg), a
        ld (inpptr), hl
inloop: call ptrget
        ld (forpnt), hl
        ld hl, (txtptr)
        ld (vartxt), hl
        ld hl, (inpptr)
        ld a, (hl)
        or a
        jr nz, datbk
        ld a, (inpflg)
        or a
        jp nz, datlop
        ld a, (devnum)
        or a
        jr z, .kq
        call flinln
        jr datbk
.kq:    call outqst
        call qinlin
datbk:  ld (txtptr), hl
        call chrget
        ld b, a
        ld a, (valtyp)
        or a
        ld a, b
        jr z, .num
        ld hl, (txtptr)
        cp '"'
        jr nz, .unq
        ld (charac), a
        ld (endchr), a
        inc hl
        jr .get
.unq:   ld a, ':'
        ld (charac), a
        ld a, ','
        ld (endchr), a
.get:   call strlit
        call st2txt
        call inpcom
        jr .strdn2
.num:   call chrgot
        call fin
        call movvf
.strdn2:
        call chrgot
        jr z, .trmok
        cp ','
        jp nz, trmnok
.trmok: ld hl, (txtptr)
        ld (inpptr), hl
        ld hl, (vartxt)
        ld (txtptr), hl
        call chrgot
        jr z, .varend
        call chkcom
        jp inloop
.varend:
        ld hl, (inpptr)
        ld a, (inpflg)
        or a
        jr z, .inp
        ld (datptr), hl
        ret
.inp:   ld a, (hl)
        or a
        ret z
        ld hl, msg_extra
        jp strout

; Find the next DATA statement from HL (at a terminator).
datlop: ld (txtptr), hl
        call datan
        inc hl
        or a
        jr nz, .nowlin
        ld e, ERR_OD
        ld a, (hl)
        inc hl
        or (hl)
        inc hl
        jp z, error
        ld d, (hl)
        inc hl
        ld e, (hl)
        inc hl
        ld (datlin), de
.nowlin:
        ld a, (hl)
        cp TK_DATA
        jr nz, datlop
        jp datbk

; ---- DIM ---------------------------------------------------------------------
st_dim: ld b, 1
        call ptrgt1
        call chrgot
        ret z
        call chkcom
        jr st_dim

; ---- DEF FN ------------------------------------------------------------------
st_def: call getfnm
        ld hl, (curlin)             ; not allowed as a direct command
        ld a, h
        and l
        inc a
        ld e, ERR_ID
        jp z, error
        call chkopn
        ld a, $80
        ld (subflg), a
        call ptrget
        call chknum
        call chkcls
        SYNCHK TK_EQUAL
        ld hl, (fnpnt)
        ld de, (txtptr)
        ld (hl), e
        inc hl
        ld (hl), d
        inc hl
        ld de, (varpnt)
        ld (hl), e
        inc hl
        ld (hl), d
        jp st_data

; Find (or make) the function named after FN. FNPNT = its value.
getfnm: SYNCHK TK_FN
        ld b, a
        ld a, $80
        ld (subflg), a
        ld a, b
        or $80
        call ptrgt2
        ld (fnpnt), hl
        jp chknum

; FN name(arg)
fndoer: call getfnm
        push hl
        call parchk
        call chknum
        pop ix                      ; the function's entry
        ld l, (ix+2)                ; HL = the dummy variable
        ld h, (ix+3)
        ld a, h
        or l
        ld e, ERR_UF
        jp z, error
        ld e, (ix+0)                ; DE = definition text
        ld d, (ix+1)
        push hl
        pop ix
        ld l, (ix+0)                ; save the dummy's value
        ld h, (ix+1)
        push hl
        ld l, (ix+2)
        ld h, (ix+3)
        push hl
        ld a, (ix+4)
        push af
        push ix
        ld hl, (txtptr)
        push hl
        ld (txtptr), de
        push ix
        pop hl
        call movmf                  ; the argument becomes the dummy
        call frmnum
        call chrgot
        jp nz, snerr
        pop hl
        ld (txtptr), hl
        pop ix
        pop af
        ld (ix+4), a
        pop hl
        ld (ix+2), l
        ld (ix+3), h
        pop hl
        ld (ix+0), l
        ld (ix+1), h
        ret

; ---- CLS ---------------------------------------------------------------------
st_cls: jr z, .green
        call getbyt
        ld a, e
        cp 9
        jr nc, .egg
        or a
        ld a, $80                   ; 0: black
        jr z, .fill
        ld a, e
        dec a
        rrca
        rrca
        rrca
        rrca
        or $8F
.fill:  jp clsfill
.green: jp grnchr
.egg:   call grnchr
        ld hl, msg_ms
        jp strout
msg_ms: db "MICROSOFT", 13, 0

; ---- '&' numbers -------------------------------------------------------------
; &Hhex, &Ooctal or &octal, at TXTPTR. Leaves the value in the FAC.
hocons: ld bc, $0300                ; B = bits per digit, C = 0
        call chrget
        cp 'H'
        jr nz, .noth
        ld b, 4
        jr .skip
.noth:  cp 'O'
        jr nz, .first
.skip:  call chrget
.first: ld hl, 0
.lp:    jr c, .dig                  ; a decimal digit
        ld c, a
        ld a, b
        cp 4
        jr nz, .done
        ld a, c
        sub 'A'
        cp 6
        jr nc, .done
        add a, 10
        jr .add
.dig:   sub '0'
        ld c, a
        ld a, b
        cp 3
        ld a, c
        jr nz, .add
        cp 8
        jr nc, .done
.add:   push bc
.sh:    add hl, hl
        jp c, overr
        djnz .sh
        pop bc
        or l
        ld l, a
        call chrget
        jr .lp
.done:  ex de, hl
        jp givuns
