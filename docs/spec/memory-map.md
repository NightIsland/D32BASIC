# Memory map on the Next

Initial plan for the MVP. It will be refined as code size becomes known.

## Principles

* The interpreter runs as a .NEX with the CPU at 28 MHz and does not use the
  Spectrum ROM: it has its own keyboard scan, screen output and IM2 interrupt
  handler. That lets the test harness run it in jnext with no SD card image,
  and makes it immune to which ROM NextZXOS left paged in.
* File access goes through `RST $08` esxDOS calls, which NextZXOS provides on
  real hardware and jnext's esxDOS stand-in provides in tests.
* The BASIC workspace is one flat 32K block, so every pointer the interpreter
  keeps (TXTTAB, VARTAB, ARYTAB, STREND, FRETOP, MEMSIZ and so on) is a plain
  16-bit address, just as on the Dragon.

## Z80 address space (8K MMU slots)

| Slots | Addresses | Contents |
|---|---|---|
| 0-1 | `$0000-$3FFF` | Interpreter core code (RAM paged over the ROM area with NextREG `$50`/`$51`). Restart vectors at the bottom. |
| 2-3 | `$4000-$7FFF` | Bank 5: system variables (the Dragon's direct page and `$0100-$03FF` equivalents), stacks, the 512-byte text screen buffer, IM2 vector table, and more interpreter code. |
| 4-7 | `$8000-$FFFF` | BASIC workspace: program text, variables, arrays, string space. 32K, slightly more than a Dragon 32 gives after `PCLEAR 4`. |

Code that does not fit in slots 0-3 (graphics, PLAY, file commands, error
messages) lives in extra 8K pages and is paged into slot 1 for the duration of
a call by a small trampoline. Graphics pages do **not** come out of the BASIC
workspace as they do on a Dragon: `PCLEAR` is accepted and checked, but the
pixels live in separate Layer 2 RAM.

Dragon programs often reserve memory for machine code with `CLEAR n,addr`,
where `addr` is a Dragon address below `$8000`. That memory does not exist in
our workspace, so an `addr` below `$8000` only sets the string space and
leaves the top of memory where it is, instead of giving `?OM ERROR`. Writes
with `POKE` to the Dragon's I/O area (`$FF00` up) are ignored.

## Display

* **Text screen:** 32x16 characters, the Dragon layout, kept in a 512-byte
  buffer laid out like Dragon video RAM (same character codes, including
  inverse video and the 4-colour semigraphics blocks), so `PRINT@`, scrolling
  and `PEEK`/`POKE` of the screen behave the same. The renderer draws each
  character as an 8x12 glyph from the MC6847 character set into a 256x192
  Layer 2 bitmap, in the Dragon's green and dark green.
* **PMODE graphics:** PMODE 0-4 resolutions and colour sets, drawn into the
  same 256x192 Layer 2 bitmap (lower resolutions are pixel-doubled). `SCREEN`
  switches between showing the text buffer and the graphics page.
* **Later (Next extensions):** new PMODE numbers for Next modes such as
  256x192 in 256 colours, 320x256 and sprites, kept isolated from the core.

Layer 2 uses 48K (three 16K banks). The renderer pages it into slot 1
briefly while drawing, so the BASIC workspace is never touched.

## Other hardware

| Dragon | Next |
|---|---|
| Keyboard matrix (PIA0) | Next membrane and PS/2 keyboard via port `$FE` and NextREGs `$B0`/`$B1`; BREAK is the Next BREAK key, CLEAR is mapped to a spare key. |
| 50 Hz field sync IRQ (TIMER, PLAY timing, cursor blink) | ULA frame interrupt (IM2), 50 Hz. |
| `SOUND`, `PLAY` (6-bit DAC) | AY chip 1, tone channels. |
| Joysticks (`JOYSTK`) | Next joystick ports (Kempston), scaled to 0-63. Later. |
| Cassette (`CLOAD`, `CSAVE`) and Dragon DOS | Files on the SD card (see below). |

## Files on the SD card

`SAVE "NAME"` writes `NAME.BAS` in Dragon DOS format: a 9-byte header (`$55`,
file type `$01`, load address, length, exec address, `$AA`) followed by the
tokenised program, so files can be moved to and from real Dragons and
emulators. `SAVE "NAME",A` writes plain ASCII. `LOAD` accepts either and
rebuilds the line links for our memory layout. `CSAVE`/`CLOAD` do the same, so
old programs that use them still work.
