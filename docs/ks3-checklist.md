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
   stops a running program (`10 GOTO 10`, `RUN`, then BREAK). CAPS SHIFT+2
   pauses a listing or a running program until another key is pressed.
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

## Settings

15. GRAPH opens the settings screen; BREAK leaves it. Try it at `OK` and
    while `10 PRINT I:I=I+1:GOTO 10` runs: the program's screen comes back
    and it carries on.
16. Set a files folder that exists (1), save with ENTER, `SAVE "X"`, and
    check the file is in that folder. Start D32BASIC again: the setting is
    still there (`D32BASIC.CFG` beside the `.NEX`).
17. Set UNSUPPORTED COMMANDS to IGNORE (2): `DRIVE 1:PRINT "HI"` prints HI.
18. Set the CPU speed (3) to 3.5 MHz: a `FOR` loop runs slower, but
    `SOUND 89,20` still lasts 1.6 seconds.

## Joysticks

19. With a joystick in port 1:
    `10 PRINT JOYSTK(0);JOYSTK(1):GOTO 10`, `RUN`: values 0, 31 or 63 as
    it moves. Note this sets both joystick ports to Kempston mode.

## DragonDOS extras

20. `AUTO`, type `PRINT 1`, ENTER, `PRINT 2`, ENTER, then ENTER on the
    empty `120`: AUTO stops and `LIST` shows lines 100 and 110.
21. `BEEP 3` gives three short beeps; `WAIT 2000` pauses about 2 seconds.
22. `10 ERROR GOTO 100:PRINT 1/0` and `100 PRINT ERR;ERL`, `RUN`: prints
    20 and 10.
23. `MKDIR "D32TEST"`, `CD "D32TEST"`, `CD` shows the folder, `CD ".."`.
    Then `CD "D:"` (if you have a second drive) and `CD` shows D:.
24. Random files: `FWRITE "R";"ONE,";2`, `FREAD "R";A$,B`, `PRINT A$;B`
    shows ONE 2; `PRINT LOF "R"` shows 7; `COPY "R.DAT" TO "S.DAT"`;
    `DIR` shows both.
25. `10 PRINT "FIRST":A=5:CHAIN "SECOND"`, with SECOND.BAS saved as
    `10 PRINT "SECOND";A`: prints FIRST, then SECOND 5.
26. `PRINT FREE` shows the free space on the card (in bytes).

## PMODE 5 (256 colours)

For each of these, type the lines then `RUN`; line 90 keeps the picture on
screen until you press BREAK.

27. `10 PMODE 5:PCLS:SCREEN 1:FOR C=0 TO 255:COLOR C:LINE(C,0)-(C,191),PSET:NEXT`
    and `90 GOTO 90`: 256 stripes, black, then the eight Dragon colours,
    then the Next's colours. BREAK brings the text screen back as normal.
28. `10 PMODE 5:PCLS 2:CIRCLE(128,96),80,3:PAINT(128,96),4,3:SCREEN 1` and
    `90 GOTO 90`: a red disc with a blue ring on yellow.
29. Smooth animation on two screens: type
    `10 PMODE 5,1:SCREEN 1:S=1:X=0`,
    `20 S=3-S:PMODE 5,S:PCLS`,
    `30 CIRCLE(X,96),20,X AND 255:X=X+4:IF X>255 THEN X=0` and
    `40 SCREEN 1:GOTO 20`, then `RUN`. A circle moves steadily left to right
    across a black screen, changing colour, with no flicker, no tearing (a
    break across the circle) and no blank frames. BREAK to stop.
30. `10 PMODE 5,2:PCLS 3:PCOPY 2 TO 1:PMODE 5,1:SCREEN 1:FOR I=1 TO 3000:NEXT`,
    `20 PMODE 4,1:PCLS:LINE(0,0)-(255,191),PSET:SCREEN 1` and `90 GOTO 90`:
    the whole screen is blue for a moment, then a normal PMODE 4 page with
    a green line. After BREAK the text screen looks right.
31. Instant screen changes: `10 PMODE 3,1:PCLS:SCREEN 1,0:CIRCLE(128,96),60,4`,
    `20 FOR I=1 TO 2000:NEXT:PMODE 4,1:PCLS:LINE(0,0)-(255,191),PSET:SCREEN 1`,
    `30 FOR I=1 TO 2000:NEXT:PRINT "BACK"`, `RUN`: text, the circle, the
    line and the text again each appear at once, with no wipe down the
    screen. Then press GRAPH while line 10's circle shows (add
    `15 GOTO 15` to hold it): the settings screen, and BREAK brings the
    circle back.

Report anything odd with what was typed and what happened.
