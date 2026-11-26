# D32BASIC

Dragon 32 BASIC for the ZX Spectrum Next.

D32BASIC is a native Z80N reimplementation of the Dragon 32's Microsoft
Extended Color BASIC, delivered as a `.NEX` program, in the same spirit as the
Next's BBC BASIC: type Dragon BASIC programs, run them, and save and load them
on the SD card. It aims to run Dragon BASIC *programs* (not Dragon machine-code
software), with the authentic 32x16 green screen, PMODE graphics, `PLAY` and
`SOUND`. Later versions will add Next hardware features through new PMODEs.

**Status:** version 1.1, checked on a real Next (KS3). You can type, edit,
run, save and load Dragon BASIC programs: the whole core language, PMODE graphics (`PSET`, `LINE`, `CIRCLE`, `PAINT`,
`DRAW`, `GET`/`PUT`, `PCOPY` and the rest, byte-identical to a Dragon), the
text-screen block graphics, `PLAY` and `SOUND` on the AY chip, `EDIT`,
`LINE INPUT`, `JOYSTK`, and SD card files (`SAVE`, `LOAD`, `MERGE`, `DIR`,
`KILL`, `RENAME`, and data files through `OPEN`/`PRINT #-1`/`INPUT #-1`).
The GRAPH key opens a settings screen for the files folder (on any drive),
the CPU speed and whether unsupported commands are skipped.

Version 1.1 adds the DragonDOS BASIC extras: `ERROR GOTO`, `ERR`, `ERL`, `SWAP`,
`AUTO`, `BEEP`, `WAIT`, `CHAIN`, `COPY`, `FREE`, `HIMEM`, `FRE$`,
random-access files (`CREATE`, `FREAD`, `FWRITE`, `FLREAD`, `LOF`, `LOC`)
and two folder commands of our own, `CD` and `MKDIR`; see
[docs/dragondos.md](docs/dragondos.md).

The Next hardware extensions have started: `PMODE 5` gives a 256x192
screen in 256 colours, with two screens for flicker-free animation. See
[docs/next-extensions.md](docs/next-extensions.md) and
[docs/ROADMAP.md](docs/ROADMAP.md).

## Using it

Download `D32BASIC.NEX` from the latest release, copy it to your SD card and
run it from the NextZXOS browser. `BYE` returns to NextZXOS.

## Building

You need [sjasmplus](https://github.com/z00m128/sjasmplus) on your `PATH`.

    make                 # build/d32basic.nex

## Testing

Every feature is checked against a real Dragon BASIC ROM. Each test case in
`tests/cases/` is typed into both the real ROM (run headless by a small 6809
emulator, `tools/oracle/`) and our `.NEX` (run headless in
[jnext](https://github.com/jorgegv/jnext)), and the printed output must match
exactly. The expected outputs from the real ROM are committed in
`tests/expected/`, so running the tests only needs jnext.

    make test            # run all cases (needs jnext; JNEXT=/path/to/jnext)
    make plumbing        # check the harness itself

See [docs/testing.md](docs/testing.md) for how to set up the tools and how to
regenerate expected output.

## Documentation

* [docs/architecture.md](docs/architecture.md): design decisions
* [docs/spec/tokens.md](docs/spec/tokens.md): the token table (byte compatible with the Dragon)
* [docs/spec/float.md](docs/spec/float.md): the floating point format and maths
* [docs/spec/memory-map.md](docs/spec/memory-map.md): how the Next's memory, screen and hardware are used
* [docs/dragondos.md](docs/dragondos.md): the DragonDOS commands, and how they differ
* [docs/next-extensions.md](docs/next-extensions.md): the Next extensions, such as `PMODE 5`
* [docs/testing.md](docs/testing.md): the test harness
* [docs/ks3-checklist.md](docs/ks3-checklist.md): checks to run on a real Next

## Licence

GPL v3, see [LICENSE](LICENSE).

D32BASIC contains no Microsoft or Dragon Data code. The original Dragon BASIC
source listing (published for reference and archival purposes only) is used
as a specification of behaviour, and to build a local test oracle that is
never distributed.
