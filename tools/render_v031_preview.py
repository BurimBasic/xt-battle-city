#!/usr/bin/env python3
"""v0.31 exact source-derived 100/200/300/400 CGA blue score popups.

Pixel runs are copied from image(20261114-142703).png; source masks are
stored in src/dos/score_v31.inc. This is art preview, NOT a game screenshot.
"""
from pathlib import Path
import re,struct,zlib
ROOT=Path(__file__).resolve().parents[1]
src=(ROOT/'src/dos/score_v31.inc').read_text()
body=src.split('score31_masks:',1)[1].split('.section .text',1)[0]
groups=[]
for line in body.splitlines():
 m=re.search(r'\.word\s+(0x[\da-fA-F]+),(0x[\da-fA-F]+),(0x[\da-fA-F]+)',line)
 if m:groups.append([int(x,16) for x in m.groups()])
assert len(groups)==4
rows=[]
for y in range(3):
 row=[]
 for i,group in enumerate(groups):
  if i:row.extend([0]*4)
  row.extend([1 if group[y]&(1<<x) else 0 for x in range(11)])
 rows.append(row)
def chunk(typ,data):return struct.pack('>I',len(data))+typ+data+struct.pack('>I',zlib.crc32(typ+data)&0xffffffff)
def write(scale,path):
 h=len(rows)*scale;w=len(rows[0])*scale
 scan=[]
 for row in rows:
  pixels=b''.join(bytes((0,170,170) if bit else (0,0,0))*scale for bit in row)
  for _ in range(scale):scan.append(b'\0'+pixels)
 png=b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR',struct.pack('>IIBBBBB',w,h,8,2,0,0,0))+chunk(b'IDAT',zlib.compress(b''.join(scan),9))+chunk(b'IEND',b'')
 path.parent.mkdir(parents=True,exist_ok=True)
 path.write_bytes(png)
 print('SCORE_CGA_PIXEL_PREVIEW',path,w,h)
write(1,ROOT/'docs/art/v031-score-100-400-1to1.png')
write(8,ROOT/'docs/art/v031-score-100-400-zoom.png')
