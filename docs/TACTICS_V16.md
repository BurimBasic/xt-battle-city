# Defender tactical update v0.16

## Root cause proven with 2048-tick DOS replay

In the first long replay, the defender left its HQ lane and traveled as far as x184, chasing an outer flank at y159. A central enemy penetrated to approximately (99,154) shortly thereafter; the stage was lost around tick 272 with only four enemies destroyed. Short `/TEST` phases did not catch the global mistake.

## Fix

1. The defender's target score is now depth plus central-lane priority (+64 when x80..160), modest adjacent-flank weight (+12), remote flank penalty (-24) and only +8 target persistence. A central breacher wins over an outer-wing decoy even if the decoy is temporarily farther down the map.
2. An active opponent near the HQ cannot be displaced by a distant bonus objective. The cached route is still reused; no new whole-map BFS happens per tick.
3. The player's x position is held around HQ in a bounded intercept range x80..144. The previous y>=152 exception that allowed full-map horizontal pursuit is removed. At the horizontal boundary the AI moves vertically within the near-HQ fighting line rather than oscillating.
4. Fire-control runs once per 18.2-Hz game tick, after movement but before projectiles advance, independent of the four-tick strategic steering period and independent of the bonus route. It selects a valid aligned opponent and can launch a bullet while continuing to move.
5. The line-of-fire check reuses real projectile collision probing over at most 72 pixels, ending short of the enemy to disregard objects behind the target. Steel and HQ veto the shot; a chippable brick is allowed. This avoids endlessly firing up the solid steel tile at (7,8) in stage 1.
6. The sentry position is offset to x96 and around y120 on the first map; bonuses and emergency pursuit may temporarily supersede it. Unlike a hardcoded win, all hits remain real projectiles and all enemy/terrain collisions remain active.
7. For a collected bonus, the 8x8 pictogram shifts from x284 to x264 in the right CGA panel without changing the icon identity or flashing period.

## Test results

- GitHub Python: 73 tests; 8086 instruction audit; map/asset compatibility; DOS shipping image 48,380 bytes, under 49,152.
- DOSBox-X on SLOW1: embedded phases 1–65, PASS. New phases 59–65 cover simultaneous pickup movement and fire, steel line rejection, clear lane firing, real CGA HUD placement, base-threat pickup override, central-target selection and edge-oscillation avoidance.
- Trace-only 2048 tick headless replay: `V16TRACE.BIN` (2048 B), 128 snapshots; stage 1 clear, 20/20 defeated, HQ intact at approximately tick 1024.

The trace executable is diagnostic-only and not the shipping file. Gameplay was not artificially modified in the trace. Tests do not establish universal stage wins or stable FPS on a real IBM PC/XT.
