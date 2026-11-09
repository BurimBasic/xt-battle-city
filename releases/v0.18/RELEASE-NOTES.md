# XT Battle City v0.18 — Retro CGA Art & HUD Polish

## Deployed on SLOW1

The executable is installed directly at `C:\XT-Battle-City\run\TANKS.COM`. Launch it via `C:\XT-Battle-City\RUN-CGA.cmd`, after closing any old DOSBox-X window. No end-user ZIP download is required. The previous **v0.17** is preserved as `C:\XT-Battle-City\run\TANKS-v017-backup-20261110-010559.COM`.

## Graphics and interface

1. Redrew the 16×12 water tile as two sparse, soft wave bands with dark separation (fewer busy sawtooth pixels).
2. Redrew ice as clean cyan with white crystalline facets; the external white plate border remains.
3. The ambiguous cyan round forest clumps were *trees*, not bonus effects. They are now **two recognizable evergreen silhouettes**, with narrow trunks and negative space.
4. Protected player flashes its outer shield every four ticks while its tank body remains visible. The ally's original distinctive shield silhouette remains.
5. Reduced the **right edge only** of every bonus square from x13 to x12 for balanced icon spacing. When `bonus_timer <= 27` (about the final 1.5 seconds), only the white frame flashes; the interior bonus icon stays on screen.
6. Centered the four-glyph **AUTO** indicator using a two-glyph blank margin on each side.
7. Drew a small white-on-black signature at the bottom right: **TANKS / ©1982 / BASIC / V0.18**. The release number is changed in one five-glyph pointer table.
8. Preserved all 11 power-ups, laser / independent ally / homing mechanics, original collision geometry, all levels and AUTO combat strategy.

The imagery is *original* hand-authored four-color CGA pixel art. The 1982 date is a requested project display signature; it does not identify the creation year of Namco's 1985 Battle City.

## Acceptance

- GitHub Actions: **87 Python tests**, 35 stage maps, regenerated assets, ISA audit for true 8086, **55,992 byte** shipping image (<57,344-byte ceiling).
- Actual DOSBox-X SLOW1: built-in `/TEST` **PASS, all 74 phases**; new 72–74 check AUTO centering, inverted brand and bonus-frame packing.
- 2048-tick real-mode diagnostic run: stage 1 ends **STAGE CLEAR**, 20/20 enemies destroyed and HQ saved (approximately tick 1024).
- Re-test of the *installed* binary `C:\XT-Battle-City\run\TANKS.COM`: `GAME_TEST=PASS`.
- Installed SHA-256: `1F93A6739AD2E3C4E2A14DEFA3C846A1320F72D30C6D69EFF56876F34AF29817`.
- The exact installed binary is stored at `dist/TANKS.COM` in GitHub.

Real 4.77-MHz XT/8088 FPS, native Poisk-1 hardware and long runs across all 35 levels have **not** been certified.
