AS ?= as
LD ?= ld
PYTHON ?= python3

.PHONY: all clean test
all: build/XTINFO.COM

build:
	mkdir -p build

build/xtinfo.o: src/dos/xtinfo.S | build
	$(AS) --32 -o $@ $<

build/XTINFO.COM: build/xtinfo.o
	$(LD) -m elf_i386 -Ttext 0x100 --oformat binary -o $@ $<

test: all
	$(PYTHON) -m unittest discover -s tests -v
	$(PYTHON) tools/validate_map.py assets/maps/level01.map

clean:
	rm -rf build
