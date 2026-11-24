; ===========================================================================
; SOUND, PLAY and AUDIO on the Next's AY chip (channel A).
; The Dragon makes its notes in software through a 6-bit D/A and times them
; from the 50 Hz field interrupt; here the AY makes the tone and the frame
; interrupt does the timing, so PLAY and SOUND last as long as on a Dragon.
; ===========================================================================

AY_REG          EQU $FFFD
AY_DAT          EQU $BFFD

; AY register A = E.
ay_out: push bc
        ld bc, AY_REG
        out (c), a
        ld b, AY_DAT >> 8
        out (c), e
        pop bc
        ret

; Channel A tone period = HL, volume = D (0-15), tone on.
snd_tone:
        ld a, 0
        ld e, l
        call ay_out
        ld a, 1
        ld e, h
        call ay_out
        ld a, 7
        ld e, $3E                   ; tone A only, no noise
        call ay_out
        ld a, 8
        ld e, d
        jr ay_out

; Silence channel A (also called by READY, so an error or BREAK in the
; middle of a note leaves no tone hanging).
snd_off:
        ld a, 8
        ld e, 0
        jr ay_out

; Wait for B frames.
snd_wait:
        ei
.lp:    halt
        djnz .lp
        ret

; SOUND frequency, duration. Both 1-255. The Dragon's pitch is set by a
; delay loop: one cycle takes 4*(5*(256-f)+27) CPU cycles at 0.894886 MHz.
; The AY period is 1.75 MHz/16 over that frequency, about 0.4889 times
; x = 5*(256-f)+27, which is x/2 - 3x/256. The duration is 4*d frames.
st_sound:
        call gnzbyt
        push de
        call chkcom
        call gnzbyt
        pop bc                      ; C = frequency, E = duration
        push de
        ld a, c
        cpl                         ; 255-f
        inc a                       ; 256-f (f is not 0)
        ld l, a
        ld h, 0
        jr nz, .nz
        inc h                       ; f=0 cannot happen, but keep HL=256
.nz:    ld d, h
        ld e, l
        add hl, hl
        add hl, hl
        add hl, de                  ; 5*(256-f)
        ld de, 27
        add hl, de                  ; x
        ld d, h
        ld e, l
        add hl, hl
        add hl, de                  ; 3x
        ld l, h
        ld h, 0                     ; 3x/256
        ex de, hl
        srl h
        rr l                        ; x/2
        or a
        sbc hl, de
        ld d, 15                    ; full swing, like PLAY V31
        call snd_tone
        pop de
        ld a, e
.dur:   ld b, 4
        call snd_wait
        dec a
        jr nz, .dur
        jp snd_off

gcnzby: call chkcom
; E = a byte expression, 1-255.
gnzbyt: call getbyt
        ld a, e
        or a
        ret nz
        jp fcerr

; AUDIO ON|OFF and MOTOR ON|OFF: there is no cassette, so they only check
; the syntax.
st_audio:
st_motor:
        cp TK_OFF
        jr z, .ok
        cp TK_ON
        jp nz, snerr
.ok:    jp chrget

; ---- PLAY ---------------------------------------------------------------------------
; PLAY string
st_play:
        ld hl, 0                    ; the end of X nesting
        push hl
        ld c, 1
        push bc
        call frmevl
plysc4: call frestr                 ; HL = text, B = length
        jr plyset
plycon: pop bc                      ; back out of an X
        pop hl
        ld b, c
plyset: ld a, b
        ld (pstlen), a
        or a
        jr z, plycon
        ld (pstptr), hl
        ld a, h
        or l
        jp z, snd_off
plyscn: ld a, (pstlen)
        or a
        jr z, plycon
        call fetchr
        cp ';'
        jr z, plyscn
        cp "'"
        jr z, plyscn
        cp 'X'
        jr z, pxcutr
        call plydoh
        jr plyscn

; X var; : play the string in var, then carry on with this one.
pxcutr: call varsub
        ld b, 2
        call getstk
        ld hl, (pstptr)
        push hl
        ld a, (pstlen)
        ld c, a
        push bc
        jr plysc4

; One PLAY command, its letter in A.
plydoh: cp 'O'
        jr nz, .v
        ld a, (octave)
        inc a
        ld b, a
        call plyarg
        dec b
        ld a, b
        cp 5
        jp nc, fcerr
        ld (octave), a
        ret
.v:     cp 'V'
        jr nz, .l
        ld a, (volume)
        ld b, a
        call plyarg
        ld a, b
        cp 32
        jp nc, fcerr
        ld (volume), a
        ret
.l:     cp 'L'
        jr nz, .t
        ld a, (lnote)
        ld b, a
        call plyarg
        ld a, b
        or a
        jp z, fcerr
        ld (lnote), a
        xor a
        ld (dotflg), a
.dot:   ld a, (pstlen)              ; count the dots after it
        or a
        ret z
        call fetchr
        cp '.'
        jp nz, fetbak
        ld hl, dotflg
        inc (hl)
        jr .dot
.t:     cp 'T'
        jr nz, .p
        ld a, (tempo)
        ld b, a
        call plyarg
        ld a, b
        or a
        jp z, fcerr
        ld (tempo), a
        ret
.p:     cp 'P'
        jr nz, .n
        call fetchr
        call plyval
        ld a, b
        or a
        jp z, fcerr
        ld a, (dotflg)              ; a rest: silent, undotted, length B
        push af
        xor a
        ld (dotflg), a
        ld d, 0
        call plyhold
        pop af
        ld (dotflg), a
        ret
.n:     cp 'N'
        jr nz, .imp
        call fetchr
.imp:   cp 'A'
        jr c, .num
        cp 'G'+1
        jr nc, .num
        sub 'A'
        ld e, a
        ld d, 0
        ld hl, notetb
        add hl, de
        ld b, (hl)
        ld a, (pstlen)
        or a
        jr z, plyb
        call fetchr
        cp '#'
        jr z, .shp
        cp '+'
        jr nz, .flt
.shp:   inc b
        jr plyb
.flt:   cp '-'
        jr nz, .nsf
        dec b
        jr plyb
.nsf:   call fetbak
        jr plyb
.num:   call plyval
; Play note B (1-12) in the current octave for the current length.
plyb:   dec b
        ld a, b
        cp 12
        jp nc, fcerr
        ld a, (octave)
        add a, 4
        ld c, a                     ; shift: octave 1 is /16
        ld l, b
        ld h, 0
        add hl, hl
        ld de, octtab
        add hl, de
        ld a, (hl)
        inc hl
        ld h, (hl)
        ld l, a
.sh:    srl h
        rr l
        dec c
        jr nz, .sh
        jr nc, .rnd
        inc hl                      ; round
.rnd:   ld a, (volume)
        ld e, a
        ld d, 0
        push hl
        ld hl, voltab
        add hl, de
        ld d, (hl)
        pop hl
        ld a, (lnote)
        ld b, a
; Sound period HL at volume D for note length B, then go silent if D=0.
; The Dragon counts 255 (or 255*(dots+2)/2) down by length*tempo each
; field, and the note ends when the count runs out.
plyhold:
        push bc
        call snd_tone
        pop bc
        ld a, (tempo)
        ld e, a
        ld d, b
        mul d, e
        push de                     ; the amount to take off each frame
        ld hl, 255
        ld a, (dotflg)
        or a
        jr z, .cnt
        add a, 2
        ld e, a
        ld d, 255
        mul d, e
        srl d
        rr e
        ex de, hl
.cnt:   pop de
.lp:    ld b, 1
        call snd_wait
        or a
        sbc hl, de
        jr c, .end
        jr z, .end
        jr .lp
.end:   ret

; PLAY's V 0-31 sets a linear amplitude on the Dragon; the AY's levels are
; about 3 dB apart, so map by loudness.
voltab: db 0, 5, 7, 8, 9, 10, 10, 11, 11, 11, 12, 12, 12, 12, 13, 13
        db 13, 13, 13, 14, 14, 14, 14, 14, 14, 14, 14, 15, 15, 15, 15, 15

; The notes A-G as 1-12 (C=1).
notetb: db 10, 12, 1, 3, 5, 6, 8

; 1.75 MHz over the frequency of each note of octave 1, C (65.41 Hz) to B.
; The tone period for octave n is this over 2^(n+3).
octtab: dw 26755, 25254, 23836, 22498, 21235, 20043
        dw 18918, 17856, 16854, 15908, 15015, 14172
