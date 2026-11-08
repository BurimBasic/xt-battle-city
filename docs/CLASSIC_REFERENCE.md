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
| Stage layouts | 35 original | 3 **original** layouts; no source-map copying |
| Brick / steel / water | Yes | v0.2 basic whole-cell rules; *partial brick damage* missing |
| Two-player cooperative | Yes | Not implemented |
| Player movement / collision | Continuous pixel motion | v0.2 tile-step; **major gap** |
| Enemy types and 4-hit armor | Four classes | v0.3: basic / faster / high-fire-rate / armored (4 HP), distinct art and 100–400 points; tuning pending |
| Power-ups | Six classic | Not implemented |
| Forest and ice | Yes | Not implemented |
| Sound | NES effects/music | Not implemented, PC Speaker/optional AdLib planned |
| Classic score screen | Per-tank tally | v0.3 score only, no stage breakdown |
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
