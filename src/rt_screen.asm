; Text screen: the 32x16 buffer at SCRADR, Dragon screen-output semantics,
; and the Layer 2 renderer that draws each cell as an 8x12 glyph.
;
; Codes in the buffer are Dragon VDG codes: $40-$7F normal (dark on green),
; $00-$3F inverse, $80-$FF semigraphics-4 blocks (bits 6-4 colour, bits 3-0
; the quadrants TL TR BL BR).

INVSP           EQU $60             ; green space
L2_PORT         EQU $123B

COL_GREEN       EQU $1C             ; RGB332
COL_DKGREEN     EQU $04
COL_BLACK       EQU $00
COL_ORANGE      EQU $F0
COL_DKORANGE    EQU $44

; ---- SCROUT: write character A to the screen at the cursor --------------
; BS backs up one cell, CR clears to end of line, other control characters
; are ignored, lower case shows as inverse upper case, the screen scrolls at
; the bottom. Preserves all registers.
scrout:
        push af
        push bc
        push de
        push hl
    IF TESTMODE
        call dbg_echo
    ENDIF
        push af                     ; output brings the text screen back
        call samalp
        pop af
        ld hl, (curadr)
        cp 8
        jr nz, .notbs
        ld de, SCRADR
        or a
        sbc hl, de
        add hl, de
        jr z, .exit                 ; can't back up from home
        dec hl
        ld a, INVSP
        ld (hl), a
        call render_hl
        jr .newpos
.notbs: cp 13
        jr nz, .notcr
        call clreol
        jr .newpos
.notcr: cp ' '
        jr c, .exit
        bit 7, a
        jr nz, .put
        cp $40
        jr c, .inv
        cp $60
        jr c, .put
        and $DF
.inv:   xor $40
.put:   ld (hl), a
        call render_hl
        inc hl
.newpos:
        ld (curadr), hl
        ld de, SCREND
        or a
        sbc hl, de
        jr c, .exit
        call scroll_up
.exit:  pop hl
        pop de
        pop bc
        pop af
        ret

    IF TESTMODE
; Mirror the oracle's view of SCROUT: printable ASCII as is, CR as LF.
dbg_echo:
        push af
        ld a, (dbg_on)
        or a
        jr z, .off
        pop af
        cp 13
        jr nz, .p
        ld a, 10
        call dbg_putc
        ld a, 13
        ret
.p:     cp ' '
        ret c
        cp $7F
        ret nc
        jp dbg_putc
.off:   pop af
        ret
    ENDIF

; Fill from HL to the end of its line with green spaces. Returns HL at the
; start of the next line.
clreol:
        ld (hl), INVSP
        call render_hl
        inc hl
        ld a, l
        and $1F
        jr nz, clreol
        ret

; Scroll the buffer up a line, clear the bottom line, cursor to its start.
scroll_up:
        ld hl, SCRADR + 32
        ld de, SCRADR
        ld bc, 512 - 32
        ldir
        ld a, (l2_scroll)           ; move the picture by 12 lines too
        add a, 12
        cp 192
        jr c, .s
        xor a
.s:     ld (l2_scroll), a
        nextreg $17, a
        ld hl, SCRADR + 480
        ld (curadr), hl
        call clreol
        ld hl, SCRADR + 480
        ld (curadr), hl
        ret

; Clear the screen to green spaces, cursor home.
grnchr:
        ld a, INVSP
; Fill the screen with A, cursor home.
clsfill:
        ld hl, SCRADR
        ld (curadr), hl
        ld (hl), a
        ld de, SCRADR + 1
        ld bc, 511
        ldir
        xor a
        ld (l2_scroll), a
        ld a, (dspon)               ; graphics on show keep their place
        or a
        jr nz, .nos
        nextreg $17, 0
.nos:   jp render_all

; ---- renderer --------------------------------------------------------------

; Redraw the cell at buffer address HL. Preserves all registers.
render_hl:
        push af
        ld a, (dspon)               ; graphics on show: the buffer only
        or a
        jr z, .text
        pop af
        ret
.text:
        push bc
        push hl
        ld a, (hl)
        push af
        ld bc, SCRADR
        or a
        sbc hl, bc                  ; offset 0-511
        ld a, l
        and $1F
        ld c, a                     ; column
        add hl, hl
        add hl, hl
        add hl, hl
        ld b, h                     ; row
        pop af
        call render_cell
        pop hl
        pop bc
        pop af
        ret

; Redraw every cell.
render_all:
        ld hl, SCRADR
.l:     call render_hl
        inc hl
        ld a, h
        cp high SCREND
        jr nz, .l
        ret

; Draw character A at row B (0-15), column C (0-31).
render_cell:
        push de
        push hl
        push ix
        ld e, a
        ld a, b                     ; y = (row*12 + scroll) mod 192
        add a, a
        add a, b
        add a, a
        add a, a
        ld hl, l2_scroll
        add a, (hl)
        jr c, .wrap
        cp 192
        jr c, .y
.wrap:  sub 192
.y:     ld (rc_y), a
        ld a, c
        add a, a
        add a, a
        add a, a
        ld (rc_x), a
        ld a, e
        bit 7, a
        jr nz, .sg
        ; text glyph
        and $40
        jr z, .inverse
        ld ix, (txtcl)              ; fg dark, bg light
        jr .glyph
.inverse:
        ld a, (txtcl)
        ld ixh, a
        ld a, (txtcl + 1)
        ld ixl, a
.glyph: ld a, e
        and $3F
        ld l, a
        ld h, 0
        add hl, hl
        add hl, hl                  ; *4
        ld d, h
        ld e, l
        add hl, hl                  ; *8
        add hl, de                  ; *12
        ld de, font_glyphs
        add hl, de
        jr .draw
.sg:    ; semigraphics: build a 12-row pattern in rc_pat
        push bc
        ld a, e
        rrca
        rrca
        rrca
        rrca
        and 7
        ld hl, sg_colours
        add a, l
        ld l, a
        adc a, h
        sub l
        ld h, a
        ld a, (hl)
        ld ixh, a                   ; fg = block colour
        ld ixl, COL_BLACK
        ld a, e
        call .half                  ; top: bits 3,2
        ld hl, rc_pat
        ld b, 6
.t:     ld (hl), d
        inc hl
        djnz .t
        ld a, e
        add a, a
        add a, a
        call .half                  ; bottom: bits 1,0
        ld b, 6
.b:     ld (hl), d
        inc hl
        djnz .b
        pop bc
        ld hl, rc_pat
        jr .draw
.half:  ld d, 0                     ; A bits 3,2 -> D = $F0/$0F mask
        bit 3, a
        jr z, .h1
        ld d, $F0
.h1:    bit 2, a
        ret z
        push af
        ld a, d
        or $0F
        ld d, a
        pop af
        ret

.draw:  ; HL = 12 pattern bytes, IXH = fg, IXL = bg
        push bc
        ld b, 12
.row:   push bc
        ld a, (rc_y)
        ld e, a
        and $C0                     ; which 64-line third
        or 3                        ; write-map on, Layer 2 visible
        ld bc, L2_PORT
        out (c), a
        ld a, e
        and $3F
        ld d, a
        ld a, (rc_x)
        ld e, a                     ; DE = address in the $0000-$3FFF window
        ld c, (hl)
        inc hl
        ld b, 8
.px:    sla c
        ld a, ixh
        jr c, .on
        ld a, ixl
.on:    ld (de), a
        inc e
        djnz .px
        ld a, (rc_y)
        inc a
        ld (rc_y), a
        pop bc
        djnz .row
        ld a, 2                     ; write-map off
        ld bc, L2_PORT
        out (c), a
        pop bc
        pop ix
        pop hl
        pop de
        ret

; Dragon semigraphics colours: green yellow blue red buff cyan magenta orange
sg_colours:
        db $1C, $FC, $03, $E0, $DB, $1F, $E3, $F0

        INCLUDE "font.inc"
