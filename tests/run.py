#!/usr/bin/env python3
"""D32BASIC test harness.

Each tests/cases/NAME.bas is typed at the keyboard, exactly as written, on
two machines, and what BASIC prints is compared:

  * the real Dragon BASIC ROM, run by tools/oracle/dragon_oracle, gives the
    expected output, stored in tests/expected/NAME.txt;
  * our .NEX (TESTMODE build) runs headless in jnext, reads the same keys
    from AUTOTYPE.TXT and writes everything it prints to a debug port.

Commands:
  run.py                 run every case against the .NEX (default)
  run.py CASE...         run only the named cases
  run.py --expected      regenerate tests/expected/ from the oracle ROM
  run.py --plumbing      check the harness itself (types and runs a one-line program)

Environment: JNEXT (jnext binary), D32_ROM (oracle ROM image),
             ORACLE (dragon_oracle binary). Defaults live under build/.
"""
import difflib, glob, os, shutil, subprocess, sys, tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CASES = os.path.join(ROOT, 'tests', 'cases')
EXPECTED = os.path.join(ROOT, 'tests', 'expected')
NEX = os.path.join(ROOT, 'build', 'd32basic-test.nex')
JNEXT = os.environ.get('JNEXT', 'jnext')
ORACLE = os.environ.get('ORACLE', os.path.join(ROOT, 'build', 'oracle', 'dragon_oracle'))
ROM = os.environ.get('D32_ROM', os.path.join(ROOT, 'build', 'oracle', 'd32.rom'))
DBG_PORT, EXIT_PORT = '0x10EF', '0x11EF'
FRAMES = os.environ.get('D32_FRAMES', '30000')   # 10 minutes of emulated time


def normalise(text):
    return text.replace('\r\n', '\n').replace('\r', '\n')


def run_nex(case_path):
    with tempfile.TemporaryDirectory() as td:
        shutil.copy(NEX, td)
        shutil.copy(case_path, os.path.join(td, 'AUTOTYPE.TXT'))
        with open(os.path.join(td, 'exit.jds'), 'w') as f:
            f.write('on io_write %s do\n    exit VALUE\nend\n' % EXIT_PORT)
        cmd = [JNEXT, '--headless', '--no-sdcard',
               '--load', os.path.join(td, os.path.basename(NEX)),
               '--esxdos-stub-root', td, '--esxdos-stub-writable',
               '--magic-port', DBG_PORT, '--magic-port-mode', 'ascii',
               '--script', os.path.join(td, 'exit.jds'),
               '--delayed-automatic-exit-frames', FRAMES,
               '--log-file', os.path.join(td, 'jnext.log')]
        r = subprocess.run(cmd, capture_output=True, text=True, errors='replace', timeout=600)
        return r.returncode, normalise(r.stderr)


def run_oracle(case_path):
    r = subprocess.run([ORACLE, ROM, case_path], capture_output=True, text=True, errors='replace', timeout=600)
    if r.returncode:
        sys.exit('oracle failed on %s: %s' % (case_path, r.stderr))
    return normalise(r.stdout)


def cases(names):
    all_cases = sorted(glob.glob(os.path.join(CASES, '*.bas')))
    if not names:
        return all_cases
    return [c for c in all_cases if any(os.path.basename(c).startswith(n) for n in names)]


def main(argv):
    if '--expected' in argv:
        os.makedirs(EXPECTED, exist_ok=True)
        for c in cases([a for a in argv if not a.startswith('--')]):
            out = run_oracle(c)
            name = os.path.splitext(os.path.basename(c))[0]
            open(os.path.join(EXPECTED, name + '.txt'), 'w').write(out)
            print('expected', name)
        return 0
    if '--plumbing' in argv:
        with tempfile.NamedTemporaryFile('w', suffix='.bas', delete=False) as f:
            f.write('10 PRINT "PLUMBING"\nRUN\n')
        rc, out = run_nex(f.name)
        os.unlink(f.name)
        ok = rc == 0 and out == '10 PRINT "PLUMBING"\nRUN\nPLUMBING\nOK\n'
        print('plumbing', 'PASS' if ok else 'FAIL (rc=%d, output %r)' % (rc, out))
        return 0 if ok else 1
    failed = []
    for c in cases(argv):
        name = os.path.splitext(os.path.basename(c))[0]
        want = open(os.path.join(EXPECTED, name + '.txt')).read()
        rc, got = run_nex(c)
        if rc == 0 and got == want:
            print('PASS', name)
        else:
            failed.append(name)
            print('FAIL', name, '(exit %d)' % rc if rc else '')
            for l in list(difflib.unified_diff(want.split('\n'), got.split('\n'), 'dragon', 'd32basic', lineterm=''))[:30]:
                print('    ' + l)
    print('%d passed, %d failed' % (len(cases(argv)) - len(failed), len(failed)))
    return 1 if failed else 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
