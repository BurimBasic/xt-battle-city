#!/usr/bin/env python3
"""Exact source-derived previews of approved v0.29 CGA assets; NOT game screenshots."""
from pathlib import Path
import importlib.util,struct,zlib
ROOT=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location("cga_assets",ROOT/"tools"/"build_cga_assets.py")
art=importlib.util.module_from_spec(spec)
spec.loader.exec_module(art)
palette={'.':(0,0,0),'0':(0,0,0),'1':(0,170,170),'2':(170,0,170),'3':(170,170,170)}
def chunk(k,b):
 return struct.pack(">I",len(b))+k+b+struct.pack(">I",zlib.crc32(k+b)&0xffffffff)
def write_png(rows,dest,scale=12):
 w,h=len(rows[0]),len(rows)
 assert all(len(x)==w and set(x)<=set('.0123') for x in rows)
 lines=[]
 for row in rows:
  b=b''.join(bytes(palette[c])*scale for c in row)
  for _ in range(scale):lines.append(b'\x00'+b)
 png=b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR',struct.pack('>IIBBBBB',w*scale,h*scale,8,2,0,0,0))+chunk(b'IDAT',zlib.compress(b''.join(lines),9))+chunk(b'IEND',b'')
 dest.parent.mkdir(parents=True,exist_ok=True);dest.write_bytes(png)
 print('APPROVED_CGA_SOURCE_ART',str(dest),w,h,len(png))
write_png(art.PLANE_H,ROOT/'docs/art/v029-airplane-sprite-preview.png')
player=art.SPRITES['player_right']
# Companion does not consume a duplicate smooth atlas: magenta bands
# are applied when it is rendered, with the same source dimensions.
companion=[list(row) for row in player]
for y in (3,9):
 for x in range(6,11):companion[y][x]='2'
companion=[''.join(row) for row in companion]
pair=tuple(a+'....'+b for a,b in zip(player,companion))
write_png(pair,ROOT/'docs/art/v029-player-companion-preview.png')
