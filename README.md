# D32BASIC

Dragon 32 BASIC for the ZX Spectrum Next.

D32BASIC is a native Z80N reimplementation of the Dragon 32's Microsoft
Extended Color BASIC, delivered as a `.NEX` program, in the same spirit as the
Next's BBC BASIC: type Dragon BASIC programs, run them, and save and load them
on the SD card. It aims to run Dragon BASIC *programs* (not Dragon machine-code
software), with the authentic 32x16 green screen, PMODE graphics, `PLAY` and
`SOUND`. Later versions will add Next hardware features through new PMODEs.

**Status:** step 1 of 4 (foundations). The `.NEX` is a skeleton; the language
is not implemented yet. See [docs/ROADMAP.md](docs/ROADMAP.md).

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
* [docs/testing.md](docs/testing.md): the test harness

## Licence

GPL v3, see [LICENSE](LICENSE).

D32BASIC contains no Microsoft or Dragon Data code. The original Dragon BASIC
source listing (published for reference and archival purposes only) is used
as a specification of behaviour, and to build a local test oracle that is
never distributed.
