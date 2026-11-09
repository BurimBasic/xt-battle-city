# XT Battle City v0.13 — CGA Tactical Strategy (2026-11-09)

Public repository: https://github.com/BurimBasic/xt-battle-city
Verified source commit: `502cb17d7212d9d444d20bfff7a7f669ba6aab91`

## Release fixes

- Global reverse-BFS route fields per stage for HQ and both flanks, in place of six-pixel greed.
- Enemy squad roles and phased coordinated assault toward the headquarters.
- Allied shells can no longer damage allied tanks; prevent deliberately firing into friendly lanes.
- AUTO defender initially moves out of the blocked headquarters spawn, then holds a defensive line, locks its target and fires.
- Manual input and AUTO commands no longer contaminate each other: pressing RIGHT after AUTO does not inherit a stored LEFT command.
- Manual-mode HUD: `TAB-AUTO`, reminding how to re-enable autopilot.
- Original CGA 320×200 four-color visual system, four hardware palette settings and optional OPL2 preserved.
- 35 independent custom levels.

## Verified

- 57 Python tests, map validation for 35 levels, and 8086/8088 ISA audit.
- Program smaller than 48 KiB strict release budget (48,656 bytes).
- SLOW1 DOSBox-X `TANKS.COM /TEST` success, both OPL2+PC Speaker detection cases passed.
- GitHub Actions build passed.

## Limitations / acceptance gate

This is an experimental strategy release, not a claim of human-approved chess-like AI.
Map-wide routing and simple squad phases are implemented; no minimax, multi-agent A* or learned policy.
Long automatic combat sessions and manual keyboard response should be observed in the user's RDP session.
DOSBox-X execution is not cycle-accurate 8088/4.77 MHz speed certification.
Poisk-1 native boot and EGA/VGA/Hercules backends are not in this DOS/CGA build.

## Startup

Run `TANKS.COM` under MS-DOS with CGA adapter or DOSBox-X configured with `machine=cga` and `cputype=8086`.
AUTO demonstration begins immediately. Physical arrows/WASD/space take manual control. Press Tab for AUTO.
`P` pauses and Page Up/Down during pause lets you change stage for testing.
Press C to cycle CGA palettes, R to restart, M to mute, Esc to exit.
