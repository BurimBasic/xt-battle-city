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
