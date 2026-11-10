# XT Battle City v0.20 — Companion V Calls & Arcade Wipe Transitions

## Installation on SLOW1

The tested game is installed directly as
`C:\XT-Battle-City\run\TANKS.COM`.
To play, close any previously open DOSBox-X and launch
`C:\XT-Battle-City\RUN-CGA.cmd`. No ZIP download is required.

Previous release backup:
`C:\XT-Battle-City\run\TANKS-v019-backup-20261110-031619.COM`.

## Companion system

- New campaigns start with **one free V call**, visible as **V×1** on the
  far right side of the bonus line.
- Press **V** to deploy an allied autonomous attacking tank from an open
  exit near headquarters. It acts for **270 BIOS ticks ≈ 15 seconds**, or
  until destroyed by real enemy fire. It has the player's base chassis
  but a visibly distinct shield outline. Ally shells use the player-side
  projectile collision engine and cannot damage the player's tank.
- New companion pickups (bonus type 7) add one reserve V call, capped at 9.
  In manual mode these can be saved. In AUTO mode the bonus immediately
  deploys or renews the companion for 15 seconds.
- If V reserve is empty and the player has at least two lives, V consumes
  **one own life** and the **V icon flashes**. The last life **cannot** be
  exchanged. If every safe deployment location is blocked, no life or
  reserve is spent.
- Companions chase and fire on enemies, move independently, and collect
  regular pickups for the team (including additional lives, freeze/laser
  and other effects). Their lifetime is kept as 16-bit, not an overflowing
  8-bit counter.
- **HUD y=96:** active bonus icon far left (x256), remaining seconds in
  the middle (x272/280), and V×N available reserve calls at right
  (x296/304/312). The ally icon/timer takes priority while one is active.

## Short arcade transitions

- **Horizontal row scan:** reveal / erase bands from top to bottom.
- **Vertical column scan:** reveal / erase from left to right.
- **Closing/opening curtains:** alternate columns from both edges to the middle.

Patterns rotate by stage and entry/exit phase. Each plays eight short
BIOS-tick steps only when a level starts or finishes, **before the stage
clear / game-over text**. An ordinary pause/unpause does not replay them.
No effects run in the per-frame update loop; no extra bitmap and no
persistent files. If no shadow buffer can be allocated, the introductory
reveal is skipped rather than corrupting the battlefield.

## Acceptance and speed protection

- GitHub CI: **108 Python tests**, all 35 authored maps, 8086 ISA audit,
  the original **strict 56 KiB** DOS size cap.
- SLOW1 actual DOSBox-X: **TANKS.COM /TEST PASS through 88 phases**
  (79–86 companion logic/UI, 87–88 real CGA entry/exit).
- 2048-tick real-mode AUTO trace still reports **20/20 enemies killed,
  STAGE CLEAR, headquarters intact at approx. tick 1024**.
- Matched 384-full-frame performance harness on SLOW1:

  | Fixed DOSBox-X CPU cycles/ms | v0.19 | v0.20 | Difference |
  |---|---:|---:|---:|
  | 240 | 40.124s | 41.057s | +2.3% runtime |
  | 500 | 20.035s | 20.039s | +0.02% runtime |

  Both benchmarks end at six kills, state 0, and use the same 384 game
  ticks. The v0.19 performance baseline and **no more than 5% slowdown**
  acceptance threshold are now mandated in root `AGENTS.md`.
- Exact installed binary retested successfully:
  **56,666 bytes**, SHA-256
  `E8F1704B1D12F2690B6944FC08D858FDBA6A7FFF31EE38887DAB6C454A10B05F`.

## Limits

Emulator run-time figures are not genuine 8088 4.77 MHz hardware FPS.
CGA is the only native rendering backend; EGA/VGA have merely CGA
compatibility, Hercules native support is absent. Standalone tape-boot
Poisk-1 is a separate target. Manual interactive assessment of the
companion's route choices and wipe aesthetics remains useful.
