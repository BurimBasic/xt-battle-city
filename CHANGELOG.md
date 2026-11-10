## v0.20 — V companion reserve, HQ summons, cinematic stage wipes (2026-11-10)

- One **free V summon** at campaign start; the sidebar shows V×N at far right. V summons a separate aggressively attacking AUTO tank from safe HQ-adjacent exits for **270 BIOS ticks (15 seconds)** or until an enemy shell destroys it.
- Each companion bonus increases V reserve (capped at 9). In **AUTO**, an allied pickup immediately dispatches a companion or renews the current ally for 15 seconds; **manual** mode saves it for V. Stock persists across levels and resets for a new campaign.
- When stock is empty, V may pay **one of the player's own lives**, but never the last life. V flashes for one second after the life expenditure. Failed summons due to blocked exits do not charge lives or stock.
- Companion seeks and fires at enemies using the existing genuine allied projectile and collision engine; its shots cannot damage P1. It collects pickups independently, sharing team effects; existing enemy bullets can destroy the ally.
- Combined HUD y96: collected bonus icon at **far left x256**, active ally or bonus countdown in **middle x272/280**, V and stock **x296..319**. The 15-second companion timer uses 16-bit storage, since 270 ticks exceed a byte.
- Three original short **stage-boundary** CGA transitions: row scan, column sweep, and symmetric curtains. Open before gameplay starts, close before stage-clear/game-over lettering; no effect inside the steady-state game loop. Pausing/unpausing does not replay intro.
- Preserved the v0.19 8088 CGA optimization. Matched SLOW1 384 full-frame benchmark: 240 cycles/ms v0.19 40.124s vs v0.20 41.057s (**2.3% longer, within the 5% gate**); 500 cycles/ms 20.035s vs 20.039s. Same 6 kills and game state. Real XT timing remains unmeasured.
- Added root **AGENTS.md** release requirements: strict performance baseline, 8086 ISA, true **56 KiB** DOS COM ceiling, cassette/diskless RAM-only state and direct SLOW1 deployment/rollback.
- GitHub CI: **108 Python tests**, 35 authored maps, 8086 instruction audit. SLOW1 DOSBox-X: **86 /TEST phases PASS**, real 2048-tick replay: first stage **20/20 kills / STAGE CLEAR / HQ saved**.

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
