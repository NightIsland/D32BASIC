; Tokenising (CRUNCH), detokenising (DCRNCH) and LIST.

; CRUNCH the text at TXTPTR into BUF-1 (a quote expands to two bytes, so
; the result starts one byte early). Returns BC = length + 4 (with the link
; and line number) and TXTPTR = BUF-2, ready to execute it.
crunch:
        ld hl, (txtptr)
        ld de, BUF - 1
.nxtscr:
        xor a
        ld (invnam), a
        ld (indata), a
.loop:  ld a, (hl)
        inc hl
        or a
        jr z, .stuff
        ld c, a
        ld a, (invnam)              ; inside a variable name?
        or a
        ld a, c
        jr z, .notvar
        call isletc
        jr nc, .stuff
        cp '0'
        jr c, .endvar
        cp '9' + 1
        jr c, .stuff
.endvar:
        xor a
        ld (invnam), a
        ld a, c
.notvar:
        cp ' '
        jr z, .stuff
        ld (trmchr), a
        cp '"'
        jr z, .qstrng
        ld c, a
        ld a, (indata)
        or a
        ld a, c
        jr z, .nindat
.stuff: ld (de), a
        inc de
        or a
        jr z, .done
        cp ':'
        jr z, .nxtscr
        jr .loop
.done:  xor a                       ; two more zeros: a zero link
        ld (de), a
        inc de
        ld (de), a
        inc de
        ex de, hl
        ld de, BUF - 3
        or a
        sbc hl, de
        ld b, h
        ld c, l
        ld hl, BUF - 2
        ld (txtptr), hl
        ret
.nindat:
        cp '?'
        jr nz, .nq
        ld a, TK_PRINT
        jr .stuff
.nq:    cp "'"
        jr nz, .nsq
        ld a, ':'
        ld (de), a
        inc de
        ld a, TK_SNGQ
        ld (de), a
        inc de
.skprem:
        xor a                       ; copy to the end of the line
        ld (trmchr), a
.strlop:
        ld a, (hl)
        inc hl
        or a
        jr z, .stuff
        ld c, a
        ld a, (trmchr)
        cp c
        ld a, c
        jr z, .stuff
.qstrng:
        ld (de), a
        inc de
        jr .strlop
.nsq:   cp '0'                      ; digits, colon and semicolon stay
        jr c, .mustcr
        cp ';' + 1
        jr c, .stuff
.mustcr:
        dec hl
        push de
        push hl
        xor a
        ld (funflg), a
        ld ix, reslst
        ld c, NUM_NORMAL
.dolist:
        ld b, 0                     ; token number
.nxtres:
        pop hl
        push hl
.reslop:
        ld a, (ix+0)
        inc ix
        sub (hl)
        inc hl
        jr z, .reslop
        cp $80
        jr z, .found
        dec ix                      ; skip the rest of this word
.skp:   ld a, (ix+0)
        inc ix
        bit 7, a
        jr z, .skp
        inc b
        dec c
        jr nz, .nxtres
        ld a, (funflg)              ; try the function words
        cpl
        ld (funflg), a
        or a
        jr z, .notfnd
        ld ix, funlst
        ld c, NUM_FUN
        jr .dolist
.notfnd:
        pop hl
        pop de
        ld a, (hl)
        inc hl
        ld (de), a
        inc de
        call isletc                 ; a letter starts a variable name
        jp c, .loop
        ld a, $FF
        ld (invnam), a
        jp .loop
.found: ld a, (funflg)
        or a
        jr nz, .found2
        ld a, b
        cp TK_CD & $7F
        jr nz, .found2
        call cdword                     ; CD is only sometimes a keyword
        jr nz, .notfnd
.found2:
        pop af                          ; drop the start pointer
        pop de
        ld a, b
        or $80
        ld c, a
        ld a, (funflg)
        or a
        jr z, .normal
        ld a, $FF
        ld (de), a
        inc de
        ld a, c
        ld (de), a
        inc de
        jp .loop
.normal:
        ld a, c
        cp TK_ELSE                  ; ELSE is stored as ':' ELSE
        jr nz, .notelse
        ld a, ':'
        ld (de), a
        inc de
        ld a, c
        ld (de), a
        inc de
        jp .loop
.notelse:
        ld (de), a
        inc de
        cp TK_DATA
        jr nz, .nodata
        ld (indata), a
.nodata:
        cp TK_REM
        jp z, .skprem
        jp .loop

; CD is a keyword only where it cannot be a variable: at the start of a
; statement, followed by a quote, the end of the statement, or a space and
; then anything but '=' or '('. HL = the text after "CD"; the stack holds
; (under the return address) the start of the word and the BUF pointer.
; Z if CD is the keyword here. Keeps B and HL.
cdword: push hl
        ld a, (hl)
        cp '"'
        jr z, .start
        or a
        jr z, .start
        cp ':'
        jr z, .start
        cp ' '
        jr nz, .no
.sp:    inc hl
        ld a, (hl)
        cp ' '
        jr z, .sp
        cp '='
        jr z, .no
        cp '('
        jr z, .no
.start: ld hl, 6                        ; the BUF pointer
        add hl, sp
        ld a, (hl)
        inc hl
        ld h, (hl)
        ld l, a
.back:  dec hl                          ; what came before, skipping spaces
        push hl
        ld de, BUF - 1
        or a
        sbc hl, de
        pop hl
        jr c, .yes                      ; the start of the line
        ld a, (hl)
        cp ' '
        jr z, .back
        cp ':'
        jr z, .yes
        cp TK_THEN
        jr z, .yes
        cp TK_ELSE
        jr z, .yes
.no:    pop hl
        or 1
        ret
.yes:   pop hl
        xor a
        ret

; DCRNCH: expand the program line at HL into BUF as ASCII, zero-terminated.
; Returns HL = the line's link address (unchanged by this routine's caller).
dcrnch:
        ld de, BUF
        xor a
        ld (de), a
        inc hl
        inc hl
        inc hl
        inc hl
.lp:    ld a, (hl)
        inc hl
        or a
        ret z
        jp m, .tok
        cp ':'                      ; drop the ':' before ELSE and '
        jr nz, .ch
        ld a, (hl)
        cp TK_ELSE
        jr z, .lp
        cp TK_SNGQ
        jr z, .lp
        ld a, ':'
.ch:    call bufchr
        jr .lp
.tok:   cp $FF
        jr z, .fn
        sub $80
        cp NUM_NORMAL
        jr nc, .bad
        ld ix, reslst
        jr .find
.fn:    ld a, (hl)
        inc hl
        sub $80
        cp NUM_FUN
        jr nc, .bad
        ld ix, funlst
.find:  or a
        jr z, .copy
.sk:    bit 7, (ix+0)
        inc ix
        jr z, .sk
        dec a
        jr nz, .sk
.copy:  ld a, (ix+0)
        inc ix
        ld c, a
        call bufchr
        bit 7, c
        jr z, .copy
        jr .lp
.bad:   ld a, '!'
        jr .ch

; Store A (bit 7 cleared) at DE in BUF unless BUF is full; keep a zero after.
bufchr:
        push hl
        ld hl, -(BUF + BUFLEN - 1)
        add hl, de
        pop hl
        ret c
        and $7F
        ld (de), a
        inc de
        xor a
        ld (de), a
        ret

; LIST [from][-[to]]
; LLIST: LIST to the printer. There is none, so the listing goes nowhere.
st_llist:
        push af
        ld a, 2
        ld (devnum), a
        pop af
st_list:
        push af
        call linget
        call fndlin
        ld (lstptr), hl
        pop af
        jr z, .toend
        call chrgot
        jr z, .go
        cp TK_MINUS
        ret nz
        call chrget
        jr z, .toend
        call linget
        jr z, .go
        ret
.toend: ld hl, $FFFF
        ld (linnum), hl
.go:    pop hl                      ; never return to NEWSTT
.lp:    call condcr
        call iscntc
        ld hl, (lstptr)
        ld a, (hl)
        inc hl
        or (hl)
        dec hl
        jr nz, .notend
.end:   xor a
        ld (devnum), a
        jp ready
.notend:
        push hl
        inc hl
        inc hl
        ld d, (hl)
        inc hl
        ld e, (hl)                  ; DE = line number
        ld hl, (linnum)
        or a
        sbc hl, de
        pop hl
        jr c, .end
        push hl
        ex de, hl
        call linprt
        call outspc
        pop hl
        push hl
        call dcrnch
        pop hl
        ld a, (hl)                  ; follow the link
        inc hl
        ld l, (hl)
        ld h, a
        ld (lstptr), hl
        ld hl, BUF
        call strout
        jr .lp
