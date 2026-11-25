; DragonDOS BASIC extras that are not about disks: error trapping, SWAP.
; Behaviour follows DragonDOS 1.0 (checked against its ROM in the oracle).

; ERROR GOTO line. ERROR GOTO 0 (or no line) turns trapping off.
st_error:
        cp TK_GO
        jp nz, snerr
        call chrget
        cp TK_TO
        jp nz, snerr
        call chrget
        call linget
        ld hl, (linnum)
        ld (traplin), hl
        ret

; Called by ERROR with the error code in (errnum), the stack reset. Records
; ERR and ERL; if a trap is set and a program is running, goes to the trap
; line and does not return.
errtrap:
        xor a
        ld (autofl), a
        ld hl, (curlin)
        ld (errlin), hl
        ld a, (errnum)
        ld (errcod), a
        ld a, h
        and l
        inc a
        ret z                           ; direct mode: never trapped
        ld hl, (traplin)
        ld a, h
        or l
        ret z
        ld (linnum), hl
        call fndlin
        jr c, .gone
        pop af                          ; not returning to ERROR
        call crdo                       ; DragonDOS starts a new line
        call dexptr
        jp newstt
.gone:  ld hl, 0                        ; no such line: DragonDOS loops
        ld (traplin), hl                ; forever; we report ?UL instead
        ld a, ERR_UL
        ld (errnum), a
        ret

; RUN clears ERR, ERL and the trap.
errclr: ld hl, 0
        ld (traplin), hl
        ld (errlin), hl
        xor a
        ld (errcod), a
        ret

; ERR: the code of the last error (twice its number in the error table).
fn_err: ld a, (errcod)
        ld e, a
        jp sngflt
; ERL: the line of the last error, -1 in direct mode.
fn_erl: ld de, (errlin)
        jp givabf

; SWAP var, var: exchange two variables or array elements of one type.
st_swap:
        call ptrget
        push hl
        ld a, (valtyp)
        push af
        call chkcom
        ld hl, (arytab)
        push hl
        call ptrget
        ex de, hl                       ; DE = second
        pop bc                          ; BC = ARYTAB before
        pop af
        pop hl                          ; HL = first
        push de
        push af
        push hl
        ld hl, (arytab)                 ; a new simple variable moves the
        or a                            ; arrays up, and the first with
        sbc hl, bc                      ; them if it is an array element
        ex de, hl                       ; (DragonDOS 1.0 swaps with the
        pop hl                          ; old place and corrupts the
        push hl                         ; array)
        or a
        sbc hl, bc
        pop hl
        jr c, .simp
        add hl, de
.simp:  pop af
        ex (sp), hl                     ; (SP) = first, HL = second
        ld b, a
        ld a, (valtyp)
        cp b
        jp nz, tmerr
        pop de                          ; DE = first, HL = second
        ld b, 5
.swp:   ld a, (de)
        ld c, (hl)
        ld (hl), a
        ld a, c
        ld (de), a
        inc hl
        inc de
        djnz .swp
        ret

; AUTO [start[,step]]: number the lines as they are typed, from 100 in
; steps of 10. Each prompt is put in the line as if typed; a line with
; nothing after the number ends AUTO, as does BREAK or an error. Direct
; mode only (?FC in a program).
st_auto:
        push af
        ld hl, (curlin)
        ld a, h
        and l
        inc a
        jp nz, fcerr
        pop af
        ld de, 100
        ld bc, 10
        jr z, .set
        jp nc, snerr                    ; a line number must come next
        call linget
        ld de, (linnum)
        ld bc, 10
        call chrgot
        jr z, .set
        push de
        call chkcom
        jp nc, snerr
        call linget
        ld bc, (linnum)
        ld a, b
        or c
        jp z, snerr
        pop de
.set:   ld (autonx), de
        ld (autoinc), bc
        ld a, 1
        ld (autofl), a
        ret

; Read a line, with the next AUTO number already in it.
autoin: ld a, (autofl)
        or a
        jp z, inlin
        ld hl, (autonx)
        ld de, 64000
        or a
        sbc hl, de
        add hl, de
        jr c, .ok
        xor a
        ld (autofl), a
        jp inlin
.ok:    push hl
        ld de, (autoinc)
        add hl, de
        jr nc, .st
        ld hl, $FFFF
.st:    ld (autonx), hl
        pop hl
        xor a
        ld (inkchr), a
        ld de, BUF
        ld ix, .pow
.dig:   ld c, (ix)
        ld b, (ix + 1)
        ld a, '0' - 1
.sub:   inc a
        or a
        sbc hl, bc
        jr nc, .sub
        add hl, bc
        cp '0'                          ; leading zeros are left out,
        jr nz, .put                     ; but not the units
        push hl
        ld hl, BUF
        or a
        sbc hl, de
        pop hl
        jr nz, .put
        dec bc
        ld a, b
        or c
        ld a, '0'
        jr nz, .skip
.put:   ld (de), a
        inc de
.skip:  inc ix
        inc ix
        ld a, (ix)
        or (ix + 1)
        jr nz, .dig
        ld a, ' '
        ld (de), a
        inc de
        ld hl, BUF
.echo:  ld a, (hl)
        call chrout
        inc hl
        or a
        sbc hl, de
        add hl, de
        jr nz, .echo
        ex de, hl                       ; HL = the end of the line so far
        ld a, l
        sub BUF & $FF
        inc a
        ld b, a                         ; characters + 1
        jp inlinp
.pow:   dw 10000, 1000, 100, 10, 1, 0

; After the line number of a typed line (Z: nothing follows it): an AUTO
; line left empty ends AUTO and keeps any line of that number.
autend: ret nz
        ld a, (autofl)
        or a
        ret z
        xor a
        ld (autofl), a
        pop af
        call crdo
        jp main

; BEEP [n]: n short beeps (1-255).
st_beep:
        ld e, 1
        jr z, .go
        call gnzbyt
.go:    ld a, e
.lp:    push af
        ld hl, 112                      ; AY period for about 1 kHz
        ld d, 15
        call snd_tone
        ld b, 3
        call snd_wait
        call snd_off
        pop af
        dec a
        ret z
        push af
        ld b, 15
        call snd_wait
        call iscntc
        pop af
        jr .lp

; WAIT n: pause for n milliseconds (0-65535), to the nearest frame.
st_wait:
        ret z                           ; WAIT alone does nothing
        call evladr
        ex de, hl
.lp:    ld de, 10
        or a
        sbc hl, de
        ret c
        push hl
        ld b, 1
        call snd_wait
        call iscntc
        pop hl
        ld de, 10
        or a
        sbc hl, de
        ret c
        jr .lp

; HIMEM: the top of BASIC's memory, as a Dragon address where it has one
; (so that CLEAR n,HIMEM+1 leaves it where it is).
fn_himem:
        ld hl, (memsiz)
        ld de, $FA00
        or a
        sbc hl, de
        add hl, de
        jr nc, .next
        ld de, -$7A00
        add hl, de
.next:  ex de, hl
        jp givuns

; FRE$: free string space, after collecting the garbage.
fn_fres:
        call garbag
        ld hl, (fretop)
        ld de, (stktop)
        or a
        sbc hl, de
        ex de, hl
        jp givuns

; FAC = unsigned 32-bit BCDE times 2^(A - $A0).
giv32:  ld (facexp), a
        ld a, b
        ld (facho), a
        ld a, c
        ld (facmoh), a
        ld a, d
        ld (facmo), a
        ld a, e
        ld (faclo), a
        xor a
        ld (facov), a
        ld (facsgn), a
        ld (valtyp), a
        jp normal

; CHAIN: copy every string whose text is in the program (A$="X") into
; string space, so the variables outlive the program. ?OS ERROR if there
; is not room for them.
chnstr: push ix
        ld hl, 0
        ld (chnneed), hl
        ld hl, .count
        ld (walkfn), hl
        call strwlk
        call garbag
        ld hl, (fretop)
        ld de, (stktop)
        or a
        sbc hl, de
        ld de, (chnneed)
        or a
        sbc hl, de
        ld e, ERR_OS
        jp c, error
        ld hl, .copy
        ld (walkfn), hl
        call strwlk
        pop ix
        ret
.count: call .chk
        ret c
        ld hl, (chnneed)
        add hl, bc
        ld (chnneed), hl
        ret
.copy:  call .chk
        ret c
        push hl
        ld hl, (fretop)
        or a
        sbc hl, bc
        ld (fretop), hl
        ex de, hl                       ; DE = its new place
        pop hl
        ld (ix + 2), d
        ld (ix + 3), e
        ldir
        ret
; Carry clear if the string at IX is in the program: HL = it, BC = length.
.chk:   ld a, (ix + 0)
        or a
        scf
        ret z
        ld c, a
        ld b, 0
        ld h, (ix + 2)
        ld l, (ix + 3)
        ld de, (txttab)
        or a
        sbc hl, de
        add hl, de
        ret c                           ; below the program
        ld de, (vartab)
        or a
        sbc hl, de
        add hl, de
        ccf                             ; at or above its end: carry
        ret
