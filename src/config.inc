; Build configuration. TESTMODE is set from the command line (-DTESTMODE=1).
    IFNDEF TESTMODE
TESTMODE        EQU 0
    ENDIF

; Ports used only by TESTMODE builds, watched by the jnext test harness.
DBG_PORT        EQU $10EF           ; text written here goes to the harness log
EXIT_PORT       EQU $11EF           ; writing here ends the run; value = exit code
SHOT_PORT       EQU $12EF           ; written as graphics leave the screen: the
                                    ; harness takes a screenshot at the frame's end

; esxDOS calls (RST $08 then this byte) and F_OPEN modes.
F_OPEN          EQU $9A
F_CLOSE         EQU $9B
F_READ          EQU $9D
F_WRITE         EQU $9E
F_OPENDIR       EQU $A3
F_READDIR       EQU $A4
F_UNLINK        EQU $AD
F_RENAME        EQU $B0
F_GETFREE       EQU $B1
F_SEEK          EQU $9F
F_FSTAT         EQU $A1
FA_READ         EQU $01
FA_WRITE        EQU $02
FA_OPEN_AL      EQU $08             ; open, or create if need be
FA_CREATE_NEW   EQU $04             ; create; an error if it exists
FA_CREATE_AL    EQU $0C             ; create, or truncate if it exists
