; PRINT USING, following the Dragon's field rules and number layout.
;
; While the format string is scanned, HL points at the next format
; character and B counts the characters left; both are saved across
; anything that evaluates an expression.

PU_SCI          EQU $01             ; ^^^^ scientific notation
PU_TRL          EQU $04             ; trailing sign
PU_PLS          EQU $08             ; '+' instead of a space when positive
PU_DOL          EQU $10             ; floating dollar sign
PU_AST          EQU $20             ; asterisk fill
PU_COM          EQU $40             ; commas every three digits

prtusg: call frmchk                 ; the format string
        call chkstr
        SYNCHK ';'
        ld hl, (facmo)
        ld (usdptr), hl
        jr u_inius
u_reusst:
        ld a, (usflg)               ; nothing printed in a whole pass?
        or a
        jp z, fcerr
        ld hl, (usdptr)
u_inius: xor a
        ld (usflg), a
        call dscget                 ; B = length, HL = text
        ld a, b
        or a
        jp z, fcerr
prcchr: xor a
        ld (pumask), a
u_plsfin:
        xor a
        ld (fldwid), a
        ld a, (hl)
        inc hl
        cp '!'
        jp z, u_smstrf
        cp '#'
        jp z, u_numnum
        dec b
        jr nz, u_twolft
        call plsprt
        call chrout
finusi: call chrgot                 ; end of the format: more values?
        jr nz, u_reusst
        ld a, (usflg)
        or a
fldfin: jr nz, u_freust              ; Z: finish with a new line
        call crdo
u_freust:
        ld hl, (usdptr)
        jp fretmp

u_twolft:
        cp '+'
        jr nz, u_ntplus
        call plsprt
        ld a, PU_PLS
        ld (pumask), a
        jr u_plsfin
u_ntplus:
        cp '.'
        jp z, u_dotnum
        cp '%'
        jp z, u_bgstrf
        cp (hl)
u_gonwuc:
        jp nz, newuch
        cp '$'
        jr z, u_dolrnm
        cp '*'
        jr nz, u_gonwuc
        ld a, (pumask)
        or PU_AST
        ld (pumask), a
        ld a, b
        cp 2
        jr c, u_ntboth
        inc hl
        ld a, (hl)
        dec hl
        cp '$'
        jr nz, u_ntboth
        dec b                       ; "**$"
        inc hl
        ld a, (fldwid)
        inc a
        ld (fldwid), a
u_dolrnm:
        ld a, (pumask)
        or PU_DOL
        ld (pumask), a
u_ntboth:
        inc hl
        ld a, (fldwid)
        inc a
        ld (fldwid), a
u_numnum:
        xor a
        ld (dpwid), a
u_numlop:
        ld a, (fldwid)
        inc a
        ld (fldwid), a
        dec b
        jr z, u_endnus
        ld a, (hl)
        inc hl
        cp '.'
        jr z, u_aftdot
        cp '#'
        jr z, u_numlop
        cp ','
        jr nz, u_finnum
        ld a, (pumask)
        or PU_COM
        ld (pumask), a
        jr u_numlop
u_dotnum:
        ld a, (hl)
        cp '#'
        jp nz, newuch
        ld a, 1
        ld (dpwid), a
        inc hl
u_aftdot:
        ld a, (dpwid)
        inc a
        ld (dpwid), a
        dec b
        jr z, u_endnus
        ld a, (hl)
        inc hl
        cp '#'
        jr z, u_aftdot
u_finnum:
        cp '^'
        jr nz, u_endnus
        cp (hl)
        jr nz, u_endnus
        inc hl
        cp (hl)
        jr nz, u_nsci1
        inc hl
        cp (hl)
        dec hl
        dec hl
        jr nz, u_endnus
        ld a, b
        cp 4
        jr c, u_endnus
        sub 4
        ld b, a
        inc hl
        inc hl
        inc hl
        inc hl
        ld a, (pumask)
        inc a
        ld (pumask), a
        jr u_endnus
u_nsci1: dec hl
u_endnus:
        dec hl
        ld a, (fldwid)
        inc a
        ld (fldwid), a
        ld a, (pumask)
        and PU_PLS
        jr nz, u_endnum
        ld a, (fldwid)
        dec a
        ld (fldwid), a
        ld a, b
        or a
        jr z, u_endnum
        ld a, (hl)
        sub '-'
        jr z, u_sgntrl
        cp '+' - '-'
        jr nz, u_endnum
        ld a, PU_PLS
u_sgntrl:
        or PU_TRL
        ld c, a
        ld a, (pumask)
        or c
        ld (pumask), a
        dec b
u_endnum:
        call chrgot
        jp z, fldfin
        ld a, b
        ld (usscnt), a
        call frmnum
        ld a, (fldwid)
        ld c, a
        ld a, (dpwid)
        add a, c
        cp 17 + 1
        jp nc, fcerr
        call pufout
        call strout
fnstrf: xor a
        ld (usflg), a
        call chrgot
        jr z, u_crdnus
        ld (usflg), a
        cp ';'
        jr z, u_semusn
        call chkcom
        jr u_crdnus
u_semusn:
        call chrget
u_crdnus:
        ld hl, (usdptr)             ; recompute the format pointer
        call dscget
        ld a, (usscnt)
        ld c, a
        ld a, b
        sub c
        ld e, a
        ld d, 0
        add hl, de
        ld b, c
        ld a, b
        or a
        jp nz, prcchr
        jp finusi

; "!" and "%  %" string fields.
u_smstrf:
        ld a, 1
        ld (fldwid), a
u_isstrf:
        dec b
        call plsprt
        call chrgot
        jp z, fldfin
        ld a, b
        ld (usscnt), a
        call frmevl
        call chkstr
        call frefac                 ; B = length, HL = text
        ld a, (fldwid)
        ld c, a
        cp b
        jr nc, u_fits
        ld b, a
u_fits:  ld a, c
        sub b                       ; spaces to pad
        ld c, a
        inc b
u_sp1:   dec b
        jr z, u_sp2
        ld a, (hl)
        inc hl
        call chrout
        jr u_sp1
u_sp2:   ld a, c
        or a
        jr z, fnstrf
u_sp3:   call outspc
        dec c
        jr nz, u_sp3
        jr fnstrf
u_bgstrf:
        ld a, b
        ld (usscnt), a
        ld (tempx1), hl
        ld a, 2
        ld (fldwid), a
u_lpstrf:
        ld a, (hl)
        cp '%'
        jr z, u_isstrf
        cp ' '
        jr nz, u_nostrf
        ld a, (fldwid)
        inc a
        ld (fldwid), a
        inc hl
        dec b
        jr nz, u_lpstrf
u_nostrf:
        ld hl, (tempx1)
        ld a, (usscnt)
        ld b, a
        ld a, '%'
newuch: call plsprt
        call chrout
        jp prcchr

; Print a '+' that did not start a numeric field. Preserves A.
plsprt: push af
        ld a, (pumask)
        or a
        jr z, u_no
        ld a, '+'
        call chrout
u_no:    pop af
        ret

; ---- number formatting -------------------------------------------------------

; Store A at PUPTR and advance it. Preserves all but flags.
putu:   push hl
        ld hl, (puptr)
        ld (hl), a
        inc hl
        ld (puptr), hl
        pop hl
        ret

; Format the FAC for the current field. Returns HL = the text.
pufout: ld hl, fbuffr + 1
        ld (puptr), hl
        ld b, ' '
        ld a, (pumask)
        and PU_PLS
        jr z, u_npl
        ld b, '+'
u_npl:   ld a, (facsgn)
        or a
        jp p, u_nmi
        xor a
        ld (facsgn), a
        ld b, '-'
u_nmi:   ld a, b
        call putu
        ld a, '0'
        call putu
        ld a, (pumask)
        and PU_SCI
        jp nz, scinot
        ld hl, n_mil
        call foutcp
        jp m, fixnot
        call fout                   ; too big: free format after a '%'
        ld hl, fbuffr
u_fend:  ld a, (hl)
        inc hl
        or a
        jr nz, u_fend
u_up:    dec hl
        ld a, (hl)
        inc hl
        ld (hl), a
        dec hl
        ld de, fbuffr
        or a
        sbc hl, de
        add hl, de
        jr nz, u_up
        ld (hl), '%'
        ret

fixnot: ld a, (facexp)
        ld (tenexp), a
        or a
        call nz, foutn
        ld a, (tenexp)
        or a
        jp m, u_ffxv04
        neg                         ; no fraction digits
        ld c, a
        ld a, (fldwid)
        add a, c
        sub 9
        call fotzer
        call foutcd
        call cnvasc
        ld a, (tenexp)
        call fotzec
        call fouted
foutd:  ld a, (dpwid)
        or a
        jr nz, keepdp
        call unputu
keepdp: dec a
        call fotzer
foutts: call foutzs                 ; A = trailing sign flag, B = sign
        or a
        jr z, u_notrl
        ld a, b
        cp '*'
        jr z, u_notrl
        call putu
u_notrl: ld hl, (puptr)
        ld (hl), 0
        ld hl, fbuffr               ; does it fit the field?
u_foube1:
        inc hl
        ld (tempx1), hl
        ld a, (fdecpt)
        sub l
        ld c, a
        ld a, (fldwid)
        ld b, a
        ld a, c
        sub b
        ret z
        ld a, (hl)
        cp ' '
        jr z, u_foube1
        cp '*'
        jr z, u_foube1
        ld c, 0                     ; count of saved characters
u_foube2:
        ld a, (hl)
        inc hl
        cp '-'
        jr z, u_push
        cp '+'
        jr z, u_push
        cp '$'
        jr z, u_push
        cp '0'
        jr nz, u_foube4
        ld a, (hl)                  ; a digit after the point?
        inc hl
        ld a, (hl)
        dec hl
        call isdigc
        jr c, u_foube4
u_foube3:
        ld a, c                     ; put the saved characters back one
        or a                        ; place further on
        jr z, u_shifted
        pop af
        dec hl
        ld (hl), a
        dec c
        jr u_foube3
u_shifted:
        dec hl
        ld (hl), 0
        jr u_foube1
u_push:  push af
        inc c
        jr u_foube2
u_foube4:
        ld a, c
        or a
        jr z, u_ovf
        pop af
        dec c
        jr u_foube4
u_ovf:   ld hl, (tempx1)
        dec hl
        ld (hl), '%'
        ret

; Fixed point with fraction digits.
u_ffxv04:
        ld a, (dpwid)
        or a
        jr z, u_f5
        dec a
u_f5:    ld hl, tenexp
        add a, (hl)
        jp m, u_f6
        xor a
u_f6:    push af
u_f7:    or a
        jp p, u_f8
        push af
        call div10
        pop af
        inc a
        jr u_f7
u_f8:    pop bc                      ; B = division count
        ld a, (tenexp)
        sub b
        ld (tenexp), a
        add a, 9
        jp m, u_f9
        ld a, (tenexp)
        ld c, a
        ld a, (fldwid)
        sub 9
        sub c
        call fotzer
        call foutcd
        jr u_f10
u_f9:    ld a, (fldwid)
        call fotzer
        call foutdp
        ld a, (tenexp)
        ld c, a
        ld a, -9
        sub c
        call fotzer
        xor a
        ld (deccnt), a
        ld (comcnt), a
u_f10:   call cnvasc
        ld a, (dpwid)
        or a
        jr nz, u_f11
        ld hl, (fdecpt)
        ld (puptr), hl
u_f11:   ld hl, tenexp
        add a, (hl)
        jp keepdp

; Scientific notation.
scinot: ld a, (facexp)
        push af
        or a
        call nz, foutn
        ld a, (dpwid)
        or a
        jr z, u_s3
        dec a
u_s3:    ld hl, fldwid
        add a, (hl)
        ld c, a
        xor a                       ; FBUFFR: 0 trailing sign, -1 leading
        ld (fbuffr), a
        ld a, (pumask)
        and PU_TRL
        jr nz, u_s4
        ld a, $FF
        ld (fbuffr), a
u_s4:    ld a, (fbuffr)
        add a, c
        sub 9
        push af
u_s5:    or a
        jp p, u_s6
        push af
        call div10
        pop af
        inc a
        jr u_s5
u_s6:    pop af
        push af
        or a
        jp m, u_s7
        xor a
u_s7:    neg
        ld hl, fldwid
        add a, (hl)
        inc a
        ld hl, fbuffr
        add a, (hl)
        ld (deccnt), a
        xor a
        ld (comcnt), a
        call cnvasc
        pop af
        call fotzec
        ld a, (dpwid)
        or a
        call z, unputu
        pop af                      ; was the FAC zero?
        ld b, 0
        or a
        jr z, u_fotexp
        ld a, (tenexp)
        add a, 9
        ld hl, fldwid
        sub (hl)
        ld hl, fbuffr
        sub (hl)
        ld b, a
u_fotexp:
        ld c, '+'
        ld a, b
        or a
        jp p, u_fexpls
        ld c, '-'
        neg
        ld b, a
u_fexpls:
        ld a, 'E'
        call putu
        ld a, c
        call putu
        ld a, b
        ld c, '0' - 1
u_fexphi:
        inc c
        sub 10
        jr nc, u_fexphi
        add a, '0' + 10
        ld b, a
        ld a, c
        call putu
        ld a, b
        call putu
        ld hl, (puptr)
        ld (hl), 0
        jp foutts

; Back PUPTR up one place. Preserves A.
unputu: push hl
        ld hl, (puptr)
        dec hl
        ld (puptr), hl
        pop hl
        ret

; Suppress leading zeros and apply asterisk fill and the dollar sign.
; Returns A = nonzero if a trailing sign is wanted, B = the sign character.
foutzs: ld hl, fbuffr + 1
        ld b, (hl)
        ld c, ' '
        ld a, (pumask)
        and PU_AST
        jr z, u_z1
        ld c, '*'
        ld a, b
        cp ' '
        jr nz, u_z1
        ld b, c
u_z1:    push bc
u_z2:    ld (hl), c
        inc hl
        ld a, (hl)
        or a
        jr z, u_z3
        cp 'E'
        jr z, u_z3
        cp '0'
        jr z, u_z2
        cp ','
        jr z, u_z2
        cp '.'
        jr nz, u_z4
u_z3:    dec hl
        ld (hl), '0'
u_z4:    ld a, (pumask)
        and PU_DOL
        jr z, u_z5
        dec hl
        ld (hl), '$'
u_z5:    ld a, (pumask)
        and PU_TRL
        pop bc
        ret nz
        dec hl
        ld (hl), b
        ret

; Carry clear if A is a digit.
isdigc: cp '0'
        ret c
        cp '9' + 1
        ccf
        ret

; Scale the FAC so all its significant digits are in the integer part.
foutn:  xor a
u_n1:    ld (tenexp), a
        ld a, (facexp)
        cp $81
        jr nc, u_n3
        ld hl, n_mil
        call fmult
        ld a, (tenexp)
        sub 9
        jr u_n1
u_n2:    call div10
        ld hl, tenexp
        inc (hl)
u_n3:    ld hl, n_9999
        call foutcp
        jr z, u_n4
        jp p, u_n2
u_n4:    ld hl, n_0999
        call foutcp
        jr z, u_n6
        ret p
u_n6:    call mul10
        ld hl, tenexp
        dec (hl)
        jr u_n4

; Write the FAC's nine digits at PUPTR, with commas and the point.
cnvasc: call faddh
        call qint
        ld ix, foutbl
        ld b, $80
        ld c, 9
u_c10:   call fouted
u_c20:   ld hl, faclo
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
        jr c, u_cy
        bit 7, b
        jr z, u_c20
        jr u_c30
u_cy:    bit 7, b
        jr nz, u_c20
        ld a, b
        sub 11
        neg
        ld b, a
u_c30:   ld a, b
        add a, '0' - 1
        ld b, a
        and $7F
        call putu
        inc ix
        inc ix
        inc ix
        inc ix
        ld a, b
        cpl
        and $80
        ld b, a
        dec c
        jr nz, u_c10
        ld hl, (puptr)
        ld (hl), 0
; Put in the decimal point or a comma when their counts run out.
fouted: ld hl, deccnt
        dec (hl)
        jr nz, u_comma
foutdp: ld hl, (puptr)
        ld (fdecpt), hl
        ld a, '.'
        call putu
        xor a
        ld (comcnt), a
        ret
u_comma: ld hl, comcnt
        dec (hl)
        ret nz
        ld (hl), 3
        ld a, ','
        jp putu

; Set the decimal point and comma counts from TENEXP.
foutcd: ld a, (tenexp)
        add a, 10
        ld (deccnt), a
        inc a
u_cd1:   sub 3
        jr nc, u_cd1
        add a, 5
        ld (comcnt), a
        ld a, (pumask)
        and PU_COM
        ret nz
        ld (comcnt), a
        ret

; A zeros at PUPTR (none if A <= 0).
fotzer: dec a
        ret m
        push af
        ld a, '0'
        call putu
        pop af
        jr fotzer

; A zeros at PUPTR, with commas and the point where they fall.
fotzec: dec a
        ret m
u_lp:    push af
        ld a, '0'
        call putu
        pop af
        or a
        ret z
        push af
        call fouted
        pop af
        dec a
        ret m
        jr u_lp
