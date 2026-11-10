# XT Battle City v0.22 — local pickup priority, attacking AUTO, steel LOS

Release date: **2026-11-10**. DOS 8086/8088, CGA, 16×12 pixel map cells.

## Gameplay fixes

- **Pickups within 1.5 cells:** the player collects active bonuses within 24 horizontal and 18 vertical pixels, even when stationary. A dropped pickup under a tank is not lost merely because it did not move. Pixel coordinates, not just coarse tile indices, are used.
- **Enemies compete for power-ups:** all four enemy roles can route toward nearby useful pickups and collect within the same proximity. Enemies still cannot steal the heart/extra-life or **V** companion reserve (types 5 and 7).
- **Tactical protection:** AUTO pursues nearby bonuses without abandoning headquarters for distant bait. Strategic bonus diversion is bounded to a three-cell neighbourhood; attacking squads keep their HQ strategy when no nearby usable bonus exists.
- **Clock/freeze:** while enemy units are frozen, AUTO player actively searches, aims, moves and attacks instead of standing still.
- **Steel between shooter and target:** AUTO checks every intervening map cell along the whole fire lane and does not fire into steel or the HQ. Brick is destructible and therefore is not considered an indestructible blocker. This uses an efficient directional cell-index scan rather than repeated per-pixel collision probes.
- Maintains 18.2 Hz gameplay cadence, smooth sprite movement, and the existing complete v0.21 systems (laser clean-up, heart as extra life, ally shield expiry).

## Verified release binary

- Filename: `TANKS.COM` (also tracked at `dist/TANKS.COM`).
- Size: **56,666 bytes** (under 57,344-byte 8086 DOS .COM CI ceiling).
- SHA-256: `F1705EFC784818691A3E69E4E778185C4BF00A2FB7C5F5AF64F7D0E3B1CAD917`.
- Source commit containing binary: `3efaaf9ab28d3cb19a182dc3d024626bf42b8c9d` (branch `fix/v022-bonus-freeze-steel`).
- SLOW1 DOSBox-X `/TEST`: **PASS**, including new proximity phases 94/95.
- SLOW1 DOSBox-X `/TRACE`: **PASS**, 2048 ticks, 20/20 enemies eliminated, player base survives, `STAGE CLEAR`.
- GitHub CI: **125 Python tests PASS**, 35 authored maps validated, strict 8086 ISA and COM-size checks PASS.
- Timing validation: repeat matched real-mode 384-frame CGA benchmarks with v0.19 at 240 and 500 cycles/ms; emulator measurements depend on SLOW1 host load. Do not claim physical XT/Poisk hardware timing or an FPS guarantee without an on-hardware measurement.

## Installation and rollback

Launch with DOSBox-X in CGA mode from `C:\XT-Battle-City\run\TANKS.COM`. Keep the previous v0.21 executable as a backup before replacing it. The game uses no disk writes for its visual settings; physical 4.77 MHz 8088, tape, native EGA/Hercules/Poisk modes are not certified.

Development and release rules: `AGENTS.md`.
