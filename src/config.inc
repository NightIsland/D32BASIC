; Build configuration. TESTMODE is set from the command line (-DTESTMODE=1).
    IFNDEF TESTMODE
TESTMODE        EQU 0
    ENDIF

; Ports used only by TESTMODE builds, watched by the jnext test harness.
DBG_PORT        EQU $10EF           ; text written here goes to the harness log
EXIT_PORT       EQU $11EF           ; writing here ends the run; value = exit code
