#!/usr/bin/env python3
"""Validate the compact 13x13 ASCII map format (no gameplay implied)."""
from pathlib import Path
import sys

ALLOWED = set(".#X~TPEBFI")


def validate(text: str) -> list[str]:
    rows = text.splitlines()
    errors = []
    if len(rows) != 13:
        errors.append(f"expected 13 rows, got {len(rows)}")
    for n, row in enumerate(rows, 1):
        if len(row) != 13:
            errors.append(f"row {n}: expected 13 chars, got {len(row)}")
        extra = set(row) - ALLOWED
        if extra:
            errors.append(f"row {n}: invalid characters {sorted(extra)!r}")
    for char, expected in (("P", 1), ("B", 1)):
        count = text.count(char)
        if count != expected:
            errors.append(f"expected {expected} '{char}', got {count}")
    if text.count("E") < 1:
        errors.append("expected at least one enemy spawn 'E'")
    return errors


def main(argv: list[str]) -> int:
    if len(argv) < 2:
        print("usage: python3 tools/validate_map.py LEVEL.map [MORE.map ...]", file=sys.stderr)
        return 2
    count = 0
    failed = 0
    for name in argv[1:]:
        p = Path(name)
        try:
            data = p.read_text(encoding="ascii")
        except (OSError, UnicodeError) as e:
            print(f"INVALID {p}: {e}", file=sys.stderr)
            failed += 1
            continue
        errors = validate(data)
        if errors:
            print("INVALID", p, *errors, sep="\n", file=sys.stderr)
            failed += 1
        else:
            count += 1
    print(f"MAPS_VALID={count} MAPS_INVALID={failed}")
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
