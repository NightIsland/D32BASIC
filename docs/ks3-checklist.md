# Checks on a real Next

Everything below passes in jnext, but jnext's esxDOS stand-in, AY and
keyboard are not the real thing. These are the checks that need a real Next
(a KS3, or any Next with NextZXOS). Copy `D32BASIC.NEX` to the SD card and
start it from the Browser.

## Start-up and screen

1. The green 32x16 screen appears with the banner and `OK`, and the cursor
   blinks.
2. Typing works, including every SYMBOL SHIFT symbol (`* - = + < > " ;`
   and so on). The DELETE key and CAPS SHIFT+5 delete; CAPS SHIFT+0 toggles
   lower case (shown inverse, as on a Dragon). `BREAK` (or CAPS SHIFT+SPACE)
   stops a running program (`10 GOTO 10`, `RUN`, then BREAK).
3. `BYE` returns to NextZXOS.
3a. `SCREEN 0,1` turns the text orange; `SCREEN 0,0` back to green.

## SD card files (the riskiest part)

The esxDOS calls run with interrupts off and the ROM paged in for each call.

4. `10 PRINT "HI"`, `SAVE "TEST"`, `NEW`, `LOAD "TEST"`, `LIST`.
5. `SAVE "TESTA",A` then `LOAD "TESTA"` (the ASCII form).
6. `DIR` lists the current folder. Long file names: check what `DIR` shows
   for a file with a long name (it reads entries in esxDOS's short-name mode).
7. `RENAME "TEST" TO "TEST2"`, `KILL "TEST2"`, then `DIR`.
8. `LOAD "NOPE"` gives `?NE ERROR` and the machine carries on.
9. Data files: `10 OPEN "O",#-1,"D":PRINT #-1,"ONE":CLOSE`,
   `20 OPEN "I",#-1,"D":LINE INPUT #-1,A$:PRINT A$:CLOSE`, `RUN` prints ONE.
10. A Dragon DOS `.BAS` file from a real Dragon or XRoar loads and runs.

## Graphics

11. `PMODE 4,1:PCLS:SCREEN 1,1:CIRCLE(128,96),80:PAINT(128,96),1,1`
    then a key loop, e.g. `10 PMODE 3,1:PCLS:SCREEN 1,0:FOR I=1 TO 8:CIRCLE(128,96),I*10,I:NEXT:GOTO 20` with `20 GOTO 20`.
    Check the colours and that nothing flickers or tears.

## Sound

12. `SOUND 89,20` plays middle C for about 1.6 seconds.
13. `PLAY "T4L8CDEFGABO+C"` plays a scale; `PLAY "V31C V5C"` gets quieter.

## Joysticks

14. With a joystick in port 1:
    `10 PRINT JOYSTK(0);JOYSTK(1):GOTO 10`, `RUN`: values 0, 31 or 63 as
    it moves. Note this sets both joystick ports to Kempston mode.

Report anything odd with what was typed and what happened.
