# v0.11 Tactical Director — deterministic, 8088-compatible

The game enters **AUTO** demonstration immediately. The player tank is computer
controlled, and all four opponent slots use coordinated roles. This is a
lightweight *tactical state machine* designed for 4.77MHz 8088, **not** a
chess engine or a guarantee of unbeatable intelligence.

## Player computer pilot

* Re-evaluates threats every four 18.2Hz ticks (~4.55 decisions/second).
* Prioritizes the active enemy closest to HQ; aims vertically or horizontally
  when aligned; otherwise travels to a firing lane.
* Projects hostile shots up to 48 pixels and chooses a perpendicular dodge.
* Checks the rectangle ahead before moving; chips brick cover with shells and
  takes a detour if the planned lane is blocked.
* Defends the central HQ approaches rather than chasing scouts indefinitely.
  Avoids firing **down into its own HQ** at close range.
* `Tab` toggles AUTO/MAN. A real arrow, WASD or Space key-press automatically
  transfers control to the human; `Tab` activates AI again. `Esc`, `R`, `P`,
  `M`, `C` keep their existing bindings.
* The four-character AUTO/MAN indicator is shown at the foot of the HUD.
* If left in AUTO after a win or loss, the result remains visible about four
  seconds; then the computer advances to the next stage or restarts the demo.

## Enemy squad cooperation

Four different roles are assigned by active slot:
1. **HQ raider** — commits to central HQ approach.
2. **Left flanker** — approaches left flank, or 32px left of the last
   player position disclosed by firing.
3. **Right flanker** — analogous right-side pincer.
4. **Interceptor** — presses towards the player's location.

Every player shot updates the shared last-known-position alert, which expires
at 96 ticks. Enemies choose a new heading every 32 ticks, on obstruction, or
when evading an approaching player shell. If close to an aligned firing lane,
they briefly halt to attempt an ambush. Before shooting, each tank checks the
next 56px for friendly tanks and may withhold fire to avoid blocking the team.
Friendly-fire collision is still physically supported when a teammate crosses
an already-flying shell.

## Engineering / limitations

* AI decisions are all integer, no FPU or 286+ opcodes; four enemies max.
* No full map-wide A*, minimax, deep search, or costly memory allocation. The
  goals and reactions are cheap enough to profile on a true 8088 emulator.
* This is the **first tactical baseline**, not the final chess-like strategy:
  comprehensive line-of-sight, robust multi-route pathfinding, trap planning,
  coordinated timing, and adaptive difficulty remain later development tasks.
* CI's 8086 prefix audit + DOSBox-X `/TEST` smoke exercise gameplay and several
  tactical scenarios, but **do not certify smooth 4.77MHz hardware timing**.
* Real multi-minute demo observations and player evaluation are required before
  claiming the AI is consistently capable or fair.

## v0.12 bounded lookahead (six pixels)

On each strategic decision an enemy samples its four headings using the real
12x10-pixel collision hull, six pixels into the future. For headings with
clearance the score is Manhattan distance to role waypoint, with a small
inertia bias and reversal penalty; the best candidate is selected. A blocked
emergency dodge falls back to ordinary planning. Ambush aim is calculated
against the player's actual coordinates (the flank waypoint remains only
for navigation). This is a tiny local planner rather than full-path A*.

The planner never runs every frame and has a strict per-decision upper bound:
4 candidates x 6 step/probe calls. CI verifies that DOS /TEST reaches
blocked and free lookahead corridors. Benchmark on 86Box 8088/4.77MHz
before claiming stable hardware speed.
