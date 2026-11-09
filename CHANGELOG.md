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
