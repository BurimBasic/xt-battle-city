#!/usr/bin/env python3
"""Faithful RGB-indexed 12x12 pixel previews; not emulator screenshots."""
from pathlib import Path
import struct,sys,zlib
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools'))
from approved_art_v030 import ART,ORDER
COL={'.':(0,0,0),'1':(0,170,170),'2':(170,0,170),'3':(170,170,170)}
def pngchunk(tag,b):
 return struct.pack('>I',len(b))+tag+b+struct.pack('>I',zlib.crc32(tag+b)&0xffffffff)
def write(rows,path,scale):
 raw=[]
 for row in rows:
  rgb=b''.join(bytes(COL[c])*scale for c in row)
  for _ in range(scale):raw.append(b'\0'+rgb)
 w,h=len(rows[0])*scale,len(rows)*scale
 png=(b'\x89PNG\r\n\x1a\n'
      +pngchunk(b'IHDR',struct.pack('>IIBBBBB',w,h,8,2,0,0,0))
      +pngchunk(b'IDAT',zlib.compress(b''.join(raw),9))
      +pngchunk(b'IEND',b''))
 path.parent.mkdir(parents=True,exist_ok=True)
 path.write_bytes(png)
 print('SOURCE_PIXELS',path,w,h,len(png))
rowset=tuple('....'.join(ART[n][y] for n in ORDER) for y in range(12))
write(rowset,ROOT/'docs/art/v030-user-six-12x12-native.png',1)
write(rowset,ROOT/'docs/art/v030-user-six-12x12-zoom.png',12)
