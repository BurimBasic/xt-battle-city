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
- **SLOW1 timing gate PASS** (DOSBox-X 2026.10.01, emulated 8086/CGA, each run 384 complete rendered frames, alternating v0.22/v0.19/v0.19/v0.22): fixed **240 cycles/ms**: v0.22 **40.058 / 52.683 s** (mean **46.371 s**), v0.19 **48.757 / 53.271 s** (mean **51.014 s**), v0.22 **9.1% faster** in this pair; fixed **500 cycles/ms**: v0.22 **20.421 / 27.826 s** (mean **24.124 s**), v0.19 **22.787 / 27.851 s** (mean **25.319 s**), v0.22 **4.7% faster**. Host load changed markedly within each series; the AI/pickup changes mean the deterministic frame count is matched but gameplay workload/kills need not be identical. These are emulator elapsed times, not a measured physical 4.77MHz 8088 FPS guarantee.

## Installation and rollback

**Deployed atomically on SLOW1** at `C:\XT-Battle-City\run\TANKS.COM`, with the exact tested SHA-256 and size verified after replacement. **Installed copy re-tested successfully** with DOSBox-X `TANKS.COM /TEST` (PASS). Rollback copy: `C:\XT-Battle-City\run\TANKS-v021-backup-20261110-203600.COM`, SHA-256 `BCEE4E795F069A5A9A59E56DF0FE2B7DDF9E508288F3F6D4C08D14F3F515D75C`. Launch/restart using `C:\XT-Battle-City\RUN-CGA.cmd`. The game uses no disk writes for its visual settings; physical 4.77 MHz 8088, tape, native EGA/Hercules/Poisk modes are not certified.

Development and release rules: `AGENTS.md`.
