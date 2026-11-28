; Graphics: PMODE pages kept in the Dragon's own format at the bottom of the
; workspace, the statements that draw into them, and the renderer that
; copies what the Dragon would show onto Layer 2.
;
; Graphics memory is laid out exactly as on a Dragon (8 pages of 1.5K from
; SCRBAS, the program above the last page PCLEAR keeps), so PPOINT, GET,
; PUT, PCOPY and PEEK see the same bytes. Every byte a graphics statement
; changes, or POKE writes, is redrawn on Layer 2 at once if it is on show.
;
; Coordinates follow the Dragon: X 0-255, Y 0-191 whatever the mode,
; scaled down for the lower-resolution modes.

GRBASE          EQU $80             ; page of graphics page 1 (Dragon: $06)

; ---- set-up ------------------------------------------------------------------
; Graphics state at power-on: PMODE 0,1, colours 3 on 0, text shown.
grinit:
        ld a, GRBASE
        ld (scrbas), a
        ld hl, GRBASE << 8
        ld (scbase), hl
        ld hl, (GRBASE + 6) << 8
        ld (sctop), hl
        xor a
        ld (scmode), a
        ld (bakclr), a
        ld (sccss), a
        ld (piacss), a
        ld (dspon), a
        ld a, 16
        ld (scwid), a
        ld a, 3
        ld (forclr), a
        ld hl, GRBASE << 8          ; clear the graphics memory
        ld de, (GRBASE << 8) + 1
        ld bc, $3000 - 1
        ld (hl), 0
        ldir
        call p5init
        jp txtcol

; ---- coordinates ---------------------------------------------------------------
; Read "x,y" into XSTORE/YSTORE, X limited to 255 and Y to 191.
scnpnt: ld ix, xstore
scnpni: push ix
        call evladr                 ; DE = x
        push de
        call chkcom
        call getbyt                 ; E = y
        pop hl
        pop ix
; HL = x, E = y: store them at IX, limited to the screen.
scnpn2: ld a, e
        cp 192
        jr c, .y
        ld a, 191
.y:     ld (ix + 2), a
        ld (ix + 3), 0
        ld a, h
        or a
        jr z, .x
        ld hl, 255
.x:     ld (ix + 0), l
        ld (ix + 1), h
        ret

; Scale XSTORE/YSTORE (or the pair at IX) to the current mode's resolution.
gscale: ld ix, xstore
gscalc: ld a, (scmode)
        cp 2
        jr nc, .x
        srl (ix + 3)
        rr (ix + 2)
.x:     cp 4
        ret nc
        srl (ix + 1)
        rr (ix + 0)
        ret
gscal2: call gscale
        ld ix, x2stor
        jr gscalc

; "(x,y)" into XSTORE/YSTORE.
onecrd: call chkopn
        call scnpnt
        jp chkcls

; "[(x1,y1)]-(x2,y2)": XSTORE/YSTORE and X2STOR/Y2STOR. A missing first
; point is the end of the last LINE.
crdget: ld hl, (lsavex)
        ld (xstore), hl
        ld hl, (lsavey)
        ld (ystore), hl
        cp TK_MINUS
        call nz, onecrd
        ld a, TK_MINUS
        call synchr
        call chkopn
        ld ix, x2stor
        call scnpni
        jp chkcls

; HL = address of the byte holding the scaled point XSTORE/YSTORE, A = the
; bits of that point in it. Preserves BC.
genadr: ld a, (scmode)
        cp 5
        jr z, .p5
        ld a, (ystore)
        ld l, a
        ld h, 0
        add hl, hl
        add hl, hl
        add hl, hl
        add hl, hl
        ld a, (scwid)
        cp 32
        jr nz, .w16
        add hl, hl
.w16:   ld de, (scbase)
        add hl, de
        ld a, (scmode)
        rra
        ld a, (xstore)
        jr c, .col
        ld e, a                     ; two-colour: 8 points a byte
        srl e
        srl e
        srl e
        ld d, 0
        add hl, de
        and 7
        ld e, a
        ld a, $80
        inc e
.bw:    dec e
        ret z
        rrca
        jr .bw
.col:   ld e, a                     ; four-colour: 4 points a byte
        srl e
        srl e
        ld d, 0
        add hl, de
        and 3
        ld e, a
        ld a, $C0
        inc e
.cl:    dec e
        ret z
        rrca
        rrca
        jr .cl
.p5:    ld a, (ystore)              ; PMODE 5: H = y, L = x
        ld h, a
        ld a, (xstore)
        ld l, a
        ld a, $FF
        ret

; Move the point at HL/A one place right (A = its bits). Preserves BC, DE.
ginx:   push af
        ld a, (scmode)
        cp 5
        jr z, .p5
        rra
        jr c, .col
        pop af
        rrca
        ret nc
        inc hl
        ret
.col:   pop af
        rrca
        rrca
        ret nc
        inc hl
        ret
.p5:    pop af
        inc l
        ret

; Move HL down one row. Preserves all but HL.
ginyl:  push de
        push af
        ld a, (scmode)
        cp 5
        jr z, .p5
        ld a, (scwid)
        ld e, a
        ld d, 0
        add hl, de
        pop af
        pop de
        ret
.p5:    inc h
        pop af
        pop de
        ret

; Set the point at HL (bits A) to the active colour. PNTCHF records any
; change. Preserves all but the flags.
grpact: push af
        ld a, (scmode)
        cp 5
        jr z, .p5
        pop af
        push af
        push bc
        push de
        ld b, a
        ld c, (hl)
        cpl
        and c
        ld e, a
        ld a, (actcle)
        and b
        or e
        ld (hl), a
        cp c
        jr z, .same
        ld a, 1
        ld (pntchf), a
        call gdirty
.same:  pop de
        pop bc
        pop af
        ret
.p5:    pop af
        jp p5pact

; ---- colours -------------------------------------------------------------------
; Read a colour 0-8 into E as the mode's colour number 0-3.
getclr: call getbyt
getclx: ld a, (scmode)
        cp 5
        ret z                       ; PMODE 5: 0-255 as they are
        ld a, e
        cp 9
        jp nc, fcerr
        cp 5
        jr c, .lo
        sub 4
.lo:    ld e, a
        ld a, (scmode)
        rra
        jr nc, .bw
        ld a, e                     ; four colours: 1-4 are 0-3, 0 is 3
        or a
        jr nz, .dec
        ld a, 4
.dec:   dec a
        ld e, a
        ret
.bw:    ld a, e                     ; two colours: odd is on, even off
        rra
        ld e, 3
        ret c
        ld e, 0
        ret

; The colour for PSET (foreground) or PRESET (background) into ACTCLR and
; ACTCLE (the colour repeated through a byte).
defcol: ld a, (setflg)
        or a
        ld a, (forclr)
        jr nz, deffor
        ld a, (bakclr)
deffor: ld (actclr), a
        ld e, a
        ld a, (scmode)
        cp 5
        ld a, e
        jr z, .p5
        and 3
        ld e, a
        add a, a
        add a, a
        or e
        ld e, a
        add a, a
        add a, a
        add a, a
        add a, a
        or e
.p5:    ld (actcle), a
        ret

; An optional ",colour" before ')' or the end.
cmcolr: call defcol
        call chrgot
        ret z
        cp ')'
        ret z
        call chkcom
        cp ','
        ret z
        call getclr
        ld a, e
        call deffor
        jp chrgot

; ---- PCLEAR, PMODE, SCREEN, COLOR, PCLS, PCOPY ---------------------------------
st_pclear:
        call getbyt
        ld a, e
        or a
        jp z, fcerr
        cp 9
        jp nc, fcerr
        ld b, a                     ; new TXTTAB = SCRBAS + 6n pages, +1
        add a, a
        add a, b
        add a, a
        ld hl, scrbas
        add a, (hl)
        ld d, a
        ld e, 1
        ld a, (sctop + 1)           ; not over the current graphics page
        dec a
        cp d
        jp nc, fcerr
        ld hl, (txttab)             ; BC = new - old TXTTAB
        ex de, hl
        or a
        sbc hl, de
        ld b, h
        ld c, l
        ld hl, (vartab)             ; the new VARTAB must leave room
        add hl, bc
        ld de, $200
        add hl, de
        ld de, (stktop)
        or a
        sbc hl, de
        jp nc, fcerr
        ld hl, (curlin)             ; running: keep TXTPTR on its statement
        ld a, h
        and l
        inc a
        jr z, .direct
        ld hl, (txtptr)
        add hl, bc
        ld (txtptr), hl
.direct:
        ld hl, (vartab)             ; the program's length
        ld de, (txttab)
        or a
        sbc hl, de
        push hl
        ld hl, (vartab)             ; VARTAB moves with it
        add hl, bc
        ld (vartab), hl
        ex de, hl                   ; HL = old TXTTAB
        push hl
        add hl, bc
        ex de, hl                   ; DE = new TXTTAB
        pop hl
        ld (txttab), de
        bit 7, b                    ; moving down?
        pop bc                      ; BC = length
        jr z, .up
        ldir
        jr .set
.up:    add hl, bc
        dec hl
        ex de, hl
        add hl, bc
        dec hl
        ex de, hl
        lddr
.set:   ld hl, (txttab)
        dec hl
        ld (hl), 0
        call cheada
        call clearc
        jp newstt

; PMODE [mode][,page]
scrtab: db 16, 6, 32, 12, 16, 12, 32, 24, 32, 24

st_pmode:
        cp ','
        jr z, .page
        call getbyt
        ld a, e
        cp 5
        jp z, p5pmod
        jp nc, fcerr
        ld hl, scrtab
        add a, a
        add a, l
        ld l, a
        adc a, h
        sub l
        ld h, a                     ; HL = this mode's entry
        ld a, (scrbas)
        ld (scbase + 1), a
        inc hl
        add a, (hl)                 ; top of the screen
        ld b, a
        ld a, (txttab + 1)
        cp b
        jp c, fcerr                 ; no memory for that mode
        ld a, b
        ld (sctop + 1), a
        xor a
        ld (scbase), a
        ld (sctop), a
        ld (bakclr), a
        dec hl
        ld a, (hl)
        ld (scwid), a
        ld a, e
        ld (scmode), a
        ld a, 3
        ld (forclr), a
        call chrgot
        ret z
.page:  ld a, (scmode)
        cp 5
        jp z, p5pgn
        call chkcom
        call getbyt
        ld a, e
        or a
        jp z, fcerr
        dec a
        ld b, a
        add a, a
        add a, b
        add a, a                    ; 6 pages per graphics page
        ld hl, scrbas
        add a, (hl)
        ld c, a                     ; new SCBASE page
        ld hl, sctop + 1
        add a, (hl)
        ld hl, scbase + 1
        sub (hl)                    ; new SCTOP page
        ld b, a
        ld a, (txttab + 1)
        cp b
        jp c, fcerr
        ld a, b
        ld (sctop + 1), a
        ld a, c
        ld (scbase + 1), a
        ret

; SCREEN [0 text / 1 graphics][,colour set]
st_screen:
        cp ','
        jr z, .css
        call getbyt
        ld a, e
        or a
        push af
        call z, samalp
        pop af
        call nz, samgrp
        call chrgot
        ret z
.css:   call chkcom
        call getbyt
        ld a, e
        or a
        jr z, .set
        ld a, 8
.set:   ld (sccss), a
; Show the colour set SCCSS.
setcss: ld a, (sccss)
        ld (piacss), a
        ld a, (dspon)
        or a
        jp nz, grall
        call txtcol
        jp render_all

; Show the text screen. Any output to the screen does this.
samalp: ld a, (dspon)
        or a
        ret z
    IF TESTMODE
        call tshot
    ENDIF
        xor a
        ld (dspon), a
        ld (piacss), a
        call txtcol
        ld a, (p5shwn)
        or a
        jr z, .txt
        call render_all             ; from PMODE 5: draw the text out of
        call p5off                  ; sight, then show it
        ld a, (l2_scroll)
        nextreg $17, a
        ret
.txt:   ld a, (l2_scroll)
        nextreg $17, a
        jp render_all

; Show the current PMODE page.
samgrp: ld hl, (scbase)
        ld (dspbase), hl
        ld hl, (sctop)
        ld (dsptop), hl
        ld a, (p5draw)
        ld (dsp5pg), a
        ld a, (scmode)
        ld (dspmode), a
        ld a, (sccss)
        ld (piacss), a
        ld a, 1
        ld (dspon), a
        nextreg $17, 0
        jp grall

; The text colours for the colour set: green or orange.
txtcol: ld hl, COL_DKGREEN << 8 | COL_GREEN
        ld a, (piacss)
        or a
        jr z, .s
        ld hl, COL_DKORANGE << 8 | COL_ORANGE
.s:     ld (txtcl), hl
        ret

; COLOR [foreground][,background]
st_color:
        cp ','
        jr z, .back
        call getclr
        ld a, e
        ld (forclr), a
        call chrgot
        ret z
.back:  call chkcom
        call getclr
        ld a, e
        ld (bakclr), a
        ret

; PCLS [colour]
st_pcls:
        ld a, (bakclr)
        ld e, a
        jr z, .fill
        call getclr
.fill:  ld a, (scmode)
        cp 5
        ld a, e
        jp z, p5pcls
        call deffor
        ld a, (actcle)
        ld hl, (scbase)
        ld de, (sctop)
.lp:    ld (hl), a
        inc hl
        push af
        ld a, l
        cp e
        jr nz, .nx
        ld a, h
        cp d
.nx:    jr z, .done
        pop af
        jr .lp
.done:  pop af
        ld a, (dspon)
        or a
        ret z
        jp grall

; PCOPY page TO page
st_pcopy:
        ld a, (scmode)
        cp 5
        jp z, p5pcop
        call pcopr
        push hl
        ld a, TK_TO
        call synchr
        call pcopr
        ex de, hl
        pop hl
        ld bc, $600
        ldir
        ld a, (dspon)
        or a
        ret z
        jp grall
; A page number as its address in HL. As on the Dragon 32 it is not
; checked against the program; only pages past the top of memory are
; refused.
pcopr:  call getbyt
        ld a, e
        or a
        jp z, fcerr
        dec a
        ld l, a
        ld h, 0
        ld b, h
        ld c, l
        add hl, hl
        add hl, bc
        add hl, hl                  ; (n-1)*6
        ld a, h
        or a
        jp nz, fcerr
        ld a, (scrbas)
        add a, l
        jp c, fcerr
        ld h, a
        ld l, 0
        ret

; ---- PSET, PRESET, PPOINT --------------------------------------------------------
st_pset:
        ld a, 1
        jr psetcn
st_preset:
        xor a
psetcn: ld (setflg), a
        call chkopn
        call scnpnt
        call gscale
        call cmcolr
        call chkcls
        call genadr
        jp grpact

; PPOINT(x,y): the colour (1-8) of a point, or 0.
fn_ppoint:
        call onecrd
        call gscale
        call genadr
        ld c, a
        ld a, (scmode)
        cp 5
        jp z, p5ppnt
        ld a, c
        and (hl)
        ld c, a
        ld a, (scmode)
        rra
        ld a, c
        jr c, .col
        or a
        jr z, .ret                  ; two colours: off is 0
        xor a
        jr .cdn
.col:   cp 4                        ; four colours: bits down to 0-3
        jr c, .cdn
        rrca
        rrca
        jr .col
.cdn:   inc a
        add a, a
        ld hl, sccss
        add a, (hl)
        srl a
.ret:   ld e, a
        jp sngflt

; ---- LINE --------------------------------------------------------------------------
; LINE [(x1,y1)]-(x2,y2),PSET|PRESET[,B[F]]
st_line:
        cp TK_INPUT
        jp z, st_lninp
        cp '('
        jr z, .crd
        cp TK_MINUS
        jr z, .crd
        ld a, '@'
        call synchr
.crd:   call crdget
        ld hl, (x2stor)
        ld (lsavex), hl
        ld hl, (y2stor)
        ld (lsavey), hl
        call chkcom
        cp TK_PRESET
        ld b, 0
        jr z, .flag
        cp TK_PSET
        jp nz, snerr
        inc b
.flag:  push bc
        call chrget
        call gscal2
        pop af
        ld (setflg), a
        call defcol
        call chrgot
        jp z, lingen
        call chkcom
        ld a, 'B'
        call synchr
        jr nz, .fill
        call xline                  ; a box
        call yline
        ld hl, (xstore)
        push hl
        ld hl, (x2stor)
        ld (xstore), hl
        call yline
        pop hl
        ld (xstore), hl
        ld hl, (y2stor)
        ld (ystore), hl
        jp xline
.fill:  ld a, 'F'
        call synchr
.fl:    call xline
        ld hl, (ystore)
        ld de, (y2stor)
        or a
        sbc hl, de
        ret z
        ld hl, (ystore)
        jr c, .inc
        dec hl
        jr .st
.inc:   inc hl
.st:    ld (ystore), hl
        jr .fl

; DE = |X2STOR - XSTORE|, carry set if X2STOR is the smaller.
xdelts: ld hl, (x2stor)
        ld de, (xstore)
        jr dlt
ydelts: ld hl, (y2stor)
        ld de, (ystore)
dlt:    or a
        sbc hl, de
        ex de, hl
        ret nc
        ld hl, 0
        or a
        sbc hl, de
        ex de, hl
        scf
        ret

; From XSTORE,YSTORE to X2STOR,YSTORE.
xline:  ld hl, (xstore)
        push hl
        call xdelts
        jr nc, .go
        ld hl, (x2stor)
        ld (xstore), hl
.go:    inc de                      ; the count of points
        push de
        call genadr
        pop bc
        pop de
        ld (xstore), de
.lp:    call grpact
        call ginx
        dec bc
        ld e, a
        ld a, b
        or c
        ld a, e
        jr nz, .lp
        ret

; From XSTORE,YSTORE to XSTORE,Y2STOR.
yline:  ld hl, (ystore)
        push hl
        call ydelts
        jr nc, .go
        ld hl, (y2stor)
        ld (ystore), hl
.go:    inc de
        push de
        call genadr
        pop bc
        pop de
        ld (ystore), de
.lp:    call grpact
        call ginyl
        dec bc
        ld e, a
        ld a, b
        or c
        ld a, e
        jr nz, .lp
        ret

; The general line from XSTORE,YSTORE to X2STOR,Y2STOR, stepping along the
; longer axis and moving on the shorter one when the running count passes
; the longer delta (starting at half of it, rounded the same way in both
; directions so a line covers the same points whichever end it starts).
lingen: call ydelts
        ld a, 0
        rla
        ld (ln_ydec), a             ; 1: Y decreases
        ld a, d
        or e
        jp z, xline
        ld (ln_dy), de
        call xdelts
        ld a, 0
        rla
        ld (ln_xdec), a
        ld a, d
        or e
        jp z, yline
        ld hl, (ln_dy)              ; which delta is bigger?
        ex de, hl                   ; HL = dx, DE = dy
        or a
        sbc hl, de
        add hl, de
        push af                     ; carry: Y major
        ld a, (ln_xdec)             ; step codes: bit 1 = Y, bit 0 = down
        ld b, a
        ld a, (ln_ydec)
        or 2
        ld c, a
        pop af
        jr nc, .set                 ; X major
        ex de, hl                   ; Y major: HL = dy, DE = dx
        ld a, b
        ld b, c
        ld c, a
.set:   ld a, b
        ld (ln_major), a
        ld a, c
        ld (ln_minor), a
        ld (ln_cnt), hl             ; points still to step
        ld (ln_maj), hl
        ld (ln_min), de
        srl h                       ; the running count starts at major/2
        rr l
        jr c, .odd
        ld a, (ln_major)            ; even: one less when stepping down
        rra
        jr nc, .odd
        dec hl
.odd:   ld (ln_acc), hl
.lp:    call genadr
        call grpact
        ld hl, (ln_cnt)
        ld a, h
        or l
        ret z
        dec hl
        ld (ln_cnt), hl
        ld a, (ln_major)
        call lnstep
        ld hl, (ln_acc)
        ld de, (ln_min)
        add hl, de
        ld de, (ln_maj)
        or a
        sbc hl, de
        jr c, .noov
        ld (ln_acc), hl
        ld a, (ln_minor)
        call lnstep
        jr .lp
.noov:  add hl, de
        ld (ln_acc), hl
        jr .lp

; Step an axis: A bit 1 = Y (else X), bit 0 = decrement.
lnstep: ld hl, xstore
        bit 1, a
        jr z, .x
        ld hl, ystore
.x:     ld e, (hl)
        inc hl
        ld d, (hl)
        rra
        jr c, .dec
        inc de
        jr .st
.dec:   dec de
.st:    ld (hl), d
        dec hl
        ld (hl), e
        ret

; ---- SET, RESET, POINT on the text screen ------------------------------------------
; Column 0-63, row 0-31: HL = the screen cell, C = the quadrant's bit.
grphar: call chkopn
grpha2: call getbyt
        ld a, e
        cp 64
        jp nc, fcerr
        push de
        call chkcom
        call getbyt
        ld a, e
        cp 32
        jp nc, fcerr
        pop bc                      ; C = column, E = row
        ld a, e
        srl a
        ld l, a
        ld h, 0
        add hl, hl
        add hl, hl
        add hl, hl
        add hl, hl
        add hl, hl
        ld a, c
        srl a
        add a, l
        ld l, a
        ld a, h
        adc a, high SCRADR
        ld h, a
        ld a, l
        add a, low SCRADR
        ld l, a
        jr nc, .nc
        inc h
.nc:    ld a, e                     ; bit = 8 >> (2*(row&1) + (col&1))
        and 1
        add a, a
        rr c
        adc a, 0
        ld b, a
        ld a, 8
        inc b
.sh:    dec b
        jr z, .got
        rrca
        jr .sh
.got:   ld c, a
        ret

; SET(x,y,colour)
st_set: call grphar
        push hl
        push bc
        call chkcom
        call getbyt
        pop bc
        pop hl
        ld a, e
        cp 9
        jp nc, fcerr
        or a
        jr z, .c0
        dec a
        add a, a
        add a, a
        add a, a
        add a, a
        jr .have
.c0:    ld a, (hl)                  ; 0: keep a block's colour, else green
        bit 7, a
        ld a, 0
        jr z, .have
        ld a, (hl)
        and $70
.have:  ld b, a
        push bc
        push hl
        call chkcls
        pop hl
        pop bc
        ld a, (hl)
        bit 7, a
        jr nz, .isg
        xor a
.isg:   and $0F
        or c
        or b
setgr:  or $80
        ld (hl), a
        jp render_hl

; RESET(x,y)
st_reset:
        call grphar
        push hl
        push bc
        call chkcls
        pop bc
        pop hl
        ld a, (hl)
        bit 7, a
        jr z, .notg
        ld b, a
        ld a, c
        cpl
        and b
        ld (hl), a
        jp render_hl
.notg:  xor a
        jr setgr

; POINT(x,y): -1 if not a block, 0 if off, else the colour 1-8.
fn_point:
        call grpha2
        ld a, (hl)
        ld de, -1
        bit 7, a
        jr z, .ret
        and c
        jr z, .inc                  ; off: -1 + 1
        ld d, 0
        ld a, (hl)
        rrca
        rrca
        rrca
        rrca
        and 7
        ld e, a
.inc:   inc de
.ret:   push de
        call chkcls
        pop de
        jp givabf

; ---- the renderer -------------------------------------------------------------------
; Graphics colours (RGB332): green yellow blue red, buff cyan magenta orange.
gr_pal: db $1C, $FC, $03, $E0, $DB, $1F, $E3, $F0

; Redraw byte HL on Layer 2 if it is on show. Preserves all but AF.
gdirty: ld a, (dspon)
        or a
        ret z
        ld a, (dspmode)
        cp 5
        ret z                       ; PMODE 5 is drawn in place
        push de
        ld de, (dspbase)
        or a
        sbc hl, de
        add hl, de
        jr c, .x
        ld de, (dsptop)
        or a
        sbc hl, de
        add hl, de
        call c, grbyte
.x:     pop de
        ret

; Redraw the whole graphics display.
grall:  ld a, (dspmode)
        cp 5
        jp z, p5disp
        ld hl, (dspbase)
.lp:    call grbyte
        inc hl
        ld de, (dsptop)
        ld a, l
        cp e
        jr nz, .lp
        ld a, h
        cp d
        jr nz, .lp
        ld a, (p5shwn)              ; leaving a PMODE 5 screen: switch only
        or a                        ; now the picture is ready
        call nz, p5off
        ret

; Draw graphics byte HL (within the display) on Layer 2. Preserves all
; but AF.
grbyte: push bc
        push de
        push hl
        push ix
        ld c, (hl)                  ; the byte
        ld de, (dspbase)
        or a
        sbc hl, de                  ; offset
        ld a, (dspmode)
        ld b, a
        cp 1
        jr z, .w32
        cp 3
        jr nc, .w32
        ld a, l                     ; 16 bytes a row: 16 pixels a byte
        and 15
        add a, a
        add a, a
        add a, a
        add a, a
        ld e, a                     ; x
        add hl, hl
        add hl, hl
        add hl, hl
        add hl, hl
        jr .row
.w32:   ld a, l                     ; 32 bytes a row: 8 pixels a byte
        and 31
        add a, a
        add a, a
        add a, a
        ld e, a
        add hl, hl
        add hl, hl
        add hl, hl
.row:   ld d, h                     ; D = the Dragon row
        ld a, b
        cp 2
        jr nc, .y1
        sla d                       ; modes 0, 1: two lines a row
.y1:    ld a, b                     ; the pattern, into grpat
        rra
        ld hl, grpat
        jr c, .colr
        ld a, (piacss)              ; two colours: black and green/buff
        or a
        ld a, $1C
        jr z, .fg
        ld a, $DB
.fg:    ld ixh, a
        ld a, b
        sub 4
        ld ixl, a                   ; 0: mode 4, one pixel a point
        ld b, 8
.bw:    xor a
        sla c
        jr nc, .off
        ld a, ixh
.off:   ld (hl), a
        inc hl
        inc ixl
        dec ixl
        jr z, .one
        ld (hl), a
        inc hl
.one:   djnz .bw
        jr .draw
.colr:  ld b, 4                     ; four colours: two pixels a point
.cl:    xor a
        sla c
        rla
        sla c
        rla
        push hl
        ld hl, piacss
        bit 3, (hl)
        jr z, .cs
        add a, 4
.cs:    ld hl, gr_pal
        add a, l
        ld l, a
        adc a, h
        sub l
        ld h, a
        ld a, (hl)
        pop hl
        ld (hl), a
        inc hl
        ld (hl), a
        inc hl
        djnz .cl
.draw:  ld a, l                     ; the pattern's length
        sub grpat & $FF
        ld c, a
        ld a, d
        call .line
        ld a, (dspmode)
        cp 2
        jr nc, .end
        ld a, d
        inc a
        call .line
.end:   ld a, 2                     ; write-map off
        ld bc, L2_PORT
        out (c), a
        pop ix
        pop hl
        pop de
        pop bc
        ret
; Copy C pattern bytes to Layer 2 line A at x = E.
.line:  push bc
        push de
        ld d, a
        and $C0
        or $0B                      ; write-map on, into NR $13's banks
        ld b, high L2_PORT
        push bc
        ld bc, L2_PORT
        out (c), a
        pop bc
        ld a, d
        and $3F
        ld d, a
        ld hl, grpat
        ld b, 0
        ldir
        pop de
        pop bc
        ret
