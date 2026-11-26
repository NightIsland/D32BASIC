; Next extension: PMODE 5, 256x192 in 256 colours, with two screens.
;
; A Dragon gives ?FC ERROR for PMODE 5, so giving it a meaning changes no
; Dragon program. The screens are not in the workspace: each is a whole
; Layer 2 picture (48K, one byte a point) in its own Next banks, so PCLEAR,
; MEM and PEEK/POKE are unchanged. SCREEN 1 shows a screen by pointing
; Layer 2 at it, so drawing on the screen on show appears at once.
;
; The graphics statements in bas_graph*.asm work in PMODE 5 unchanged: in
; this mode a "point address" from GENADR is H = y, L = x (the bits in A
; are $FF), and the few routines that touch a point call in here.
;
; A point is reached by paging its 8K of the screen into slot 1
; ($2000-$3FFF) for a moment. This code is in bank 5 and the frame
; interrupt never touches slot 1, so that is safe with interrupts on.
; Nothing here may call the core while a screen page is in slot 1.
;
; Colours 0-8 are the Dragon's (black, then green to orange as in
; COLOR), 9-255 the Next's standard RRRGGGBB colours. They come from Layer
; 2's second palette, which only PMODE 5 shows.

P5PAGE1         EQU 24              ; screen 1: banks 12-14 (8K pages 24-29)
P5PAGE2         EQU 32              ; screen 2: banks 16-18 (8K pages 32-37)
P5FORE          EQU 5               ; colours after PMODE 5: buff on black

; ---- set-up ------------------------------------------------------------------
; At power-on: draw on screen 1, both screens black, and the palette.
p5init: xor a
        ld (p5page), a
        ld (p5shwn), a
        ld a, P5PAGE1
        ld (p5draw), a
        ld (dsp5pg), a
        ld c, P5PAGE1
        xor a
        call p5fill
        ld c, P5PAGE2
        xor a
        call p5fill
        nextreg $43, $50            ; write Layer 2's second palette
        nextreg $40, 0
        nextreg $41, 0              ; 0: black
        ld hl, gr_pal               ; 1-8: the Dragon's colours
        ld b, 8
.drg:   ld a, (hl)
        nextreg $41, a
        inc hl
        djnz .drg
        ld a, 9                     ; 9-255: the standard colours
.std:   nextreg $41, a
        inc a
        jr nz, .std
        nextreg $43, 0              ; first palettes on show
        ret

; ---- PMODE 5[,screen] -----------------------------------------------------------
p5pmod: ld a, 5
        ld (scmode), a
        ld a, P5FORE
        ld (forclr), a
        xor a
        ld (bakclr), a
        ld e, 1                     ; no screen given: screen 1
        call chrgot
        jr z, p5sel
; ",screen" (PMODE ,n in PMODE 5).
p5pgn:  call chkcom
        call getbyt
p5sel:  ld a, e
        dec a
        cp 2
        jp nc, fcerr
        ld (p5page), a
        call p5first
        ld (p5draw), a
        ret

; A = the first 8K page of screen A (0 or 1).
p5first:
        or a
        ld a, P5PAGE1
        ret z
        ld a, P5PAGE2
        ret

; ---- showing a screen ---------------------------------------------------------------
; Show the PMODE 5 screen DSP5PG: Layer 2 there, with the second palette.
; Moving from one screen to the other waits for the frame interrupt first,
; so the picture never changes part-way down.
p5disp: ld a, (p5shwn)
        or a
        jr z, .set                  ; no PMODE 5 screen on show
        ld b, a
        ld a, (dsp5pg)
        cp b
        jr z, .set
        halt
.set:   ld a, (dsp5pg)
        ld (p5shwn), a
        srl a                       ; its 16K bank
        nextreg $12, a
        nextreg $43, $04            ; Layer 2's second palette
        nextreg $17, 0
        ret

; Back to the text screen's Layer 2 and palette.
p5off:  xor a
        ld (p5shwn), a
        nextreg $12, L2_BANK
        nextreg $43, 0
        ret

; ---- points -------------------------------------------------------------------------
; Page in point HL (H = y, L = x) of the screen being drawn on: HL = its
; address in slot 1. Preserves BC, DE.
p5map:  ld a, h
        rlca
        rlca
        rlca
        and 7                       ; y / 32: which 8K of the screen
        push bc
        ld b, a
        ld a, (p5draw)
        add a, b
        nextreg $51, a
        pop bc
        ld a, h
        and $1F
        or $20
        ld h, a
        ret

; The core back in slot 1.
p5unmp: nextreg $51, CORE_PAGE + 1
        ret

; A = the colour of point HL. Preserves all but AF.
p5get:  push hl
        call p5map
        ld a, (hl)
        call p5unmp
        pop hl
        ret

; Set point HL to ACTCLR; PNTCHF records a change. Preserves all but the
; flags.
p5pact: push af
        push hl
        call p5map
        ld a, (actclr)
        cp (hl)
        jr z, .same
        ld (hl), a
        ld a, 1
        ld (pntchf), a
.same:  call p5unmp
        pop hl
        pop af
        ret

; PAINT's border test: Z if XSTORE,YSTORE has the border colour. HL = the
; point, A = $FF.
p5brd:  call genadr
        call p5get
        ld b, a
        ld a, (pntclr)
        cp b
        ld a, $FF
        ret

; PPOINT(x,y) in PMODE 5: the colour, 0-255.
p5ppnt: call p5get
        ld e, a
        jp sngflt

; ---- PCLS and PCOPY -------------------------------------------------------------------
; PCLS: fill the screen being drawn on with colour A.
p5pcls: ld hl, p5draw
        ld c, (hl)
; Fill the screen starting at 8K page C with colour A.
p5fill: ld b, 6
.pg:    push bc
        push af
        ld a, c
        nextreg $51, a
        pop af
        ld hl, $2000
        ld de, $2001
        ld bc, $1FFF
        ld (hl), a
        ldir
        pop bc
        inc c
        djnz .pg
        jp p5unmp

; PCOPY screen TO screen: the whole picture, 128 bytes at a time through
; P5BUF, so only slot 1 is ever paged and interrupts stay on.
P5BUF           EQU rlbuf           ; FREAD's line buffer, free between statements
p5pcop: call getbyt
        call p5scr
        push af
        ld a, TK_TO
        call synchr
        call getbyt
        call p5scr
        ld e, a                     ; E = to
        pop af
        ld d, a                     ; D = from
        ld hl, $2000                ; HL = where in the 8K page
        ld b, 6
.pg:    push bc
.ch:    ld a, d
        nextreg $51, a
        push de
        ld de, P5BUF
        ld bc, 128
        ldir
        pop de
        ld a, e
        nextreg $51, a
        push de
        ld de, -128
        add hl, de
        ex de, hl                   ; DE = the same place
        ld hl, P5BUF
        ld bc, 128
        ldir
        ex de, hl                   ; HL = the next place
        pop de
        ld a, h
        cp $40
        jr nz, .ch
        ld h, $20
        inc d
        inc e
        pop bc
        djnz .pg
        jp p5unmp
; A = the first 8K page of screen E (1 or 2).
p5scr:  ld a, e
        dec a
        cp 2
        jp nc, fcerr
        jp p5first

; ---- GET and PUT ----------------------------------------------------------------------
; One array byte a point, row by row. XSTORE,YSTORE is the top left
; corner, X2STOR+1 points a row and Y2STOR+1 rows. PUT's action applies
; to each point: PSET copies, PRESET copies inverted, AND and OR combine
; with the screen, NOT inverts the screen. The array must hold the whole
; area, or ?FC ERROR before anything is copied.
p5gtpt: ld hl, (x2stor)
        inc hl
        ld (p5cols), hl
        ld a, (y2stor)
        inc a
        ld (p5rows), a
        ld b, a                     ; HL = points in all
        ld de, (p5cols)
        ld hl, 0
.mul:   add hl, de
        djnz .mul
        ld de, (aryidx)
        add hl, de                  ; the last array byte used
        ld de, (aryfin)
        or a
        sbc hl, de
        jp nc, fcerr
        ld hl, $0000                ; the action, as two instructions
        ld a, (gtptfl)
        or a
        jr z, .act
        ld a, (ggrpfl)
        or a
        jr z, .act                  ; PUT with no action: copy
        ld a, (putac0)
        add a, a
        add a, a
        ld b, a
        ld a, (putac1)
        add a, b                    ; PSET 1, PRESET 4, OR 9, AND 2, NOT 15
        cp 4
        ld hl, $002F                ; PRESET: cpl
        jr z, .act
        cp 9
        ld hl, $00B6                ; OR: or (hl)
        jr z, .act
        cp 2
        ld hl, $00A6                ; AND: and (hl)
        jr z, .act
        cp 15
        ld hl, $2F7E                ; NOT: ld a,(hl) / cpl
        jr z, .act
        ld hl, $0000                ; PSET: as it is
.act:   ld (.op), hl
        ld de, (aryidx)
        inc de                      ; DE = the array's first byte
        ld a, (ystore)
        ld h, a
.row:   ld a, (xstore)
        ld l, a
        push hl
        call p5map
        ld bc, (p5cols)
        ld a, (gtptfl)
        or a
        jr nz, .put
        ldir                        ; GET: screen to array
        jr .next
.put:   ld a, (de)
.op:    nop
        nop
        ld (hl), a
        inc hl
        inc de
        dec bc
        ld a, b
        or c
        jr nz, .put
.next:  call p5unmp
        pop hl
        inc h
        ld a, (p5rows)
        dec a
        ld (p5rows), a
        jr nz, .row
        ret
