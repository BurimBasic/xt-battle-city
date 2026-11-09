# CGA performance engineering — 8088 / 4.77 MHz

## What is proven, and what is not
- Proven in CI: 16-bit 8086/8088 ISA audit; unit tests; map correctness; compact DOS .COM build.
- Proven on SLOW1/DOSBox-X: `TANKS.COM /TEST`; optional OPL2 presence/absence smoke tests.
- **Not proven yet:** stable target FPS on cycle-accurate original XT 4.77 MHz, CGA snow avoidance on genuine adapter, base Poisk-1 compatibility.

## Why this architecture
In CGA 320×200 mode 4, each pixel is 2 bits (four pixels per video byte); VRAM lives at B800:0000 with alternating scanlines in two 8 KiB banks. A full repaint copies ~16,000 bytes, too expensive for 8088 real-time animation.

Instead:
1. Keep a static 16×16 map of 16×12 tiles and a 256-element dirty-tile marker array.
2. Restore only tiles under moving and destroyed sprites.
3. Draw moving sprites directly to CGA VRAM with four precomputed horizontal subpixel masks and colors.
4. Animate tracks in two coordinate-linked phases, so the track stops when movement stops.
5. Animate explosions using four pre-rendered 16×12 frames and bounded lifetime; no runtime particle physics.
6. Write palette register 3D9h when the user changes palette rather than remapping individual pixels.
7. Use integer coordinates and precomputed graphics, no FPU and no instructions requiring a 286+.

The expanded arena uses 256×192 pixels. The adjacent rightmost 64px are reserved for a compact HUD. The 16×16 grid is an optimization for indexing (row*16 + column), not a promise to draw the full 320×200 area as battlefield.

## Measured acceptance plan (do not mark PASS without observations)
Use 86Box with a correctly configured PC XT (8088 4.77 MHz, CGA RGB, genuine-speed timings, MS-DOS), then repeat with an alternate BIOS and a Hercules/EGA/VGA ISA adapter only when those backends exist. Record exact 86Box version, ROM provenance, RAM size, CPU/cycle settings, screenshots and host statistics.

Measure in-game frame cadence, not just `/TEST` runtime:
- No enemies, 1 player moving continuously along walls.
- Four active enemy tanks plus player, shots and terrain destruction.
- Worst overlap: all shots, multiple explosions, bonus, shield, animated tracks.
- Pause / stage change / palette selection / result overlay transition.

For each, report minimum, median, p95 frame time, effective FPS, maximum input latency, program memory footprint and any CGA snow/tearing. Set an achievable performance target **only after baseline measurements**. If frame time exceeds budget, reduce per-frame sprite work and make expensive overlays render only on state transitions; retain game tick stability.

## References
- [CGA graphics, palettes, VRAM layout](https://www.usebox.net/jjm/notes/cga/)
- [8088 game engine optimizations and caveats](https://github.com/mills32/Little-Game-Engine-for-VGA-EGA)
- [Hardware-limited CGA graphics techniques](https://github.com/dschmenk/LORES)

Keep all project assets original; do not copy third-party sprite or level data.


## v0.19 — measured DOSBox-X CPU work reduction (SLOW1)

A fixed-rate 8086 DOSBox-X run with *identical source-level benchmark harnesses*
for v0.18 and v0.19. Two internally built diagnostic programs execute exactly
384 game ticks, call `render_frame` **every tick**, and write the same 24
16-byte trace snapshots. They are not installed as user-facing games.

| DOSBox-X fixed cycles/ms | v0.18 | v0.19 | Less elapsed time |
|---|---:|---:|---:|
| 500 | 28.088 s | 20.033 s | **28.7%** |
| 240 | 56.123 s | 40.051 s | **28.6%** |

Both traces end with 6 enemies destroyed and the same current game state.
Reproducibility: see the SLOW1 PowerShell scripts
`C:\Users\Office20Agent\Office20\tanks-bench-full-v019.ps1`
and `tanks-run-bench-240.ps1`, with matched independent builds under
`C:\XT-Battle-City\bench-018\TANKS-PERF.COM` and
`C:\XT-Battle-City\bench-019\TANKS-PERF.COM`.

An additional 2048-tick replay rendering only every 16th frame changed
from 52.120/52.062 s to 50.062/50.066 s at cycles/ms 500, approximately
**4% lower execution time**. This demonstrates that the major win is the
*renderer*, not a 28% general acceleration in AI/physics. All four replays
defeated 20/20 enemies and saved the HQ.

The reductions describe **emulated program runtime**, not hardware FPS.
DOSBox-X's fixed cycle-count number does not reproduce exact 8088 timing;
the actual IBM XT 4.77MHz target and CGA bus contention still need 86Box
or hardware benchmarks.

### Speedups: source details

- A packed y/12, y%12 LUT replaces per-corner 8088 8-bit DIV and per-sprite
  dirty-rect divisions; a separate 192-entry word table gives the interleaved
  CGA scanline offset without repeated arithmetic inside 12-line sprite loops.
- Map reads replace MUL by four shifts, while dirty marking, restoration,
  and updates to VRAM operate on flat 256-byte tile arrays.
- The AUTO/MAN indicator is painted only on state change, not every 18.2Hz tick.
- Lasers draw a thin continuous line at actual hit length rather than spawning
  multiple 16x12 masked projectile sprites. After expiration the normal
  dirty-tile restoration erases it.

There is no palette settings file or external state dependency. Palette index
remains in process RAM across every BIOS CGA re-initialization, matching
cassette and diskless boot requirements. After a full cold start it necessarily
returns to the built-in default.
