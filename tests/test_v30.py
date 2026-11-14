"""v0.30 exact pixel and all-projectile muzzle regressions.

The six hashes are computed from user-authored 115x20 PNG cropped at
x=3,17,52,66,83,98; y=4..15, 12x12, row-delimited with ASCII LF.
Not an AI-approximated sprite; white in PNG is transparent in-game.
"""
from pathlib import Path
import hashlib
import sys
import unittest

ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools'))
import build_cga_assets as a
from approved_art_v030 import ART, ORDER, directions, SOURCE_X, SOURCE_Y

R=(ROOT/'src/dos/v027_render.inc').read_text()
T=(ROOT/'src/dos/tanks.S').read_text()
Q=(ROOT/'src/dos/bonus_v23.inc').read_text()
ALLY=(ROOT/'src/dos/ally_marker_v21.inc').read_text()

HASHES={
 'player':'6e24cad5a4f18597ec7dfa24dcfc75d199ecc53cdc6fd673a8e3b01ed9e3e79e',
 'companion':'28b95a8d4319b1000a3e9942a35548ad8efa7e4c0563e3c49b1703a3978de500',
 'light':'d099c65f9f00b877f99b133f7b0ada0f1843a71ff2e640ad1f8c7393f5ecf691',
 'medium':'c67b6ec8354b0f0913f202cb3563dcb2c7a135c3810a5931a653ed4ad91d4f69',
 'assault':'e758b417c9d8cadc5bd7cd7fecf991eb00f2358e894dabe09d65356a41c6dea7',
 'heavy':'90102a525c653d77289fb8d8d1bf6f1d3e419f3e298d89cfda8a895a161e05b1',
}

class UserArtV30(unittest.TestCase):
 def test_exact_six_user_pixel_hashes_no_resizing(self):
  self.assertEqual(ORDER,('player','companion','light','medium','assault','heavy'))
  self.assertEqual(SOURCE_X,(3,17,52,66,83,98))
  self.assertEqual(SOURCE_Y,4)
  for name in ORDER:
   with self.subTest(name=name):
    rows=ART[name]
    self.assertEqual(len(rows),12)
    self.assertTrue(all(len(row)==12 and set(row)<=set('.123') for row in rows))
    digest=hashlib.sha256('\n'.join(rows).encode('ascii')).hexdigest()
    self.assertEqual(digest,HASHES[name])

 def test_all_four_rotations_are_exact_square_12x12(self):
  assets={'player':'player','light':'enemy','medium':'fast',
          'assault':'power','heavy':'armor'}
  suffixes=('up','right','down','left')
  for kind,atlas in assets.items():
   a0=directions(kind)
   for d,frame in zip(suffixes,a0):
    key='enemy' if atlas=='enemy' and d=='down' else f'{atlas}_{d}'
    self.assertEqual(a.SPRITES[key],frame,(kind,d))
    self.assertEqual(len(a.pack_smooth(frame)),480)
    self.assertTrue(all(row[:2]=='..' and row[-2:]=='..' for row in frame))
   self.assertEqual(a0[0],tuple('..'+r+'..' for r in ART[kind]))

 def test_ally_diff_is_only_four_magenta_pixels_after_rotation(self):
  p=ART['player']
  c=ART['companion']
  diff=[(x,y) for y in range(12) for x in range(12) if p[y][x]!=c[y][x]]
  self.assertEqual(diff,[(4,10),(5,10),(6,10),(7,10)])
  self.assertNotIn('2',''.join(p))
  self.assertEqual(len(a.SMOOTH_SPRITES),len(set(a.SMOOTH_SPRITES)))
  self.assertNotIn('ally_up',a.SMOOTH_SPRITES)
  self.assertIn('ally30_horizontal:',ALLY)
  self.assertIn('ally30_vertical:',ALLY)
  self.assertIn('add dl,6\n    add dh,10',ALLY)
  self.assertIn('add dl,3\n    add dh,4',ALLY)
  self.assertIn('add dl,12\n    add dh,4',ALLY)
  self.assertIn('mov cx,4',ALLY)

 def test_enemy_primary_spread_laser_and_pong_muzzle(self):
  primary=T.split('enemy_fire_smooth_init:',1)[1].split('enemy23_fire_not_laser:',1)[0]
  self.assertIn('call gun29_muzzle',primary)
  self.assertIn('mov [shot_px+bx],dl',primary)
  self.assertIn('mov [shot_py+bx],dh',primary)
  spread=Q.split('enemy23_burst:',1)[1].split('enemy23_burst_skip:',1)[0]
  self.assertIn('call gun29_muzzle',spread)
  self.assertIn('mov [shot_px+si],dl',spread)
  laser=Q.split('enemy23_laser:',1)[1].split('enemy23_laser_loop:',1)[0]
  self.assertIn('mov al,[shot_px+bx]',laser)
  self.assertIn('mov al,[shot_py+bx]',laser)
  pong=Q.split('pong23_origin_ready:',1)[1].split('/* Four diagonal directions',1)[0]
  self.assertIn('call gun29_muzzle',pong)

 def test_bomber_props_are_over_actual_both_engine_hubs(self):
  from approved_art_v029 import PLANE_RIGHT,plane_sprites
  self.assertEqual(PLANE_RIGHT[7][25],'3')
  self.assertEqual(PLANE_RIGHT[16][25],'3')
  # Generated UP master has gray horizontal blades on row 5.
  up=plane_sprites()[0]
  for x in (10,22):self.assertEqual(up[5][x],'3')
  block=R.split('wide27_propellers:',1)[1].split('.section .data',1)[0]
  for term in ('add dl,25','add dl,6','add dh,7','add dh,9',
               'add dh,18','add dh,5','add dl,9','add dl,10',
               'add dl,12','test byte ptr [game_tick],1'):
   self.assertIn(term,block)
  self.assertIn('wide30_vertical_up:',block)
  self.assertIn('wide30_horizontal_left:',block)

if __name__=='__main__':
 unittest.main()
