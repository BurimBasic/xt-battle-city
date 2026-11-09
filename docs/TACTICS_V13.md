# XT Battle City v0.13 — coordinated tactics and input fix

## Explicit acceptance blockers addressed

1. **No sticky LEFT after AUTO takeover.** `manual_keys` is updated solely by actual XT keyboard make/break events; `held_keys` is now the effective game command and may be AI-owned. The very first human key replaces AI commands instead of OR'ing an extra direction. Tab toggles AUTO; when in manual mode the compact HUD reads **TAB-AUTO**.
2. **Mapwide navigation replaces six-pixel greed.** Each 16×16 stage builds three *reverse breadth-first distance fields* (HQ at 7,14; west rally at 3,11; east rally at 12,11). Path queries are O(4) candidate headings with existing physical-hull probes; no BFS happens in the per-frame hot path. Destroying a full brick tile schedules a route refresh. The central raider advances to the HQ. Flanks stage at separate lanes, then attack on a shared operation phase or after the bounded rally timeout; the fourth tank intercepts the defender. Global routes are built **from actual traversable map cells**, not a direct x/y guess.
3. **No accidental allied casualties.** Before firing, enemies reject any shot whose row/column intersects an allied hull **anywhere forward**, not just within 56 pixels. A teammate that later crosses an already flying enemy round absorbs the round without losing health. The game cannot count allied hits as player kills.
4. **Protect the HQ rather than meander.** The AUTO defender holds a defensive patrol line when distant enemies are not threatening the HQ, persists with its selected target instead of selecting a different one every decision, and stops to shoot when aligned. The emergency shell-dodge override remains.
5. **No random wall-spinning.** Blocked tanks request a new tactical heading on a bounded cadence; no automatic 90-degree reversal on every failed pixel movement.

## 8088 performance constraints

- Fields: 3×256 bytes, plus one reused 256-byte BFS queue (1024 bytes total). Built at level load; only rebuilt after terrain is actually destroyed (deferred to a strategy tick).
- Player decisions remain every four BIOS ticks; four enemy route queries are at most one per 32 ticks plus an occasional blocked-path response.
- The full release remains under the original 49,152-byte (48 KiB) 8086 DOS `.COM` cap; no FPU or 286+ opcodes.
- Real 8088/4.77MHz frametime has **not** been profiled in 86Box. DOSBox-X smoke tests verify functional execution, not cycle timing or strategic quality over a full 35-stage campaign.

## What is not yet implemented

This is a real global BFS + simple squad operation, **not** a chess-style minimax search, optimal multi-agent A*, predictive suppressive-fire scheduler, or learned behavior. The stage geometry can create narrow lanes where tanks temporarily wait for each other. The raid/intercept/flank roles are deliberately deterministic, cheap and observable. Manual RDP play and long-duration auto-game observation remain required acceptance gates.

## Verification

- `make test` — source/data compatibility, 8088 audit, 35 connected maps, six new strategic tests.
- `TANKS.COM /TEST` — real-mode tests through phases 44–51, including human takeover from left-moving AUTO, global flow fields, HQ aim, squad assault timeout, ally fire safety.
- Run `tools/dosbox_smoke.ps1` on SLOW1 using both audio/no-audio emulated configurations.
- Visually verify `TAB-AUTO` in manual mode and that a human pressing RIGHT no longer inherits AUTO LEFT after release.

### Repeatable 384-tick tactical replay

The shipping `TANKS.COM` is under the stricter original 48 KiB binary budget and **does not contain** the DOS replay recorder.
Build a separate diagnostic-only `TANKS-TRACE.COM` using `make build/TANKS-TRACE.COM`. Run `TANKS-TRACE.COM /TRACE` in DOSBox-X; the program records 24 consecutive 16-byte snapshots in `V13TRACE.BIN` (384 bytes) at 16-tick intervals, then exits. Parse with `python tools/analyze_trace.py V13TRACE.BIN`. The trace build consumes additional code and conventional RAM; do not benchmark its speed as if it were the shipping release.

The trace confirms **which** units moved and **when** the squad changed phase, not whether they demonstrated optimal strategy. Longer repeatable simulations and human observation are required before accepting more ambitious coordination claims.
