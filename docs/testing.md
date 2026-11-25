# Testing

## How it works

A test case is a text file in `tests/cases/`. Each line is typed at the
keyboard and followed by ENTER, exactly as a person would type it. A case can
type a program and `RUN` it, or type direct commands.

The same keystrokes go to two machines:

1. **The oracle**: the real Dragon BASIC ROM, run by `tools/oracle/dragon_oracle`,
   a small headless 6809 machine. It feeds keys through the ROM's keyboard
   routine and records every character the ROM sends to the screen. Its output
   for each case is committed as `tests/expected/NAME.txt`.
2. **D32BASIC**: the TESTMODE build of the `.NEX` (`build/d32basic-test.nex`),
   run headless in jnext with no SD card image. It reads the keystrokes from
   `AUTOTYPE.TXT`, served by jnext's esxDOS stand-in, writes every character it
   prints to debug port `$10EF`, and when the input is used up and it is back at
   the prompt, writes its exit code to port `$11EF`, which ends the run.

The case passes when the two outputs are identical.

## Running

    make test                # all cases
    python3 tests/run.py 05  # cases whose names start with 05
    make plumbing            # harness self-check

`JNEXT` points at the jnext binary if it is not on `PATH`.

## Tools

* **sjasmplus**: `git clone https://github.com/z00m128/sjasmplus && make`.
* **jnext**: an SDL-only build is enough, and needs SDL3, zlib, libpng and
  libcurl development files:

      git clone https://github.com/jorgegv/jnext && cd jnext
      cmake -B build-sdl -DCMAKE_BUILD_TYPE=Release -DENABLE_QT_UI=OFF \
            -DENABLE_DEBUGGER=OFF -DENABLE_TESTS=OFF -DJNEXT_WERROR=OFF
      cmake --build build-sdl -j

* **lwasm** (LWTools), only needed to build the oracle ROM.

## Regenerating expected output

Only needed when you add or change a case. The preferred oracle is a genuine
Dragon 32 ROM image (16K):

    make rom D32ROM=/path/to/d32.rom            # copies it to build/oracle/d32.rom
    make expected                               # rewrites tests/expected/

Without one, build the ROM from the Dragon BASIC source listing (the
DragonBasic repository) instead:

    make rom DRAGONBASIC=/path/to/DragonBasic

`build_rom.py` assembles the 32-mode ROM from the source with lwasm. The
source is Dragon 64 BASIC, so the result is byte-identical to the Dragon 64's
first ROM (checked against a real dump), which differs from the Dragon 32 ROM
in 26 small places, mostly Dragon 64 extras and fixes. All starter cases give
the same output on both. Either way, the ROM is a local file used only for
testing. It is git-ignored and must never be committed. You can also point
`D32_ROM` at any ROM image without copying it.

For the DragonDOS commands, the oracle can also run with the 8K DragonDOS
cartridge ROM mapped at `$C000`:

    build/oracle/dragon_oracle build/oracle/d32.rom case.bas --cart ddos10.rom

It has no disk controller, so anything that needs a disk fails (`DIR`,
`FREE(1)`), but the commands that don't, such as `ERROR GOTO`, `ERR`, `ERL`,
`SWAP`, `HIMEM` and `BEEP`, behave as on a real Dragon with DragonDOS. Like
the BASIC ROM, the DragonDOS ROM stays a local file and is never committed.

## Writing cases

* Type only characters a Dragon keyboard has: upper case, digits and the usual
  punctuation. There is no `|`, `{`, `}`, `~` or lower case.
* Keep each case to one area of the language so a failure points somewhere.
* Avoid anything that depends on timing (`TIMER`, `INKEY$` loops) or on
  machine addresses (`PEEK`/`POKE`/`VARPTR` values), which are not meant to
  match.
* Look at the generated expected output before committing it: it is what a
  real Dragon does, quirks included, and our code has to reproduce it.
