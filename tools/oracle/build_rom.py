#!/usr/bin/env python3
"""Assemble the Dragon 32-mode BASIC ROM from the DragonBasic source listing.

Part of D32BASIC (GPLv3). The Microsoft/Dragon Data source itself is NOT part
of this repository: point this script at a local copy of the DragonBasic
repository (github.com/prime6809/DragonBasic or the copy in your Resources
folder). The ROM it builds is used only as a local test oracle and must not
be committed or distributed.

Usage: build_rom.py DRAGONBASIC_DIR OUT.rom [--listing OUT.lst]

The source was written for the Motorola RASM09 assembler, which linked each
module separately. lwasm assembles it here as one file, which needs:
  - Motorola expression operators mapped to lwasm ones (!+ | , !X ^ , !. &; &decimal literals after
    !. become hex so lwasm does not read && as logical AND)
  - XREF/XDEF dropped and FDBEXT turned into FDB
  - 6800 compatibility mnemonics (DEX, INX, SEC, ...) enabled
  - SETCC turned into ORCC, "0,X+" style offsets into ",X+"
  - module-local labels that clash across modules renamed per module
  - constant EQUs hoisted to the top so direct-page references assemble
    as direct addressing, as the original linker produced
  - the RAM module (ECBRAM) turned into pure storage reservations
Requires lwasm (LWTools) on PATH.
"""
import os, re, subprocess, sys, tempfile

ORDER = ['ECBTAB', 'ECBBAS', 'ECBBS2', 'ECBMTH', 'ECBEXT', 'ECBDNL', 'ECBPU',
         'ECBGRP', 'ECBMOD', 'ECBOEM']
RENAME = {
    'ECBOEM': 'WRTLDR SFTINI SCROUT POLCAT POTVAL CASBUF LPTOUT JOYIN CSRDON '
              'CBOUT CBLINK CBIN CASON CASOFF BITIN'.split(),
    'ECBEXT': ['GOINT'],
    'ECBMOD': ['SETIT', 'GOIOER', 'SAM'],
}
SYM = r'[A-Za-z0-9_$]'


def fix_line(l):
    if l.startswith('*'):
        return l
    l = re.sub(r'!\.&(\d+)', lambda m: '&$%X' % int(m.group(1)), l)
    l = l.replace('!+', '|').replace('!X', '^').replace('!.', '&')
    l = re.sub(r'([ ,#])0,(-*[XYUS]\+*)', r'\1,\2', l)
    l = re.sub(r'^(\S*\s+)SETCC(\s+)(\S+)', r'\1ORCC\2#\3', l)
    return l


def strip(lines):
    out = []
    for l in lines:
        if re.match(r'^\s+(XREF|XDEF|NAM|TTL|END|ASCT)\b', l):
            continue
        l = re.sub(r'^(\S*)(\s+)FDBEXT(\s+)', r'\1\2FDB\3', l)
        out.append(l)
    return out


def rename(lines, syms, suffix):
    out = []
    for l in lines:
        if not l.startswith('*'):
            for s in syms:
                l = re.sub(r'(?<!%s)%s(?!%s)' % (SYM, re.escape(s), SYM), s + '_' + suffix, l)
        out.append(l)
    return out


def ram_module(lines):
    out = []
    for l in lines:
        if re.match(r'^\S*\s+ORG\s+@77400', l):
            continue
        l = re.sub(r'^(\S*)(\s+)DSCT.*', r'\1', l)
        l = re.sub(r'^(\S*)(\s+)JMP(\s+)\S+', r'\1\2RMB\g<3>3', l)
        l = re.sub(r'^(\S*)(\s+)FCB(\s+)\S+', r'\1\2RMB\g<3>1', l)
        l = re.sub(r'^(\S*)(\s+)FDB(\s+)\S+', r'\1\2RMB\g<3>2', l)
        l = re.sub(r'^(\S*)(\s+)RTS\b', r'\1\2RMB 1', l)
        out.append(l)
    return out


def main():
    if len(sys.argv) < 3:
        print(__doc__); sys.exit(1)
    root, out_rom = sys.argv[1], sys.argv[2]
    listing = sys.argv[sys.argv.index('--listing') + 1] if '--listing' in sys.argv else None
    rd = lambda p: open(p, encoding='latin-1').read().split('\n')
    com = rd(os.path.join(root, 'lwtools', 'ecbcom-0.sa'))
    text = '\n'.join(com)
    text = re.sub(r'FDBEXT MACRO.*?FDBEXT ENDM\n', '', text, flags=re.S)
    lines = ['C = $01', 'I = $10', 'F = $40'] + text.split('\n')
    lines += [' ORG $0100'] + ram_module(strip(rd(os.path.join(root, 'src', 'ECBRAM.SA'))))
    lines += [' ORG $8000']
    for m in ORDER:
        body = strip(rd(os.path.join(root, 'src', m + '.SA')))
        if m in RENAME:
            body = rename(body, RENAME[m], m)
        lines += body + ['']
    lines = [fix_line(l) for l in lines]
    # hoist constant EQUs whose label is defined only once
    count = {}
    for l in lines:
        m = re.match(r'^([A-Z][A-Z0-9$_]*)\s', l)
        if m:
            count[m.group(1)] = count.get(m.group(1), 0) + 1
    hoist, body = [], []
    for l in lines:
        m = re.match(r'^([A-Z][A-Z0-9$_]*)\s+EQU\s+([$@&]?[0-9A-F]+)(\s|$)', l)
        if m and count[m.group(1)] == 1:
            hoist.append('%s EQU %s' % (m.group(1), m.group(2)))
        else:
            body.append(l)
    src = '\n'.join(hoist + body) + '\n'
    with tempfile.TemporaryDirectory() as td:
        asm = os.path.join(td, 'd32.asm'); srec = os.path.join(td, 'd32.srec')
        open(asm, 'w', encoding='latin-1').write(src)
        cmd = ['lwasm', '--6809', '--format=srec', '--pragma=6800compat,nosymbolcase,nodollarlocal',
               '-o', srec, asm]
        if listing:
            cmd.insert(1, '--list=' + listing)
        r = subprocess.run(cmd, capture_output=True, text=True)
        if r.returncode:
            sys.stderr.write(r.stdout + r.stderr); sys.exit(2)
        mem = {}
        for l in open(srec):
            l = l.strip()
            if l[:2] == 'S1':
                n = int(l[2:4], 16); a = int(l[4:8], 16)
                for i, b in enumerate(bytes.fromhex(l[8:8 + (n - 3) * 2])):
                    mem[a + i] = b
    if any(a >= 0xC000 and a < 0xFF00 for a in mem) or mem.get(0xBFFE) is None:
        sys.exit('ROM layout check failed')
    open(out_rom, 'wb').write(bytes(mem.get(a, 0) for a in range(0x8000, 0xC000)))
    print('wrote %s (POWRUP $%02X%02X)' % (out_rom, mem[0xBFFE], mem[0xBFFF]))


main()
