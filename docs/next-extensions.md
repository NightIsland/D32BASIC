# Next extensions

D32BASIC adds Next hardware features to Dragon BASIC in small phases. Each
one only gives a meaning to something a Dragon refuses, such as `PMODE 5`,
which is `?FC ERROR` on a Dragon. So every Dragon program behaves exactly as
before, and a program that uses an extension stops with an error on a real
Dragon instead of doing something else.

| Phase | Extension | Status |
|---|---|---|
| 4a | `PMODE 5`: 256x192 in 256 colours, with two screens | done |
| 4b | `PLAY A$,B$,C$`: three voices | planned |
| 4c | A mouse through `JOYSTK(4)` to `JOYSTK(6)` | planned |
| 4d | `PALETTE`: choose the colours | planned |
| 4e | `PMODE 6` and `7`: 320x256 and 640x256 | planned |
| 4f | Hardware sprites | planned |
| 4g | `WIDTH 40` and `WIDTH 80` | planned |

## PMODE 5: 256 colours

`PMODE 5` is a 256x192 screen where every point can be any of 256 colours.
The coordinates are the same as in every other PMODE, x 0 to 255 and y 0 to
191, but here each one is a single point, so nothing is scaled.

    10 PMODE 5,1:PCLS:SCREEN 1
    20 FOR C=0 TO 255:COLOR C:LINE(C,0)-(C,191),PSET:NEXT
    30 GOTO 30

### Colours

| Colour | |
|---|---|
| 0 | black |
| 1 to 8 | the Dragon's colours, as in `COLOR`: green, yellow, blue, red, buff, cyan, magenta, orange |
| 9 to 255 | the Next's standard colours: the number in binary is RRRGGGBB, three bits of red, three of green and two of blue |

So a program can move from `PMODE 4` to `PMODE 5` and keep its colours. Some
of the standard colours: 28 bright green, 224 red, 227 magenta, 252 yellow,
255 white, 146 grey, 3 blue (the Dragon's blue is 3 as well).

`PMODE 5` sets the colours to 5 (buff) on 0 (black). `COLOR`, `PCLS`,
`PSET`, `PRESET`, `CIRCLE`, `PAINT` and `DRAW`'s `C` take any colour from 0 to
255; 256 or more is `?FC ERROR`. `PPOINT(x,y)` gives the colour of a point,
0 to 255. The colour set in `SCREEN 1,1` makes no difference in this mode.

### Two screens

There are two PMODE 5 screens, 1 and 2. `PMODE 5,1` or `PMODE 5,2` chooses
the one to draw on (`PMODE 5` alone is screen 1, and `PMODE ,2` changes
screen without changing mode). `SCREEN 1` shows the screen being drawn on, as
on a Dragon.

Drawing on the screen on show appears at once. Drawing on the other screen
doesn't, so a program can draw the next picture out of sight and then show
it. When `SCREEN 1` changes from one screen to the other it waits for the
start of the next frame, so the picture never changes part-way down:

    10 PMODE 5,1:SCREEN 1:S=1:X=0
    20 S=3-S:PMODE 5,S:PCLS
    30 CIRCLE(X,96),20,X AND 255:X=X+4:IF X>255 THEN X=0
    40 SCREEN 1:GOTO 20

`PCOPY 1 TO 2` (or `2 TO 1`) copies a whole PMODE 5 screen. In `PMODE 5`,
`PCOPY` only knows screens 1 and 2; to copy the Dragon's graphics pages, go
back to `PMODE 0` to `4` first. `PCLS` clears only the screen being drawn on.

The screens are kept in the Next's own memory, not in the 32K BASIC
workspace, so `PCLEAR`, `MEM` and the room for programs are the same as
always. `PEEK` and `POKE` don't reach the PMODE 5 screens; `PPOINT` does. Both
screens start black, and keep their pictures when you change PMODE and come
back.

### GET and PUT

`GET` and `PUT` work in PMODE 5 with one array byte for each point. The
array needs one element for every five points: a 40x40 area is 1,600 points,
so `DIM A(319)` is enough. An array that is too small gives `?FC ERROR`
before anything is copied.

`PUT`'s action works on the colour numbers:

| Action | Result |
|---|---|
| `PSET` or none | the array's colours |
| `PRESET` | the array's colours inverted (255 minus the colour) |
| `AND`, `OR` | the array's colour ANDed or ORed with the screen's |
| `NOT` | the screen's colours inverted |

`,G` makes no difference to `GET` in this mode.
