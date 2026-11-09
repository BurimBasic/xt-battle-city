# Тестовая стратегия и матрица

## Быстрые локальные проверки

```sh
make clean all
make test
file build/XTINFO.COM
```

`XTINFO.COM` — диагностика DOS, **не игра**. `TANKS.COM` — CGA DOS-прототип; команда `TANKS.COM /TEST` выполняет программный smoke test движения/столкновений/разрушения и возвращает errorlevel 0 или 1. CI пока проверяет сборку, уровни, ассеты и отсутствие обнаруженных 386+ префиксов; эмуляторный smoke test запускается отдельно на SLOW1.

## Эмуляция

### 86Box

Подготовить **отдельные** конфигурации: PC/XT 8088 4,77 МГц + CGA, EGA, VGA ISA и Hercules. Для каждого: минимальный RAM профиль, MS-DOS, keyboard, Speaker, дополнительный вариант с AdLib. Настроить частоту именно эмулируемого CPU, не ориентироваться на скорость современного хоста. Сохранять конфигурацию, версии BIOS, скриншот, FPS и ошибки.

### MAME

Система `poisk1`, ранняя редакция BIOS при наличии законных ROM-образов, профиль 96 КБ RAM, встроенная клавиатура/видео, без floppy, без AdLib. Тест native cassette/ROM boot отдельно от DOS. MAME-реализация ревизии 1991 **не равнозначна** всем ранним платам: записывать ограничения покрытия.

## Приёмка каждой видеокарты

- Режим включается и выключается корректно.
- Материалы различимы; нет мусора/перерисовки/исчезнувших спрайтов.
- Управление не «залипает», направления/выстрелы работают одновременно.
- Идентичные последовательности seed+input → идентичные события игрового ядра.
- 10 мин игровой сцены без зависания, неверных обращений к памяти, переполнения стека.
- Замеры: CPU, частота кадров, максимальная нагрузка по спрайтам, RAM high-water mark.
- OPL2 отсутствует — fallback на Speaker; карта присутствует — детект и FM.

## Форма протокола проверки

```
Date / commit:
Emulator + version:
Machine / BIOS / RAM:
CPU frequency:
Video adapter & mode:
Audio adapter:
Load path: DOS / Poisk native:
Scene/object count:
FPS min/median/max:
RAM high-water:
Input/audio/render issues:
Status: PASS / FAIL / NOT RUN
Evidence: logs/screenshots/repro:
```

## v0.2 game logic smoke test (DOSBox-X)

`TANKS.COM /TEST` executes a deterministic test of initial enemy spawn slots, player movement and steel collision, destruction of a brick, an enemy projectile reducing lives, destruction of headquarters, and wave completion. It returns DOS `ERRORLEVEL 0` for PASS or `1` for FAIL. Run this under `machine=cga` in DOSBox-X. Save an emulator log and ensure a conditional `IF ERRORLEVEL 1` detects failures. This test **does not** validate timing or natural AI behavior under gameplay input.

For visual play, start `TANKS.COM` without arguments. While playing, send arrow keys/WASD and Space, verify enemy movement and shots, score, remaining enemies/lives, lose on HQ impact, and stage advance after 20 kills. Three game maps are authored locally. Do not call this a full Battle City replica: reference gaps tracked in [CLASSIC_REFERENCE.md](CLASSIC_REFERENCE.md).

## v0.4 — экранная компоновка CGA

- После запуска режима 04h в B800: проверяются белый первый байт боковой панели (`B800:003E = FFFFh`) и байты первого значка врага (`B800:02C0 = hud_tank_icon[0..1]`). Это включено в `TANKS.COM /TEST` (errorlevel 10 при ошибке экрана).
- В режиме игры верхняя и нижняя полосы свободны от текста; HUD располагается справа от поля x32..239. HUD: 20 миниатюрных врагов в двух колонках; `1P`, запасные жизни; флажок и двухзначный этап.
- После победы/проигрыша выводится центрированный экранный блок `STAGE CLEAR`/`GAME OVER` со счётом, форматирование `01234` дополнительно проверяется `/TEST` (errorlevel 11).
- Для ручной приёмки: `RUN-CGA.cmd` на SLOW1; убить врага и убедиться, что **один** значок исчез, проверить обновление жизней и новую панель после `R`.
- Это графическая/логическая проверка **DOSBox-X**, а не замер скорости на реальном XT 4,77 МГц или нативном «Поиске-1».

## v0.5 integration regression / powerups

Build `make clean all && make test` with GNU binutils and run `TANKS.COM /TEST` in DOSBox-X using a `.BAT` script that checks `ERRORLEVEL` **immediately** after TANKS returns; later DOS shell commands may overwrite it. Test stages now include two-step brick damage, six bonus effects (direct/star/helmet/clock/life/grenade, shovel protection/restore), player and enemy bullet cancellation, forest/ice traversal and stage-9 selection, and max-level star/steel destruction. The integrated test reports a nonzero errorlevel encoding the first failed phase.

This checks gameplay branches and memory access in emulation, **not** correct 4.77MHz timing or actual Poisk-1 hardware. Mouse-free input and visual fidelity still require manual gameplay. PC Speaker may not be audible over headless sessions, and AdLib has not been implemented.

New regressions also verify that the dedicated four-type tally displays two-digit counts correctly. `P` pauses the tick loop without discarding player/enemy state; `M` toggles PC Speaker. Manual RDP checks should include both hotkeys, stage completion and restore from pause. Avoid declaring a successful visual test from a headless `/TEST` alone.

## v0.6 smooth pixel pipeline

The game still starts as an IBM PC/XT DOS .COM in CGA graphics mode 04h. It installs an IRQ1 (INT 09h) keyboard handler to process both *make* and *break* scan codes (held arrows/WASD) and restores the interrupt vector before DOS exit. The 8042/XT port 61h acknowledgment requires verification in DOSBox-X, 86Box, and on physical compatible hardware. Do not claim Poisk native input compatibility from this test.

- `TANKS.COM /TEST` now includes phases 21–25: 1px movement, steel blocking, quadrant destruction, enemies' initial pixel positions, and shell motion.
- `make test` verifies every shift and alpha mask in all 32 animated sprites; 8086 opcode-prefix audit must pass.
- Use manual gameplay to verify holding arrows for smooth motion; turning into brick/steel must stop without clipping; shoot each 8x6 brick section; verify that a moving tank does not erase the tile below it; enemies should not appear inside one another; no abrupt early GAME OVER.
- Confirm BIOS/PC Speaker/IRQ behavior with the exact emulator, not just CI; save screenshots and all changed configuration/PC speed settings.
- Performance target: 8088 4.77MHz via 86Box; current DOSBox-X at 1000 cycles/ms is not an authoritative 8088 speed measurement.
