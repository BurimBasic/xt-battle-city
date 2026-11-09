# XT Battle City v0.16 — Headquarters Defense / Independent Fire

## Installed on SLOW1

This release is deployed directly at `C:\XT-Battle-City\run\TANKS.COM`.
The user launches it with `C:\XT-Battle-City\RUN-CGA.cmd`.
No ZIP download is required. Previous v0.15 COM was backed up in the run directory.

## Gameplay changes

- AUTO shooting runs independently of navigation, so an aligned enemy may be fired upon even while the tank is collecting a bonus.
- Before locking onto a target, the defender probes the true projectile center line to reject steel barriers and the HQ. Destructible brick blocks can still be chipped.
- The defender uses a forward sidelong sentry line, with x96 on level 1, avoiding the center x112 steel barricade.
- The highest-scored base danger wins target selection: central corridor invaders receive a large bias, while wing decoys no longer pull the tank all the way to the outer map boundary.
- Horizontal interception is constrained to x80–144; when at the limit the defender moves vertically rather than oscillating left/right.
- All serious headquarters incursions veto chasing a distant power-up.
- The right-panel blinking icon for the actual collected bonus shifts left from x284 to x264. Each of the six bonus types keeps its distinct icon.

## Acceptance evidence

- GitHub CI: 73 Python unit tests, assets and all 35 maps, 8086 instruction audit, DOS binary under 49,152 bytes.
- SLOW1 physical DOSBox-X launch: `TANKS.COM /TEST` PASS through diagnostic phase 65.
- Separate instrumented `TANKS-TRACE.COM /TRACE`: 2048 ticks sampled every 16; level 1 achieved **20 of 20 enemies destroyed** and `game_state=1` (stage clear) by approximately tick 1024, with the base intact.
- The installed binary was tested again from `C:\XT-Battle-City\run\TANKS.COM`: PASS.
- Release size: **48,380 bytes**. SHA-256: `C8076219D8F591177D4B2A11CC6C4051DB6DD130327FA10E83B6DCF15E421482`.

One deterministic first-stage replay does not prove victory across different seeds or all 35 stages. Long human gameplay acceptance and cycle-accurate 4.77-MHz 8088 profiling remain open.
