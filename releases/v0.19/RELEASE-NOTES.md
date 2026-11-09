# XT Battle City v0.19 — Faster XT CGA, Clean Laser, In-Memory Palette

## Installation

Deployed directly on SLOW1: `C:\XT-Battle-City\run\TANKS.COM`. Launch via
`C:\XT-Battle-City\RUN-CGA.cmd`; close any previous DOSBox-X process first.
No ZIP is required for the player. The previous v0.18 executable is preserved
in the run directory as an automatically timestamped backup.

## Improvements

- **Measured faster full-frame CGA rendering:** 384 exact full frames on
  SLOW1 DOSBox-X (8086 core and fixed 240 cycles/ms) execute in **40.051s**
  rather than v0.18's **56.123s** — **28.6% less elapsed time**. Fixed
  500 cycles/ms: 20.033s instead of 28.088s — 28.7% less. Both tests have
  the same 24 trace samples and 6 enemy kills at tick 384. In contrast, the
  low-paint 2048-tick trace improves by only about 4%: this is a
  **graphics-focused improvement**, not an arbitrary game-speed multiplier.
- Replaced 8088 integer division in per-pixel collision tests with a 256-byte
  packed y/12 & y%12 lookup, and repeated CGA interlace shifts in every
  sprite line with a 192-word row-offset table.
- Static tile operations now scan compact dirty/upload flags, instead of
  calling grid coordinate helpers for 256 unchanged cells every frame.
  Grid indexing uses shifts rather than integer multiplication.
- The unchanging AUTO/MAN glyph strip is no longer redundantly repainted
  every single game tick; toggle and screen refresh still repaint it.
- **Laser artifact fix:** continuous single-pixel ray from muzzle to the real
  projectile stopping point. The line alternates color indexes 1 and 3 each
  BIOS tick, and every affected tile is marked for restoration when it fades.
  No 16×12 bullet-sprite splats remain along the laser path.
- The bottom-right footer has an entire eight-pixel empty row separating
  **TANKS** and **©1982**. The one-pixel font descender spacing remains
  between ©1982/BASIC/V0.19; version changed from V0.18 to **V0.19**.
- **Palette survives stage changes, restart and other BIOS mode resets** while
  the game is running, using its existing RAM byte plus reapplication of CGA
  register 3D9h. **No DOS settings file or other persistent storage**: this
  is compatible with cassette/diskless loading; a full cold start returns to
  the built-in palette.
- All 35 original stages, eleven pickups and tactical AI behavior preserved.

## Acceptance

- GitHub Actions: **96 Python tests**, all 35 map checks, CGA source/atlas,
  legal 8086/8088 instruction audit, and 56KiB maximum shipping program size.
- SLOW1 DOSBox-X: shipping `TANKS.COM /TEST` **PASS through phase 78**
  (including phase 78: physical laser trail restoration on CGA).
- 2048-tick test replay: first stage still ends in **STAGE CLEAR** with
  20/20 enemies destroyed and HQ intact.
- Video modes on DOSBox-X: **EGA PASS** and **VGA PASS** when they emulate
  *CGA mode 4 only*; **Hercules FAIL**. Native EGA 16 colors, VGA 256 colors,
  Hercules monochrome, and Poisk-1 backend are **not ready**.
- Shipping image: **56,648 bytes** (strictly below 57,344 byte budget);
  SHA-256 `5BE7E123D0BBDAF5B34A69DA7B90BDA5FE4CE14CAC1D14B86D32114287D55FB6`.

Emulator speed measurements are not certified FPS on physical 4.77-MHz 8088,
nor proof of compatibility with a stock cassette-booted Poisk-1.
