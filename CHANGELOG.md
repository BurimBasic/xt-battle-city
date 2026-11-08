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
