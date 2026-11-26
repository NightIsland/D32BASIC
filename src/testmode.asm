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

; Graphics are leaving the screen: ask the harness for a screenshot, taken
; at the end of this frame, and keep the picture until then.
tshot:  push bc
        ld bc, SHOT_PORT
        out (c), a
        pop bc
        halt
        halt
        ret

; End the test run with exit code A.
test_exit:
        ld bc, EXIT_PORT
        out (c), a
        ret

; AUTOTYPE.TXT is kept in its own 8K page. At boot it is read through slot
; 6 (the workspace is not in use yet); afterwards TEST_INCHR pages it into
; slot 0 for a moment to fetch each byte. AT_PTR and AT_END are offsets.
AT_PAGE         EQU 30
AUTOTYPE_MAX    EQU $2000

; Load AUTOTYPE.TXT and set at_ptr/at_end. Must run before RAM is paged
; over the ROM area, while RST $08 still reaches esxDOS.
load_autotype:
        ld hl, 0
        ld (at_ptr), hl
        ld (at_end), hl
        ld bc, $243B                ; remember slot 6's page
        ld a, $56
        out (c), a
        inc b
        in a, (c)
        ld (.slot6 + 3), a
        nextreg $56, AT_PAGE
        ld a, '*'
        ld ix, autotype_name
        ld b, FA_READ
        rst $08
        db F_OPEN
        jr c, .slot6
        push af
        ld ix, $C000
        ld bc, AUTOTYPE_MAX
        rst $08
        db F_READ
        jr c, .close
        ld (at_end), bc
.close: pop af
        rst $08
        db F_CLOSE
.slot6: nextreg $56, 0              ; operand patched above
        ret

; Next typed character for the line input: A = char. Skips CR (files use
; CRLF or LF), turns LF into CR, and ends the run when the input is used up.
test_inchr:
        push hl
        push de
        ld a, 1                     ; the oracle records from the first input
        ld (dbg_on), a
.again: ld hl, (at_ptr)
        ld de, (at_end)
        or a
        sbc hl, de
        jr nc, .end
        add hl, de
        di
        nextreg $50, AT_PAGE
        ld a, (hl)
        nextreg $50, CORE_PAGE
        ei
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
