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

; Read AUTOTYPE.TXT and echo it to the debug port (step 1 plumbing check).
test_echo_autotype:
        ld a, '*'
        ld ix, autotype_name
        ld b, FA_READ
        rst $08
        db F_OPEN
        jr c, .missing
        ld (.handle), a
.loop:
        ld a, (.handle)
        ld ix, io_buffer
        ld bc, 256
        rst $08
        db F_READ
        jr c, .done
        ld a, b
        or c
        jr z, .done
        ld hl, io_buffer
.out:   ld a, (hl)
        call dbg_putc
        inc hl
        dec bc
        ld a, b
        or c
        jr nz, .out
        jr .loop
.done:  ld a, (.handle)
        rst $08
        db F_CLOSE
        ret
.missing:
        ld hl, msg_missing
        jp dbg_puts
.handle: db 0

autotype_name:  db "AUTOTYPE.TXT", 0
msg_missing:    db "NO AUTOTYPE.TXT", 13, 0
io_buffer:      ds 256
