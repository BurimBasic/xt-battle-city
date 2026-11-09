# CGA visual engine — v0.8 (8088-optimized)

**Goal:** detailed, original 16×12 pixel tank and environment sprites on a 4.77 MHz
8088 in CGA 320×200 mode, not pixel-perfect source art from another game.

## What is actually playable

The interactive tile world is **16×16 cells (256×192 physical pixels)**,
starting at the upper-left corner. The rightmost 64 pixels hold a compact
HUD in the top section; the remaining bottom/right black strip is reserved
for further expansion. This is a significant expansion from the earlier
13×13 (208×156) arena, **but not yet a full 320-pixel-wide playable world.**

The 8-bit per-actor X coordinates currently limit the unsegmented arena to
256 pixels. Full 320-pixel play will require 16-bit X positions (or a
carefully tested fixed-point/segmented representation) and retesting all
collision and CGA bank address calculations. Do not advertise full-screen
320×200 game physics until this work is complete.

## Sprites & effects

- Tank bodies show tracks, rivets, turret, barrel and armour plates at 16×12.
- Every moving tank receives a **two-phase directional tread overlay**; the
  phase is derived from position, so it stops changing on a stopped tank.
- Distinct base, metal, brick, water, ice and foliage textures use all CGA
  colour indices with stippling. Walls retain four 8×6 destructible pieces.
- Impact FX are four authored masked-sprite frames with spark/debris pixels.
  Only **one impact animation** can be active at a time. This hard cap keeps
  VRAM traffic and RAM constant even in busy firefights.
- Enemy shells hit the other three enemy tanks as well as the player. The
  shooter cannot harm itself. Friendly-fire kills reduce the stage enemy
  count but give the player no undeserved score.

## Hardware palette

Press **C** (make scancode 2Eh) to cycle four CGA mode 04h RGBI combinations.
The game writes port 03D9h directly, without re-entering the BIOS video mode
or clearing the screen. The colours are hardware presets, **not arbitrary
independent colour selection**:

| State | Register | RGBI output (pixel indices 1,2,3) |
|---|---|---|
| 0 | 20h | cyan / magenta / white (normal) |
| 1 | 00h | green / red / brown (normal) |
| 2 | 30h | light cyan / light magenta / white (intense) |
| 3 | 10h | light green / light red / yellow (intense) |

CGA mode 05h can expose a third palette on some hardware, but is not used
because it is not universally reliable on later clones. Unlike VGA, CGA
cannot freely change each of the four colour registers.

## 8088 performance guardrails

1. No new per-frame 16 KB full-screen buffer; use existing cell dirty marking.
2. No sprites larger than 16×12, and the explosion pool is strictly one.
3. The new 35×256-stage map data stays in the executable; only **one** 256-byte
   level is live and decoded into gameplay state.
4. No 80186+ / 286+ instructions; enforce with the repo ISA checker.
5. Real 8088/4.77MHz timing and physical CGA snow/tearing remain **unverified**.
   DOSBox-X validation confirms logic, not a stable target FPS.

References: [CGA technical notes](https://seasip.info/VintagePC/cga.html),
[CGA direct mode / palette programming](https://www.usebox.net/jjm/notes/cga/).
