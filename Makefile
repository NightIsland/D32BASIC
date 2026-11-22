# D32BASIC build and test
#
#   make               build build/d32basic.nex (release)
#   make test-nex      build build/d32basic-test.nex (TESTMODE)
#   make test          run every test case against the .NEX in jnext
#   make plumbing      check the test harness itself
#   make oracle        build the 6809 oracle runner
#   make rom DRAGONBASIC=/path/to/DragonBasic   build the oracle ROM (local only)
#   make expected      regenerate tests/expected/ from the oracle ROM
#
# Tools: sjasmplus, jnext, lwasm (only for `make rom`) and a C compiler.
# Override paths with SJASMPLUS=..., JNEXT=..., LWASM=...

SJASMPLUS ?= sjasmplus
JNEXT     ?= jnext
CC        ?= cc
SRC       := $(wildcard src/*.asm src/*.inc)

all: build/d32basic.nex

build/d32basic.nex: $(SRC) | build
	$(SJASMPLUS) -isrc --msg=war --lst=build/d32basic.lst src/main.asm

build/d32basic-test.nex: $(SRC) | build
	$(SJASMPLUS) -isrc --msg=war -DTESTMODE=1 --lst=build/d32basic-test.lst src/main.asm

test-nex: build/d32basic-test.nex

build build/oracle:
	mkdir -p $@

oracle: build/oracle/dragon_oracle

build/oracle/dragon_oracle: tools/oracle/dragon_oracle.c tools/oracle/mc6809.c tools/oracle/mc6809.h | build/oracle
	$(CC) -O2 -o $@ tools/oracle/dragon_oracle.c tools/oracle/mc6809.c

rom: | build/oracle
	@test -n "$(DRAGONBASIC)" || (echo "set DRAGONBASIC=/path/to/DragonBasic (the source repository)"; exit 1)
	python3 tools/oracle/build_rom.py "$(DRAGONBASIC)" build/oracle/d32.rom --listing build/oracle/d32.lst

expected: oracle
	python3 tests/run.py --expected

test: build/d32basic-test.nex
	JNEXT=$(JNEXT) python3 tests/run.py

plumbing: build/d32basic-test.nex
	JNEXT=$(JNEXT) python3 tests/run.py --plumbing

clean:
	rm -f build/d32basic*.nex build/d32basic*.lst

.PHONY: all test-nex oracle rom expected test plumbing clean
