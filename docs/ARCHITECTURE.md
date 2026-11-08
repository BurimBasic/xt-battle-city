# Архитектура

```text
boot/load (dos .COM | poisk cassette/native)
       |
platform: input / clock / memory layout / shutdown
       |
fixed-tick game core: state, AI, bullets, collision, map, score
       |                                |
   video API                         audio API
       |                                |
  CGA EGA VGA HERC P1            Speaker | OPL2 (if detected)
```

## Жёсткие правила

* Разработчик пишет для 8086/8088 instruction set: никаких `pusha`, `enter`, 32-bit registers, protected mode.
* Общее ядро не вызывает DOS/BIOS и не работает с I/O портами напрямую.
* Нет malloc/heap на базовой платформе: массивы и максимальное число объектов ограничены статически.
* Все расчёты integer/fixed-point; где возможно, избегать 16×16 деления в игровом кадре.
* API `platform_init`, `platform_poll_input`, `platform_tick`, `platform_shutdown`; `video_init`, `video_draw_tile`, `video_draw_sprite`, `video_present`; `audio_init`, `audio_effect`, `audio_music_tick`, `audio_shutdown`. Это **предварительные контракты**, ещё не реализованные функции.
* Ядро обновляется с детерминированным шагом (включая collision order), отрисовка может выполняться реже.

## Игровая модель

* Поле 13×13 логических клеток; позиции целочисленные или fixed point внутри клетки.
* Раздельные классы тайлов (brick, steel, water, forest, empty, base).
* Один активный выстрел игрока на ранней стадии; спавн врагов лимитирован.
* Столкновение в игровом коде, а не по цвету пикселя.
* Несколько графических skin-пакетов с разной bitplane-представленностью; единая логическая сцена.

## Вертикальный срез

Вывести фон → движение игрока → стрельба → разрушение кирпича → столкновение → 1 враг → завершение уровня. Только после этого FM, графические эффекты и второй игрок.
