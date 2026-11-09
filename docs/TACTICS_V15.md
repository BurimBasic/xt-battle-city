# v0.15 — stronger defender, distinct bonus icons, variable attack plans

The DOS/8086 CGA gameplay remains a 35-stage, 48-KiB-limited program. AUTO runs on its existing bounded decision cadence.

## Defender
- **Tread hits:** physical player-shell collision now allows a 2-pixel visible-edge margin around the enemy 16×12 hull. AUTO vertical/horizontal alignment uses the same bounds rather than requiring a hit through the center.
- **HQ defence:** the pickup route yields when an enemy enters the middle HQ corridor at y≥120, before the previous y≥144 emergency. The defender engages at y≥96 and weights central invaders above equally distant outer-wing scouts. It avoids pulling away from the base in pursuit of premature distant wing threats.
- **Dodge:** shells heading toward the player are considered up to 72px ahead (previously 48px). Every evasion must pass the actual six-pixel collision probe, otherwise the opposite perpendicular direction is checked; blocked evasions are discarded.
- **Fire range:** keep the bounded 96px static hold-and-fire range to avoid freezing indefinitely at a distant aligned target behind terrain. Nearer tread-aligned enemies are shot immediately.

## Enemy squad doctrines
The four individual roles (HQ breacher, left wing, right wing, interceptor) remain. A new per-stage squad directive provides meaningful variety: balanced attack (0), blitz with no staging delay (1), patient pincer with an extended staging timeout (2), or right-approach denial by the interceptor (3). Bonuses and disclosed P1 positions still override the interceptor's patrol. Live game startup mixes BIOS clock ticks into the RNG; subsequent stages draw another directive. Regression mode stays deterministic after its first initialization.

## Sidebar
Immediately on collection of any bonus, the upper-right panel shows the **specific 8×8 pictogram**, blinking for about 6 seconds: star / helmet / grenade / shovel / clock / life. Icons are unique black-on-white CGA sprites. No bonus number is shown. The existing `TAB-AUTO` control label is retained on the row below.

## Anti-stall / occupied corridors
The v0.14 six-pixel collision probe checked only terrain. In congested corridors it could select the same neighbor-occupied cell repeatedly, leaving both attacker and defender idle. The v0.15 probe also rejects projected overlap with every active friendly tank and the defender. After six failed moves a squad unit attempts a legal reverse step to yield the lane, rather than locking its old heading. When no route candidate is feasible, the local planner's safe fallback faces away from its blocked heading. The defender now moves to a forward sentry row (y≈112) when its HQ is safe instead of waiting forever near the base while distant enemies are stalled. Physical DOSBox-X /TEST phases 56–58 cover occupied route, yielding, and sentry behavior; phases 41–49 are isolated from the autonomous replay to avoid false positives.

## Acceptance criteria
`make test` and a real-mode `TANKS.COM /TEST` smoke must pass and compiled `TANKS.COM` must remain under 49,152 bytes. During AUTO play, observe grazing shots, base breaches, shell evasion near terrain, and variation over several full stages. CPU timing for a real 4.77-MHz 8088 and qualitative AI balance still need on-device evaluation.