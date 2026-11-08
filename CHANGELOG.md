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
