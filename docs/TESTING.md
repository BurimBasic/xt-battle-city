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
