# Oracle

Tools for running the real Dragon BASIC ROM headless, to produce the expected
output for tests. See [docs/testing.md](../../docs/testing.md).

* `build_rom.py`: assembles the Dragon 32-mode ROM from the DragonBasic source
  listing with lwasm. The source and the ROM stay local and are never committed.
* `dragon_oracle.c`: a minimal headless Dragon (RAM, ROM, a stub PIA and the
  50 Hz interrupt) that types a file into BASIC and prints what BASIC prints.
* `dump_tokens.py`: writes `docs/spec/tokens.md` from a ROM image.
* `mc6809.c`, `mc6809.h`: the 6809 CPU core by Sean Conner,
  <https://github.com/spc476/mc6809>, LGPL v3, included unchanged.
