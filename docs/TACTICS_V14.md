# v0.14 — asymmetric team tactics (CGA/8088)

## Defender: one intelligent player-controlled or AUTO tank

**Mission:** keep the HQ intact, then accumulate upgrades and clear each wave.
The defender does not have omniscient pathfinding every frame. Every fourth
18.2Hz tick it evaluates a *local threat*, a *bonus objective*, and a *combat
lane*, in this priority:

1. Escape an approaching enemy shell using a legal six-pixel side step.
2. If an enemy tank has penetrated the central HQ defensive zone, defend base.
3. If a pickup appears and no immediate base-breach threat exists, follow a
   cached whole-map 256-cell reverse BFS flow field to the pickup.
4. Otherwise choose a critical enemy and shoot immediately if it shares a
   horizontal or vertical lane, even if it is not in the final defensive rows.
5. If not aligned, move into an intercept lane; hold a good line rather than
   pursuing each enemy into a wall. Movement is checked against actual sprite
   collision rectangles before committing.

The six pickups already have active gameplay effects. The AUTO controller
collects one by physically entering its tile; it does not get pickups by
teleportation. Bonus BFS runs on spawn and after a terrain topology change,
not on every video frame. The shield and base emergency take precedence over
pickup greed in a base crisis.

## Attackers: an independent four-tank squad

**Mission:** destroy the HQ, not score P1 kills. Roles are explicitly distinct:

- HQ breacher: attacks center HQ firing lane.
- Left and right wings: first reach opposite staging points, then converge.
- Interceptor/denier: blocks bonus collection when one is available, otherwise
  targets the last *disclosed* P1 position (firing reveals it), or screens the
  central approach in the absence of intelligence.

The squad uses three cached 16×16 whole-map flow fields, directional hull
probes, a staging clock and an assault phase. The HQ breacher holds for a
short barrage only when its teammate is not blocking the firing lane.

## Friendly fire policy

Enemy shells are *not* harmless to other enemies: an accidental crossing shot
reduces armor, and a lethal hit removes that unit, its projectile and one of
the wave's 20 units. The defender receives no score or pickup for such losses.
Tactical safe-fire logic should avoid predictable ally collisions, but cannot
magically prevent all collisions after tanks dodge or cross a shot's path.

## Implementation boundaries

Maps are encoded in 4-bit material IDs (128 B each), decompressed only when
loading a stage to the original 256-byte in-memory tile array. This saves
roughly 4.5 KiB in the DOS binary, covering the new tactical logic without
raising the strict 48 KiB release budget.

Each /TEST check executes actual 16-bit routines, including friendly armor
loss, lethal friendly hits, pickup BFS and alignment-triggered shooting.
Passing these tests does not prove chess-like foresight or real-world opponent
skill. Qualitative game acceptance still needs the SLOW1 RDP playtest.
