; Floating point: Microsoft 5-byte format, bit-exact with the Dragon ROM.
;
; Packed (in memory): exponent (bias 128, 0 = zero), then 4 mantissa bytes,
; most significant first, with the sign in bit 7 of the first.
; Unpacked (FAC, ARG): exponent, 4 mantissa bytes with bit 7 of the first
; set, and a separate sign byte (bit 7). FACOV holds extra bits for rounding.
;
; The algorithms are the ROM's, step for step, including where a carry from
; one stage feeds the next, so that results match to the last bit.

; ---- add and subtract ------------------------------------------------------

faddh:  ld hl, fhalf
; FAC = (HL) + FAC
fadd:   call conupk
        jr faddt
; FAC = (HL) - FAC
fsub:   call conupk
; FAC = ARG - FAC
fsubt:  ld hl, facsgn
        ld a, (hl)
        cpl
        ld (hl), a
        ld hl, arisgn
        ld a, (hl)
        cpl
        ld (hl), a
; FAC = ARG + FAC
faddt:  ld a, (facexp)
        or a
        jp z, movfa                     ; FAC = 0: the answer is ARG
        ld a, (argexp)
        ld ix, argexp                   ; normally shift ARG
; A = ARG's exponent.
faddc:  or a
        ret z                           ; ARG = 0: FAC is the answer
        ld b, a
        ld a, (facexp)
        ld c, a
        ld a, b
        sub c
        ld b, a
        jp z, fadd5                     ; no shift
        jr c, fadd1                     ; ARG smaller: shift it
        ld a, b                         ; ARG bigger: it sets exponent, sign
        add a, c
        ld (facexp), a
        ld a, (argsgn)
        ld (facsgn), a
        ld ix, facexp
        ld a, b
        neg
        ld b, a
fadd1:  ld a, b                         ; B <= -8 (signed): shift bytes
        xor $80
        cp $79
        jp c, fadd5
        xor a
        srl (ix+1)
        call rolshf
fadd4:  ; A = overflow byte, carry = carry in
        ld b, a
        ld a, (arisgn)
        ld c, a
        bit 7, a                        ; (carry kept)
        ld a, b
        jr z, fadd2
        ld b, a                         ; signs differ: complement the
        ld a, (ix+1)                    ; smaller one and add
        cpl
        ld (ix+1), a
        ld a, (ix+2)
        cpl
        ld (ix+2), a
        ld a, (ix+3)
        cpl
        ld (ix+3), a
        ld a, (ix+4)
        cpl
        ld (ix+4), a
        ld a, b
        cpl
        add a, 1
fadd2:  ld (facov), a
        ld hl, arglo
        ld a, (faclo)
        adc a, (hl)
        ld (faclo), a
        dec hl
        ld a, (facmo)
        adc a, (hl)
        ld (facmo), a
        dec hl
        ld a, (facmoh)
        adc a, (hl)
        ld (facmoh), a
        dec hl
        ld a, (facho)
        adc a, (hl)
        ld (facho), a
        bit 7, c
        jr z, round
; Carry = sign of the result of a subtraction.
fadflt: jr c, normal
        call negfac
normal: ld b, 0
norm3:  ld a, (facho)
        or a
        jr nz, norm1
        ld a, (facmoh)                  ; shift 8 bits at a time
        ld (facho), a
        ld a, (facmo)
        ld (facmoh), a
        ld a, (faclo)
        ld (facmo), a
        ld a, (facov)
        ld (faclo), a
        xor a
        ld (facov), a
        ld a, b
        add a, 8
        ld b, a
        cp 40
        jr c, norm3                     ; (B only grows from 0, so unsigned)
zerofc: xor a
zerof1: ld (facexp), a
        ld (facsgn), a
        ret
fadd5:  call shiftr
        or a                            ; clear carry
        jp fadd4
norm2:  inc b
        ld hl, facov
        sla (hl)
        ld hl, faclo
        rl (hl)
        dec hl
        rl (hl)
        dec hl
        rl (hl)
        dec hl
        rl (hl)
norm1:  jp p, norm2                     ; flags from FACHO
        ld a, (facexp)
        sub b
        ld (facexp), a
        jr c, zerofc                    ; underflow
        jr z, zerofc
        jr rndit
round:  jr c, rndshf
rndit:  ld hl, facov
        sla (hl)                        ; carry = top extra bit
        ld (hl), 0
        jr qrnd
rndshf: ld hl, facexp
        inc (hl)
        jp z, overr
        inc hl
        rr (hl)                         ; FACHO..FACLO
        inc hl
        rr (hl)
        inc hl
        rr (hl)
        inc hl
        rr (hl)
qrnd:   ret nc
        call incfac
        jr z, rndshf
        ret

; Negate the FAC (two's complement of the mantissa, flip the sign).
negfac: ld hl, facsgn
        ld a, (hl)
        cpl
        ld (hl), a
negfch: ld hl, facho
        ld a, (hl)
        cpl
        ld (hl), a
        inc hl
        ld a, (hl)
        cpl
        ld (hl), a
        inc hl
        ld a, (hl)
        cpl
        ld (hl), a
        inc hl
        ld a, (hl)
        cpl
        ld (hl), a
        scf
; Add 1 to the FAC mantissa. Z set if it wrapped to zero. Carry kept.
incfac: ld hl, faclo
        inc (hl)
        ret nz
        dec hl
        inc (hl)
        ret nz
        dec hl
        inc (hl)
        ret nz
        dec hl
        inc (hl)
        ret

; ---- shifting --------------------------------------------------------------
; Shift (IX+1)..(IX+4) right by -B bits (B negative), bytes first. Bytes
; shifted out go through FACOV; BITS fills from the left. Returns A = the
; overflow byte, B = 0, carry = last bit shifted out of A.
mulshf: ld ix, resho - 1
shftr2: ld a, (ix+4)
        ld (facov), a
        ld a, (ix+3)
        ld (ix+4), a
        ld a, (ix+2)
        ld (ix+3), a
        ld a, (ix+1)
        ld (ix+2), a
        ld a, (bits)
        ld (ix+1), a
shiftr: ld a, b                         ; B += 8; again while B <= 0 (signed)
        add a, 8
        ld b, a
        jr z, shftr2
        jp pe, .ov
        jp m, shftr2
        jr .bits
.ov:    jp p, shftr2
.bits:  ld a, b
        sub 8
        ld b, a
        ld a, (facov)
        ret z
shftr3: sra (ix+1)
rolshf: rr (ix+2)
        rr (ix+3)
        rr (ix+4)
        rra
        inc b
        jr nz, shftr3
        ret

; ---- multiply ----------------------------------------------------------------
; FAC = (HL) * FAC
fmult:  call conupk
; FAC = ARG * FAC
fmultt: ld a, (facexp)
        or a
        ret z
        ld a, (argexp)
        call muldiv
rndmul: xor a
        ld (resho), a
        ld (resmoh), a
        ld (resmo), a
        ld (reslo), a
        ld a, (faclo)
        ld b, a
        or a
        call mltply
        ld a, (facov)
        ld (rndtmp + 3), a
        ld a, (facmo)
        ld b, a
        or a
        call mltply
        ld a, (facov)
        ld (rndtmp + 2), a
        ld a, (facmoh)
        ld b, a
        or a
        call mltply
        ld a, (facov)
        ld (rndtmp + 1), a
        ld a, (facho)
        ld b, a
        call mltpl1
        ld a, (facov)
        ld (rndtmp), a
        call movfr
        jp normal

; Add ARG into RES for each set bit of B, shifting RES right each time.
mltply: jp z, mulshf
mltpl1: scf
mltpl2: ld a, (resho)
        rr b
        ret z
        jr nc, mltpl3
        ld hl, arglo
        ld a, (reslo)
        add a, (hl)
        ld (reslo), a
        dec hl
        ld a, (resmo)
        adc a, (hl)
        ld (resmo), a
        dec hl
        ld a, (resmoh)
        adc a, (hl)
        ld (resmoh), a
        dec hl
        ld a, (resho)
        adc a, (hl)
mltpl3: rra
        ld (resho), a
        ld hl, resmoh
        rr (hl)
        inc hl
        rr (hl)
        inc hl
        rr (hl)
        ld hl, facov
        rr (hl)
        or a
        jr mltpl2

; Unpack the number at HL into ARG. Sets ARISGN. Returns A = ARG exponent,
; B = FAC exponent. Preserves HL.
conupk: push hl
        inc hl
        ld a, (hl)
        ld (argsgn), a
        or $80
        ld (argho), a
        inc hl
        ld a, (hl)
        ld (argmoh), a
        inc hl
        ld a, (hl)
        ld (argmo), a
        inc hl
        ld a, (hl)
        ld (arglo), a
        ld a, (argsgn)
        ld b, a
        ld a, (facsgn)
        xor b
        ld (arisgn), a
        pop hl
        ld a, (hl)
        ld (argexp), a
        ld a, (facexp)
        ld b, a
        ld a, (argexp)
        ret

; Add the exponents for multiply/divide (A = ARG's), with overflow and
; underflow checks. On underflow it returns zero from the caller.
muldiv: or a
        jr z, .under
        ld hl, facexp
        add a, (hl)
        jr c, .c
        bit 7, a
        jr z, .under                    ; below range
        jr .ok
.c:     bit 7, a
        jp nz, overr
.ok:    add a, $80
        ld (facexp), a
        jp z, zerofc                    ; (returns to our caller)
        ld a, (arisgn)
        ld (facsgn), a
        ret
.under: pop hl                          ; return zero from the caller
        jp zerofc
; Overflow or underflow from EXP, depending on the sign.
mldvex: ld a, (facsgn)
        cpl
        or a
        jp p, zerofc
        jp overr

; FAC = FAC * 10
mul10:  call movaf
        ret z
        add a, 2
        jp c, overr
        ld b, a
        xor a
        ld (arisgn), a
        ld a, b
        call faddc
        ld hl, facexp
        inc (hl)
        jp z, overr
        ret

; FAC = FAC / 10
div10:  call movaf
        ld hl, ten_c
        ld b, 0
; FAC = ARG / (HL), with ARISGN = B.
fdivf:  ld a, b
        ld (arisgn), a
        call movfm
        jr fdivt
; FAC = (HL) / FAC
fdiv:   call conupk
; FAC = ARG / FAC
fdivt:  ld a, (facexp)
        or a
        jp z, dv0err
        neg
        ld (facexp), a
        ld a, (argexp)
        call muldiv
        ld hl, facexp
        inc (hl)
        jp z, overr
        ld ix, resho
        ld a, 4
        ld (count), a
        ld b, 1
.divide:
        ld hl, argho
        ld a, (facho)
        cp (hl)
        jr nz, .savquo
        inc hl
        ld a, (facmoh)
        cp (hl)
        jr nz, .savquo
        inc hl
        ld a, (facmo)
        cp (hl)
        jr nz, .savquo
        inc hl
        ld a, (faclo)
        cp (hl)
        jr nz, .savquo
        scf
.savquo:
        push af                         ; keep the comparison's carry
        rl b
        jr nc, .qshft
        ld (ix+0), b
        inc ix
        ld hl, count
        dec (hl)
        jp m, .divnrm
        jr z, .ld100
        ld b, 1
.qshft: pop af
        jr c, .divsub
.shfarg:
        ld hl, arglo
        sla (hl)
        dec hl
        rl (hl)
        dec hl
        rl (hl)
        dec hl
        rl (hl)
        jr c, .savquo
        jp m, .divide
        jr .savquo
.divsub:
        ld hl, faclo
        ld a, (arglo)
        sub (hl)
        ld (arglo), a
        dec hl
        ld a, (argmo)
        sbc a, (hl)
        ld (argmo), a
        dec hl
        ld a, (argmoh)
        sbc a, (hl)
        ld (argmoh), a
        dec hl
        ld a, (argho)
        sbc a, (hl)
        ld (argho), a
        jr .shfarg
.ld100: ld b, $40                       ; two more bits
        jr .qshft
.divnrm:
        pop af
        scf                             ; the sentinel bit came out
        rr b
        rr b
        rr b
        ld a, b
        ld (facov), a
        call movfr
        jp normal

; ---- moves -----------------------------------------------------------------
; FAC mantissa = RES.
movfr:  ld hl, resho
        ld de, facho
        ld bc, 4
        ldir
        ret

; FAC = packed number at HL. Preserves A, BC, DE, HL.
movfm:  push af
        push hl
        ld a, (hl)
        ld (facexp), a
        inc hl
        ld a, (hl)
        ld (facsgn), a
        or $80
        ld (facho), a
        inc hl
        ld a, (hl)
        ld (facmoh), a
        inc hl
        ld a, (hl)
        ld (facmo), a
        inc hl
        ld a, (hl)
        ld (faclo), a
        xor a
        ld (facov), a
        pop hl
        pop af
        ret

; Pack the FAC into memory. Preserves BC, DE.
mov2f:  ld hl, tempf2
        jr movmf
mov1f:  ld hl, tempf1
        jr movmf
movvf:  ld hl, (forpnt)
movmf:  push hl
        ld a, (facexp)
        ld (hl), a
        inc hl
        ld a, (facsgn)
        or $7F
        push bc
        ld b, a
        ld a, (facho)
        and b
        pop bc
        ld (hl), a
        inc hl
        ld a, (facmoh)
        ld (hl), a
        inc hl
        ld a, (facmo)
        ld (hl), a
        inc hl
        ld a, (faclo)
        ld (hl), a
        pop hl
        ret

; FAC = ARG. Returns A = the sign.
movfa:  ld a, (argsgn)
movfa1: ld (facsgn), a
        ld a, (argexp)
        ld (facexp), a
        ld a, (argho)
        ld (facho), a
        xor a
        ld (facov), a
        ld a, (argmoh)
        ld (facmoh), a
        ld a, (argmo)
        ld (facmo), a
        ld a, (arglo)
        ld (faclo), a
        ld a, (facsgn)
        ret

; ARG = FAC. Returns A = the exponent, Z set if zero. Preserves BC.
movaf:  push bc
        ld hl, facexp
        ld de, argexp
        ld bc, 6
        ldir
        pop bc
        ld a, (facexp)
        or a
        ret

; ---- sign, compare, integer ------------------------------------------------
; A = -1, 0 or 1 by the sign of the FAC, flags set accordingly.
sign:   ld a, (facexp)
        or a
        ret z
fcsign: ld a, (facsgn)
fcomps: rla
        ld a, $FF
        ret c
        ld a, 1
        or a
        ret

; SGN
fn_sgn: call sign
; FAC = signed byte A.
float:  ld (facho), a
        xor a
        ld (facmoh), a
        ld b, $88
floats: ld a, (facho)
        sub $80                         ; carry set if positive
floatc: ld a, b
        ld (facexp), a
        ld a, 0
        ld (facmo), a
        ld (faclo), a
        ld (facov), a
        ld (facsgn), a
        jp fadflt

; ABS
fn_abs: xor a
        ld (facsgn), a
        ret

; A = 1 if (HL) < FAC, 0 if equal, -1 if (HL) > FAC. Flags set.
fcomp:  ld a, (hl)
        or a
        jr z, sign
        inc hl
        ld a, (facsgn)
        xor (hl)
        dec hl
        jp m, fcsign
; Compare magnitudes as well as signs (same as fcomp once signs match).
foutcp: ld a, (facexp)
        cp (hl)
        jr nz, .c
        inc hl
        ld a, (hl)
        or $7F
        push bc
        ld b, a
        ld a, (facho)
        and b
        pop bc
        cp (hl)
        dec hl
        jr nz, .c
        push hl
        inc hl
        inc hl
        ld a, (facmoh)
        cp (hl)
        jr nz, .c2
        inc hl
        ld a, (facmo)
        cp (hl)
        jr nz, .c2
        inc hl
        ld a, (faclo)
        sub (hl)
        jr nz, .c2
        pop hl
        ret                             ; A = 0, Z set
.c2:    pop hl
.c:     rra                             ; carry: FAC smaller in magnitude
        push bc
        ld b, a
        ld a, (facsgn)
        xor b
        pop bc
        jr fcomps

; Leave INT(FAC) as a signed 32-bit integer in FACHO..FACLO. FAC < 2^31.
qint:   ld a, (facexp)
        or a
        jr z, clrfac
        sub $A0
        ld b, a
        ld a, (facsgn)
        or a
        jp p, .shift
        ld a, (bits)
        cpl
        ld (bits), a
        call negfch
.shift: ld ix, facexp
        ld a, b                         ; B > -8 (signed): bit by bit
        xor $80
        cp $79
        jr nc, .qint1
        call shiftr
        xor a
        ld (bits), a
        ret
.qint1: xor a
        ld (bits), a
        ld a, (facsgn)
        rla
        ld hl, facho
        rr (hl)
        jp rolshf
clrfac: ld b, a
        ld (facho), a
        ld (facmoh), a
        ld (facmo), a
        ld (faclo), a
        ret

; INT
fn_int: ld a, (facexp)
        cp $A0
        ret nc
        call qint
        ld a, b
        ld (facov), a
        ld a, (facsgn)
        ld c, a
        ld a, b
        ld (facsgn), a
        ld a, c
        sub $80                         ; carry set if positive
        ld a, $A0
        ld (facexp), a
        ld a, (faclo)
        ld (integr), a
        jp fadflt

; Negate the FAC.
negop:  ld a, (facexp)
        or a
        ret z
        ld a, (facsgn)
        cpl
        ld (facsgn), a
        ret

; ---- constants -------------------------------------------------------------
fone:   db $81, $00, $00, $00, $00      ; 1.0
fhalf:  db $80, $00, $00, $00, $00      ; 0.5
ten_c:  db $84, $20, $00, $00, $00      ; 10.0
