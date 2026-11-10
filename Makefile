AS ?= as
LD ?= ld
PYTHON ?= python3

.PHONY: all clean test assets
all: build/XTINFO.COM build/TANKS.COM

build:
	mkdir -p build

build/xtinfo.o: src/dos/xtinfo.S | build
	$(AS) --32 -o $@ $<

build/XTINFO.COM: build/xtinfo.o
	$(LD) -m elf_i386 -Ttext 0x100 --oformat binary -o $@ $<

build/tanks.o: src/dos/tanks.S src/dos/cga_assets.inc src/dos/tactics.inc src/dos/strategy_v13.inc src/dos/bonuses_v17.inc src/dos/ally_v20.inc src/dos/transitions_v20.inc | build
	$(AS) --32 -o $@ $<

build/TANKS.COM: build/tanks.o
	$(LD) -m elf_i386 -Ttext 0x100 --oformat binary -o $@ $<

# Debug-only instrumented build; the shipped TANKS.COM excludes trace code.
build/tanks-trace.o: src/dos/tanks.S src/dos/cga_assets.inc src/dos/tactics.inc src/dos/strategy_v13.inc src/dos/bonuses_v17.inc src/dos/ally_v20.inc src/dos/transitions_v20.inc | build
	$(AS) --32 --defsym TRACE_BUILD=1 -o $@ $<

build/TANKS-TRACE.COM: build/tanks-trace.o
	$(LD) -m elf_i386 -Ttext 0x100 --oformat binary -o $@ $<

# CI-only no-clock 384 full-frame benchmark, never shipped to users.
build/tanks-perf.o: src/dos/tanks.S src/dos/cga_assets.inc src/dos/tactics.inc src/dos/strategy_v13.inc src/dos/bonuses_v17.inc src/dos/ally_v20.inc src/dos/transitions_v20.inc | build
	$(AS) --32 --defsym TRACE_BUILD=1 --defsym PERF_BUILD=1 -o $@ $<

build/TANKS-PERF.COM: build/tanks-perf.o
	$(LD) -m elf_i386 -Ttext 0x100 --oformat binary -o $@ $<

assets:
	$(PYTHON) tools/build_cga_assets.py

test: all
	$(PYTHON) -m unittest discover -s tests -v
	$(PYTHON) tools/validate_map.py assets/maps/level*.map
	$(PYTHON) tools/build_cga_assets.py --check
	$(PYTHON) tools/check_8086.py build/tanks.o
	@test "$$(wc -c < build/TANKS.COM)" -lt 57344

clean:
	rm -rf build
