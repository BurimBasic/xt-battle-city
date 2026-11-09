# XT Battle City v0.14 — CGA Tactical Objectives

New independent attacking and defending objectives. The automatic defender
seeks bonuses via a cached whole-map route, reacts to nearby HQ threats, and
fires at aligned opponents inside an effective engagement range. Enemy tanks
can again be damaged or destroyed by other enemies' stray shots, without
awarding player points. The interceptor tries to deny exposed power-ups and
uses last disclosed player position. Base breachers relocate if a teammate
blocks the firing lane.

To preserve the 48 KiB release limit, all 35 original maps are stored as
4-bit material codes and unpacked to 256-byte RAM grids when a stage loads.
The executable is 48,282 bytes, assembled for PC 8086/8088 CGA 320x200.

Launch TANKS.COM in MS-DOS or DOSBox-X CGA; TANKS.COM /TEST performs embedded
real-mode regressions. Arrow keys/WASD take manual control; TAB toggles AUTO.
All artwork/assets in this project are original.

The automatic tests do not prove long-horizon chess-like planning or physical
4.77 MHz hardware speed. Extended human game acceptance still required.
