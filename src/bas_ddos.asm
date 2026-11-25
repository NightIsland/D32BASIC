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
