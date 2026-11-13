#!/usr/bin/env python3
"""Render an honest preview from the actual v0.27 CGA airplane source.
This is NOT a gameplay screenshot and must be labeled as an art preview.
No third-party image libraries, external image assets, or ROM graphics.
"""
import importlib.util
from pathlib import Path
import struct
import zlib

ROOT=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location("cga_assets",ROOT/"tools"/"build_cga_assets.py")
art=importlib.util.module_from_spec(spec)
spec.loader.exec_module(art)
rows=art.PLANE_V
assert len(rows)==12 and all(len(row)==16 for row in rows)
palette={".":(0,0,0),"0":(0,0,0),"1":(0,170,170),"2":(170,0,170),"3":(255,255,255)}
scale=8
pixels=["".join(c*2 for c in row) for row in rows for _ in (0,1)]
width,height=32*scale,24*scale
scanlines=[]
for source_row in pixels:
    px=b"".join(bytes(palette[c])*scale for c in source_row)
    for _ in range(scale):
        scanlines.append(b"\x00"+px)
def chunk(k,data):
    return struct.pack(">I",len(data))+k+data+struct.pack(">I",zlib.crc32(k+data)&0xffffffff)
png=(b"\x89PNG\r\n\x1a\n"+
     chunk(b"IHDR",struct.pack(">IIBBBBB",width,height,8,2,0,0,0))+
     chunk(b"IDAT",zlib.compress(b"".join(scanlines),9))+
     chunk(b"IEND",b""))
dest=ROOT/"docs"/"art"/"v027-airplane-sprite-preview.png"
dest.parent.mkdir(parents=True,exist_ok=True)
dest.write_bytes(png)
print("CGAV27_ART_PREVIEW",dest,len(png),width,height)
