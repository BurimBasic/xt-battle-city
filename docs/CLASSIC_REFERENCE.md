# Battle City reference / fidelity tracking

Goal: recreate the *rules and feel* of Namco's 1985 Battle City using our own source, maps, illustrations and sound. Never bundle a commercial ROM, copyrighted stage dumps, music or sprite sheets. Track exact reproduction of gameplay **separately** from real 8088 performance and Poisk-1 compatibility.

## Reference rules (NES/Famicom 1985)

- Top-down play area of 13 × 13 major tiles, player protects a headquarters at the bottom.
- Three top spawn positions, at most four enemy tanks simultaneously in the original NES game, 20 total enemies for each stage, 35 original stages.
- Brick wall takes damage from shots; steel is normally resistant, while terrain also includes water, forest, ice and other special tiles.
- Base shot ends play immediately; player loses a life if hit; classic single-player starts with three lives.
- Four enemy types (including faster and armored) and six classic power-ups: star, extra life, helmet, shovel, clock and grenade. Two-player cooperative play.

References (independent descriptions):
- https://www.mobygames.com/game/8277/battle-city/
- https://strategywiki.org/wiki/Battle_City
- https://strategywiki.org/wiki/Battle_City/Gameplay

## Progress grid

| Feature | Classic reference | XT Battle City status |
|---|---|---|
| Defend HQ / lose when destroyed | Yes | v0.2 CGA: implemented |
| Player lives | 3 | v0.2 CGA: implemented; respawn shield basic |
| 20 enemies per stage | Yes | v0.2 CGA: implemented |
| Concurrent enemies | Up to 4 | v0.3 CGA: up to 4; performance not yet profiled on 8088 |
| Enemy AI and enemy fire | Yes | v0.3 basic path selection and single projectiles |
| Stage layouts | 35 original | 9 **original** layouts; no source-map copying |
| Brick / steel / water | Yes | v0.5: separate 4-bit wall mask with directional half-cell removal; pixel collision is pending |
| Two-player cooperative | Yes | Not implemented |
| Player movement / collision | Continuous pixel motion | v0.2 tile-step; **major gap** |
| Enemy types and 4-hit armor | Four classes | v0.3: basic / faster / high-fire-rate / armored (4 HP), distinct art and 100–400 points; tuning pending |
| Power-ups | Six classic | v0.5: all six item effects; drops and durations are provisional, not NES timing-accurate |
| Forest and ice | Yes | v0.5: original sprites, passable forest and short ice auto-slide; true ice physics pending |
| Sound | NES effects/music | v0.5: original PC Speaker short beeps + mute; AdLib OPL2 pending |
| Classic score screen | Per-tank tally on separate results screen | v0.5: per-type kill tally on stage victory, game-over score remains compact |
| Poisk-1 base configuration | Outside NES target | Separate native loader / video / keyboard not yet implemented |

## Work order toward gameplay fidelity

1. Move player/tanks **by sub-tile pixels** in a fixed game loop, with direct keyboard state (no reliance on typematic repeat).
2. Split brick tiles into damageable quadrants; implement bullet-to-bullet collisions and precise tanks/shell hitboxes.
3. Tune class-specific speed/fire/armor to reference timings, test 8088 budget and attack balance.
4. Two-player cooperative mode, shared HQ defense, friendly fire rules.
5. Add forest/ice overlays, six power-ups and temporary effects.
6. Develop 35 **new** levels inspired by progressive challenge, plus builder/selector; not copied NES map dumps.
7. Sound and proper PC Speaker/AdLib fallback, intro/inter-stage score panels, tune gameplay timing using measurements.
8. Complete EGA/VGA/Hercules, native Poisk-1 and physical hardware testing.

All claims about equivalence to the original need reproduction tests (reference recordings/measurements) instead of assumption. All test reports must state `DOSBox-X / 86Box / MAME / physical hardware` explicitly.

## v0.4 CGA presentation compared with original NES

Classic Namco Battle City shows 20 enemy tank marks on the right, 1P/2P extra lives and a flag with the current stage. The action view does **not** have a bottom help strip or a running score label. After the stage the score is shown on a results screen.

CGA v0.5 retains **original project-made** 8×8 monochrome HUD glyphs on the white right sidebar (20 enemies, `1P`, spare lives, stage flag). Game Over displays a compact center overlay; Stage Clear now displays a separate tally of kills by four enemy classes and the cumulative score. It is still not a pixel-identical NES port: wall hitboxes and grid-step movement differ significantly. The CGA layout is adapted to 320×200 with four colors and 16×12 cells.

Reference manuals/reports:
- https://usermanual.wiki/Document/UserManual.2090753506.pdf
- https://www.cs.columbia.edu/~sedwards/classes/2011/4840/reports/Battle-City.pdf
