# Architecture and decisions

## What we are building

A `.NEX` for the ZX Spectrum Next that behaves like a Dragon 32 running its
built-in BASIC: same keywords and tokens, same maths and number formatting,
same error messages, the same 32x16 text screen, PMODE graphics, `PLAY` and
`SOUND`, with programs saved to and loaded from the SD card.

Out of scope: running Dragon machine code, emulating the 6847/SAM/PIA
registers, cassette hardware, and tricks that depend on poking video hardware.

## Decisions

| Decision | Why |
|---|---|
| Native Z80N assembly, built with sjasmplus | Speed on a 28 MHz Z80N, full control over memory, and straightforward Next extensions. sjasmplus is the standard Next assembler and writes `.NEX` directly. |
| Reimplement, do not emulate | Running the Dragon ROM in a 6809 emulator would be slower and would mean shipping Microsoft's code. We write our own Z80 code and use the 6809 source only as a description of behaviour. No Microsoft code is copied. |
| Byte-compatible tokens | Programs tokenise to the same bytes as on a Dragon ([tokens](spec/tokens.md)), so saved files are interchangeable. |
| Bit-identical floating point | Same 5-byte format and the same algorithms, so every printed number matches ([float](spec/float.md)). |
| Authentic 32x16 screen | Chosen by the project owner. Programs that use `PRINT@` and screen layouts work unchanged. Wider modes can come later as extensions. |
| Tested against the real ROM | Each test is typed into the real ROM and into our `.NEX`; output must match exactly ([testing](testing.md)). |
| No Spectrum ROM dependency | Own keyboard, screen and interrupt code, file access only through `RST $08`. Runs the same under NextZXOS and in jnext without an SD image. |
| Dragon DOS file format on SD | `SAVE` writes Dragon DOS-style tokenised `.BAS` files; `SAVE "X",A` writes ASCII. |

## Source layout

    src/            Z80N source (main.asm includes everything)
    tests/cases/    BASIC test programs, typed as keystrokes
    tests/expected/ what the real Dragon ROM printed for each case
    tests/dos/      DragonDOS cases, checked against the DragonDOS ROM
    tests/next/     cases for what a Dragon lacks (SD files, extensions)
    tests/pictures/ cases that also check a screenshot, pixel for pixel
    tests/run.py    the harness
    tools/oracle/   the 6809 oracle: ROM builder and headless runner
    docs/           specs and design notes

## Interpreter structure (step 2 onwards)

The interpreter follows the same broad structure as the Dragon's, because
matching behaviour is much easier when the moving parts line up:

* **Line editor and tokeniser:** read a line into a buffer, crunch keywords to
  tokens, then either execute it directly or insert it into the program.
* **Program store:** lines kept in ascending order as
  `link(2) number(2) tokens... 0`, ending with a zero link.
* **Interpreter loop:** fetch the next statement, dispatch on its token
  through a jump table, handle `BREAK` between statements.
* **Expression evaluator:** operator-precedence parsing over FAC and ARG,
  with the same precedence table as the ROM.
* **Variables:** simple variables (7 bytes: 2-char name + 5-byte value or
  string descriptor), then arrays, then free space, then strings growing down
  from the top, with the same garbage collector behaviour.
* **Devices:** screen, keyboard, SD files, printer (later), behind one
  character I/O layer.
