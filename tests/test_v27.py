"""v0.27 executable acceptance: original doubled 1942 plane, stage flights, gun recoil, AUTO pickup."""
from pathlib import Path
import unittest,sys
ROOT=Path(__file__).resolve().parents[1]
T=(ROOT/'src/dos/tanks.S').read_text()
B=(ROOT/'src/dos/bomber_v25.inc').read_text()
R=(ROOT/'src/dos/v027_render.inc').read_text()
C=(ROOT/'src/dos/coop_v24.inc').read_text()
A=(ROOT/'src/dos/tactics.inc').read_text()
sys.path.insert(0,str(ROOT/'tools'))
import build_cga_assets as art
class V27Tests(unittest.TestCase):
 def test_original_1942_twin_engine_shape_is_twice_tank(self):
  for name in art.WIDE_PLANES:
   self.assertIn(name,art.SPRITES)
   data=art.pack_wide_plane(art.SPRITES[name])
   self.assertEqual(len(data),384)
  self.assertEqual(len(art.PLANE_V),24)
  self.assertEqual(len(art.PLANE_V[0]),32)
  self.assertIn('wide27_draw:',R)
  self.assertIn('mov bp,24',R)
  self.assertIn('call wide27_dirty',R)  # optimized one-pass rectangle
  self.assertIn('mov cx,4',R)  # 4 x 16-bit words per row
 def test_two_animated_propellers(self):
  self.assertIn('wide27_propellers:',R)
  self.assertGreaterEqual(R.split('wide27_propellers:',1)[1].count('call gun27_pixel'),4)
  self.assertIn('test byte ptr [game_tick],1',R)
 def test_stage_limit_1_2_3(self):
  reset=B.split('bomber25_reset:',1)[1].split('bomber26_roll:',1)[0]
  self.assertIn('cmp byte ptr [stage],6',reset)
  self.assertIn('cmp byte ptr [stage],15',reset)
  self.assertIn('bomber27_limit',reset)
  self.assertIn('inc byte ptr [bomber27_passes]',B)
  self.assertIn('bomber27_wait',B)
  self.assertIn('cmp al,[bomber27_limit]',B)
 def test_tank_gun_recoil_steps_and_muzzle(self):
  self.assertIn('gun27_draw:',R)
  self.assertIn('gun27_pixel:',R)
  self.assertIn('gun27_tick:',R)
  self.assertIn('mov byte ptr [gun27_p1],4',T)
  self.assertIn('mov byte ptr [gun27_p2],4',C)
  self.assertIn('call gun27_draw',T)
  self.assertIn('call gun27_inward',R)
 def test_hud_author_and_version(self):
  self.assertIn('brand_basic_glyphs: .word hud_b_char, hud_u_char, hud_r_char, hud_i_char, hud_m_char',T)
  self.assertIn('hud_r_char',art.generate_hud().__str__())
  self.assertIn('brand_version_glyphs: .word hud_v_char, hud_digit_0, hud_dot_char, hud_digit_2, hud_digit_8',T)
 def test_auto_high_value_pickups_respect_base_guard(self):
  x=A.split('tactical_defense_orders:',1)[1].split('tactical27_normal_orders:',1)[0]
  self.assertIn('cmp al,2',x) # wipe enemies
  self.assertIn('cmp al,6',x) # laser
  self.assertIn('cmp al,5',x) # heart
  self.assertIn('call strategy_bonus_heading',x) # base threat veto and connectivity
  self.assertIn('jnc tactical27_normal_orders',x)
 def test_binary_size(self):
  f=ROOT/'build/TANKS.COM'
  if f.exists():self.assertLess(f.stat().st_size,57344)
if __name__=='__main__':unittest.main()
