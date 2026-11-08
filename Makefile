AS ?= as
LD ?= ld
PYTHON ?= python3

.PHONY: all clean test
all: build/XTINFO.COM build/TANKS.COM

build:
	mkdir -p build

build/xtinfo.o: src/dos/xtinfo.S | build
	$(AS) --32 -o $@ $<

build/XTINFO.COM: build/xtinfo.o
	$(LD) -m elf_i386 -Ttext 0x100 --oformat binary -o $@ $<

build/tanks.o: src/dos/tanks.S src/dos/cga_assets.inc | build
	$(AS) --32 -o $@ $<

build/TANKS.COM: build/tanks.o
	$(LD) -m elf_i386 -Ttext 0x100 --oformat binary -o $@ $<

assets:
	$(PYTHON) tools/build_cga_assets.py

test: all
	$(PYTHON) -m unittest discover -s tests -v
	@for f in assets/maps/level*.map; do $(PYTHON) tools/validate_map.py "$$f" || exit 1; done
	$(PYTHON) tools/build_cga_assets.py --check
	$(PYTHON) tools/check_8086.py build/tanks.o
	@test "$$(wc -c < build/TANKS.COM)" -lt 16384

clean:
	rm -rf build
