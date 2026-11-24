; D32BASIC - Dragon BASIC for the ZX Spectrum Next
; Copyright (C) 2026 the D32BASIC authors. Licensed under the GNU GPL v3.
;
; Memory map (see docs/spec/memory-map.md):
;   $0000-$3FFF  interpreter core, RAM pages 16-17 paged over the ROM area
;   $4000-$4FFF  bank 5: text screen buffer and system variables
;   $5000-$7FFF  bank 5: boot code, the runtime and more interpreter code
;   $8000-$FFFF  BASIC workspace (program, variables, stack, strings)
; Layer 2 (256x192) lives in banks 9-11.

        DEVICE ZXSPECTRUMNEXT
        OPT --zxnext

        INCLUDE "config.inc"
        INCLUDE "sysvars.asm"

CORE_PAGE       EQU 16
L2_BANK         EQU 9
BOOT_STACK      EQU $FF00           ; in the workspace, unused at boot
WORKSPACE       EQU $8000

; ===========================================================================
; Bank 5 code: boot and runtime
; ===========================================================================
        MMU 2 3, 10
        ORG $5000
boot:
        di
        nextreg $07, 3                  ; 28 MHz
        ld sp, BOOT_STACK
    IF TESTMODE
        call load_autotype              ; while RST $08 still reaches esxDOS
    ENDIF
        nextreg $50, CORE_PAGE          ; core code over the ROM area
        nextreg $51, CORE_PAGE + 1
        nextreg $12, L2_BANK            ; Layer 2: 256x192, banks 9-11
        nextreg $70, 0
        nextreg $14, $25                ; transparency: a colour we never use
        nextreg $16, 0
        nextreg $17, 0
        nextreg $1C, 1                  ; reset the Layer 2 clip window
        nextreg $18, 0
        nextreg $18, 255
        nextreg $18, 0
        nextreg $18, 191
        nextreg $68, $80                ; ULA off: Layer 2 is the screen
        ld bc, L2_PORT
        ld a, 2                         ; Layer 2 visible
        out (c), a
        xor a                           ; black border
        out ($FE), a
        im 1
        jp cold_start

        INCLUDE "rt_screen.asm"
        INCLUDE "rt_keyboard.asm"
        INCLUDE "rt_dos.asm"
        INCLUDE "bas_graph.asm"
    IF TESTMODE
        INCLUDE "testmode.asm"
    ENDIF
bank5_code_end:
        ASSERT bank5_code_end <= $8000

; ===========================================================================
; Core: RAM pages 16-17 at $0000-$3FFF
; ===========================================================================
        MMU 0 1, CORE_PAGE
        ORG $0000
        di
        jp boot

        ORG $0038
; Frame interrupt, 50 Hz.
isr:
        push af
        push bc
        push de
        push hl
        ld hl, (ticker)
        inc hl
        ld (ticker), hl
        ld hl, frames
        inc (hl)
        call kb_scan
        pop hl
        pop de
        pop bc
        pop af
        ei
        reti

        ORG $0066
        retn

        ORG $0070
        INCLUDE "basic.asm"
core_end:
        ASSERT core_end <= $4000

; ===========================================================================
    IF TESTMODE
        SAVENEX OPEN "build/d32basic-test.nex", boot, BOOT_STACK
    ELSE
        SAVENEX OPEN "build/d32basic.nex", boot, BOOT_STACK
    ENDIF
        SAVENEX CORE 3, 0, 0
        SAVENEX CFG 0, 0, 0, 0
        SAVENEX AUTO
        SAVENEX CLOSE
