"""v0.25 playable DOS 8086 airplane, three-life co-op and pickup feedback gates."""
from pathlib import Path
import sys,unittest
R=Path(__file__).resolve().parents[1]
T=(R/'src/dos/tanks.S').read_text()
B=(R/'src/dos/bomber_v25.inc').read_text()
C=(R/'src/dos/coop_v24.inc').read_text()
P=(R/'src/dos/bonus_v23.inc').read_text()
E=(R/'src/dos/enemy_pickups_v21.inc').read_text()
sys.path.insert(0,str(R/'tools'))
import build_cga_assets as a

class Release25(unittest.TestCase):
 def test_two_independent_three_lives_and_respawn_base(self):
  self.assertIn('mov byte ptr [coop_lives],3',C)
  self.assertIn('mov byte ptr [lives],3',C)
  hit=C.split('coop25_hit_p2:',1)[1].split('.section .data',1)[0]
  for text in ('dec byte ptr [coop_lives]','call coop25_try_respawn'):
   self.assertIn(text,hit)
  for text in ('call ally17_spawn','mov word ptr [ally_ticks],0x7fff','mov byte ptr [coop25_respawn_pending],1'):
   self.assertIn(text,C)
  self.assertIn('call coop25_hit_p2',T)
  self.assertIn('call coop25_hit_p2',P)
  for phase in (110,111,119,120):self.assertIn(f'mov byte ptr [test_phase],{phase}',T)
 def test_no_duplicate_coop_label_in_bonus_row_and_bounded_timer(self):
  h=T.split('draw_bonus_indicator:',1)[1].split('draw_mode_indicator:',1)[0]
  row=h.split('bonus24_coop_hud:',1)[1].split('bonus24_hud_end:',1)[0]
  self.assertNotIn('hud_c_char',row)
  self.assertIn('mov si,offset hud_blank_icon',row)
  self.assertIn('cmp byte ptr [coop_mode],0',h)
  self.assertIn('bonus25_timer_flash:',h)
  self.assertIn('mov ax,[ally_ticks]',h)
  self.assertIn('tactical_coop_glyphs:',T)
  self.assertIn('mov byte ptr [test_phase],112',T)
 def test_bonus_never_shot_away_and_pickup_flash(self):
  self.assertIn('mov byte ptr [bonus_timer],220',T)
  self.assertIn('call bonus25_collected',T)
  self.assertIn('call bonus25_collected',C)
  self.assertIn('call bonus25_collected',E)
  self.assertIn('bonus25_flash_ticks: .byte 0',B)
  self.assertIn('call bomber25_paint',T)
  self.assertIn('call bomber25_mark_old',T)
  self.assertIn('smooth_shield_outline',B)
  for phase in (116,118,122):self.assertIn(f'mov byte ptr [test_phase],{phase}',T)
  for section in (T.split('advance_bullet_smooth:',1)[1].split('update_enemy_shots_smooth:',1)[0],B.split('bomber25_impact:',1)[1].split('bomber25_hit_enemies:',1)[0]):
   self.assertNotIn('mov byte ptr [bonus_active],0',section)
 def test_one_aircraft_per_stage_both_axes_and_bomb_lanes(self):
  for marker in ('bomber25_reset:','bomber25_tick:','bomber25_finished:','bomber25_impact:','bomber25_paint:'):
   self.assertIn(marker,B)
  self.assertIn('mov byte ptr [bomber25_state],2',B)
  self.assertIn('cmp byte ptr [bomber25_state],2',B)
  self.assertIn('cmp byte ptr [bomber25_timer],8',B)
  self.assertIn('cmp byte ptr [bomber25_timer],6',B)
  self.assertIn('add byte ptr [bomber25_x],2',B)
  self.assertIn('add byte ptr [bomber25_y],2',B)
  self.assertIn('test byte ptr [bomber25_step],1',B)
  self.assertIn('add dh,2',B)
  self.assertIn('add dl,2',B)
  self.assertIn('cmp al,\'B\'',B)
  self.assertIn('call damage_brick',B)
  self.assertIn('call bomber25_hit_enemies',B)
  self.assertIn('call bomber25_hit_players',B)
  for phase in (113,114,115,117,121): self.assertIn(f'mov byte ptr [test_phase],{phase}',T)
 def test_real_aircraft_cga_sprites_and_size(self):
  self.assertIn('plane_horizontal',a.SMOOTH_SPRITES)
  self.assertIn('plane_vertical',a.SMOOTH_SPRITES)
  for n in ('plane_horizontal','plane_vertical'):
   self.assertEqual(len(a.pack_smooth(a.SPRITES[n])),480)
  self.assertIn('smooth_plane_horizontal',B)
  self.assertIn('smooth_plane_vertical',B)
  self.assertNotIn('bomb_falling_sprite',B)
  binary=R/'build/TANKS.COM'
  if binary.exists():self.assertLess(binary.stat().st_size,57344)
  self.assertIn(' -N -Ttext 0x100', (R/'Makefile').read_text())
 def test_no_bombs_over_headquarters(self):
  body=B.split('bomber25_impact:',1)[1].split('bomber25_no_brick:',1)[0]
  self.assertLess(body.index("cmp al,'B'"),body.index('call damage_brick'))
  self.assertIn('je bomber25_impact_done',body)
  self.assertNotIn('mov byte ptr [game_state],2',body)
  self.assertIn('call bomber25_reset',T)
  self.assertIn('call bomber25_tick',T)

if __name__=='__main__':unittest.main()
