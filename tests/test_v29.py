"""v0.29 acceptance: approved CGA source sprites, ally bands, muzzle origins.

These source tests complement the REAL DOS /TEST, 2048-tick /TRACE and
384-frame ABBA performance gate. Never consider source-only checks sufficient.
"""
import sys
import unittest
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools'))
import build_cga_assets as a
from approved_art_v029 import PLAYER_RIGHT,PLANE_RIGHT,player_sprites,plane_sprites
T=(ROOT/'src/dos/tanks.S').read_text()
R=(ROOT/'src/dos/v027_render.inc').read_text()
COOP=(ROOT/'src/dos/coop_v24.inc').read_text()
EXTRA=(ROOT/'src/dos/bonuses_v17.inc').read_text()
QUAD=(ROOT/'src/dos/bonus_v23.inc').read_text()
ALLY=(ROOT/'src/dos/ally_marker_v21.inc').read_text()

class ApprovedArtworkV29(unittest.TestCase):
 def test_approved_16x12_player_must_never_look_enemy_pink(self):
  self.assertEqual((len(PLAYER_RIGHT),len(PLAYER_RIGHT[0])),(12,16))
  self.assertNotIn('2',''.join(PLAYER_RIGHT))
  for i,d in enumerate(('up','right','down','left')):
   self.assertEqual(a.SPRITES[f'player_{d}'],player_sprites()[i])
   self.assertEqual(len(a.pack_smooth(a.SPRITES[f'player_{d}'])),480)

 def test_approved_native_plane_is_one_master_with_four_rotations(self):
  self.assertEqual((len(PLANE_RIGHT),len(PLANE_RIGHT[0])),(24,32))
  self.assertTrue({'1','2','3'}<=set(''.join(PLANE_RIGHT)))
  for i,dir_name in enumerate(('plane_vertical','plane_horizontal',
                                'plane_vertical_down','plane_horizontal_left')):
   self.assertEqual(a.SPRITES[dir_name],plane_sprites()[i])
   self.assertEqual(len(a.pack_wide_plane(a.SPRITES[dir_name])),384)

 def test_companion_two_pink_stripes_no_second_1920b_atlas(self):
  self.assertIn('ally29_next_stripe:',ALLY)
  self.assertIn('mov bl,2',ALLY)
  self.assertIn('mov cx,5',ALLY)
  self.assertIn('cmp si,2',ALLY)
  self.assertIn('call gun27_pixel',ALLY)
  self.assertNotIn('ally_up',a.SMOOTH_SPRITES)
  self.assertIn('call ally21_draw_mark',T)

 def test_muzzle_spawn_applies_to_all_shot_types(self):
  self.assertIn('gun29_muzzle:',R)
  self.assertIn('sub dh,7',R)
  self.assertIn('add dl,8',R)
  self.assertIn('add dh,6',R)
  self.assertIn('sub dl,9',R)
  self.assertIn('call gun29_muzzle',T)
  self.assertEqual(EXTRA.count('call gun29_muzzle'),2)
  self.assertIn('call gun29_muzzle',QUAD)
  self.assertIn('mov al,[bullet_px]\n    mov [laser_start_x],al',EXTRA)

 def test_recoil_and_propellers_visible_correctly(self):
  self.assertIn('mov byte ptr [gun27_p1],5',T)
  self.assertEqual(COOP.count('mov byte ptr [gun27_p2],5'),2)
  self.assertIn('cmp byte ptr [gun27_phase],3\n    jb gun27_done',R)
  self.assertIn('add dl,15\n    add dh,6',R)
  self.assertIn('add dl,29',R)
  self.assertIn('add dh,9',R)

if __name__=='__main__':unittest.main()
