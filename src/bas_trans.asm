; Transcendental functions, powers and RND, using the ROM's methods and
; polynomial constants so results match it exactly.

; SQR(X) = X^0.5
fn_sqr: call movaf
        ld hl, fhalf
        call movfm
; FAC = ARG ^ FAC
fpwrt:  ld a, (facexp)
        or a
        jp z, fn_exp                ; X^0 = 1
        ld a, (argexp)
        or a
        jr nz, .x
        ld a, (facsgn)              ; 0^Y
        or a
        jp m, dv0err
        xor a
        jp zerof1
.x:     ld hl, tempf3
        call movmf
        ld b, 0
        ld a, (argsgn)
        or a
        jp p, .fpwr1
        call fn_int                 ; X < 0: only integer powers
        ld hl, tempf3
        call foutcp
        ld a, (argsgn)
        jr nz, .fpwr1
        cpl
        push af
        ld a, (integr)
        ld b, a
        pop af
.fpwr1: call movfa1
        push bc
        call fn_log
        ld hl, tempf3
        call fmult
        call fn_exp
        pop bc
        rr b
        ret nc
        jp negop

; EXP
fn_exp: ld hl, logeb2
        call fmult
        call mov1f
        ld a, (facexp)
        cp $88
        jp nc, mldvex
        call fn_int
        ld a, (integr)
        add a, $81
        jp z, mldvex
        dec a
        push af
        ld hl, tempf1
        call fsub
        ld hl, expcon
        call poly
        xor a
        ld (arisgn), a
        pop af
        call muldiv
        ret

; Evaluate the odd polynomial at HL for X = FAC:
; C0*X + C1*X^3 + C2*X^5 ...
polyx:  ld (polypt), hl
        call mov1f
        ld hl, tempf1
        call fmult                  ; X^2
        call poly1
        ld hl, tempf1
        jp fmult
; Evaluate the polynomial at HL (degree byte, then constants, highest
; power first) for X = FAC.
poly:   ld (polypt), hl
poly1:  call mov2f
        ld hl, (polypt)
        ld a, (hl)
        ld (degree), a
        inc hl
        ld (polypt), hl
.loop:  call fmult
        ld hl, (polypt)
        ld de, 5
        add hl, de
        ld (polypt), hl
        call fadd
        ld hl, tempf2
        ld a, (degree)
        dec a
        ld (degree), a
        jr nz, .loop
        ret

; LOG
fn_log: call sign
        jp m, fcerr
        jp z, fcerr
        ld hl, sqr05
        ld a, (facexp)
        sub $80
        push af
        ld a, $80
        ld (facexp), a
        call fadd
        ld hl, sqr20
        call fdiv
        ld hl, fone
        call fsub
        ld hl, logcn2
        call polyx
        ld hl, neghlf
        call fadd
        pop af
        call finlog
mulln2: ld hl, log2
        jp fmult

; RND
fn_rnd: call sign
        jp m, rnd0.seed
        jr z, rnd0
        call fn_int
        call mov1f
        call rnd0
        ld hl, tempf1
        call fmult
        ld hl, fone
        call fadd
        jp fn_int
rnd0:   ld hl, rndx + 1
        ld de, facho
        ld bc, 4
        ldir
.seed:  ld hl, multr
        ld de, argho
        ld bc, 4
        ldir
        call rndmul
        ld a, (rndtmp + 3)
        add a, $8B
        ld (rndx + 4), a
        ld (faclo), a
        ld a, (rndtmp + 2)
        adc a, $65
        ld (rndx + 3), a
        ld (facmo), a
        ld a, (rndtmp + 1)
        adc a, $B0
        ld (rndx + 2), a
        ld (facmoh), a
        ld a, (rndtmp)
        adc a, $05
        ld (rndx + 1), a
        ld (facho), a
        xor a
        ld (facsgn), a
        ld a, $80
        ld (facexp), a
        ld a, (resmo)
        ld (facov), a
        jp normal

; COS(X) = SIN(X + PI/2)
fn_cos: ld hl, pi2
        call fadd
; SIN
fn_sin: call movaf
        ld hl, twopi
        ld a, (argsgn)
        ld b, a
        call fdivf
        call movaf
        call fn_int
        xor a
        ld (arisgn), a
        call fsubt
        ld hl, fr4
        call fsub
        ld a, (facsgn)
        ld (sinqd), a
        or a
        jp p, .sin1
        call faddh
        ld a, (facsgn)
        or a
        jp m, .sin2
        ld a, (tansgn)
        cpl
        ld (tansgn), a
.sin1:  call negop
.sin2:  ld hl, fr4
        call fadd
        ld a, (sinqd)
        or a
        jp p, .sin3
        call negop
.sin3:  ld hl, sincon
        jp polyx

; TAN
fn_tan: call mov1f
        xor a
        ld (tansgn), a
        call fn_sin
        ld hl, tempf3
        call movmf
        ld hl, tempf1
        call movfm
        xor a
        ld (facsgn), a
        ld a, (tansgn)              ; COS via the SIN code
        ld (sinqd), a
        call fn_sin.sin1
        ld a, (facexp)
        or a
        jp z, overr
        ld hl, tempf3
        jp fdiv

; ATN
fn_atn: ld a, (facsgn)
        push af
        or a
        call m, negop
        ld a, (facexp)
        push af
        cp $81
        jr c, .atn2
        ld hl, fone
        call fdiv
.atn2:  ld hl, atncon
        call polyx
        pop af
        cp $81
        jr c, .atn3
        ld hl, pi2
        call fsub
.atn3:  pop af
        or a
        ret p
        jp negop

; FIX
fn_fix: ld a, (facsgn)
        or a
        jp p, fn_int
        call negop
        call fn_int
        jp negop

; ---- constants (the ROM's) ---------------------------------------------------
sqr05:  db $80, $35, $04, $F3, $34
sqr20:  db $81, $35, $04, $F3, $34
neghlf: db $80, $80, $00, $00, $00
log2:   db $80, $31, $72, $17, $F8
logeb2: db $81, $38, $AA, $3B, $29
pi2:    db $81, $49, $0F, $DA, $A2
twopi:  db $83, $49, $0F, $DA, $A2
fr4:    db $7F, $00, $00, $00, $00
multr:  db $40, $E6, $4D, $AB
logcn2: db $03
        db $7F, $5E, $56, $CB, $79
        db $80, $13, $9B, $0B, $64
        db $80, $76, $38, $93, $16
        db $82, $38, $AA, $3B, $20
expcon: db $07
        db $71, $34, $58, $3E, $56
        db $74, $16, $7E, $B3, $1B
        db $77, $2F, $EE, $E3, $85
        db $7A, $1D, $84, $1C, $2A
        db $7C, $63, $59, $58, $0A
        db $7E, $75, $FD, $E7, $C6
        db $80, $31, $72, $18, $10
        db $81, $00, $00, $00, $00
sincon: db $05
        db $84, $E6, $1A, $2D, $1B
        db $86, $28, $07, $FB, $F8
        db $87, $99, $68, $89, $01
        db $87, $23, $35, $DF, $E1
        db $86, $A5, $5D, $E7, $28
        db $83, $49, $0F, $DA, $A2
atncon: db $0B
        db $76, $B3, $83, $BD, $D3
        db $79, $1E, $F4, $A6, $F5
        db $7B, $83, $FC, $B0, $10
        db $7C, $0C, $1F, $67, $CA
        db $7C, $DE, $53, $CB, $C1
        db $7D, $14, $64, $70, $4C
        db $7D, $B7, $EA, $51, $7A
        db $7D, $63, $30, $88, $7E
        db $7E, $92, $44, $99, $3A
        db $7E, $4C, $CC, $91, $C7
        db $7F, $AA, $AA, $AA, $13
        db $81, $00, $00, $00, $00
