# Первые задачи для GitHub Issues

Ниже подготовлены семь первых issue. При создании удалённого репозитория их можно переносить 1:1 с критериями приёмки.

## P0 / Research: Poisk-1 96 KB + bootstrap

Проверить ранние BIOS, кассетный протокол, карту памяти, поддержку загрузки с 96 КБ и ввод. Done: native hello (без DOS/дисковода) в MAME, с отчётом по BIOS и памяти.

## P0 / DOS: first CGA display and input

Сделать первый прямой/BIOS-совместимый видеобэкенд CGA, вход с клавиатуры, frame timing на 8088. Done: 13×13 карта и движущийся танк на 86Box 4,77 МГц с замерами.

## P0 / Core: vertical gameplay slice

Разрушение кирпичей, снаряды, столкновения, 1 enemy, база, конец уровня. Done: полный цикл без жёсткой зависимости от драйвера.

## P0 / Poisk-1: video and keyboard backend

Исследовать встроенное видео и ввод отдельно от IBM CGA. Done: артефакты тестов MAME и работающий доступный basic render/input без IBM-специфичных предположений.

## P1 / Video: EGA, VGA, Hercules

Добавить backend/skin под каждый режим. Done: тот же уровень с тем же игровым результатом, захват экрана и FPS каждой карты.

## P1 / Audio: Speaker and optional AdLib

Сделать события звука и детектор OPL2 через timer flags, безопасный fallback. Done: работа без платы и FM на имитируемой OPL2 плате.

## P1 / Bench: 4.77 MHz benchmark and memory tracking

Worst-case scene, RAM high-water/stack, fixed tick. Done: воспроизводимый тест и отчёт для XT и Poisk, на основании которого выбираем объём эффектов.
