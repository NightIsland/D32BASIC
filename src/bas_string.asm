; Strings: descriptors, temporaries, string space and garbage collection,
; and the string functions.
;
; A descriptor is 5 bytes: length, 0, address (big-endian), 0, the same
; shape as a variable's value. Strings live in string space (FRETOP up to
; MEMSIZ) or, for literals in a stored program, in the program text itself.
; Results of string expressions are kept in a small stack of temporary
; descriptors (TEMPST); FACMO holds a pointer to the current descriptor.

; ---- allocation ------------------------------------------------------------

; Reserve A bytes of string space for a new string. Sets DSCTMP (length
; and address) and FRESPC. Returns HL = address. The current FAC descriptor
; pointer is saved in DSCPNT first, as the string functions expect.
strini: ld hl, (facmo)
        ld (dscpnt), hl
strspa: push af
        call getspa
        pop af
        ld (dsctmp), a
        ld a, h
        ld (dsctmp + 2), a
        ld a, l
        ld (dsctmp + 3), a
        ret

; HL = A bytes of string space (garbage collecting once if needed), also
; stored in FRESPC. ?OS ERROR if there is still no room. Preserves A.
getspa: push bc
        ld b, a
        xor a
        ld (garbfl), a
.try:   ld e, b
        ld d, 0
        ld hl, (fretop)
        or a
        sbc hl, de
        jr c, .full
        ld de, (strend)
        or a
        sbc hl, de
        jr c, .full
        add hl, de
        ld (fretop), hl
        ld (frespc), hl
        ld a, b
        pop bc
        ret
.full:  ld a, (garbfl)
        or a
        ld e, ERR_OS
        jp nz, error
        push bc
        call garbag
        pop bc
        ld a, $FF
        ld (garbfl), a
        jr .try

; Push DSCTMP on the temporary stack and make it the FAC's value.
putnew: ld hl, (temppt)
        ld de, tempend
        or a
        sbc hl, de
        jr nz, .ok
        ld e, ERR_ST
        jp error
.ok:    add hl, de
        ld (lastpt), hl
        ld (facmo), hl
        ex de, hl
        ld hl, dsctmp
        ld bc, STRSIZ
        ldir
        ld (temppt), de
        ld a, $FF
        ld (valtyp), a
        ret

; ---- literals --------------------------------------------------------------

; String literal: HL points at the opening quote.
strlti: inc hl
        ld a, '"'
        ld (charac), a
        ld (endchr), a
; Make a string of the text at HL, ending at a zero or at the CHARAC or
; ENDCHR character. A closing quote is skipped. STRNG2 = the character after
; the string. Literals in the stored program are used where they are; other
; text (the input buffer, number output) is copied into string space.
strlit: ld (strng1), hl
        ld b, 0
.scan:  ld a, (hl)
        or a
        jr z, .end
        ld c, a
        ld a, (charac)
        cp c
        jr z, .term
        ld a, (endchr)
        cp c
        jr z, .term
        inc hl
        inc b
        jr .scan
.term:  ld a, c
        cp '"'
        jr nz, .end
        inc hl
.end:   ld (strng2), hl
        ld hl, (strng1)
        call inprog
        ld a, b
        jr c, .copy
        ld (dsctmp), a              ; point into the program text
        ld a, h
        ld (dsctmp + 2), a
        ld a, l
        ld (dsctmp + 3), a
        jp putnew
.copy:  call strspa
        ld hl, (strng1)
        ld a, (dsctmp)
        ld b, a
        call movstr
        jp putnew

; Carry clear if HL lies in the program text (TXTTAB <= HL < VARTAB).
inprog: push de
        ld de, (txttab)
        or a
        sbc hl, de
        add hl, de
        jr c, .no
        ld de, (vartab)
        or a
        sbc hl, de
        add hl, de
        ccf
.no:    pop de
        ret

; Copy B bytes from HL to FRESPC, advancing FRESPC.
movstr: ld de, (frespc)
        ld a, b
        or a
        jr z, .done
        ld c, b
        ld b, 0
        ldir
.done:  ld (frespc), de
        ret

; Copy the string whose descriptor is at HL to FRESPC.
movins: call dscget
        jr movstr

; B = length, HL = address of the descriptor at HL. Preserves DE.
dscget: ld b, (hl)
        inc hl
        inc hl
        ld a, (hl)
        inc hl
        ld l, (hl)
        ld h, a
        ret

; ---- freeing temporaries ---------------------------------------------------

; Check the FAC is a string, then free it: B = A = length, HL = address.
frestr: call chkstr
frefac: ld hl, (facmo)
; Free the descriptor at HL if it is the newest temporary, and its text if
; that is the newest string. Returns B = A = length, HL = address.
fretmp: push hl
        call fretms
        pop hl
        push af                     ; Z: it was a temporary
        call dscget
        pop af
        jr nz, .ret
        push de
        ld de, (fretop)             ; at the bottom of string space?
        or a
        sbc hl, de
        add hl, de
        jr nz, .nofre
        push hl
        ld e, b
        ld d, 0
        add hl, de
        ld (fretop), hl
        pop hl
.nofre: pop de
.ret:   ld a, b
        ret

; Pop the descriptor at HL off the temporary stack if it is the newest.
; Z if it was.
fretms: ld de, (lastpt)
        or a
        sbc hl, de
        ret nz
        ld (temppt), de
        ld hl, -STRSIZ
        add hl, de
        ld (lastpt), hl
        xor a
        ret

; ---- garbage collection ----------------------------------------------------

; Move every string in string space up to the top, highest first.
garbag: ld hl, (memsiz)
        ld (fretop), hl
.pass:  ld hl, (strend)
        ld (grbtop), hl             ; highest address found so far
        ld hl, 0
        ld (grbpnt), hl
        ld ix, tempst               ; temporaries
.tmp:   push ix
        pop hl
        ld de, (temppt)
        or a
        sbc hl, de
        jr nc, .vars
        call gcchk
        ld de, STRSIZ
        add ix, de
        jr .tmp
.vars:  ld ix, (vartab)             ; simple variables
.var:   push ix
        pop hl
        ld de, (arytab)
        or a
        sbc hl, de
        jr nc, .arys
        bit 7, (ix+1)
        jr z, .vnext
        inc ix
        inc ix
        call gcchk
        dec ix
        dec ix
.vnext: ld de, 7
        add ix, de
        jr .var
.arys:  ld ix, (arytab)             ; arrays
.ary:   push ix
        pop hl
        ld de, (strend)
        or a
        sbc hl, de
        jr nc, .move
        ld d, (ix+2)                ; HL = end of this array
        ld e, (ix+3)
        push ix
        pop hl
        add hl, de
        ld (arypnt), hl
        bit 7, (ix+1)
        jr z, .anext
        ld e, (ix+4)                ; skip the header
        ld d, 0
        ex de, hl
        add hl, hl
        ld de, 5
        add hl, de
        ex de, hl
        add ix, de
.adsc:  push ix
        pop hl
        ld de, (arypnt)
        or a
        sbc hl, de
        jr nc, .anext
        call gcchk
        ld de, STRSIZ
        add ix, de
        jr .adsc
.anext: ld ix, (arypnt)
        jr .ary
.move:  ld hl, (grbpnt)             ; none left: done
        ld a, h
        or l
        ret z
        push hl
        pop ix
        ld c, (ix+0)                ; BC = length
        ld b, 0
        ld h, (ix+2)
        ld l, (ix+3)
        add hl, bc
        dec hl                      ; HL = last byte of the string
        ld de, (fretop)
        dec de                      ; DE = new last byte
        lddr
        inc de                      ; new address
        ld (fretop), de
        ld (ix+2), d
        ld (ix+3), e
        jp .pass

; Note the descriptor at IX if it is the highest string not yet moved.
gcchk:  ld a, (ix+0)
        or a
        ret z
        ld h, (ix+2)
        ld l, (ix+3)
        ld de, (fretop)
        or a
        sbc hl, de
        add hl, de
        ret nc                      ; already moved (or not in string space)
        ld de, (grbtop)
        or a
        sbc hl, de
        add hl, de
        ret c                       ; below STREND or below the best so far
        ld (grbtop), hl
        ld (grbpnt), ix
        ret

; ---- concatenation -------------------------------------------------------

; Left string in the FAC, TXTPTR at '+'. Concatenate the next operand.
cat:    ld hl, (facmo)
        push hl
        call eval
        call chkstr
        pop hl
        ld (strng1), hl
        ld a, (hl)
        ld hl, (facmo)
        add a, (hl)
        jp c, lserr
        call strini                 ; DSCPNT = right descriptor
        ld hl, (strng1)
        call movins
        ld hl, (dscpnt)
        call fretmp
        call movstr
        ld hl, (strng1)
        call fretmp
        call putnew
        jp lp_tstop

; ---- functions -------------------------------------------------------------

; LEN
fn_len: call lenset
        ld e, b
        jp sngflt
lenset: call frestr
        ld b, a
        xor a
        ld (valtyp), a
        ret

; ASC
fn_asc: call lenset
        ld a, b
        or a
        jp z, fcerr
        ld e, (hl)
        jp sngflt

; CHR$
fn_chr: call conint
        ld a, 1
        push de
        call strspa
        pop de
        ld (hl), e
chrdon: jp putnew

; STR$
fn_str: call chknum
        call fout
        ld hl, fbuffr
        xor a
        ld (charac), a
        ld (endchr), a
        jp strlit

; LEFT$(s$, n): HL = descriptor, B = n.
fn_left:
        push hl
        call chkcls
        pop hl
        ld a, (hl)                  ; n > length: whole string
        cp b
        jr nc, .ok
        ld b, a
.ok:    ld c, 0
substr: ld (dscpnt), hl             ; take B bytes from offset C
        ld a, b
        push bc
        call strspa
        ld hl, (dscpnt)
        call fretmp
        pop bc
        ld e, c
        ld d, 0
        add hl, de
        call movstr
        jp putnew

; RIGHT$(s$, n)
fn_right:
        push hl
        call chkcls
        pop hl
        ld a, (hl)
        sub b
        jr nc, .ok
        xor a
        ld b, (hl)
.ok:    ld c, a
        jr substr

; MID$(s$, start [, n])
fn_mid: ld a, b
        or a
        jp z, fcerr
        dec b
        push bc
        push hl
        ld e, $FF
        call chrgot
        cp ')'
        jr z, .def
        call chkcom
        call getbyt
.def:   call chkcls
        pop hl
        pop bc
        ld c, b                     ; C = offset, E = count
        ld a, (hl)
        sub c
        jr nc, .in
        xor a                       ; start beyond the end: empty
.in:    cp e
        jr c, .short
        ld a, e
.short: ld b, a
        jr substr

; VAL
fn_val: call lenset
        ld a, b
        or a
        jp z, zerofc
        ld e, b                     ; put a zero after the text
        ld d, 0
        push hl
        add hl, de
        ld a, (hl)
        ld (hl), 0
        ex (sp), hl                 ; stack: end, HL = text
        push af
        ld de, (txtptr)
        push de
        dec hl
        ld (txtptr), hl
        call chrget
        call fin
        pop de
        ld (txtptr), de
        pop af
        pop hl
        ld (hl), a
        ret

; PEEK
fn_peek:
        call getadr
        ld a, (de)
        ld e, a
        jp sngflt

; POKE addr, byte. Writes to the Dragon's I/O area ($FF00 up) are ignored:
; they set up hardware that does not exist here.
st_poke:
        call evladr
        push de
        call chkcom
        call getbyt
        pop hl
        ld a, h
        inc a
        ret z
        ld (hl), e
        ret

; INSTR([start,] search$, target$)
fn_instr:
        call chkopn
        call frmevl
        ld e, 1
        ld a, (valtyp)
        or a
        jr nz, .str
        call conint
        ld a, e
        or a
        jp z, fcerr
        push de
        call chkcom
        call frmevl
        call chkstr
        jr .s2
.str:   push de
.s2:    ld hl, (facmo)
        push hl
        call chkcom
        call frmevl
        call chkstr
        call chkcls
        call frefac                 ; target: B = length, HL = text
        ld (strng2), hl
        ld a, b
        ld (dsctmp), a
        pop hl
        call fretmp                 ; search: B = length, HL = text
        pop de                      ; E = start
        ld a, e
        ld (count), a
        ld c, b
        dec a
        ld e, a
        ld d, 0
        cp c
        jr nc, .none                ; start beyond the end
        add hl, de                  ; HL = first place to try
        ld a, c
        sub e
        ld c, a                     ; C = characters left
        ld a, (dsctmp)
        or a
        jr z, .found                ; empty target: found at start
.try:   ld a, (dsctmp)
        ld b, a
        ld a, c
        cp b
        jr c, .none
        push hl
        ld de, (strng2)
.cmp:   ld a, (de)
        cp (hl)
        jr nz, .miss
        inc hl
        inc de
        djnz .cmp
        pop hl
        jr .found
.miss:  pop hl
        inc hl
        dec c
        ld a, (count)
        inc a
        ld (count), a
        jr .try
.none:  xor a
        ld (count), a
.found: ld a, (count)
        ld e, a
        jp sngflt

; STRING$(n, char or string)
fn_string:
        call chkopn
        call getbyt
        push de
        call chkcom
        call frmevl
        call chkcls
        ld a, (valtyp)
        or a
        jr z, .num
        call frefac
        ld a, b
        or a
        jp z, fcerr
        ld e, (hl)
        jr .have
.num:   call conint
.have:  pop bc                      ; C = count
        ld a, c
        push de
        call strspa
        pop de
        ld b, c
        ld a, b
        or a
        jr z, .done
.fill:  ld (hl), e
        inc hl
        djnz .fill
.done:  jp putnew

; HEX$
fn_hex: call getadr
        ld hl, fbuffr
        ld c, 0                     ; nonzero once a digit is out
        ld a, d
        call .byte
        ld a, e
        call .byte
        ld a, c
        or a
        jr nz, .end
        ld (hl), '0'
        inc hl
.end:   ld (hl), 0
        ld hl, fbuffr
        xor a
        ld (charac), a
        ld (endchr), a
        jp strlit
.byte:  push af
        rrca
        rrca
        rrca
        rrca
        call .dig
        pop af
.dig:   and $0F
        jr nz, .out
        inc c
        dec c
        ret z
.out:   ld c, 1
        add a, '0'
        cp '9' + 1
        jr c, .put
        add a, 7
.put:   ld (hl), a
        inc hl
        ret

; INKEY$
fn_inkey:
        ld a, (inkchr)
        or a
        jr nz, .got
        call polcat
        jr nz, .got
        xor a
.got:   push af
        xor a
        ld (inkchr), a
        pop af
        or a
        jr z, .empty
        push af
        ld a, 1
        call strspa
        pop af
        ld (hl), a
        jp putnew
.empty: xor a
        call strspa
        jp putnew

; MEM: free bytes between the arrays and the stack.
fn_mem: ld hl, 0
        add hl, sp
        ld de, (strend)
        or a
        sbc hl, de
        ex de, hl
        jp givuns

; TIMER
fn_timer:
        di
        ld de, (ticker)
        ei
; FAC = unsigned 16-bit DE.
givuns: xor a
        ld (valtyp), a
        ld a, d
        ld (facho), a
        ld a, e
        ld (facmoh), a
        ld b, $90
        xor a
        sub 1                       ; carry set: positive
        jp floatc

; VARPTR(var)
fn_varptr:
        call chkopn
        call ptrget
        call chkcls
        ex de, hl
        jp givuns

; POS(n)
fn_pos: call chknum
        ld a, (devpos)
        ld e, a
        jp sngflt

; MID$(var$, start [, n]) = string$: overwrite part of a string variable.
lhmid:  call chrget
        call chkopn
        call ptrget
        call chkstr
        push hl                     ; the variable
        call chkcom
        call getbyt
        ld a, e
        or a
        jp z, fcerr
        dec a
        push af                     ; start offset
        ld e, $FF
        call chrgot
        cp ')'
        jr z, .def
        call chkcom
        call getbyt
.def:   push de                     ; count
        call chkcls
        SYNCHK TK_EQUAL
        call frmevl
        call chkstr
        pop bc                      ; C = count
        pop af
        ld b, a                     ; B = start offset
        pop hl                      ; the variable's descriptor
        push bc
        push hl
        call dscget                 ; text in the program? Copy it first
        call inprog
        pop hl
        jr c, .inspc
        push hl
        ld a, (hl)
        call strini
        pop hl
        push hl
        call movins
        pop de
        push de
        ld hl, dsctmp
        ld bc, STRSIZ
        ldir
        pop hl
.inspc: push hl
        call frefac                 ; B = source length, HL = source text
        ex de, hl                   ; DE = source
        pop hl
        ld a, b
        pop bc                      ; B = start, C = count
        cp c
        jr nc, .c1
        ld c, a                     ; no more than the source
.c1:    ld a, (hl)                  ; the variable's length
        sub b
        jp c, fcerr                 ; start beyond the end
        jp z, fcerr
        cp c
        jr nc, .c2
        ld c, a                     ; no more than the rest of the variable
.c2:    push bc
        call dscget                 ; HL = variable text
        pop bc
        ld a, c
        ld c, b
        ld b, 0
        add hl, bc
        or a
        ret z
        ld c, a
        ex de, hl
        ldir
        ret
