; More graphics: GET, PUT, PAINT, CIRCLE and DRAW, and the command-string
; reader DRAW shares with PLAY. They work on the Dragon-format pages like
; the rest of bas_graph.asm, step for step as the Dragon ROM does, so the
; same points come out.

; ---- GET / PUT ------------------------------------------------------------------
; GET [@](x1,y1)-(x2,y2),array[,G]
; PUT [@](x1,y1)-(x2,y2),array[,PSET|PRESET|AND|OR|NOT]
st_get: xor a
        jr gget
st_put: ld a, 1
gget:   ld (gtptfl), a
        call chrgot
        cp '@'
        call z, chrget
        call crdget
        call chkcom
        call pgtary
        xor a
        ld (ggrpfl), a
        call chrgot
        jr z, .bytes
        ld a, $FF
        ld (ggrpfl), a
        call chkcom
        ld b, a
        ld a, (gtptfl)
        or a
        ld a, b
        jr nz, .verb
        ld a, 'G'
        call synchr
        jr .cn2
.verb:  ld hl, puttab
        ld b, 5
.vl:    cp (hl)
        jr z, .vfound
        inc hl
        inc hl
        inc hl
        djnz .vl
        jp snerr
.vfound:
        inc hl
        ld a, (hl)
        ld (putac0), a
        inc hl
        ld a, (hl)
        ld (putac1), a
        call chrget
        jr .cn2
.bytes: ld a, (scmode)
        cp 5
        jr z, .cn2                  ; PMODE 5: a byte a point
        ld b, $F8                   ; whole bytes: round X down to one
        ld a, (scmode)
        rra
        jr nc, .bw
        ld b, $FC
.bw:    ld a, (xstore)
        and b
        ld (xstore), a
        ld a, (x2stor)
        and b
        ld (x2stor), a
.cn2:   call xdelts                 ; X2STOR = columns - 1
        jr nc, .xok
        ld hl, (x2stor)
        ld (xstore), hl
.xok:   ld (x2stor), de
        call ydelts                 ; Y2STOR = rows - 1
        jr nc, .yok
        ld hl, (y2stor)
        ld (ystore), hl
.yok:   ld (y2stor), de
        ld a, (scmode)
        cp 5
        jp z, p5gtpt
        ld a, (scmode)              ; two bits a point in colour
        rra
        jr nc, .sc
        ld hl, (x2stor)
        add hl, hl
        ld (x2stor), hl
.sc:    call gscal2
        ld hl, (y2stor)
        inc hl
        ld (y2stor), hl
        ld hl, (x2stor)
        ld a, (ggrpfl)
        or a
        jp nz, grpgtp
        srl h                       ; bytes a row
        rr l
        srl h
        rr l
        srl h
        rr l
        inc hl
        ld (x2stor), hl
        call genadr
.row:   push hl
        ld a, (x2stor)
        ld b, a
.col:   call garysb                 ; IX = the next array byte
        ld a, (gtptfl)
        or a
        jr nz, .put
        ld a, (hl)
        ld (ix + 0), a
        jr .nx
.put:   ld a, (ix + 0)
        ld (hl), a
        call gdirty
.nx:    inc hl
        djnz .col
        pop hl
        call ginyl
        ld a, (y2stor)
        dec a
        ld (y2stor), a
        jr nz, .row
        ret

; The next byte of the array in IX; ?FC ERROR past its end.
garysb: push hl
        ld hl, (aryidx)
        inc hl
        ld (aryidx), hl
        push hl
        pop ix
        ld de, (aryfin)
        or a
        sbc hl, de
        pop hl
        ret nz
        jp fcerr

; Action codes for a 0 and a 1 in the array: 0 clear, 1 set, 2 leave, 3 flip.
puttab: db TK_PSET, 0, 1
        db TK_PRESET, 1, 0
        db TK_OR, 2, 1
        db TK_AND, 0, 2
        db TK_NOT, 3, 3

; GET/PUT point by point.
grpgtp: inc hl
        ld (x2stor), hl             ; points a row
        ld a, (gtptfl)
        or a
        jr nz, .noclr
        ld hl, (aryfin)             ; GET clears the array first
        ld de, (aryidx)
.clr:   dec hl
        or a
        sbc hl, de
        add hl, de
        jr z, .noclr
        ld (hl), 0
        jr .clr
.noclr: call genadr                 ; HL, A = the first point
        ld c, a
        ld a, (scmode)
        rra
        jr nc, .bw
        ld a, c
        and $AA                     ; colour: one bit of each pair
        ld c, a
.bw:    ld b, 1                     ; the array bit
        ld ix, (aryidx)
.rows:  push hl
        ld a, c
        push af                     ; the row's first point
        ld de, (x2stor)
.pts:   srl b
        jr nc, .same
        ld b, $80
        inc ix
        push hl
        push ix
        pop hl
        push de
        ld de, (aryfin)
        or a
        sbc hl, de
        pop de
        pop hl
        jp z, fcerr
.same:  ld a, (gtptfl)
        or a
        jr nz, .put
        ld a, c                     ; GET: copy a lit point to the array
        and (hl)
        jr z, .next
        ld a, b
        or (ix + 0)
        ld (ix + 0), a
        jr .next
.put:   ld a, b
        and (ix + 0)
        ld a, (putac0)
        jr z, .act
        ld a, (putac1)
.act:   or a
        jr z, .zer
        dec a
        jr z, .set
        dec a
        jr z, .next
        ld a, c                     ; flip
        xor (hl)
        jr .st
.zer:   ld a, c
        cpl
        and (hl)
        jr .st
.set:   ld a, c
        or (hl)
.st:    ld (hl), a
        call gdirty
.next:  srl c                       ; the next point to the right
        jr nc, .nc
        ld c, $80
        inc hl
.nc:    dec de
        ld a, d
        or e
        jr nz, .pts
        pop af
        ld c, a
        pop hl
        call ginyl
        ld a, (y2stor)
        dec a
        ld (y2stor), a
        jr nz, .rows
        ret

; Find the array named at TXTPTR. ARYIDX = the byte before its data,
; ARYFIN = the byte after it. ?FC ERROR if there is none or it holds
; strings.
pgtary: call ptrget
        ld a, (valtyp)
        or a
        jp nz, fcerr
        ld hl, (arytab)
.lp:    ld de, (strend)
        or a
        sbc hl, de
        add hl, de
        jp z, fcerr
        ld a, (varnam)
        cp (hl)
        jr nz, .next
        inc hl
        ld a, (varnam + 1)
        cp (hl)
        dec hl
        jr z, .found
.next:  push hl
        inc hl
        inc hl
        ld d, (hl)
        inc hl
        ld e, (hl)
        pop hl
        add hl, de
        jr .lp
.found: push hl
        inc hl
        inc hl
        ld d, (hl)
        inc hl
        ld e, (hl)
        pop hl
        push hl
        add hl, de
        ld (aryfin), hl
        pop hl
        ld de, 4
        add hl, de                  ; the number of dimensions
        ld a, (hl)
        add a, a
        ld e, a
        add hl, de
        ld (aryidx), hl
        ret

; ---- PAINT --------------------------------------------------------------------------
; PAINT [@](x,y)[,colour[,border]]
; A scan-line fill. Each pending scan is 6 bytes on the stack: direction
; and Y, the X just left of it, and its length. A pass that changes nothing
; drops the scans it queued, as on the Dragon.
st_paint:
        cp '@'
        call z, chrget
        call onecrd
        call gscale
        ld a, 1
        ld (setflg), a
        call cmcolr
        ld hl, (actclr)             ; ACTCLR and ACTCLE: the paint colour
        push hl
        call chrgot
        call nz, cmcolr
        ld a, (actcle)
        ld (pntclr), a
        pop hl
        ld (actclr), hl
        ld hl, 0                    ; a dummy scan: direction 0
        push hl
        push hl
        push hl
        call stmaxs
        call scanl
        jr z, pntlp2
        call scncon
        ld a, 1
        ld (pdirct), a
        call enters
        ld a, -1
        ld (pdirct), a
        call enters
pntlp2: ld (pntstk), sp
pntlop: ld a, (pntchf)
        or a
        jr nz, .pull
        ld sp, (pntstk)             ; nothing changed: prune
.pull:  pop de                      ; D = direction, E = Y
        pop hl                      ; X
        pop bc                      ; length
        xor a
        ld (pntchf), a
        ld (pntstk), sp
        inc hl
        ld (xstore), hl
        ld (pcount), bc
        ld a, d
        ld (pdirct), a
        or a
        ret z                       ; the dummy: done
        jp m, .dn
        inc e
        ld a, (ymax)
        cp e
        jr nc, .cn1
        ld e, 0
.dn:    ld a, e
        or a
        jr z, pntlop
        dec e
.cn1:   ld a, e
        ld (ystore), a
        xor a
        ld (ystore + 1), a
        call scanl                  ; HL = points filled leftward
        jr z, .cn4
        ld a, h
        or a
        jr nz, .ov
        ld a, l
        cp 3
        jr c, .nl                   ; an overhang on the left: look back
.ov:        ld d, h
        ld e, l
        dec de
        dec de
        call enterl                 ; (keeps HL; it pushes under us)
.nl:    call scncon
.lc1:   call enters
.cn4:   call cplhl
.lcn:   ld de, (pcount)
        add hl, de
        ld (pcount), hl
        bit 7, h
        jr nz, .fin
        ld a, h
        or l
        jr z, .fin
        call xinc
        call tstbrd
        jr nz, .lc2
        ld hl, -1
        jr .lcn
.lc2:   call xdec
        call savloc
        call scanr
        jr .lc1
.fin:   push hl                     ; an overhang on the right?
        call xinc
        pop de
        add hl, de
        ld (xstore), hl
        ex de, hl
        call cplhl
        dec hl
        bit 7, h
        jp nz, pntlop
        ld a, h
        or l
        jp z, pntlop
        ex de, hl
        call enterl
        jp pntlop

cplhl:  ld a, h
        cpl
        ld h, a
        ld a, l
        cpl
        ld l, a
        ret

xinc:   ld hl, (xstore)
        inc hl
        ld (xstore), hl
        ret
xdec:   ld hl, (xstore)
        dec hl
        ld (xstore), hl
        ret
savloc: ld hl, (xstore)
        ld (x2stor), hl
        ret

; Queue a scan of DE points: ENTERL from XSTORE the other way, ENTERS from
; X2STOR this way. Preserves HL.
enterl: ld a, (pdirct)
        neg
        ld bc, (xstore)
        jr entcon
enters: ld a, (pdirct)
        ld bc, (x2stor)
entcon: ld (pnttmp), hl
        pop hl                      ; our return
        push de                     ; length
        push bc                     ; X
        ld b, a
        ld a, (ystore)
        ld c, a
        push bc                     ; direction, Y
        push hl
        push de
        ld b, 2
        call getstk
        pop de
        ld hl, (pnttmp)
        ret

; XMAX, YMAX: the last point in this mode.
stmaxs: ld hl, 255
        ld (xmax), hl
        ld hl, 191
        ld (ymax), hl
        ld ix, xmax
        jp gscalc

; Fill leftward (SCANL) or rightward (SCANR, from the next point) from
; XSTORE until a border or the edge. HL = DE = points filled, Z if none.
scanl:  call savloc
        ld a, 1
        jr scanlc
scanr:  call xinc
        xor a
scanlc: ld (scdir), a
        ld hl, 0
        ld (sccnt), hl
        ld hl, (xstore)
.lp:    bit 7, h
        jr nz, .ret
        ex de, hl
        ld hl, (xmax)
        or a
        sbc hl, de
        jr c, .ret
        call tstbrd
        jr z, .ret
        call grpact
        ld hl, (sccnt)
        inc hl
        ld (sccnt), hl
        ld a, (scdir)
        or a
        jr z, .inc
        call xdec
        jr .lp
.inc:   call xinc
        jr .lp
.ret:   ld hl, (sccnt)
        ld d, h
        ld e, l
        ld a, h
        or l
        ret

; Scan right from the start of the last left scan and join the two:
; HL = left count, returns HL = right count + 1, DE = their total.
scncon: ld (pcnt2), hl
        ld hl, (x2stor)
        push hl
        call savloc
        pop hl
        ld (xstore), hl
        call scanr
        ld de, (pcnt2)
        ex de, hl
        add hl, de
        ex de, hl
        inc hl
        ret

; Z if XSTORE,YSTORE has the border colour. HL, A = the point.
tstbrd: ld a, (scmode)
        cp 5
        jp z, p5brd
        call genadr
        ld b, a
        ld a, (pntclr)
        and b
        ld c, a
        ld a, (hl)
        and b
        cp c
        ld a, b
        ret

; ---- CIRCLE -----------------------------------------------------------------------
; Sines and cosines of 0 to 45 degrees in eight steps, plus one (0 = 1.0).
circtb: dw 0, 1, 65221, 6425, 64278, 12786, 62715, 19025, 60548, 25081
        dw 57799, 30894, 54492, 36411, 50661, 41577, 46342, 46342

; CIRCLE [@](x,y),r[,colour[,aspect[,start[,end]]]]
st_circle:
        cp '@'
        call z, chrget
        call stmaxs
        call onecrd
        call gscale
        ld hl, (xstore)
        ld (cntrx), hl
        ld hl, (ystore)
        ld (cntry), hl
        call chkcom
        call evladr
        ld (radius), de
        ld ix, radius
        call gscalc
        ld a, 1
        ld (setflg), a
        call cmcolr
        ld hl, 256                  ; aspect 1.0
        call chrgot
        jr z, .asp
        call chkcom
        call frmnum
        ld a, (facexp)              ; times 256
        or a
        jr z, .z
        add a, 8
        ld (facexp), a
.z:     call getadr
        ex de, hl
.asp:   ld a, (scmode)
        and 2
        jr z, .sta
        add hl, hl
.sta:   ld (aspect), hl
        ld a, 1
        ld (setflg), a
        ld (cstrfl), a
        call cpossb                 ; the start
        push bc
        call cpossb                 ; the end
        ld (cendps), bc
        pop bc
.quad:  ld (cqpos), bc              ; B = octant, C = step
        ld hl, (x2stor)
        ld (xstore), hl
        ld hl, (y2stor)
        ld (ystore), hl
        ld a, b
        and 1
        ld a, c
        jr z, .fwd
        neg
        add a, 8
.fwd:   add a, a
        add a, a
        ld l, a
        ld h, 0
        ld de, circtb + 2
        add hl, de
        push hl
        call radmul                 ; Y
        pop hl
        dec hl
        dec hl
        push de
        call radmul                 ; X
        pop hl                      ; HL = Y, DE = X
        ld a, (cqpos + 1)
        and 3
        jr z, .nosw
        cp 3
        jr z, .nosw
        ex de, hl
.nosw:  ld (x2stor), de
        ld de, (aspect)             ; Y times the aspect / 256
        call mul16                  ; DEHL = HL * DE
        ld a, d
        or a
        jp nz, fcerr
        ld l, h                     ; bits 8-23
        ld h, e
        ld (y2stor), hl
        ld a, (cqpos + 1)           ; X: minus in octants 2-5
        cp 2
        jr c, .addx
        cp 6
        jr nc, .addx
        ld hl, (cntrx)
        ld de, (x2stor)
        or a
        sbc hl, de
        jr nc, .xok
        ld hl, 0
        jr .xok
.addx:  ld hl, (cntrx)
        ld de, (x2stor)
        add hl, de
        jr c, .xmax
        ld de, (xmax)
        or a
        sbc hl, de
        add hl, de
        jr c, .xok
.xmax:  ld hl, (xmax)
.xok:   ld (x2stor), hl
        ld a, (cqpos + 1)           ; Y: plus in octants 0-3
        cp 4
        jr c, .addy
        ld hl, (cntry)
        ld de, (y2stor)
        or a
        sbc hl, de
        jr nc, .yok
        ld hl, 0
        jr .yok
.addy:  ld hl, (cntry)
        ld de, (y2stor)
        add hl, de
        jr c, .ymax
        ld de, (ymax)
        or a
        sbc hl, de
        add hl, de
        jr c, .yok
.ymax:  ld hl, (ymax)
.yok:   ld (y2stor), hl
        ld a, (cstrfl)
        or a
        call z, lingen
        ld bc, (cqpos)
        ld hl, cstrfl
        srl (hl)
        jr c, .step                 ; the first point
        ld hl, (cendps)
        or a
        sbc hl, bc
        ret z
.step:  inc c
        ld a, c
        cp 8
        jp nz, .quad
        ld c, 0
        inc b
        ld a, b
        and 7
        ld b, a
        jp .quad

; DE = RADIUS times the factor at (HL) / 65536 (factor 0 is 1.0).
radmul: ld e, (hl)
        inc hl
        ld d, (hl)
        ld a, d
        or e
        jr nz, .mul
        ld de, (radius)
        ret
.mul:   dec de
        ld hl, (radius)
        call mul16
        ret

; DEHL = HL * DE (unsigned).
mul16:  ld b, h
        ld c, l
        ld hl, 0
        ld a, 16
.lp:    add hl, hl
        rl e
        rl d
        jr nc, .no
        add hl, bc
        jr nc, .no
        inc de
.no:    dec a
        jr nz, .lp
        ret

; An optional ",fraction" (0-1) of the way round: B = octant, C = step.
cpossb: ld b, 0
        call chrgot
        jr z, .end
        call chkcom
        call frmnum
        ld a, (facexp)              ; times 64
        or a
        jr z, .z
        add a, 6
        ld (facexp), a
.z:     call conint
        ld a, e
        and 63
        ld b, a
.end:   ld a, b
        and 7
        ld c, a
        srl b
        srl b
        srl b
        ret

; ---- the DRAW/PLAY command string -----------------------------------------------
; A = the next character of the string, spaces skipped; ?FC ERROR if none.
fetchr: ld a, (pstlen)
        or a
        jp z, fcerr
        dec a
        ld (pstlen), a
        push hl
        ld hl, (pstptr)
        ld a, (hl)
        inc hl
        ld (pstptr), hl
        pop hl
        cp ' '
        jr z, fetchr
        ret

; Step back over the character FETCHR returned.
fetbak: push hl
        ld hl, pstlen
        inc (hl)
        ld hl, (pstptr)
        dec hl
        ld (pstptr), hl
        pop hl
        ret

; B = a command's value, B its current one: +, -, > (double), < (halve),
; =var; or a number.
plyarg: call fetchr
        cp '+'
        jr z, pa_inc
        cp '-'
        jr z, pa_dec
        cp '>'
        jr z, pa_dbl
        cp '<'
        jr z, pa_hlf
; A = the first character of a value: =var; or digits. B = the value.
plyval: cp '='
        jr z, varget
        call isdigc
        jp c, fcerr
        ld b, 0
.nlp:   sub '0'
        ld c, a
        ld a, b
        cp 26
        jp nc, fcerr
        add a, a
        ld b, a
        add a, a
        add a, a
        add a, b
        add a, c
        jp c, fcerr
        ld b, a
        ld a, (pstlen)
        or a
        ret z
        call fetchr
        call isdigc
        jr nc, .nlp
        jp fetbak
pa_inc:   inc b
        ret nz
        jp fcerr
pa_dec:   ld a, b
        or a
        jp z, fcerr
        dec b
        ret
pa_hlf:   ld a, b
        or a
        jp z, fcerr
        srl b
        ret
pa_dbl:   bit 7, b
        jp nz, fcerr
        sla b
        ret
varget: call varsub
        call conint
        ld b, e
        ret

; The variable named in the string up to ';', into the FAC.
varsub: ld hl, (pstptr)
        push hl
        call fetchr
        call isletc
        jp c, fcerr
.lp:    call fetchr
        cp ';'
        jr nz, .lp
        pop hl
        ld de, (txtptr)
        push de
        ld (txtptr), hl
        call isvar
        pop hl
        ld (txtptr), hl
        ret

; ---- DRAW ---------------------------------------------------------------------------
; Set up the PLAY and DRAW defaults (RUN and start-up).
xrrun:  ld a, 15
        ld (volume), a
        ld a, 2
        ld (tempo), a
        ld (octave), a
        ld a, 4
        ld (lnote), a
        xor a
        ld (dotflg), a
        ld (drwang), a
        ld (drwscl), a
        ld hl, 128
        ld (lsavex), hl
        ld hl, 96
        ld (lsavey), hl
        ret

; DRAW string
st_draw:
        ld hl, 0                    ; the end of X nesting
        push hl
        ld c, 1
        push bc
        ld a, 1
        ld (setflg), a
        xor a
        ld (drwfl1), a
        ld (drwfl2), a
        call defcol
        call frmevl
drwsc4: call frestr                 ; HL = text, B = length
        jr drwset
drwcon: pop bc                      ; back out of an X
        pop hl
        ld b, c
drwset: ld a, b
        ld (pstlen), a
        or a
        jr z, drwcon
        ld (pstptr), hl
        ld a, h
        or l
        ret z
drwscn: ld a, (pstlen)
        or a
        jr z, drwcon
        call fetchr
        cp ';'
        jr z, drwscn
        cp "'"
        jr z, drwscn
        cp 'N'
        jr nz, .s1
        ld hl, drwfl1
.flip:  ld a, (hl)
        cpl
        ld (hl), a
        jr drwscn
.s1:    cp 'B'
        jr nz, .s2
        ld hl, drwfl2
        jr .flip
.s2:    cp 'X'
        jp z, dxcutr
        cp 'M'
        jp z, ddrwmv
        ld c, a
        ld b, 1                     ; the value defaults to 1
        ld a, (pstlen)
        or a
        jr z, .def
        call fetchr                 ; a letter next: another command
        call isletc
        push af
        call fetbak
        pop af
        jr nc, .def
        push bc
        call fetchr
        call plyval
        ld a, b
        pop bc
        ld b, a
.def:   ld a, c
        ld l, b
        ld h, 0
        ld de, 0
        cp 'C'
        jr z, .col
        cp 'A'
        jr z, .ang
        cp 'S'
        jr z, .scl
        cp 'U'
        jr z, .up
        cp 'D'
        jr z, .down
        cp 'L'
        jr z, .left
        cp 'R'
        jr z, .right
        sub 'E'
        jr z, .ru
        dec a
        jr z, .rd
        dec a
        jr z, .ld
        dec a
        jp nz, fcerr
        call neghl                  ; H: left and up
        ld d, h
        ld e, l
        jr dodraw
.rd:    ld d, h                     ; F: right and down
        ld e, l
        jr dodraw
.ru:    ld d, h                     ; E: right and up
        ld e, l
        call neghl
        jr dodraw
.ld:    ld d, h                     ; G: left and down
        ld e, l
        ex de, hl
        call neghl
        ex de, hl
        jr dodraw
.right: ex de, hl                   ; DE = x, HL = y
        jr dodraw
.left:  call neghl
        ex de, hl
        jr dodraw
.down:  jr dodraw
.up:    call neghl
        jr dodraw
.col:   ld e, b
        call getclx
        ld a, e
        ld (forclr), a
        call defcol
        jp drwscn
.ang:   ld a, b
        cp 4
        jp nc, fcerr
        ld (drwang), a
        jp drwscn
.scl:   ld a, b
        cp 63
        jp nc, fcerr
        ld (drwscl), a
        jp drwscn

neghl:  xor a
        sub l
        ld l, a
        sbc a, a
        sub h
        ld h, a
        ret

; Draw by DE across and HL down: scale, turn, clip, then the line.
dodraw: push de
        call dmulsb
        ex (sp), hl                 ; HL = x, stack = y
        call dmulsb
        ex de, hl                   ; DE = x
        pop hl                      ; HL = y
        ld a, (drwang)              ; 90 degrees each: x, y = -y, x
        or a
        jr z, .go
        ld b, a
.ang:   push de
        call neghl
        ex de, hl
        pop hl
        djnz .ang
.go:    push hl                     ; target X: 0 if left of the screen
        ld hl, (lsavex)
        add hl, de
        bit 7, h
        jr z, .xo
        ld hl, 0
.xo:    ex de, hl
        pop hl
        ld bc, (lsavey)
        add hl, bc
        bit 7, h
        jr z, drwabs
        ld hl, 0
; DE = target X, HL = target Y: clip to the screen and draw.
drwabs: push hl
        ld hl, 255
        or a
        sbc hl, de
        jr nc, .xok
        ld de, 255
.xok:   pop hl
        push de
        ld de, 192
        or a
        sbc hl, de
        add hl, de
        pop de
        jr c, .yok
        ld hl, 191
.yok:   ld bc, (lsavex)
        ld (xstore), bc
        ld bc, (lsavey)
        ld (ystore), bc
        ld (y2stor), hl
        ld (x2stor), de
        ld a, (drwfl1)
        or a
        jr nz, .nsv
        ld (lsavey), hl
        ld (lsavex), de
.nsv:   call gscal2
        ld a, (drwfl2)
        or a
        call z, lingen
        xor a
        ld (drwfl1), a
        ld (drwfl2), a
        jp drwscn

; HL times DRWSCL / 4, keeping the sign (no change while the scale is 0).
dmulsb: ld a, (drwscl)
        or a
        ret z
        ld b, a
        ld c, h
        bit 7, h
        call nz, neghl
        ex de, hl
        ld hl, 0
.m:     add hl, de
        djnz .m
        srl h
        rr l
        srl h
        rr l
        bit 7, c
        ret z
        jp neghl

; X var; : draw the string in var, then carry on with this one.
dxcutr: call varsub
        ld b, 2
        call getstk
        ld hl, (pstptr)
        push hl
        ld a, (pstlen)
        ld c, a
        push bc
        jp drwsc4

; M[+|-]x,[+|-]y: relative if X has a sign, else absolute.
ddrwmv: call fetchr
        push af
        call sgnvl2
        push hl
        call fetchr
        cp ','
        jp nz, fcerr
        call sgnval
        pop de                      ; DE = x, HL = y
        pop af
        cp '+'
        jp z, dodraw
        cp '-'
        jp z, dodraw
        jp drwabs

; HL = a signed value from the string.
sgnval: call fetchr
sgnvl2: cp '+'
        jr z, .pls
        cp '-'
        jr z, .min
        call fetbak
.pls:   xor a
.min:   push af
        call fetchr
        call plyval
        pop af
        ld l, b
        ld h, 0
        or a
        ret z
        jp neghl
