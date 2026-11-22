/*
 * dragon_oracle - run BASIC programs on a real Dragon BASIC ROM, headless.
 *
 * Part of D32BASIC (GPLv3). This is a test oracle only: it needs a Dragon
 * BASIC ROM image that you supply locally; no ROM is distributed with it.
 *
 * Usage: dragon_oracle ROM INPUT.txt [--screen FILE] [--max-cycles N]
 *
 * INPUT.txt is typed at the keyboard exactly as written (LF becomes ENTER).
 * Everything BASIC prints to the screen is written to stdout (CR -> LF).
 * With --screen, the final 32x16 text screen is written to FILE.
 * The run ends when all input has been consumed and BASIC has sat idle at
 * the keyboard for a while, or after --max-cycles CPU cycles.
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "mc6809.h"

static uint8_t mem[65536];
static uint8_t *input; static size_t inlen, inpos;
static uint16_t polcat_addr, scrout_addr;
static int irq_flag;
static unsigned long idle_polls;
static uint16_t line_caller;  /* return address of the line-input POLCAT call */

static mc6809byte__t rd(mc6809__t *cpu, mc6809addr__t a, bool ifetch)
{
  (void)cpu; (void)ifetch;
  if (a >= 0xFF00) {
    if (a >= 0xFFF0) return mem[a - 0x4000];          /* vectors from ROM $BFF0 */
    switch (a & 0xFF23) {
      case 0xFF00: return 0x7F;                        /* no key on any row, comparator low */
      case 0xFF02: irq_flag = 0; return mem[a];        /* reading clears field-sync flag */
      case 0xFF03: return (mem[a] & 0x7F) | (irq_flag ? 0x80 : 0);
      default: return mem[a];
    }
  }
  if (a >= 0xC000) return 0xFF;                       /* no cartridge */
  return mem[a];
}

static void wr(mc6809__t *cpu, mc6809addr__t a, mc6809byte__t v)
{
  (void)cpu;
  if (a >= 0x8000 && a < 0xFF00) return;               /* ROM / cartridge */
  mem[a] = v;
}

static void fault(mc6809__t *cpu, mc6809fault__t f)
{
  fprintf(stderr, "6809 fault %d at %04X\n", f, cpu->instpc);
  exit(2);
}

static void rts(mc6809__t *cpu)
{
  cpu->pc.b[MSB] = mem[cpu->S.w]; cpu->pc.b[LSB] = mem[(uint16_t)(cpu->S.w + 1)];
  cpu->S.w += 2;
}

static char decode(uint8_t v)
{
  if (v >= 0x80) return '#';                          /* semigraphics block */
  uint8_t c = v & 0x3F;
  char ch = c < 0x20 ? c + 0x40 : c;
  if (!(v & 0x40) && ch >= 'A' && ch <= 'Z') ch += 32; /* inverse video shown as lower case */
  return ch;
}

int main(int argc, char **argv)
{
  const char *screen = NULL; unsigned long maxc = 2000000000UL;
  if (argc < 3) { fprintf(stderr, "usage: %s ROM INPUT [--screen F] [--max-cycles N]\n", argv[0]); return 1; }
  for (int i = 3; i < argc; i++) {
    if (!strcmp(argv[i], "--screen") && i + 1 < argc) screen = argv[++i];
    else if (!strcmp(argv[i], "--max-cycles") && i + 1 < argc) maxc = strtoul(argv[++i], 0, 10);
  }
  FILE *f = fopen(argv[1], "rb");
  if (!f || fread(mem + 0x8000, 1, 0x4000, f) != 0x4000) { fprintf(stderr, "cannot read 16K ROM %s\n", argv[1]); return 1; }
  fclose(f);
  f = fopen(argv[2], "rb"); if (!f) { perror(argv[2]); return 1; }
  fseek(f, 0, SEEK_END); inlen = ftell(f); rewind(f);
  input = malloc(inlen + 1); inlen = fread(input, 1, inlen, f); fclose(f);

  polcat_addr = mem[0xA000] << 8 | mem[0xA001];         /* IOVECT table */
  scrout_addr = (mem[0x800D] << 8 | mem[0x800E]);       /* JMP ZSCROU at $800C */

  mc6809__t cpu; memset(&cpu, 0, sizeof cpu);
  cpu.read = rd; cpu.write = wr; cpu.fault = fault;
  mc6809_reset(&cpu);

  unsigned long next_irq = 17897, idle_after_input = 0;
  int boot_done = 0;
  while (cpu.cycles < maxc) {
    if (cpu.cycles >= next_irq) { next_irq += 17897; irq_flag = 1; if (mem[0xFF03] & 1) cpu.irq = true; }
    /* An IRQ taken here returns to this same PC via RTI, so only count the call
       when the instruction will really execute, or a character prints twice. */
    if (cpu.pc.w == scrout_addr && !(cpu.irq && !cpu.cc.i)) {
      uint8_t ch = cpu.A;
      if (boot_done) { if (ch == 0x0D) putchar('\n'); else if (ch >= 0x20 && ch < 0x7F) putchar(ch); }
    }
    if (cpu.pc.w == polcat_addr) {
      if (!boot_done) { boot_done = 1; }
      uint16_t ret = mem[cpu.S.w] << 8 | mem[(uint16_t)(cpu.S.w + 1)];
      if (!line_caller && boot_done && idle_polls >= 4) line_caller = ret;
      if (inpos < inlen && idle_polls >= 4 && ret == line_caller) {
        uint8_t ch = input[inpos++];
        if (ch == '\r') { rts(&cpu); cpu.A = 0; cpu.cc.z = true; continue; }  /* ignore CR of CRLF */
        if (ch == '\n') ch = 0x0D;
        cpu.A = ch; cpu.cc.z = false; idle_polls = 0;
        if (getenv("ORACLE_TRACE")) fprintf(stderr, "feed %02X ret %02X%02X\n", ch, mem[cpu.S.w], mem[(uint16_t)(cpu.S.w+1)]);
      } else {
        cpu.A = 0; cpu.cc.z = true; idle_polls++;
        if (inpos >= inlen && ++idle_after_input > 300) break;
      }
      rts(&cpu);
      continue;
    }
    int rc = mc6809_step(&cpu);
    if (rc) { fprintf(stderr, "6809 stopped rc=%d at %04X\n", rc, cpu.instpc); return 2; }
  }
  fflush(stdout);
  if (screen) {
    FILE *s = fopen(screen, "w");
    for (int r = 0; r < 16; r++) { for (int c = 0; c < 32; c++) fputc(decode(mem[0x400 + r * 32 + c]), s); fputc('\n', s); }
    fclose(s);
  }
  if (cpu.cycles >= maxc) { fprintf(stderr, "max cycles reached pc=%04X inpos=%zu/%zu polls=%lu\n", cpu.pc.w, inpos, inlen, idle_polls); return 3; }
  return 0;
}
