; D32BASIC - Dragon BASIC for the ZX Spectrum Next
; Copyright (C) 2026 the D32BASIC authors. Licensed under the GNU GPL v3.
;
; Step 1 skeleton: boots as a .NEX, and in a TESTMODE build proves the test
; plumbing by echoing tests' typed input back out through the debug port.

        DEVICE ZXSPECTRUMNEXT
        OPT --zxnext

        INCLUDE "config.inc"

        ORG $8000
start:
        di
        nextreg $07, 3                  ; CPU to 28 MHz
        ld sp, stack_top
        ld a, 4                         ; green border, a nod to the Dragon
        out ($FE), a

    IF TESTMODE
        ld hl, msg_hello
        call dbg_puts
        call test_echo_autotype
        xor a
        call test_exit                  ; does not return under the harness
    ENDIF

.idle:  jr .idle

    IF TESTMODE
        INCLUDE "testmode.asm"
msg_hello:      db "D32BASIC SKELETON", 10, 0
    ENDIF

        ds 256
stack_top:

    IF TESTMODE
        SAVENEX OPEN "build/d32basic-test.nex", start, stack_top
    ELSE
        SAVENEX OPEN "build/d32basic.nex", start, stack_top
    ENDIF
        SAVENEX CORE 3, 0, 0
        SAVENEX CFG 4, 0, 0, 0
        SAVENEX AUTO
        SAVENEX CLOSE
