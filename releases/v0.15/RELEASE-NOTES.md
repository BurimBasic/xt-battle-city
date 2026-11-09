# XT Battle City v0.15 — Defender & Anti-Stall (CGA, 8086)

Installed on **SLOW1** as `C:\XT-Battle-City\run\TANKS.COM`. Launch via `C:\XT-Battle-City\RUN-CGA.cmd`; no ZIP download needed.

Changes:
- Defender fires at tread/edge contacts, protects HQ more actively and tries both legal evasions.
- Enemy squad selects one of four tactical doctrines per stage; its route probes avoid occupied ally hulls and repeated jams provoke a yield.
- A collected bonus flashes its own small CGA icon on the sidebar (star, helmet, grenade, shovel, clock or extra life).
- Forward sentry prevents indefinite defender inactivity while distant enemies remain out of range.

Acceptance: 68 Python tests; GNU 8086 ISA audit; 35-map and graphics tests; binary under 48 KiB; actual DOSBox-X (SLOW1) /TEST PASS for built-in phases 1–58. Longer qualitative gameplay and true 8088 clock performance remain unverified.

The previous installed version is preserved on SLOW1 for rollback. All game sources remain in this repository.
