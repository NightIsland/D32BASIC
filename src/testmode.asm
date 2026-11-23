; TESTMODE support: debug text output, the harness exit, and reading the
; AUTOTYPE.TXT file that the harness puts beside the .NEX (served by jnext's
; esxDOS stand-in). Never assembled into release builds.

; Write the zero-terminated string at HL to the debug port.
dbg_puts:
        ld a, (hl)
        or a
        ret z
        call dbg_putc
        inc hl
        jr dbg_puts

; Write A to the debug port (preserves all registers).
dbg_putc:
        push bc
        ld bc, DBG_PORT
        out (c), a
        pop bc
        ret

; End the test run with exit code A.
test_exit:
        ld bc, EXIT_PORT
        out (c), a
        ret

; esxDOS calls
F_OPEN          EQU $9A
F_CLOSE         EQU $9B
F_READ          EQU $9D
FA_READ         EQU $01

AUTOTYPE_BUF    EQU $7000           ; bank 5, below the boot stack's page
AUTOTYPE_MAX    EQU $0FF0

; Load AUTOTYPE.TXT into AUTOTYPE_BUF and set at_ptr/at_end. Must run before
; RAM is paged over the ROM area, while RST $08 still reaches esxDOS.
load_autotype:
        ld hl, AUTOTYPE_BUF
        ld (at_ptr), hl
        ld (at_end), hl
        ld a, '*'
        ld ix, autotype_name
        ld b, FA_READ
        rst $08
        db F_OPEN
        ret c
        push af
        ld ix, AUTOTYPE_BUF
        ld bc, AUTOTYPE_MAX
        rst $08
        db F_READ
        jr c, .close
        ld hl, AUTOTYPE_BUF
        add hl, bc
        ld (at_end), hl
.close: pop af
        rst $08
        db F_CLOSE
        ret

; Next typed character for the line input: A = char. Skips CR (files use
; CRLF or LF), turns LF into CR, and ends the run when the input is used up.
test_inchr:
        push hl
        push de
.again: ld hl, (at_ptr)
        ld de, (at_end)
        or a
        sbc hl, de
        jr nc, .end
        add hl, de
        ld a, (hl)
        inc hl
        ld (at_ptr), hl
        cp 13
        jr z, .again
        cp 10
        jr nz, .ok
        ld a, 13
.ok:    pop de
        pop hl
        ret
.end:   xor a
        call test_exit
        di
        halt

autotype_name:  db "AUTOTYPE.TXT", 0
