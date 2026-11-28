# Memory map on the Next

How D32BASIC uses the Next's memory, screen and hardware.

## Principles

* The interpreter runs as a .NEX with the CPU at 28 MHz and does not use the
  Spectrum ROM: it has its own keyboard scan, screen output and IM 1 frame
  interrupt handler (at `$0038` in our own RAM). That lets the test harness
  run it in jnext with no SD card image, and makes it immune to which ROM
  NextZXOS left paged in.
* File access goes through `RST $08` esxDOS calls, which NextZXOS provides on
  real hardware and jnext's esxDOS stand-in provides in tests. A small
  trampoline in bank 5 pages the ROM back in for each call.
* The BASIC workspace is one flat 32K block, so every pointer the interpreter
  keeps (TXTTAB, VARTAB, ARYTAB, STREND, FRETOP, MEMSIZ and so on) is a plain
  16-bit address, just as on the Dragon.

## Z80 address space (8K MMU slots)

| Slots | Addresses | Contents |
|---|---|---|
| 0-1 | `$0000-$3FFF` | Interpreter core (RAM pages 16-17 over the ROM area): the interrupt handler at `$0038`, the interpreter loop, tokeniser, expressions, maths, strings, `PRINT`/`INPUT`, `EDIT`, `RENUM`. |
| 2-3 | `$4000-$7FFF` | Bank 5: system variables, the 512-byte text screen buffer and line buffer, then the Next extensions' code (`$4000-$4FFF`), then more code from `$5000`: screen and keyboard drivers, SD files, graphics, `PLAY`/`SOUND`. |
| 4-7 | `$8000-$FFEF` | BASIC workspace, laid out as on a Dragon: graphics pages first, then program text, variables, arrays, free space, the stack and string space at the top. |

### Graphics pages are in the workspace, as on a Dragon

The first plan kept the PMODE pixels outside the workspace. The built version
keeps them inside it, in the Dragon's own format, because so many programs
depend on that: `PCLEAR` moves the program up and down, `PEEK`/`POKE` of the
graphics pages work, `PCOPY` copies real memory, and `PRINT MEM` gives the
Dragon's answers.

* The eight possible 1.5K graphics pages start at `$8000` (the Dragon's
  `$0600`, so the offset is `$7A00`). `PCLEAR 4`, the default, puts the
  program at `$9801`, with the Dragon's zero byte at `$9800`.
* Drawing commands write the Dragon bytes. Every byte that changes on the
  page being shown is also drawn into Layer 2 straight away, and `SCREEN`
  redraws the whole display, so the picture on the Next always matches the
  bytes in memory.

### Other pages

| Page | Use |
|---|---|
| 16-17 | Interpreter core (slots 0-1). |
| 18-23 (banks 9-11) | Layer 2, 256x192: the text screen and PMODE 0-4. Written through the Layer 2 write window (port `$123B`), never mapped over the workspace. |
| 38-43 (banks 19-21) | A second copy of that picture. Writes go to the copy NextREG `$13` names, which is the one on show; `SCREEN`, or the text coming back, draws the whole new picture into the other copy and then shows it, so the change is instant, as on a Dragon (`rt_flip.asm`). |
| 24-29 (banks 12-14) | PMODE 5 screen 1: a whole 256x192 Layer 2 picture, one byte a point. |
| 32-37 (banks 16-18) | PMODE 5 screen 2. |
| 30 | Test builds only: the keystrokes typed by the harness (`AUTOTYPE.TXT`), read a byte at a time through slot 0. |

Dragon programs often reserve memory for machine code with `CLEAR n,addr`,
where `addr` is a Dragon address below `$8000`. That memory does not exist in
our workspace, so an `addr` below `$8000` only sets the string space and
leaves the top of memory where it is, instead of giving `?OM ERROR`. Writes
with `POKE` to the Dragon's I/O area (`$FF00` up) are ignored.

## Display

* **Text screen:** 32x16 characters, the Dragon layout, kept in a 512-byte
  buffer laid out like Dragon video RAM (same character codes, including
  inverse video and the semigraphics blocks), so `PRINT@`, scrolling and
  `PEEK`/`POKE` of the screen behave the same. The renderer draws each
  character as an 8x12 glyph into the 256x192 Layer 2 bitmap, in green and
  dark green, or orange with `SCREEN 0,1`.
* **PMODE graphics:** PMODE 0-4 resolutions and colour sets, drawn into the
  same Layer 2 bitmap (lower resolutions are pixel-doubled). `SCREEN 1`
  shows the graphics page, `SCREEN 0` the text.
* **PMODE 5 (Next extension):** 256x192 in 256 colours. Each of its two
  screens is a whole Layer 2 picture in its own banks, so `SCREEN 1` just
  points NextREG `$12` at it and drawing on the screen on show appears at
  once. The drawing code reaches a point by paging its 8K into slot 1
  (`$2000-$3FFF`) for a moment; that code is in bank 5 and the frame
  interrupt never touches slot 1, so interrupts stay on. Colours come from
  Layer 2's second palette (0 black, 1-8 the Dragon's colours, 9-255 the
  standard RRRGGGBB colours), which only PMODE 5 shows. The global
  transparency colour (NextREG `$14`) is `$01`, which neither Layer 2
  palette holds. See [next-extensions.md](../next-extensions.md).
* **Later (Next extensions):** `PMODE 6` and `7` (320x256 and 640x256),
  sprites and wider text, kept isolated from the core.

## Other hardware

| Dragon | Next |
|---|---|
| Keyboard matrix (PIA0) | Next keyboard matrix via port `$FE`, read in the frame interrupt. SYMBOL SHIFT gives the symbols printed on the keys. CAPS SHIFT+0 is the Dragon's SHIFT+0 (lower case toggle); CAPS+5/6/7/8 are the arrows (left arrow deletes, as on the Dragon); CAPS+SPACE is BREAK; CAPS+1 is CLEAR; CAPS+2 is SHIFT+@ (pause a listing or program until another key). The KS2/KS3 extra keys (DELETE, BREAK, arrows, `; " , .`, CAPS LOCK, INV VIDEO) are read from NextREGs `$B0`/`$B1` and kept out of the matrix. |
| 50 Hz field sync IRQ (TIMER, PLAY timing, cursor blink) | ULA frame interrupt (IM 1), 50 Hz. |
| `SOUND`, `PLAY` (6-bit DAC) | AY chip 1, tone channel A. Notes are equal-tempered (octave 1 C is 65.4 Hz, as on the Dragon); `V0`-`V31` maps to AY levels by loudness; note lengths are timed by the frame interrupt, so they last exactly as long as on a Dragon. |
| Joysticks (`JOYSTK`) | Next joystick ports, set to Kempston at start-up. They are digital, so each axis reads 0, 31 or 63. `JOYSTK(0)`/`(1)` are port 1, `(2)`/`(3)` port 2. |
| Cassette (`CLOAD`, `CSAVE`, `OPEN`/`PRINT #-1`/`INPUT #-1`) and Dragon DOS | Files on the SD card (see below). |
| Printer (`LLIST`, `PRINT #-2`) | None: the output is thrown away. |

## Files on the SD card

`SAVE "NAME"` writes `NAME.BAS` in Dragon DOS format: a 9-byte header (`$55`,
file type `$01`, load address, length, exec address, `$AA`) followed by the
tokenised program, so files can be moved to and from real Dragons and
emulators. `SAVE "NAME",A` writes plain ASCII. `LOAD` accepts either and
rebuilds the line links for our memory layout. `CSAVE`/`CLOAD` do the same, so
old programs that use them still work.

Data files use the cassette's device number: `OPEN "O",#-1,"NAME"` creates
`NAME.DAT` (when the name has no extension), `PRINT #-1` writes lines ending
CR LF, and `OPEN "I"`, `INPUT #-1`, `LINE INPUT #-1` and `EOF(-1)` read them
back (CR, LF or CR LF all end a line). One data file can be open at a time,
as with the one cassette. A file still open when the program stops is
written out and closed.

## Settings

The GRAPH key opens a settings screen at any time, even while a program
runs: the polling routine (`POLCAT`) sees the key, saves the 512-byte text
screen, the cursor and the display state, shows the settings, and puts it
all back afterwards. The settings are kept in `D32BASIC.CFG`, a plain text
file in the folder the `.NEX` was started from (found with `F_GETCWD` at
start-up):

    FOLDER=D:/DRAGON/       programs and data files, on any drive (empty: the start-up folder)
    UNSUPPORTED=ERROR       or IGNORE: skip statements D32BASIC does not have
    SPEED=28                CPU speed in MHz: 3.5, 7, 14 or 28

The files folder's drive is made the current drive (`M_GETSETDRV`, the
start-up drive when the folder names none) and the folder the current folder
(`F_CHDIR`), so every file command uses it with no change of its own.
`F_CHDIR` alone is not enough for another drive: it changes that drive's
folder, not which drive is current. With `IGNORE`, an
unsupported statement is skipped like `DATA` (to the next `:` or the end of
the line); unsupported functions still give `?FC ERROR`.
