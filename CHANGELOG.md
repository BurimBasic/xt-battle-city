## v0.28 — Native-resolution aircraft, animated twin propellers, reliable muzzle recoil, fast AUTO dodge (2026-11-13)

- Replaced the enlarged 16×12 block silhouette with **one original 32×24-pixel top-view WWII twin-engine master**: tapered wings, distinct nacelles, canopy and tail. **All four orientations are algorithmically rotated/reflected from the same source artwork**; the packed four-frame CGA memory budget remains unchanged.
- Propeller hubs and 1px highlight tips now sit in the correct places for **right, left, up and down** flight and alternate every simulated tick. Previous dots had the wrong coordinates and appeared static.
- Fixed the gun animation frame ordering: initial recoil is stored as phase 4 so update-before-paint renders phase 3's **outward muzzle flash**, with a **2px kickback** followed by **1px/tick return**, for both human tanks.
- Solo AUTO sees all **seven** ordinary/spread enemy projectile slots. It scans on the spare even tick between 4-tick decisions, but only performs early emergency maneuvers for shells within **24px**; distant threats are handled by the normal 72px strategic scan. This protects last-enemy pursuit from unnecessary dodge-driven detours.
- **170 Python tests PASS**, all 35 maps and 8086 ISA audit PASS. On SLOW1 real-mode DOSBox-X CGA: internal **/TEST PASS**, deterministic **2048-tick /TRACE PASS**, 20/20 kills and stage clear. Native COM **56,894 bytes**, SHA-256 `5C061F5D0D4F148C769668A3AEC32F5CF5BC6432B1E3AC275AFE4CB28B1464A3`.
- Accurate art source preview (not gameplay screenshot), 384-frame ABBA XT speed comparison, staged QA binaries and exact release manifest are described in `releases/v0.28/RELEASE-NOTES.md`.

## v0.27 — Twin-engine 1942-style airplane, gun recoil, BURIM and AUTO pickups (2026-11-13)

- Original **32×24 CGA top-down twin-engine airplane** (twice the 16×12 tank footprint), with independently animated 1px propeller tips; authentic 1940s arcade silhouette without copied 1942 ROM data. Four flight directions and random approach direction/start/lane retained.
- Flyby quotas: **stages 1–5: 1; 6–14: 2; 15–35: 3**. Bomb impacts remain alternating left/right in the checkerboard pattern, behind the plane; bricks and tanks take ordinary-shot damage, headquarters is immune.
- **One-shot gun recoil:** 2px kickback at firing and a short muzzle flash, then barrel returns by 1px per tick. Includes co-op P2. All effects fit the dirty-tile compositing model.
- Replace sidebar author label **BASIC → BURIM** and show **v0.27**.
- Solo AUTO preferentially pursues **enemy-wipe grenade, laser and extra life** when map BFS confirms a route and no nearby enemy poses an urgent HQ threat; ordinary defensive combat still has priority in emergencies.
- Per-stage DOS embedded phases **130–132** check aircraft counts, repeat launch and recoil. **165 tests, 35 maps and 8086 ISA PASS**, SLOW1 DOS `/TEST PASS`, 2048-tick `/TRACE PASS (20/20, STAGE CLEAR, HQ intact)`. The v0.27 renderer uses word-sized 8086 CGA writes and one-pass tile dirties to avoid slowdown on PC/XT.
- Full download, controls, feature catalogue, real CGA screenshot provenance, source-derived plane art preview, checksums, benchmark and SLOW1 rollback are documented in `README.md` and `releases/v0.27/RELEASE-NOTES.md`.

## v0.26 — Four directional 1980s arcade planes, randomized flyby and contact pickup (2026-11-13)

- Replaced vague oval bomber with **four original direction-specific, masked CGA pixel sprites** (up, down, left, right). One flyby per stage; **start delay, entering edge, direction and flight lane randomized** without perturbing the tank AI RNG. Aircraft still moves 2px per tick.
- Fixed bomb placement: **strictly behind the bomber**, alternating one cell to the **left/right of its exact axis**, staggered along direction of travel; no more offset 2–1–2–1 waves. Real projectile-equivalent impact damages bricks, actors and armoured treads, but never headquarters.
- **Pickup requires actual overlap of the visible tank body** with the bonus for P1, P2, ally and enemies, rather than allowing acquisition 1.5 tiles early. After collection the **collector tank briefly changes color**; removed the old flashing outline left on an empty tile.
- Preserved 35 maps, all 14 bonuses, two humans with three lives and respawn, automatic last-enemy hunt, defensive AI, enemy-use of weapons and tank damage, and CGA pixel-motion performance.
- GitHub **158 tests PASS**, 35 maps + 8086 ISA PASS, **56,184-byte** .COM (<56KiB), SLOW1 real-mode DOS `/TEST PASS`, 2048-tick `/TRACE PASS`: **20/20 enemies, STAGE CLEAR, base saved**. Per-build checksum `CEA54A294CDC10308E930B1B54BD838F8CF8371A07FD560D2BEDF6D899536D79`. Exact speed measurements and rollback are in `releases/v0.26/RELEASE-NOTES.md`.
- README homepage now gives v0.26 downloads, correct contact mechanic and aircraft description, full controls/bonuses, a **real user-supplied screenshot of v0.25 clearly marked as previous version** and honest adapter status.

## v0.25 — Bomber aircraft, visible pickups and 3-life co-op (2026-11-12)

- Adds a **single aircraft flyby per stage**: horizontal (odd levels) / vertical (even), moving at medium-tank speed, leaving a checkerboard pattern of explosion impacts. Bombs are not drawn in flight. Each explosion counts as one ordinary projectile hit against brick/tanks/players, but **headquarters is immune**.
- **Three starting lives per human player**, separate life counters; either player respawns at the base with a temporary shield while any personal lives remain. If spawn is obstructed, retry on subsequent ticks.
- Coop HUD **hides the V× reserve row entirely** without replacing it with COOP; the mode indicator remains separately.
- Bonus duration increased to 220 game ticks on the field; shells do not destroy unclaimed bonuses. Picking one up produces a bounded blinking outline at its location plus existing HUD icon flash.
- Preserves 14 bonuses, AUTO/V in solo, 2P controls WASD + Ctrl, anti-oscillation tactics, enemy weapon bonuses and armored tread damage from v0.24.
- Builds as an **8086 DOS CGA .COM 54,560 bytes** with strict 56KiB cap; avoids wasteful section page-alignment and removes unused BIOS key handlers. **151 Python tests PASS**, 35 maps, ISA check PASS; **SLOW1 DOSBox-X /TEST PASS**, **2048-tick TRACE PASS (20/20 kills, STAGE CLEAR, HQ survives)**. Bench results and installed/rollback record: `releases/v0.25/RELEASE-NOTES.md`.
- Main README includes full current controls, 1P/2P life rules, aircraft effects, all 14 bonuses, versioned GitHub Release downloads and genuinely labeled CGA screenshot/unsupported adapter statuses.

## v0.24 — Two-player cooperative play, anti-loop tactics, armored-only track damage (2026-11-12)

- **Join the co-op immediately** with 2P **W/A/S/D + Ctrl**; 1P uses **arrows + Space**. The first P2 key switches 1P from AUTO into MAN. The old AI companion tank becomes the human P2 avatar; solo V remains available, co-op V/auto-ally is disabled. TAB AUTO toggling remains solo-only.
- **Independent human lives** visible on HUD as **1P×1 2P×1**; one player can survive the other's elimination, with the base shared. Hearts belong to the collector. **Half as many pickups** in co-op (4 potential drops vs. 8 in solo across 20 enemy deaths).
- **Actual bounded A-B-A-B repetition detection** for autonomous P1 and each hostile tank: track repeated headings/cell positions and persist with an alternative collision-verified perpendicular direction when oscillation is detected.
- **Fix spurious tread pixels**: remove cyan/black decorative track dots from all healthy tanks and both human players; draw small black tread damage markers ONLY on damaged armored enemies, which genuinely travel at half their healthy armored speed.
- Enemy-held combat pickups are real: temporary laser, burst, guidance, super-shell, ricochet and clock effects. Armed enemies fire at every legal firing opportunity; their laser leaves a bounded visible beam flash. New DOS smoke phase verifies an enemy picking up and shooting a laser.
- **GitHub CI PASS**: 145 tests, 35 maps validated, strict 8086 ISA and 56 KiB DOS cap. Native SLOW1 DOSBox-X **/TEST PASS** including phases 100–109; 2048-tick AUTO **20/20 kills, STAGE CLEAR, HQ saved**. See `releases/v0.24/RELEASE-NOTES.md` for current ABBA performance and installed/rollback proof.
- Expanded homepage: versioned **GitHub Releases** download, updated full controls, gameplay details, honest adapter-status gallery, and exact tested `dist/TANKS.COM` with SHA-256.

## v0.23 — Ricochet, four-way barrage, hyper-shell and tactical pursuit (2026-11-10)

- **Two compatible pickup doctrines:** collect within 1.5 tiles, including while stationary, and follow the whole-map bonus flow when there is no imminent HQ danger. Enemy pressure near the center cancels dangerous detours. Clear enemy firing lanes outrank pickup movement.
- AUTO uses a separate cached enemy-hunt BFS so pursuit (laser rush, final hidden enemy) never corrupts the route to the real active bonus. Freeze does not stop the player's attacks. With an accessible shot AUTO fires; steel behind obstacles still blocks futile shots.
- **14 distinct bonuses total.** Newly added: independent fast 10-second ping-pong ricochet, lethal to enemy and player alike (single ball until expiry); four real directional shots; full-penetration color-alternating super-shell. All are playable with 8086 physics, not decorative sprites.
- Real enemy-owned temporary weapon abilities (laser, burst, homing, super, hazardous ricochet), enemy clock slowing P1, and existing prohibition against stealing hearts or V reserve.
- Repeated hits damage heavy tank tracks (black tread dots, half movement speed). CGA stage curtains/scan/sweep transitions now stay visible longer at stage boundaries only.
- Removed unused legacy sprite copies and encoded all 35 original maps with compact RLE; shipping **52,860-byte** DOS .COM stays under strict 56KiB cap.
- **GitHub Actions PASS:** 136 Python tests, 35 maps validated, 8086 ISA. **SLOW1 DOSBox-X /TEST PASS** and 2048-tick /TRACE **20/20 kills, STAGE CLEAR, HQ saved**. Matched ABBA 384-frame 8086/CGA speed gate **PASS**: at 240 cycles/ms v0.23 mean **57.748 s** vs v0.19 **68.520 s** (15.7% faster in these runs); at 500 cycles/ms **24.074 vs 30.347 s** (20.7%). Variable host load; no physical XT performance claim. **Installed atomically on SLOW1** at `C:\XT-Battle-City\run\TANKS.COM`, installed DOS /TEST PASS. Rollback: `run\TANKS-v022-backup-20261110-232330.COM` (SHA-256 `F1705EFC784818691A3E69E4E778185C4BF00A2FB7C5F5AF64F7D0E3B1CAD917`).
- Full controls, 14-bonus encyclopedia and real CGA screenshot with clearly labeled compatibility limitations on the updated [README homepage](README.md). Binary at `dist/TANKS.COM`; versioned ZIP under `releases/v0.23/`.

## v0.22 — Nearby power-ups, active AUTO during freeze, steel-aware fire (2026-11-10)

- Player collects any active bonus within **1.5 cells** (24x18 pixels), including without moving after a bonus appears; uses real pixel coordinates rather than exact equality of 16x12 cells.
- All enemy roles route towards nearby **usable** bonuses and collect within 1.5 cells. Hearts/lives and V ally reserves remain exclusively for the player.
- AUTO uses the clock freeze window to pursue and fire at immobilized enemies, while dangerous far-away bonus distractions are vetoed to keep headquarters defended.
- AUTO firing-lane obstruction detection covers every intervening map tile, ignoring destructible brick but suppressing shots through **steel** or headquarters. Efficient tile-index scanner preserves the normal per-tick auto attack cadence.
- Strict GitHub CI: **125 Python tests**, **35 valid stages**, original CGA artwork, 8086 ISA audit, DOS .COM size ceiling PASS. Native SLOW1 DOSBox-X **/TEST PASS** through phase 95 and 2048-tick **/TRACE: 20/20 kills, STAGE CLEAR, base saved**.
- **Performance gate PASS** on SLOW1: matched alternating 384 full-frame 8086/CGA runs at fixed 240 cycles/ms: v0.22 **40.058/52.683 s**, baseline v0.19 **48.757/53.271 s** (means **46.371 vs 51.014 s**). At fixed 500 cycles/ms: v0.22 **20.421/27.826 s**, v0.19 **22.787/27.851 s** (means **24.124 vs 25.319 s**). Host load changed substantially during runs; deterministic frames do not imply identical gameplay state, and physical XT timing is not proven.
- **Installed atomically on SLOW1** at `C:\XT-Battle-City\run\TANKS.COM` and retested the installed copy: DOSBox-X **/TEST PASS**. Rollback at `run\TANKS-v021-backup-20261110-203600.COM` (old v0.21 SHA `BCEE4E795F069A5A9A59E56DF0FE2B7DDF9E508288F3F6D4C08D14F3F515D75C`). Exact new binary in `dist/TANKS.COM`: 56,666 bytes, SHA256 `F1705EFC784818691A3E69E4E778185C4BF00A2FB7C5F5AF64F7D0E3B1CAD917`.
- See `releases/v0.22/RELEASE-NOTES.md` for gameplay, testing, hardware limitations and rollback.

## v0.21 — Artifact-free laser, enemy wreck pickups and temporary ally protection (2026-11-10)

- **No persistent laser ghosts:** the colored continuous 1px beam is drawn only into actual CGA B800h **after** committing the RAM shadow frame. It never corrupts the untouched composition buffer. Each affected tile is scheduled for background restoration on the next rendered frame, including after the laser expires.
- The extra-life pickup is a recognizable **heart** (not a cross); P1 / allied team earns exactly one additional life, capped at 9. Enemy tanks cannot steal hearts or V/companion reserves.
- Instead of a fixed scripted bonus location, a pickup now appears at the actual defeated enemy's grid cell (subject to open terrain and the existing single-active-bonus limit). **Eight possible drops per 20 kills**, for a 1.6× opportunity frequency versus the prior five. Opportunities skipped while a bonus is already on the map are not queued.
- Enemies can claim other dropped pickups for specific advantages: armor on star/helmet, heavier fire on weapon bonuses, freeing frozen troops with clock, canceling HQ protection with shovel, destroying an active companion with grenade and stopping friendly-fire frenzy. No artificial armor inflation for unrelated bonus types.
- Companion uses the normal P1 chassis with a tiny contrasting **colored 2×2 cockpit marker**, not a permanent invulnerability halo. It has a real **48-tick (~2.6s) shield** after spawning/renewal: blinking visual indicator, real bullet protection, then expires while its 15-second lifetime continues.
- AUTO guard doctrine updated: **do not abandon HQ** to chase front-line bonus drops in the upper eight map rows; the ally/enemies can still collect those. The first level returns to **STAGE CLEAR** despite stronger opponents.
- **SLOW1 real DOSBox-X acceptance:** 118 Python tests and 93 built-in real-mode DOS /TEST phases PASS; full 2048-tick AUTO trace defeated **20/20 enemies**, HQ survived, stage clear appeared at about tick 1568.
- **Preserved speed:** SLOW1 384 rendered-frame emulator comparison, 8086/CGA fixed 240 cycles/ms: v0.20 **41.111s** vs v0.21 **40.063s**; at 500 cycles/ms 20.032s vs 20.035s. These are not exactly the same gameplay workload (6 versus 5 kills at tick 384 due to changed pickup rules). No measured regression against the accepted v0.19 reference, but physical XT benchmarks remain outstanding.
- **Directly installed** on SLOW1 at `C:\XT-Battle-City\run\TANKS.COM`, previous v0.20 backed up. Exact 8086 binary: **56,666 bytes**, SHA-256 `BCEE4E795F069A5A9A59E56DF0FE2B7DDF9E508288F3F6D4C08D14F3F515D75C`. No ZIP needed by the user.

## v0.20 — V companion reserve, HQ summons, cinematic stage wipes (2026-11-10)

- One **free V summon** at campaign start; the sidebar shows V×N at far right. V summons a separate aggressively attacking AUTO tank from safe HQ-adjacent exits for **270 BIOS ticks (15 seconds)** or until an enemy shell destroys it.
- Each companion bonus increases V reserve (capped at 9). In **AUTO**, an allied pickup immediately dispatches a companion or renews the current ally for 15 seconds; **manual** mode saves it for V. Stock persists across levels and resets for a new campaign.
- When stock is empty, V may pay **one of the player's own lives**, but never the last life. V flashes for one second after the life expenditure. Failed summons due to blocked exits do not charge lives or stock.
- Companion seeks and fires at enemies using the existing genuine allied projectile and collision engine; its shots cannot damage P1. It collects pickups independently, sharing team effects; existing enemy bullets can destroy the ally.
- Combined HUD y96: collected bonus icon at **far left x256**, active ally or bonus countdown in **middle x272/280**, V and stock **x296..319**. The 15-second companion timer uses 16-bit storage, since 270 ticks exceed a byte.
- Three original short **stage-boundary** CGA transitions: row scan, column sweep, and symmetric curtains. Open before gameplay starts, close before stage-clear/game-over lettering; no effect inside the steady-state game loop. Pausing/unpausing does not replay intro.
- Preserved the v0.19 8088 CGA optimization. Matched SLOW1 384 full-frame benchmark: 240 cycles/ms v0.19 40.124s vs v0.20 41.057s (**2.3% longer, within the 5% gate**); 500 cycles/ms 20.035s vs 20.039s. Same 6 kills and game state. Real XT timing remains unmeasured.
- Added root **AGENTS.md** release requirements: strict performance baseline, 8086 ISA, true **56 KiB** DOS COM ceiling, cassette/diskless RAM-only state and direct SLOW1 deployment/rollback.
- GitHub CI: **108 Python tests**, 35 authored maps, 8086 instruction audit. SLOW1 DOSBox-X: **88 /TEST phases PASS**, real 2048-tick replay: first stage **20/20 kills / STAGE CLEAR / HQ saved**.

## v0.19 — XT 8088 speed, clean laser line, RAM-only palette (2026-11-10)

- Reduced complete real-mode frame rendering time on SLOW1: at fixed 240 DOSBox-X cycles/ms, **384 full frames: 56.123s (v0.18) → 40.051s (v0.19), 28.6% elapsed-time reduction**. At fixed 500 cycles/ms: 28.088s → 20.033s, 28.7% reduction. Both replays have identical 24 snapshots/6 kills at 384 ticks. This is emulator timing, not proof of physical 4.77MHz 8088 FPS.
- Separate less visual 2048-tick/128-frame trace: 52.12s→50.06s (~4% lower elapsed); both cleared stage 1 at 1040 sample tick with 20 kills. The gain primarily comes from rendering optimizations.
- Avoid repeated CGA row calculations in every masked sprite: precomputed even/odd bank offsets for 192 scanlines. Replace MUL-16 on map lookups with shifts and DIV-12 per collision corner with a 256-byte lookup.
- Rewrite dirty-tile marking, static restoration and VRAM upload to scan flat 256-byte flags directly instead of 256 full get_tile() calculations per frame. Suppress redundant per-tick AUTO HUD repaint.
- Draw laser as a continuous 1-pixel segment from muzzle to actual projectile collision. Switch CGA color 1/3 every tick and restore every touched tile on the next frame. No more repeated 16×12 projectile sprite splats/ghosts.
- Correct palette reset: after every BIOS CGA mode reinitialization, replay the current user-selected 3D9h palette index held in RAM. **No filesystem settings file, no cassette I/O, and no write to CMOS**; user choice cannot outlive power loss without an external medium.
- Retro footer: move TANKS up by eight pixels for an empty separator row; ©1982/BASIC/V0.19 remain in regular rows with one blank font scanline between them.
- Emulated adapter smoke: CGA baseline PASS; EGA PASS and VGA PASS only under **CGA mode 4 compatibility**; Hercules FAIL. Native EGA-16, VGA-256 and Hercules drivers remain future work.
- GitHub: 96 Python tests, 35 stages, regenerated CGA assets, 8086 ISA audit, DOS binary under 56KiB. SLOW1 actual DOSBox-X /TEST through phase 78 PASS (new palette, y lookup, laser cleanup).
- Real XT/Poisk hardware, all-stage play, diskless and tape-native Poisk boot still not certified.

## v0.18 — lighter classic CGA artwork and readable sidebar (2026-11-10)

- Redrew water as two thin wave ribbons with dark space, replacing thick sawtooth bands. Ice is a clean cyan sheet with broad asymmetric white crystalline facets.
- Replaced unreadable rounded cyan forest clusters with a pair of recognizable miniature pine-tree silhouettes.
- Narrowed the right bonus border from x13 to x12, keeping all eleven symbols centered; in the last 27 ticks, only the border flashes while the symbol remains visible. No bonus duration/gameplay changes.
- Player shield now flashes at a four-tick phase while the underlying tank is always rendered; the aggressive ally keeps its distinct halo.
- AUTO is centered in the 64px right HUD strip. Added compact four-line white-on-black CGA signature: TANKS / ©1982 / BASIC / V0.18. The five-glyph version table is the single place to update each subsequent release.
- All new sprites and glyphs are original CGA 2bpp artwork inspired by limited-palette, silhouette-first 1980s game art principles; no third-party ROM sprite bytes copied.
- CI: 87 Python tests, 35 original maps, asset regeneration, legal 8086 ISA, 55,992-byte binary (under 56 KiB).
- SLOW1 DOSBox-X: embedded /TEST phases 1–74 PASS; 2048-tick AUTO first-stage replay 20/20 defeated / STAGE CLEAR / base survives at approximately tick 1024.
- Installed directly in C:\\XT-Battle-City\\run\\TANKS.COM (sha256 1F93A6739AD2E3C4E2A14DEFA3C846A1320F72D30C6D69EFF56876F34AF29817); previous v0.17 backed up. Quality/fps on physical 4.77-MHz 8088 remains to be tested.

## v0.17 — laser, allied AUTO tank, triple fire, guided missiles and enemy frenzy (2026-11-09)

- Five new CGA bonus pickup symbols and sidebar icons, eleven power-ups total. The pre-existing clock remains the freeze-enemies bonus.
- Instant laser hits by sweeping the existing pixel projectile engine within one tick. A short alternating white/cyan trail renders over the actual impact trajectory.
- Temporary companion tank has the original player's chassis with a distinct shield outline, independently seeks/fires at enemies using spare projectile slots and can be destroyed.
- Three concurrent friendly bullets (one primary and two extra); primary and extra projectiles can home toward the nearest live enemy and visibly flash.
- Frenzy effect instructs enemy tanks to target other enemy tanks; existing true friendly-fire collision/hit rules remain live.
- Grenade kills animate up to four separate explosion FX instead of silently hiding enemies.
- Sidebar shows the bonus glyph and a 2-digit remaining-seconds countdown for timed effects; permanent upgrades and instantaneous pickups show no misleading expiry.
- Expanded bonus order retains original defensive aids early in stage 1 before rotating through the new effects.
- Shipping DOS program budget is now **56 KiB** (previously 48 KiB); no 286 instructions or floating point; actual 8088 cycle costs and base Poisk-1 memory still require measurements.
- CI and DOS real-mode /TEST regression include phases 66–71 for instant laser, capped bullet pool, guidance, ally fire, enemy-to-enemy intent and animated grenade victims.
- SLOW1 diagnostic /TRACE still cleared stage 1 in the 2048-tick simulation (20/20 enemies, HQ intact). One replay is not multi-seed gameplay certification.

## v0.16 — HQ-first AUTO and bonus-time combat (2026-11-09)

- Separated AUTO firing from navigation: a clear shot is taken even while moving to a pickup.
- Check the actual projectile lane before committing to fire; steel and the HQ block shots, but chippable bricks do not.
- Move the collected-bonus glyph from x284 to x264 while keeping the original six distinct icons.
- Hold the first stage's viable x96 sentry lane instead of x112 behind steel.
- Prioritize central HQ breachers over distant flank decoys; stay within a bounded interception corridor and avoid edge jitter.
- Increase emergency sensitivity: any enemy near the final base rows vetoes the bonus route.
- Embedded DOS /TEST now reaches phase 65; CI includes 73 Python tests, map checks, 8086 ISA audit and strict 48 KiB cap.
- SLOW1 DOSBox-X validation: 2048-tick /TRACE produced a win on stage 1 with 20/20 enemies destroyed and the HQ intact; a prior iteration lost around tick 272, prompting the central-threat scoring fix.
- Installed directly at C:\\XT-Battle-City\\run\\TANKS.COM; old v0.15 retained for rollback. Extended multi-seed gameplay validation and real 8088 timing are still pending.

## v0.15 — defender fire/dodge, squad diversity, bonus HUD, anti-stall (2026-11-09)

- Player shells now score edge/tread overlaps, and AUTO aims within the same physical collision margins.
- Improved base defence: forward sentry, earlier central-breach priority and less chasing of remote flank decoys.
- Incoming shells are considered farther ahead; the escape heading must be physically legal, with an opposite-side fallback.
- New per-stage enemy squad doctrines: standard, fast HQ blitz, delayed pincer, right-side denial.
- Collected power-ups display their own blinking 8x8 icon in the right HUD (not a star/number placeholder).
- Prevented multi-tank stalemates: collision probes consider live occupied hulls; repeatedly blocked attackers yield to free corridors.
- DOS /TEST adds phases 56–58 (actor congestion, jam backoff, sentry advance). Python unit tests cover visual/logic invariants.
- CI: 68 Python tests, ISA audit, map checks and strict 48 KiB size budget PASS. Physical DOSBox-X on SLOW1: /TEST phase script PASS. Qualitative gameplay and true 4.77-MHz 8088 speed still require observation.

## v0.14 — collision-aware squad, pickup pursuit and proactive fire (2026-11-09)

- Restored enemy-on-enemy damage and kills without awarding player points.
- DEFENDER doctrine: emergency HQ defense > pickup BFS goal > lane interception.
- Added a cached 16x16 bonus route recalculated on spawn/terrain change only.
- AUTO aims/fires on aligned enemies before the HQ final defensive rows.
- ATTACKER interceptor: deny accessible power-ups, use last revealed player
  position and central screening, instead of knowing exact hidden coordinates.
- HQ breacher relocates when a teammate blocks its firing lane.
- 35 stage maps packed in 4-bit tile IDs, decoded once per stage; 48 KiB budget kept.
- New DOS /TEST phases 52-54 and Python roundtrip/friendly-fire tests.
- Skill of full-game strategy requires manual acceptance: no claim of chess search.

## v0.13.0 — release stabilization (2026-11-09)

- Reinstated strict 48 KiB shipping DOS binary limit; extracted 384-tick diagnostic trace into optional `TANKS-TRACE.COM` instead of inflating the release.
- Preserved `TANKS.COM /TEST` with the improved real-mode autopilot/keyboard regressions.
- Added explicit release-size assertions and kept original CI size gate intact.

## v0.13 — global tactical routes, coordinated HQ assault and manual keyboard fix (2026-11-09)

- Compute three cached reverse-BFS distance fields (HQ, left staging, right staging) on each 16×16 map; rebuild after destroyed walls.
- Coordinated phased squad attack with HQ artillery posture; interceptor keeps separate hunter behavior.
- Defender holds a defensive line and retains its target, instead of chasing random screen objects.
- Physical XT keys separate from AI movement. Manual takeover no longer inherits the AI's previous LEFT, and the sidebar shows TAB-AUTO in manual mode.
- Suppress ally-targeted fire over the full line; stray allied projectiles cannot damage allies.
- Remove collision-triggered random rotations; use route replanning.
- Expanded Python and DOSBox regression phases; do not claim 86Box 4.77MHz performance certification.

## v0.12 — local tactical route planning and ambush corrections (2026-11-09)

- Bounded six-pixel lookahead scores four possible headings for each active enemy.
- Enemy plans keep squad roles and last-known opponent position, but avoid obvious dead-end turns and wall-adjacent oscillation.
- Emergency dodge checks for an actually open escape path.
- Corrected ambush barrel direction to aim at the player, rather than the flank waypoint.
- Extended real-mode DOS regression with blocked/open corridor test.
- No FPU, heap or 286+ instructions; XT 4.77 MHz cycle timing still needs 86Box tests.
- Every part remains original project code/assets.

## v0.11 — Tactical Director and CGA materials (2026-11-09)

- Autoplay begins immediately, with a low-cost 8088 player defender that
  selects objectives, seeks firing lanes, dodges enemy shells and protects HQ.
- Manual arrows/WASD/space take over; Tab toggles AI mode, displayed as AUTO/MAN.
- AI demo advances/restarts after a result-screen hold.
- Four enemy squad roles (HQ raider, left/right flank, interceptor), shared
  short-lived last-known player location, ambush holds and incoming-shot dodge.
- Friend-aware shot suppression alongside existing live friendly-fire physics.
- Material pass: negative-space water waves and bright cracked ice.
- Align GAME OVER/SCORE/R - RESTART and add mode indicator to the CGA HUD.
- 8086 ISA, DOS /TEST tactical probes, map and asset QA; **true 8088 FPS still unmeasured**.

## v0.10 — CGA silhouette and material readability (2026-11-09)
- Redesigned player and four enemy classes as silhouette-first original 12×12 cores, keeping a visible turret/muzzle and two physically separated tracks.
- Removed all cyan/green ornamentation from brick; dark mortar, staggered courses and deliberate white highlight strips remain recognizable under all four CGA palette settings.
- Redrew steel as a riveted plate, water as flowing horizontal wave crests, forest as foliage clusters, and ice as a faceted diagonal crack; each texture has its own non-color visual signature.
- Redrew and optically centered all six pickup pictograms, including a miniature tank for the extra life.
- Replaced shield's sparse dots with a symmetric protective outer arc that preserves all tank pixels.
- Added six automated v0.10 art-readability regressions, 4-palette atlas preview and pixel-size visual proof. Fixed `make assets` always to regenerate instead of colliding with the `assets/` directory.
- Same 8088 runtime renderer and atlas dimensions, no additional CPU drawing work; ~47KB DOS binary. Existing anti-flicker buffer is unchanged.
- Remaining gates: manual long-session game review, 86Box 8088/4.77MHz timing and native Poisk-1 hardware backend.

## v0.9 — CGA art and anti-flicker engine (2026-11-09)
- New 16KB conventional-RAM frame-composition buffer on DOS/XT, with safe direct-VRAM fallback when allocation fails.
- Compositing occurs off-screen; only completed dirty tiles are transferred into B800 CGA VRAM, avoiding the old visible clear-before-draw flicker.
- Completely reworked original tank silhouettes (player, basic, fast, power, armor), two-phase tread animation, invulnerability halo, bonus icon centering and terrain art designed with large color clusters.
- Added engine/visual regression tests plus an in-DOS shadow-vs-CGA-memory consistency check.
- Preserves four real CGA palette choices, 35 stages, optional AdLib/PC Speaker and 8088 instruction safety.
- Caveats: performance still needs physical XT/86Box profile measurement; display update uses a fallback path on very low DOS RAM.

## v0.8 — CGA art, moving tracks, debris, friendly fire and compact HUD

- Detailed original tanks/walls/water/ice/forest and base; 2-phase directional treads.
- Four-frame debris explosion (single bounded instance, no full redraw buffer).
- Enemy projectiles can hit other enemies, without awarding player score.
- Press C to cycle four supported hardware RGBI CGA palette/intensity presets.
- Wider/taller 16×16 map (256×192 pixels), compact top-right HUD and live score.
- 35 stage maps adapted to new geometry, assembler ISA and DOS regression tests.
- Full 320px playable width and certified 8088 FPS remain future work.

## v0.7 — 35-stage campaign, stage navigation and optional AdLib (2026-11-09)
- CI map checks now validate all 35 maps in a single Python process (faster on slow hosts).
- Added conservative OPL2 timer probe and one-channel FM effects with PC Speaker fallback.
- Extended the original project campaign from 9 to 35 distinct new maps without copying NES layouts.
- Stage path safety: two-tile winding center corridor, safe P/HQ and enemy spawn positions.
- Stage-aware opponent class mix, with more power/armor enemies in later stages.
- Page Up / Page Down during Pause/results to start adjacent stages for QA.
- DOS /TEST stage-35 landmark and wrapping checks, Python campaign connectivity checks.
- 86Box 8088 timing and native Poisk-1 remain not verified.

# Журнал изменений

## 2026-11-08 — initialization

- Создано техническое задание и критерии совместимости XT / Poisk-1.
- Запланированы CGA, EGA, VGA, Hercules, PC Speaker и необязательный OPL2.
- Добавлены тестируемый формат уровней и DOS-диагностика `XTINFO.COM`.
- Нативный запуск на Poisk-1 и игровая реализация ещё не выполнены.

## 2026-11-08 — CGA playable prototype (pre-alpha)
- First 8086 DOS `TANKS.COM` at 320x200x4 CGA palette 1; tile-map, four-direction tank sprite, keyboard, shooting, brick/steel/water, three static enemy targets, win and restart.
- Built-in `/TEST` DOSBox-X smoke scenario and checked-in original 16x12 sprites generated from ASCII art.
- 8086 Jcc/prefix static audit; GitHub CI uploads both DOS `.COM` artifacts.
- **Not yet:** moving enemy AI, original Poisk-1 boot, EGA/VGA/Hercules display drivers, AdLib audio, 8088 FPS benchmark.

## Unreleased — CGA gameplay milestone 0.2

- First enemy simulation: up to 3 active enemies, fresh enemies arriving from top spawn lanes, 20 kills to clear a stage.
- Enemy movement, turning, direction-sensitive original art, and enemy projectiles that damage terrain, the headquarters, and player.
- Three original 13×13 level layouts; each stage loads separately, score and remaining lives persist through stage transitions.
- Three player lives, short respawn protection, stage clear / game over, HUD with stage / enemies / lives / score.
- Additional assembly smoke test covers spawning, player collision with steel, brick destruction, player damage, HQ destruction and stage completion.
- Updated 8086 instruction audit, map tests, and deterministic assets generator; *does not* claim pixel-perfect Battle City compatibility or tested base Poisk-1 support.

## Unreleased — CGA gameplay milestone 0.3

- Up to four enemies simultaneously, matching the classic concurrency budget.
- Four enemy types in repeating wave composition: basic, faster, frequent-fire, armor (4 hits); 100/200/300/400 scoring.
- Different CGA palette/pattern sprites for types, generated from project-owned pixel art.
- Extended built-in DOS smoke test with enemy type and armored damage regression.
- **Not** a pixel-perfect recreation: sub-tile motion, quadrant brick damage, bonuses, two-player and 35 authored stages are still in the fidelity backlog.

## 2026-11-09 — wave 0.5 (CGA gameplay)

- Nine original hand-authored levels, stage pointer table, enhanced terrain with forest and ice.
- Four independently stored brick quadrants; directional projectile impact removes an exposed half, updating the tile sprite. **Not yet pixel-level collision.**
- Six original power-up icons and effects: star, helmet, grenade, temporary steel HQ barrier, freeze enemies, extra life. One visible pickup with timeout; drops every fourth kill if the previous pickup is gone.
- Player/enemy projectile interception, extra star-powered fire and top-tier steel shot, short ice sliding.
- PC Speaker non-blocking sound effects and `M` mute; no AdLib implementation yet.
- Visible shield silhouette and star-level indicator on the classic CGA sidebar.
- New emulator `/TEST` phases and Python asset/map invariants. Still needs real XT 4.77MHz / Poisk native benchmarks.
- Separate stage-results tally (four enemy classes, counts, global score); nonintrusive `P` pause and resume without resetting simulation.
- Ice-slide stops retrying when the next cell is blocked; documentation updated after v0.5 acceptance.

## 2026-11-09 — v0.6 smooth pixel gameplay (candidate)

- Replace grid-step runtime movement with exact integer pixel coordinates for player and enemies; keyboard IRQ1 captures key make/break (held arrows/WASD, fire, pause, mute, restart and exit) on an XT PC with restoration at exit.
- Add a 4-phase masked sprite atlas for transparent 1-pixel horizontal shifts, dirty background restoration without a full-screen backbuffer, and integer-pixel CGA draw coordinates.
- Add hull-based collision checks against solid quadrants of bricks, HQ, water, steel and other tanks; stable movement near walls, less frantic enemy movement and shooting.
- Projectiles advance in 1-pixel substeps with exact 8x6-brick quadrant damage, tank hits, shot-vs-shot collisions and improved damage rules; nine stages and all six bonuses retained.
- Extend /TEST with smooth movement, steel boundary, precise brick damage and bullet advance; add structural regression suite and increase DOS COM size cap to 48KiB.
- **Note:** keyboard hook and 4.77MHz performance need specific emulator and manual user checks, and this binary remains a DOS/CGA build rather than a base Poisk-1 native build.
