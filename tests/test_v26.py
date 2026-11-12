"""v0.26 acceptance: arcade aircraft / unpredictable flight, checkerboard bomb and touch-only pickup."""
from pathlib import Path
import unittest,sys
R=Path(__file__).resolve().parents[1]
T=(R/'src/dos/tanks.S').read_text()
B=(R/'src/dos/bomber_v25.inc').read_text()
E=(R/'src/dos/enemy_pickups_v21.inc').read_text()
C=(R/'src/dos/coop_v24.inc').read_text()
A=(R/'src/dos/ally_v20.inc').read_text()
sys.path.insert(0,str(R/'tools'))
import build_cga_assets as art

class V26Regression(unittest.TestCase):
 def test_bomber_four_original_directional_sprites_not_an_oval(self):
  for name in ('plane_horizontal','plane_horizontal_left','plane_vertical','plane_vertical_down'):
   self.assertIn(name,art.SPRITES)
   self.assertEqual(len(art.pack_smooth(art.SPRITES[name])),480)
   self.assertIn('smooth_'+name,B)
  self.assertNotEqual(art.SPRITES['plane_horizontal'],art.SPRITES['plane_horizontal_left'])
  self.assertNotEqual(art.SPRITES['plane_vertical'],art.SPRITES['plane_vertical_down'])
  self.assertLess(sum(1 for row in art.SPRITES['plane_horizontal'] for c in row if c!='.'),160)
  self.assertIn('1', ''.join(art.SPRITES['plane_vertical']))  # canopy
 def test_bomber_randomized_four_routes_and_delay(self):
  roll=B.split('bomber26_roll:',1)[1].split('bonus26_touch:',1)[0]
  self.assertGreaterEqual(roll.count('call random_byte'),3)
  self.assertIn('and al,3',roll)
  self.assertIn('and al,127',roll)
  self.assertIn('bomber26_departure',roll)
  self.assertIn('call bomber26_roll',T.split('normal_play:',1)[1].split('normal_play_doctrine_ready:',1)[0])
  for step in ('sub byte ptr [bomber25_x],2','sub byte ptr [bomber25_y],2','add byte ptr [bomber25_x],2','add byte ptr [bomber25_y],2'):
   self.assertIn(step,B)
  self.assertIn('cmp al,[bomber26_departure]',B)
 def test_bombs_alternate_a_single_left_right_cell_behind_axis(self):
  wave=B.split('bomber25_wave:',1)[1].split('bomber25_wave_done:',1)[0]
  self.assertEqual(wave.count('call bomber25_impact'),1)
  self.assertIn('dec dh',wave)
  self.assertIn('inc dh',wave)
  self.assertIn('dec dl',wave)
  self.assertIn('inc dl',wave)
  self.assertNotIn('add dh,2',wave)
  self.assertNotIn('add dl,2',wave)
  self.assertIn('sub al,16',B)
  self.assertIn('add al,16',B)
  self.assertIn('sub al,12',B)
  self.assertIn('add al,12',B)
 def test_bomb_can_damage_brick_like_normal_shell_but_never_base(self):
  impact=B.split('bomber25_impact:',1)[1].split('bomber25_hit_enemies:',1)[0]
  self.assertLess(impact.index("cmp al,'B'"),impact.index('call damage_brick'))
  self.assertIn('call damage_brick',impact)
  self.assertIn('call draw_cell',impact)
  self.assertNotIn('mov byte ptr [bonus_active],0',impact)
 def test_all_collectors_use_one_visible_sprite_overlap(self):
  contact=B.split('bonus26_touch:',1)[1].split('bonus25_collected:',1)[0]
  for needle in ('add al,13','add al,2','add bl,12','add al,11','add bl,9','stc','clc'):
   self.assertIn(needle,contact)
  for body in (T.split('bonus_can_collect:',1)[1].split('bonus_pickup_done:',1)[0],C.split('coop24_pickup:',1)[1].split('coop24_pickup_done:',1)[0],E.split('enemy21_scan:',1)[1].split('enemy21_row_ok:',1)[0],A.split('ally20_pickup_auto:',1)[1].split('ally20_pickup_done:',1)[0]):
   self.assertIn('call bonus26_touch',body)
   self.assertNotIn('cmp al,24',body)
   self.assertNotIn('cmp al,18',body)
 def test_bonus_recolors_collector_no_overlay_artifact(self):
  self.assertIn('bonus26_flash_owner',B)
  assert 'mov [bonus26_flash_owner],al' in B
  assert 'call bonus25_collected' in E
  self.assertNotIn('smooth_shield_outline',B)
  for label in ('paint_player_color_ready:','paint_ally_color_ready:','paint_enemy_color_ready:'):
   self.assertIn(label,T)
  for phase in range(123,130):
   self.assertIn('mov byte ptr [test_phase],'+str(phase),T)
 def test_xt_dos_binary_ceiling(self):
  binary=R/'build/TANKS.COM'
  if binary.exists():self.assertLess(binary.stat().st_size,57344)

if __name__=='__main__':unittest.main()
