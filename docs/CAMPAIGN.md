# Campaign: 35 original maps

Nine early stages are retained unchanged. Stages 10–35 add original authored
patterns (not copied or extracted from NES ROMs). Each uses 13×13 text tiles
and the same 8086 game simulation; generated level tables add under 5KB to the
DOS binary.

Maps: `E` enemy spawn, `P` player, `B` headquarters, `#` brick, `T`
steel, `~` water, `F` forest, `I` ice. New maps preserve spawn points,
player/base wall, and at least one walkable two-cell meandering central lane.
Late stages include more obstacles and a tougher enemy class mix.

### How to inspect any stage
While **paused (P)**, or on the stage-clear/game-over screen, press
**Page Up** / **Page Down** to start the following/previous level. This is a
QA convenience, not classic Battle City gameplay. Entering a new level keeps
the campaign score/lives but resets the battlefield.
Completing stage 35 wraps the campaign to stage 1.

`make test` validates all maps and regenerated ASM tables.
`TANKS.COM /TEST` checks stage 35 and both navigation wrap directions.
DOSBox-X checks do **not** certify 8088 cycle-accurate speed.
