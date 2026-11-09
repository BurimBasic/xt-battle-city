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

build/tanks.o: src/dos/tanks.S src/dos/cga_assets.inc src/dos/tactics.inc | build
	$(AS) --32 -o $@ $<

build/TANKS.COM: build/tanks.o
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
