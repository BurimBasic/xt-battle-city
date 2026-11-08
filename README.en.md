# XT Battle City (English)

An **original** open-source top-down tank arcade inspired by the genre popularized by Battle City. It targets a stock IBM PC/XT 8088 at 4.77 MHz, as well as the Soviet **Poisk-1** at approximately 5 MHz, including early 96 KB usable-memory configurations.

Planned video backends: CGA (320×200, 4 colors), EGA (320×200, 16 colors), VGA (320×200, 256 colors), Hercules (720×348, monochrome), and a dedicated Poisk-1 backend because its graphics hardware is not fully IBM CGA compatible. PC Speaker is the default; OPL2/AdLib is optional and detected where physically available.

The core game, native Poisk-1 cassette loader and playable binary are **not yet implemented**. The project currently includes architecture documents, test plans, a level-map validator and a tiny DOS hardware diagnostic (`XTINFO.COM`). See [Russian README](README.md) for the full plan and build steps. No copyrighted Battle City assets or ROMs are included.

License: MIT for source code. New artwork/music will be original with explicit licenses.
