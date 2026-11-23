; Number input (FIN) and output (FOUT), following the ROM digit by digit.

; FIN: read a number at TXTPTR into the FAC. A = first character, flags as
; CHRGET left them. TXTPTR ends on the character after the number.
fin:    push af
        xor a
        ld hl, facsgn               ; FACSGN, SGNFLG
        ld (hl), a
        inc hl
        ld (hl), a
        ld hl, facexp
        ld b, 5
.z:     ld (hl), a
        inc hl
        djnz .z
        ld (tenexp), a
        ld (expsgn), a
        ld (deccnt), a
        ld (dptflg), a
        pop af
        jp c, findig
        cp '&'
        jp z, hocons
        cp '-'
        jr nz, .qplus
        ld a, $FF
        ld (sgnflg), a
        jr finc
.qplus: cp '+'
        jr nz, fin1
finc:   call chrget
        jr c, findig
fin1:   cp '.'
        jr z, findp
        cp 'E'
        jr nz, fine
        call chrget
        jp c, finedg
        cp TK_MINUS
        jr z, finec1
        cp '-'
        jr z, finec1
        cp TK_PLUS
        jr z, finec
        cp '+'
        jr z, finec
        jr finec2
finec1: ld a, (expsgn)
        cpl
        ld (expsgn), a
finec:  call chrget
        jr c, finedg
finec2: ld a, (expsgn)
        or a
        jr z, fine
        ld a, (tenexp)
        neg
        ld (tenexp), a
        jr fine
findp:  ld a, (dptflg)
        cpl
        ld (dptflg), a
        or a
        jr nz, finc
fine:   ld a, (tenexp)
        ld hl, deccnt
        sub (hl)
        ld (tenexp), a
        jr z, finqng
        jp p, finmul
findiv: call div10
        ld hl, tenexp
        inc (hl)
        jr nz, findiv
        jr finqng
finmul: call mul10
        ld hl, tenexp
        dec (hl)
        jr nz, finmul
finqng: ld a, (sgnflg)
        or a
        ret p
        jp negop
findig: ld b, a
        ld a, (dptflg)
        ld c, a
        ld a, (deccnt)
        sub c
        ld (deccnt), a
        push bc
        call mul10
        pop bc
        ld a, b
        sub '0'
        call finlog
        jp finc
; FAC = FAC + signed byte A.
finlog: push af
        call mov1f
        pop af
        call float
        ld hl, tempf1
        jp fadd
finedg: sub '0'                     ; TENEXP = TENEXP*10 + digit
        ld c, a
        ld a, (tenexp)
        ld b, a
        add a, a
        add a, a
        add a, b
        add a, a
        add a, c
        ld (tenexp), a
        jp finec

; FOUT: convert the FAC to text at FBUFFR, zero-terminated. Returns HL =
; FBUFFR. The first character is '-' or a space.
fout:   ld de, fbuffr
        ld a, (facsgn)
        or a
        ld a, ' '
        jp p, .f1
        ld a, '-'
.f1:    ld (de), a
        inc de
        ld (fbufpt), de
        ld (facsgn), a              ; positive now, for QINT
        ld a, (facexp)
        or a
        jr nz, .nz
        ld a, '0'
        ld (de), a
        inc de
        xor a
        ld (de), a
        jp .ret
.nz:    cp $81
        ld a, 0
        jr nc, .f7
        ld hl, n_mil                ; below 1: scale up by 10^9
        call fmult
        ld a, -9
.f7:    ld (deccnt), a
.f4:    ld hl, n_9999
        call foutcp
        dec a
        jr z, .f9                   ; above 999999999.499: smaller
.f3:    ld hl, n_0999
        call foutcp
        dec a
        jr z, .f5                   ; above 99999999.9499: done
        call mul10
        ld hl, deccnt
        dec (hl)
        jr .f3
.f9:    call div10
        ld hl, deccnt
        inc (hl)
        jr .f4
.f5:    call faddh
        call qint
        ld b, 1
        ld a, (deccnt)
        add a, 10
        jp m, .f6                   ; below .01: E notation
        cp 11
        jr nc, .f6                  ; above 999999999: E notation
        dec a
        ld b, a
        ld a, 2
.f6:    dec a
        dec a
        ld (tenexp), a
        ld a, b
        ld (deccnt), a
        ld de, (fbufpt)
        or a
        jr z, .dp
        jp p, .f8
.dp:    ld a, '.'
        ld (de), a
        inc de
        ld a, b
        or a
        jr z, .f8
        ld a, '0'
        ld (de), a
        inc de
.f8:    ld ix, foutbl
        ld b, $80
        ld c, 9
.f2:    ld hl, faclo
        ld a, (hl)
        add a, (ix+3)
        ld (hl), a
        dec hl
        ld a, (hl)
        adc a, (ix+2)
        ld (hl), a
        dec hl
        ld a, (hl)
        adc a, (ix+1)
        ld (hl), a
        dec hl
        ld a, (hl)
        adc a, (ix+0)
        ld (hl), a
        inc b
        jr c, .c1
        bit 7, b                    ; carry clear: again while bit 7 clear
        jr z, .f2
        jr .typ
.c1:    bit 7, b                    ; carry set: again while bit 7 set
        jr nz, .f2
.typ:   jr nc, .foutyp
        ld a, b
        sub 11
        neg
        ld b, a
.foutyp:
        ld a, b
        add a, '0' - 1
        ld b, a
        inc ix
        inc ix
        inc ix
        inc ix
        and $7F
        ld (de), a
        inc de
        ld hl, deccnt
        dec (hl)
        jr nz, .cm
        ld a, '.'
        ld (de), a
        inc de
.cm:    ld a, b
        cpl
        and $80
        ld b, a
        dec c
        jr nz, .f2
.f11:   dec de                      ; drop trailing zeros and the point
        ld a, (de)
        cp '0'
        jr z, .f11
        cp '.'
        jr nz, .f12
        dec de
.f12:   ex de, hl
        inc hl
        ld a, (tenexp)
        or a
        jr z, .f17
        ld c, '+'
        jp p, .f14
        ld c, '-'
        neg
.f14:   ld (hl), 'E'
        inc hl
        ld (hl), c
        inc hl
        ld b, '0' - 1
.f15:   inc b
        sub 10
        jr nc, .f15
        add a, '0' + 10
        ld (hl), b
        inc hl
        ld (hl), a
        inc hl
.f17:   ld (hl), 0
.ret:   ld hl, fbuffr
        ret

n_0999: db $9B, $3E, $BC, $1F, $FD      ; 99999999.9499
n_9999: db $9E, $6E, $6B, $27, $FD      ; 999999999.499
n_mil:  db $9E, $6E, $6B, $28, $00      ; 10^9
foutbl: db $FA, $0A, $1F, $00           ; -100000000
        db $00, $98, $96, $80           ; 10000000
        db $FF, $F0, $BD, $C0           ; -1000000
        db $00, $01, $86, $A0           ; 100000
        db $FF, $FF, $D8, $F0           ; -10000
        db $00, $00, $03, $E8           ; 1000
        db $FF, $FF, $FF, $9C           ; -100
        db $00, $00, $00, $0A           ; 10
        db $FF, $FF, $FF, $FF           ; -1
