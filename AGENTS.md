# AGENTS.md — XT Battle City development and release rules

## Hard platform constraints

- Shipping DOS CGA executable is **8086/8088 real-mode** code; no 186/286 instructions, near conditional jumps, FPU, 32-bit runtime operations or browser technology. Always run `make assets && make clean all test` and the 8086 ISA audit before shipping.
- Current DOS .COM image cap: **strictly less than 57,344 bytes (56 KiB)**. Keep `program_end + 0x0fff` under 0x10000 so the intended 4 KiB stack is not lost. Do not silently increase the limit or turn the DOS game into a 32-bit binary.
- The Poisk-1 native/tape-boot target **cannot depend on files, disks, config saves, CMOS writes or an initialized DOS filesystem**. Temporary values such as palette, companion reserve and stage state live in RAM. A full power cycle resets them.
- Native EGA 16-color, VGA 256-color, Hercules and Poisk-1 video backends are not implemented. CGA mode-4 running under an EGA/VGA emulator does not constitute native driver support.

## Mandatory performance gate — protect v0.19 baseline

v0.19 is the accepted speed baseline on **SLOW1** at `C:\XT-Battle-City`. Do not sacrifice it without measured evidence and an explicit tradeoff.

1. After an edit to the renderer, collision engine, navigation, projectile system, animation or HUD, build `TANKS-PERF.COM` (384 deterministic ticks, **every frame rendered**) with the `PERF_BUILD=1` harness.
2. On SLOW1 DOSBox-X with the **8086** CPU, **CGA**, fixed **240 cycles/ms**, compare the baseline v0.19 and candidate from separate folders with identical `PERF.COM /TRACE` commands. Prefer alternating ABBA runs and report median times, matching final states and kills. Record the DOSBox-X version and host if those change.
3. Previously measured v0.19: **40.051 seconds** for 384 full frames at 240 cycles/ms, **20.033 seconds** at 500 cycles/ms; v0.18 was 56.123/28.088 s. These were one-pair historical measurements, **not proof of real 4.77 MHz 8088 throughput**.
4. Default acceptance: **no >5% regression versus an in-session matched baseline** on the 384-frame workload (use the previous measurement only as a reference); target near 40s at 240 cycles/ms and near 20s at 500 cycles/ms. If slower, profile the hot path, reduce per-frame work and repeat before release.
5. Also run a 2048-tick diagnostic trace and verify stage-one HQ survives, enemy count reaches 20/20, and `STAGE CLEAR` occurs. A first-stage win is a smoke test, not proof for all 35 maps.
6. Stage intros/exits may be visually elaborate **only at boundaries** and must have bounded, short duration. Never animate full-screen effects on every gameplay tick. Gameplay uses BIOS clock ticks, not a speed-dependent busy loop.

## Implementation and deployment workflow

- Prefer straight-line 16-bit tables, compact state machines, dirty tiles and limited palettes over extra allocations and global redraws. Keep HUD refreshes scoped to actual changes where possible.
- Add regression tests for new player actions, reserve/life conservation, hostile/ally collisions, pickup ownership, bonus UI state, laser cleanup and 8086 branch ranges.
- Run GitHub Actions to PASS and **then** run `TANKS.COM /TEST` on SLOW1 DOSBox-X. Inspect actual exit codes, including the `test_phase` failure code; static tests alone do not certify gameplay.
- Do not replace `C:\XT-Battle-City\run\TANKS.COM` before success. Deploy the exact tested binary atomically via a staged file and backup, compare SHA256 before and after, then re-test **installed** COM.
- The user starts the game with `C:\XT-Battle-City\RUN-CGA.cmd`. Do **not** ask the user to download/extract a ZIP; place the executable on SLOW1.
- Commit source, tests, release notes and the exact verified `dist/TANKS.COM` to GitHub; merge into `main` only after passing CI. Keep automatic rollback artifacts and honest limits in the release notes.
