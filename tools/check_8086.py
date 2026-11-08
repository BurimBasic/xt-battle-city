#!/usr/bin/env python3
"""Reject 386+ prefixes and near Jcc in the 16-bit .text section.

This does NOT replace a full ISA audit or running on a real 8088, but catches
GAS's silent promotion of distant conditional branches to 386-only 0F 8x.
"""
import pathlib
import re
import subprocess
import sys


def check(path: pathlib.Path):
    proc = subprocess.run(
        ['objdump', '-d', '-m', 'i8086', '-M', 'intel', str(path)],
        check=True, capture_output=True, text=True,
    )
    bad = []
    for line in proc.stdout.splitlines():
        m = re.match(r'^\s*([0-9a-f]+):\s+((?:[0-9a-f]{2}\s+)+)', line)
        if not m:
            continue
        instr = bytes.fromhex(m.group(2))
        if (instr and instr[0] in (0x66, 0x67)) or (
            len(instr) > 1 and instr[0] == 0x0f and 0x80 <= instr[1] <= 0x8f
        ):
            bad.append(line.strip())
    if bad:
        raise SystemExit('8086-incompatible instruction(s):\n' + '\n'.join(bad))
    print(f'8086 prefix / long Jcc audit OK: {path.name}')


if __name__ == '__main__':
    check(pathlib.Path(sys.argv[1]))
