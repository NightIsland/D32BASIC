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

st_edit:
st_exec:
        jp st_unimpl

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
