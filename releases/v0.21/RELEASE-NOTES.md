# XT Battle City v0.21 — Clean Laser, Wreck Bonuses, Ally Markers

## Installed release on SLOW1

The game is already installed in the existing runtime directory:

- Game: `C:\XT-Battle-City\run\TANKS.COM`
- Launch: `C:\XT-Battle-City\RUN-CGA.cmd`
- Previous v0.20 backup: `C:\XT-Battle-City\run\TANKS-v020-backup-20261110-181018.COM`

Close the earlier DOSBox-X session before launching, otherwise the old game
may remain loaded. No ZIP download or extraction is needed.

**Installed COM:** 56,666 bytes. SHA256:
`BCEE4E795F069A5A9A59E56DF0FE2B7DDF9E508288F3F6D4C08D14F3F515D75C`.
The exact installed binary is committed to `dist/TANKS.COM`.

## User-visible fixes

- Laser: a continuous one-pixel ray blinks between two CGA colors until
  impact. It is overlaid only onto live CGA VRAM after frame composition,
  never into the shadow, then erased by re-uploading the clean underlying
  tiles. This addresses persistent long vertical laser trails.
- Life heart: real heart sprite; collecting adds one own life, up to nine.
- Pickups drop at the **defeated enemy's last location** if the terrain
  permits placement. In each 20-enemy wave, there are eight possible
  bonus opportunities instead of five (1.6 times as often). Single active
  pickup remains the cap; missed opportunities while occupied do not queue.
- Enemies may collect **combat** bonuses and gain the corresponding useful
  effect (armor, fire, anti-freeze, protection removal etc), but may **not**
  collect extra lives/hearts or companion/V summons.
- Companion is recognizable by a small colored cockpit marker, not a
  permanent shield. A genuine blinking protection halo now lasts 48 ticks
  (~2.6 seconds) after dispatch or renewal, then disappears; the companion
  can continue its 15-second run and be killed by enemy shells.
- Defender AUTO retains its HQ lane instead of chasing drops deep into
  the upper battlefield, important with enemy-location bonus placement.
- The footer is **V0.21**; the original 35 stages, palette choice in RAM,
  11 available bonuses and cassette-friendly design remain.

## Verification evidence

- GitHub CI: **118 Python tests**, 35 map validations, generated artwork
  check, 8086 prefix / long-branch ISA audit; no code overrun.
- SLOW1 DOSBox-X, **real .COM /TEST**: **93 phases PASS**.
- Full 2048-tick AUTO first-stage trace: **20/20 kills, STAGE CLEAR**
  around tick **1568**, headquarters survives.
- Installed `C:\XT-Battle-City\run\TANKS.COM` tested independently:
  **GAME_TEST=PASS**, SHA matches the staged/CI release image.
- Matched DOSBox-X 8086/CGA 384-rendered-frame timing:

  | Fixed cycles/ms | v0.20 | v0.21 |
  |---|---:|---:|
  | 240 | 41.111 s | **40.063 s** |
  | 500 | 20.032 s | **20.035 s** |

  No measured speed regression. The combat workloads are *not identical*
  (different bonus drops: 6 vs 5 enemy kills after 384 frames), so these
  are observed emulator elapsed times rather than exact cycle comparisons.

## Remaining limitations

A physical 4.77-MHz IBM XT and native Poisk-1 tape boot have not yet been
verified. EGA/VGA native color backends and Hercules native rendering remain
separate future tasks. Long manual play across all 35 stages and screenshots
of the corrected laser animation remain useful acceptance checks.
