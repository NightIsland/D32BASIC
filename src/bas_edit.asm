; Program editing commands: DEL, RENUM, EDIT.

; DEL line, DEL from-to, DEL -to, DEL from-
st_del: jp z, fcerr
        call linget
        call fndlin
        ld (tmpptr), hl             ; first line to delete
        call chrgot
        jr z, .src
        cp TK_MINUS
        ret nz                      ; NEWSTT gives the ?SN ERROR
        call chrget
        jr z, .toend
        call linget
        call chrgot
        jp nz, snerr
        jr .src
.toend: ld a, $FF
        ld (linnum + 1), a
.src:   ld hl, (tmpptr)
.lp:    ld a, (hl)                  ; end of program?
        inc hl
        or (hl)
        dec hl
        jr z, .dor
        push hl
        inc hl
        inc hl
        ld d, (hl)
        inc hl
        ld e, (hl)
        ld hl, (linnum)
        or a
        sbc hl, de                  ; carry: this line is beyond the range
        pop hl
        jr c, .dor
        ld a, (hl)
        inc hl
        ld l, (hl)
        ld h, a
        jr .lp
.dor:   ex de, hl                   ; DE = first line kept
        ld hl, (vartab)
        or a
        sbc hl, de
        ld b, h
        ld c, l
        inc bc                      ; (never zero)
        ex de, hl
        ld de, (tmpptr)
        ldir
        dec de
        ld (vartab), de
        call runc
        ld hl, (tmpptr)
        call chead
        jp ready

st_exec:
        jp st_unimpl

; EDIT line: the Dragon's line editor. Subcommands (n = an optional count):
; n<space> move right, nD delete, nC change, I insert, X add at the end,
; H cut here and add, nK<c> delete up to c, nS<c> move to c, n<left>
; move left, L list and restart, A start again, E or ENTER save, Q quit.
; While inserting, ENTER saves and SHIFT-up/'_' (escape) stops inserting.
EDESC           EQU $1B
EDDEL           EQU 8
st_edit:
        call linget
        call chrgot
        jp nz, snerr
        pop hl                      ; EDIT ends in the line-entry code
edita:  ld a, 1
        ld (edtlst), a
        call fndlin
        jp c, ulerr
        call dcrnch
        ld hl, BUF
        ld b, 0
.len:   ld a, (hl)
        or a
        jr z, .lend
        inc hl
        inc b
        jr .len
.lend:  ld a, b
        ld (edtlen), a
edtpln: ld hl, (linnum)
        call linprt
        call outspc
        ld hl, BUF
        ld a, (edtlst)
        or a
        jr nz, elstit
edtsub: ld b, 0                     ; the count
.rep:   call editin
        call isdigc
        jr c, .ndg
        sub '0'
        ld c, a
        ld a, b
        add a, a
        ld b, a
        add a, a
        add a, a
        add a, b
        add a, c
        ld b, a
        jr .rep
.ndg:   inc b                       ; a count of 0 is 1
        dec b
        jr nz, .cnt
        inc b
.cnt:   cp 'A'
        jr nz, .l
        call crdo
        jr edita
.l:     cp 'L'
        jr nz, editcr
elstit: call edtprt
        xor a
        ld (edtlst), a
        call crdo
        jr edtpln
editcr: cp 13
        jr nz, edte
        call edtprt
edtend: call crdo
        ld hl, BUF
        ld (txtptr), hl
        ld hl, $FFFF
        ld (curlin), hl
        jp edtent
edte:   cp 'E'
        jr z, edtend
        cp 'Q'
        jr nz, edtsb
        call crdo
        jp ready
edtsb:  call dosubc
        jr edtsub

; One subcommand: A = its letter, B = its count, HL = the place in BUF.
dosubc: cp ' '
        jp z, eplop
        cp 'D'
        jr z, .del
        cp 'C'
        jr z, .chg
        cp 'I'
        jr z, editi
        cp 'X'
        jr z, editx
        cp 'H'
        jr z, .hack
        cp EDDEL
        jr z, .back
        cp 'K'
        jr z, .kill
        cp 'S'
        ret nz                      ; anything else is ignored
        xor a                       ; S: the same as K but no deleting
.kill:  ld c, a                     ; C = 0: search only
        call editin
        ld d, a                     ; D = the character to find
.srch:  ld a, (hl)
        or a
        ret z
        inc c
        dec c
        jr nz, .isk
        call chrout
        inc hl
        jr .nok
.isk:   call delchr
.nok:   ld a, (hl)
        cp d
        jr nz, .srch
        djnz .srch
        ret
.del:   ld a, (hl)
        or a
        ret z
        call delchr
        djnz .del
        ret
.chg:   ld a, (hl)
        or a
        ret z
        call editin
        jr nc, .chg                 ; ENTER, escape and delete are ignored
        ld (hl), a
        inc hl
        call chrout
        djnz .chg
        ret
.back:  call goback
        djnz .back
        ret
.hack:  ld (hl), 0
        push hl
        ld de, BUF
        or a
        sbc hl, de
        ld a, l
        ld (edtlen), a
        pop hl
editx:  call edtprt
editi:  call editin
        cp 13
        jr nz, .nocr
        pop de                      ; ENTER: end the edit
        jp editcr
.nocr:  cp EDESC
        ret z
        cp EDDEL
        jr nz, .ins
        ld de, BUF
        or a
        sbc hl, de
        add hl, de
        jr z, editi
        call goback
        call delchr
        jr editi
.ins:   ld c, a
        ld a, (edtlen)
        cp BUFLEN
        jr z, editi                 ; full: only ENTER or escape now
        ld d, h                     ; DE = the place
        ld e, l
.end:   ld a, (hl)                  ; find the end
        or a
        jr z, .mv
        inc hl
        jr .end
.mv:    ld a, (hl)                  ; move up a byte, the zero first
        inc hl
        ld (hl), a
        dec hl
        ld a, l
        cp e
        jr nz, .nx
        ld a, h
        cp d
        jr z, .put
.nx:    dec hl
        jr .mv
.put:   ld (hl), c
        inc hl
        ld a, c
        call chrout
        ld a, (edtlen)
        inc a
        ld (edtlen), a
        jr editi

; Print the rest of the line, or B characters of it (EPLOP).
edtprt: ld b, BUFLEN
eplop:  ld a, (hl)
        or a
        ret z
        call chrout
        inc hl
        djnz eplop
        ret

; Delete the character at HL.
delchr: push hl
        push de
        ld a, (edtlen)
        dec a
        ld (edtlen), a
        ld d, h
        ld e, l
.lp:    inc hl
        ld a, (hl)
        ld (de), a
        inc de
        or a
        jr nz, .lp
        pop de
        pop hl
        ret

; Move back one character (not before the start).
goback: push de
        ld de, BUF
        or a
        sbc hl, de
        add hl, de
        pop de
        ret z
        dec hl
        ld a, EDDEL
        jp chrout

; A key for the editor: carry clear for ENTER, escape and delete, carry set
; for a printable character. Others are ignored; SHIFT-up ('_') is escape.
editin: push bc
        push de
        push hl
.get:   call inchr
        cp 127
        jr nc, .get
        cp '_'
        jr nz, .ne
        ld a, EDESC
.ne:    cp 13
        jr z, .low
        cp EDESC
        jr z, .low
        cp EDDEL
        jr z, .low
        cp ' '
        jr c, .get
        scf
.low:   pop hl
        pop de
        pop bc
        ret

fn_usr:
fn_unimpl:
        jp fcerr

; RENUM [new [, from [, step]]]
; References after GOTO, GOSUB, THEN and ELSE (and lists after them) are
; changed to the new numbers. A reference to a line that does not exist is
; kept and reported as "UL old IN line".
st_renum:
        call clearc
        ld hl, 10
        ld (rennew), hl
        ld (reninc), hl
        ld hl, 0
        ld (renfst), hl
        call chrgot
        jr nc, .dfltnn
        call linget
        ld hl, (linnum)
        ld (rennew), hl
        call chrgot
.dfltnn:
        jr z, .endprm
        call chkcom
        jr nc, .dfltmm
        call linget
        ld hl, (linnum)
        ld (renfst), hl
        call chrgot
.dfltmm:
        jr z, .endprm
        call chkcom
        jr nc, .dfltii
        call linget
        ld hl, (linnum)
        ld a, h
        or l
        jp z, fcerr
        ld (reninc), hl
.dfltii:
        call chrgot
        jp nz, snerr
.endprm:
        ld hl, (renfst)             ; the first line to renumber
        ld (linnum), hl
        call fndlin
        push hl
        call lnum
        ld (rfirst), de
        ld hl, (rennew)             ; it must not land on earlier lines
        ld (linnum), hl
        call fndlin
        pop de
        push de
        or a
        sbc hl, de
        jp c, fcerr
        pop hl                      ; check no new number passes 63999
        ld de, (rennew)
.cn:    ld a, (hl)
        inc hl
        or (hl)
        dec hl
        jr z, .scan0
        ld a, (hl)
        inc hl
        ld l, (hl)
        ld h, a
        ld a, (hl)
        inc hl
        or (hl)
        dec hl
        jr z, .scan0
        push hl
        ld hl, (reninc)
        add hl, de
        ex de, hl
        pop hl
        jp c, fcerr
        ld a, d
        cp 250
        jp nc, fcerr
        jr .cn

.scan0: ld hl, (txttab)             ; change the references
.line:  ld a, (hl)
        inc hl
        or (hl)
        dec hl
        jr z, .passb
        inc hl
        inc hl
        ld d, (hl)
        inc hl
        ld e, (hl)
        ld (rencur), de
        ld (txtptr), hl
.scan:  call chrget
.exam:  or a
        jr z, .eol
        jp p, .scan
        cp $FF
        jr nz, .nfn
        call chrget
        jr .scan
.nfn:   cp TK_THEN
        jr z, .num
        cp TK_ELSE
        jr z, .num
        cp TK_GO
        jr nz, .scan
        call chrget
        cp TK_TO
        jr z, .num
        cp TK_SUB
        jr z, .num
        jr .exam
.num:   call chrget
        jr nc, .exam
        ld hl, (txtptr)
        ld (renst), hl
        call linget
        ld hl, (txtptr)             ; back up to just after the last digit
.bk:    dec hl
        ld a, (hl)
        call isdigc
        jr c, .bk
        inc hl
        ld (renend), hl
        call renmap
        call renrep
        call cheada
        call chrget
        cp ','
        jr z, .num
        jr .exam
.eol:   ld hl, (txtptr)
        inc hl
        jr .line

.passb: ld hl, (txttab)             ; give the lines their new numbers
        ld de, (rennew)
.pb:    ld a, (hl)
        inc hl
        or (hl)
        dec hl
        jr z, .done
        push hl
        inc hl
        inc hl
        ld b, (hl)
        inc hl
        ld c, (hl)
        push hl
        ld hl, (rfirst)
        scf
        sbc hl, bc                  ; carry: number >= RFIRST
        pop hl
        jr nc, .keep
        ld (hl), e
        dec hl
        ld (hl), d
        ld hl, (reninc)
        add hl, de
        ex de, hl
.keep:  pop hl
        ld a, (hl)
        inc hl
        ld l, (hl)
        ld h, a
        jr .pb
.done:  call clearc
        call cheada
        jp ready

; DE = the number of the line at HL, or $FFFF at the end of the program.
lnum:   ld de, $FFFF
        ld a, (hl)
        inc hl
        or (hl)
        dec hl
        ret z
        push hl
        inc hl
        inc hl
        ld d, (hl)
        inc hl
        ld e, (hl)
        pop hl
        ret

; DE = the new number for line LINNUM (unchanged if it is not renumbered).
; A line that does not exist is reported and keeps its number.
renmap: ld hl, (linnum)
        call rnum
        ret nc
        ld hl, msg_ul
        call strout
        ld hl, (linnum)
        call linprt
        ld hl, (rencur)
        call rnum
        ex de, hl
        call inprt
        call crdo
        ld de, (linnum)
        ret
msg_ul: db "UL ", 0

; DE = the new number of the line numbered HL; carry if there is none.
rnum:   push hl
        pop bc                      ; BC = the old number
        ld hl, (txttab)
        ld de, (rennew)             ; DE = the next new number
.lp:    ld a, (hl)
        inc hl
        or (hl)
        dec hl
        scf
        ret z
        push hl
        inc hl
        inc hl
        ld a, (hl)
        inc hl
        ld l, (hl)
        ld h, a                     ; HL = this line's number
        push hl
        push de
        ld de, (rfirst)
        or a
        sbc hl, de                  ; no carry: it is renumbered
        pop de
        pop hl
        jr c, .old
        or a
        sbc hl, bc
        jr z, .hitnew
        ld hl, (reninc)
        add hl, de
        ex de, hl
        jr .next
.old:   or a
        sbc hl, bc
        add hl, bc
        jr z, .hitold
.next:  pop hl
        ld a, (hl)
        inc hl
        ld l, (hl)
        ld h, a
        jr .lp
.hitnew:
        pop hl
        or a
        ret
.hitold:
        pop bc
        ex de, hl
        or a
        ret

; Replace the text RENST..RENEND with the number DE in decimal.
renrep: ld hl, rbuf
        ld ix, rtens
        ld c, 0                     ; digits written
        ex de, hl                   ; HL = number, DE = buffer
.dg:    ld a, (ix+0)
        or (ix+1)
        jr z, .last
        ld b, '0' - 1
.sub:   inc b
        ld a, l
        sub (ix+0)
        ld l, a
        ld a, h
        sbc a, (ix+1)
        ld h, a
        jr nc, .sub
        ld a, l
        add a, (ix+0)
        ld l, a
        ld a, h
        adc a, (ix+1)
        ld h, a
        inc ix
        inc ix
        ld a, b
        cp '0'
        jr nz, .put
        inc c
        dec c
        jr z, .dg                   ; a leading zero
.put:   ld (de), a
        inc de
        inc c
        jr .dg
.last:  ld a, l
        add a, '0'
        ld (de), a
        inc c                       ; C = length of the new text
        ld a, c
        ld (count), a
        ld hl, (renend)
        ld de, (renst)
        or a
        sbc hl, de                  ; L = length of the old text
        ld a, c
        sub l
        jr z, .copy
        ld e, a                     ; DE = signed difference
        rla
        sbc a, a
        ld d, a
        ld hl, (vartab)
        push hl
        add hl, de
        ld (vartab), hl
        bit 7, d
        jr nz, .down
        push de
        call reason
        pop de
        pop hl                      ; old VARTAB
        push hl
        ld bc, (renend)
        or a
        sbc hl, bc
        ld b, h
        ld c, l                     ; bytes to move
        pop hl
        dec hl
        push hl
        add hl, de
        ex de, hl
        pop hl
        lddr
        jr .copy
.down:  pop hl
        ld bc, (renend)
        or a
        sbc hl, bc
        ld b, h
        ld c, l
        ld hl, (renend)
        push hl
        add hl, de
        ex de, hl
        pop hl
        ldir
.copy:  ld a, (count)
        ld c, a
        ld hl, rbuf
        ld de, (renst)
        ld b, 0
        ldir                        ; (C = length)
        dec de
        ld (txtptr), de
        ret
rtens:  dw 10000, 1000, 100, 10, 0
