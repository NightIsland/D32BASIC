; Expression evaluation (FRMEVL), operands (EVAL), variables (PTRGET),
; arrays and integer conversions.
;
; FRMEVL works as the ROM's does: each pending operator level is a frame on
; the stack (precedence and relation mask), the left operand of an operator
; is pushed unpacked while its right operand is evaluated, and the operator
; that ends an inner level is passed back (OPPTR) to be looked at again.

PREC_REL        EQU $64             ; relational operators
PREC_NOT        EQU $5A
PREC_NEG        EQU $7D             ; unary minus

; Type checks.
frmnum: call frmevl
chknum: ld a, (valtyp)
        or a
        ret z
        jp tmerr
chkstr: ld a, (valtyp)
        or a
        ret nz
        jp tmerr

; Evaluate an expression at TXTPTR+1... FRMEVL backs up one character so
; it can be called with TXTPTR at the expression's first character.
frmevl: ld hl, (txtptr)
        dec hl
        ld (txtptr), hl
frmchk: xor a
        ld b, a
; A = precedence of the operator waiting for this operand (0: none),
; B = its relation mask. Returns with B = that mask and OPPTR = the operator
; that ended the operand (0 if none).
lpoper: ld c, a
        push bc
        ld b, 1
        call getstk
        call eval
lp_tstop:
        xor a
        ld (opmask), a
        call chrgot
.loprel:
        sub TK_GREATER
        jr c, .endrel
        cp 3
        jr nc, .qop
        cp 1                        ; > = < to bits 1 2 4
        rla
        ld hl, opmask
        xor (hl)
        cp (hl)
        jp c, snerr                 ; the same relation twice
        ld (hl), a
        call chrget
        jr .loprel
.endrel:
        ld a, (opmask)
        or a
        jr nz, .finrel
        call chrgot
        sub TK_PLUS
        jr c, .qop
        cp 7
        jr nc, .qop
        ld c, a
        or a                        ; '+' with a string on the left
        jr nz, .notcat
        ld a, (valtyp)
        or a
        jp nz, cat
.notcat:
        ld a, c
        add a, a
        add a, c
        ld e, a
        ld d, 0
        ld hl, optab
        add hl, de
.qprec: pop bc                      ; C = waiting precedence
        push bc
        ld a, c
        cp (hl)
        jr nc, lp_unwind_chk
        ld a, (hl)
        cp PREC_REL
        call nz, chknum
        jr lp_doprec
.finrel:
        ld a, (valtyp)              ; mask = relations*2 + string flag
        rla
        ld a, (opmask)
        rla
        ld (opmask), a
        ld hl, (txtptr)
        dec hl
        ld (txtptr), hl
        xor a
        ld (valtyp), a
        ld hl, ptdorl
        jr .qprec
.qop:   ld hl, 0
; Finish this level, checking the right operand is numeric unless the
; waiting operator is a relation.
lp_unwind_chk:
        ld (opptr), hl
        pop bc
        ld a, c
        or a
        ret z
        cp PREC_REL
        ret z
        jp chknum
lp_unwind:
        ld (opptr), hl
        pop bc
        ret

; Push the left operand and operator, evaluate the right operand, apply.
lp_doprec:
        ld a, (hl)                  ; new precedence
        push hl                     ; operator entry
        ld c, a
        ld a, (facsgn)
        ld d, a
        ld a, (facexp)
        ld e, a
        push de
        ld de, (facho)
        push de
        ld de, (facmo)
        push de
        ld a, (opmask)
        ld b, a
        ld a, c
        call lpoper                 ; B = relation mask on return
        pop hl
        ld (argmo), hl
        pop hl
        ld (argho), hl
        pop hl
        ld a, l
        ld (argexp), a
        ld a, h
        ld (argsgn), a
        ld c, a
        ld a, (facsgn)
        xor c
        ld (arisgn), a
        ld a, b
        and 1
        ld (relstr), a
        ld a, b
        srl a
        ld (domask), a
        pop hl                      ; operator entry
        inc hl
        ld a, (hl)
        inc hl
        ld h, (hl)
        ld l, a
        call jphl
        ld hl, (opptr)              ; the operator that ended the operand
        ld a, h
        or l
        jr z, .none
        pop bc
        push bc
        ld a, c
        cp (hl)
        jr nc, lp_unwind
        jr lp_doprec
.none:  jr lp_unwind

jphl:   jp (hl)

; Operator table: precedence, routine.
optab:  db $79
        dw faddt
        db $79
        dw fsubt
        db $7B
        dw fmultt
        db $7B
        dw fdivt
        db $7F
        dw fpwrt
        db $50
        dw andop
        db $46
        dw orop
ptdorl: db PREC_REL
        dw dorel

; ---- operands ----------------------------------------------------------------
eval:   xor a
        ld (valtyp), a
        call chrget
        jr nc, .e2
.e1:    jp fin
.e2:    call isletc
        jr nc, isvar
        cp '.'
        jr z, .e1
        cp TK_MINUS
        jr z, domin
        cp TK_PLUS
        jr z, eval
        cp '"'
        jp z, strtxt
    cp TK_NOT
        jr nz, .e4
        ld a, PREC_NOT
        ld b, 0
        call lpoper
        call intcnv
        ld a, d
        cpl
        ld d, a
        ld a, e
        cpl
        ld e, a
        jp givabf
.e4:    cp TK_FN
        jp z, fndoer
        cp '&'
        jp z, hocons
        cp $FF
        jr z, isfun
parchk: call chkopn
        call frmevl
        jp chkcls

; A string literal at TXTPTR.
strtxt: ld hl, (txtptr)
        call strlti
st2txt: ld hl, (strng2)
        ld (txtptr), hl
        ret

domin:  ld a, PREC_NEG
        ld b, 0
        call lpoper
        jp negop

isvar:  ld a, 1
        ld (evalflg), a
        call ptrget
        ld (facmo), hl
        ld a, (valtyp)
        or a
        ret nz
        jp movfm

; A function: $FF then the function token.
isfun:  call chrget
        ld c, a                     ; token
        call chrget
        ld a, c
        cp FN_LEFTS
        jr c, .cls0
        cp FN_INKEYS
        jr nc, .fingo               ; no arguments here
        call chkopn
        ld a, c
        cp FN_POINT
        jr nc, .fingo
        push bc                     ; LEFT$, RIGHT$, MID$: string, byte
        call frmevl
        call chkcom
        call chkstr
        pop bc
        ld hl, (facmo)
        push hl
        push bc
        call getbyt
        pop bc
        pop hl
        ld b, e                     ; HL = descriptor, B = the number
        ld a, c
        jr .disp
.cls0:  push bc
        call parchk
        pop bc
.fingo: ld a, c
; A = token, HL and B = arguments for LEFT$/RIGHT$/MID$.
.disp:  push af
        push hl
        sub $80
        add a, a
        ld e, a
        ld d, 0
        ld hl, fundsp
        add hl, de
        ld e, (hl)
        inc hl
        ld d, (hl)
        push de
        pop ix
        pop hl
        call jpix
        pop af
        ld hl, strfns               ; string results are not checked
        ld bc, strfns_end - strfns
        cpir
        ret z
        jp chknum
jpix:   jp (ix)
strfns: db FN_STRS, FN_CHRS, FN_HEXS, FN_LEFTS, FN_RIGHTS, FN_MIDS
        db FN_INKEYS, FN_STRINGS
strfns_end:

; ---- AND, OR, relations --------------------------------------------------------
orop:   ld a, 1
        jr andor
andop:  xor a
andor:  ld (count), a
        call intcnv
        ld (integr2), de
        call movfa
        call intcnv
        ld hl, (integr2)
        ld a, (count)
        or a
        jr nz, .or
        ld a, d
        and h
        ld d, a
        ld a, e
        and l
        ld e, a
        jp givabf
.or:    ld a, d
        or h
        ld d, a
        ld a, e
        or l
        ld e, a
        jp givabf

; Compare ARG (left) with FAC (right) and give -1 (true) or 0.
dorel:  ld a, (relstr)
        or a
        jr nz, .str
        call chknum
        ld a, (argsgn)              ; pack ARG for FCOMP
        or $7F
        ld b, a
        ld a, (argho)
        and b
        ld (argho), a
        ld hl, argexp
        call fcomp
        jr docmp
.str:   call chkstr
        xor a
        ld (valtyp), a
        call frefac                 ; B = length, HL = text (right)
        ld a, b
        ld (dsctmp), a
        ld (dsctmp + 2), hl
        ld hl, (argmo)
        call fretmp                 ; left
        ld a, (dsctmp)
        sub b
        jr z, .stasgn
        ld a, 1
        jr nc, .stasgn
        ld a, (dsctmp)
        ld b, a
        ld a, $FF
.stasgn:
        ld (facsgn), a
        ld de, (dsctmp + 2)
        inc b
.nxt:   dec b
        jr nz, .get
        ld a, (facsgn)
        jr docmp
.get:   ld a, (de)
        ld c, a
        ld a, (hl)
        inc hl
        inc de
        cp c
        jr z, .nxt
        ld a, $FF
        jr nc, docmp
        ld a, 1
; A = sign(FAC - ARG): map to 1/2/4 and test against the relation mask.
docmp:  add a, 1
        rla
        ld hl, domask
        and (hl)
        jr z, .f
        ld a, $FF
.f:     jp float

; ---- variables -----------------------------------------------------------------

; Find (or create) the variable named at TXTPTR. Returns HL = VARPNT =
; pointer to its value. VALTYP is set from its type.
ptrget: ld b, 0
        call chrgot
ptrgt1: push af
        ld a, b
        ld (dimflg), a
        pop af
ptrgt2: ld (varnam), a
        call chrgot
        call isletc
        jp c, snerr
        ld b, 0
        xor a
        ld (valtyp), a
        call chrget
        jr c, .issec
        call isletc
        jr c, .nosec
.issec: ld b, a
.eatem: call chrget
        jr c, .eatem
        call isletc
        jr nc, .eatem
.nosec: cp '$'
        jr nz, .notstr
        ld a, $FF
        ld (valtyp), a
        ld a, b
        add a, $80
        ld b, a
        call chrget
.notstr:
        ld c, a
        ld a, b
        ld (varnam + 1), a
        ld a, (subflg)
        or c
        cp '('
        jp z, isary
        xor a
        ld (subflg), a
        ld a, (evalflg)
        ld c, a
        xor a
        ld (evalflg), a
        ld hl, (vartab)
.lopfnd:
        ld de, (arytab)
        or a
        sbc hl, de
        add hl, de
        jr z, .notfns
        ld a, (varnam)
        cp (hl)
        inc hl
        jr nz, .notit
        ld a, (varnam + 1)
        cp (hl)
        jr z, .found
.notit: ld de, 6
        add hl, de
        jr .lopfnd
.found: inc hl
        ld (varpnt), hl
        ret
.notfns:
        ld a, c                     ; reading an unset variable: zero,
        or a                        ; without creating it
        ld hl, zero5
        ret nz
        ld hl, (strend)             ; make room for a new entry
        ld (hightr), hl
        ld de, 7
        add hl, de
        ld (highds), hl
        ld hl, (arytab)
        ld (lowtr), hl
        call bltu
        ld hl, (highds)
        ld (strend), hl
        ld hl, (lowds)
        ld (arytab), hl
        ld hl, (lowtr)
        ld a, (varnam)
        ld (hl), a
        inc hl
        ld a, (varnam + 1)
        ld (hl), a
        inc hl
        ld (varpnt), hl
        push hl
        xor a
        ld b, 5
.clr:   ld (hl), a
        inc hl
        djnz .clr
        pop hl
        ret

zero5:  db 0, 0, 0, 0, 0

; An array element. Indices go on the stack, last on top.
isary:  xor a                       ; (EVAL's flag is for simple variables)
        ld (evalflg), a
        ld a, (dimflg)
        ld b, a
        ld a, (valtyp)
        ld c, a
        push bc
        ld b, 0                     ; number of dimensions
.indlop:
        ld hl, (varnam)
        push hl
        push bc
        call intidx                 ; DE = index
        pop bc
        pop hl
        ld (varnam), hl
        pop hl                      ; DIMFLG/VALTYP stay on top
        push de
        push hl
        inc b
        call chrgot
        cp ','
        jr z, .indlop
        ld a, b
        ld (count), a
        call chkcls
        pop bc
        ld a, c
        ld (valtyp), a
        ld a, b
        ld (dimflg), a
        ld hl, (arytab)
.lopfda:
        ld de, (strend)
        or a
        sbc hl, de
        add hl, de
        jr z, .notfdd
        ld a, (varnam)
        cp (hl)
        jr nz, .next
        inc hl
        ld a, (varnam + 1)
        cp (hl)
        dec hl
        jr z, .gotary
.next:  push hl
        inc hl
        inc hl
        ld d, (hl)
        inc hl
        ld e, (hl)
        pop hl
        add hl, de
        jr .lopfda
.gotary:
        ld a, (dimflg)
        or a
        ld e, ERR_DD
        jp nz, error
        ld a, (count)
        push hl
        ld de, 4
        add hl, de
        cp (hl)
        pop hl
        jp nz, bserr
        jp .getdef
.notfdd:
        ld de, 5                    ; build a new array at STREND
        ld (curtol), de
        ld a, (varnam)
        ld (hl), a
        inc hl
        ld a, (varnam + 1)
        ld (hl), a
        dec hl
        ld a, (count)
        push hl
        ld de, 4
        add hl, de
        ld (hl), a
        ld b, a
        call getstk
        pop hl
        ld (arypnt), hl
.loppta:
        ld de, 11                   ; default size
        ld a, (dimflg)
        or a
        jr z, .notdim
        pop de
        inc de
.notdim:
        push hl
        ld bc, 5
        add hl, bc
        ld (hl), d
        inc hl
        ld (hl), e
        pop hl
        call umult
        ld (curtol), de
        inc hl
        inc hl
        ld a, (count)
        dec a
        ld (count), a
        jr nz, .loppta
        ld (tmpptr), hl             ; HL + curtol + 5 = new STREND
        ex de, hl
        ld hl, (curtol)
        add hl, de
        jp c, omerr
        ld bc, 5
        add hl, bc
        jp c, omerr
        push hl
        call reason
        pop hl
        ld (strend), hl
        ld de, (tmpptr)             ; zero the values
        ex de, hl
        ld bc, 5
        add hl, bc                  ; HL = first value byte
.zer:   or a
        sbc hl, de
        add hl, de
        jr z, .zdone
        ld (hl), 0
        inc hl
        jr .zer
.zdone: ld hl, (strend)
        ld de, (arypnt)
        or a
        sbc hl, de                  ; total length
        ex de, hl
        inc hl
        inc hl
        ld (hl), d
        inc hl
        ld (hl), e
        dec hl
        dec hl
        dec hl
        ld a, (dimflg)
        or a
        ret nz
.getdef:
        push hl
        ld de, 4
        add hl, de
        ld a, (hl)
        ld (count), a
        pop hl
        ld de, 0
.inlpnm:
        ld (curtol), de
        pop de                      ; an index
        ld (indice), de
        push hl
        ld bc, 5
        add hl, bc
        ld a, d                     ; index >= size: ?BS ERROR
        cp (hl)
        jr c, .ok
        jp nz, bserr
        inc hl
        ld a, e
        cp (hl)
        jp nc, bserr
.ok:    pop hl
        ld de, (curtol)
        ld a, d
        or e
        ld de, (indice)
        jr z, .nomult
        call umult
        ex de, hl
        ld bc, (indice)
        add hl, bc
        ex de, hl
.nomult:
        inc hl
        inc hl
        ld a, (count)
        dec a
        ld (count), a
        jr nz, .inlpnm
        push hl                     ; HL + 5 + DE*5
        ld h, d
        ld l, e
        add hl, hl
        add hl, hl
        add hl, de
        pop de
        add hl, de
        ld de, 5
        add hl, de
        ld (varpnt), hl
        ret

; DE = CURTOL * the 16-bit size at (HL+5) (big-endian). ?BS ERROR on
; overflow. Preserves HL.
umult:  push hl
        ld bc, 5
        add hl, bc
        ld b, (hl)
        inc hl
        ld c, (hl)
        ld hl, 0
        ld de, (curtol)
        ld a, 16
.l:     add hl, hl
        jp c, bserr
        sla e
        rl d
        jr nc, .n
        add hl, bc
        jp c, bserr
.n:     dec a
        jr nz, .l
        ex de, hl
        pop hl
        ret

; ---- integer conversions -------------------------------------------------------
n32768: db $90, $80, $00, $00, $00
intidx: call chrget
intid2: call frmnum
posint: call chknum
        ld a, (facsgn)
        or a
        jp m, fcerr
; DE = the FAC as a signed 16-bit integer, else ?FC ERROR.
intcnv: call chknum
        ld a, (facexp)
        cp $90
        jr c, .q
        ld hl, n32768
        call fcomp
        jp nz, fcerr
.q:     call qint
        ld a, (facmo)
        ld d, a
        ld a, (faclo)
        ld e, a
        ret

; FAC = signed 16-bit DE.
givabf: xor a
        ld (valtyp), a
        ld a, d
        ld (facho), a
        ld a, e
        ld (facmoh), a
        ld b, $90
        jp floats
; FAC = unsigned byte E.
sngflt: ld d, 0
        jr givabf

; E = a byte expression (0-255); A and flags = the next character.
gtbytc: call chrget
getbyt: call frmnum
conint: call posint
        ld a, d
        or a
        jp nz, fcerr
        jp chrgot

; DE = an address expression (0-65535).
evladr: call frmnum
getadr: ld a, (facsgn)
        or a
        jp m, fcerr
        ld a, (facexp)
        cp $91
        jp nc, fcerr
        call qint
        ld a, (facmo)
        ld d, a
        ld a, (faclo)
        ld e, a
        ret
