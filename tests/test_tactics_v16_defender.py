"""v0.16: prioritize real HQ defence; allow independent fire while moving."""
import unittest
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
T=(ROOT/'src/dos/tanks.S').read_text()
AI=(ROOT/'src/dos/tactics.inc').read_text()
NAV=(ROOT/'src/dos/strategy_v13.inc').read_text()

class AutonomousDefence(unittest.TestCase):
    def test_fire_does_not_depend_on_bonus_route(self):
        tick=T[T.index('game_tick_step:'):T.index('/* Power-up sequence:')]
        self.assertLess(tick.index('call move_player_smooth'),tick.index('call tactical_player_autofire'))
        self.assertLess(tick.index('call tactical_player_autofire'),tick.index('call advance_bullet_smooth'))
        self.assertIn('tactical_player_autofire:',AI)
        self.assertIn('call tactical_player_aim_if_aligned',AI[AI.index('tactical_player_autofire:'):AI.index('tactical_player_line_clear:')])
        self.assertIn('mov byte ptr [test_phase],59',T)
    def test_wall_ray_is_checked_before_holding_a_fire_lane(self):
        aim=AI[AI.index('tactical_player_aim_if_aligned:'):AI.index('tactical_player_path_open:')]
        self.assertIn('call tactical_player_line_clear',aim)
        self.assertIn('pixel_y_tile_lookup+bx',aim)
        self.assertIn('level_data+bx',aim)
        self.assertIn("cmp al,'T'",aim)
        self.assertIn("cmp al,'B'",aim)
        self.assertIn('mov byte ptr [test_phase],60',T)
        self.assertIn('mov byte ptr [test_phase],61',T)
    def test_our_hq_is_prioritized_before_bonus_and_guard_is_offset(self):
        self.assertLess(AI.index('call tactical_find_target'),AI.index('call strategy_bonus_heading'))
        self.assertIn('cmp byte ptr [enemy_py+bx],136',AI)
        self.assertIn('cmp byte ptr [enemy_py+bx],140',NAV)
        self.assertIn('cmp byte ptr [player_px],96',AI)
        self.assertIn('cmp byte ptr [player_py],120',AI)
        self.assertIn('mov byte ptr [test_phase],63',T)
    def test_bonus_icon_is_left_of_previous_position(self):
        h=T[T.index('draw_bonus_indicator:'):T.index('draw_mode_indicator:')]
        self.assertIn('mov di,3906',h)
        self.assertIn('mov si,[hud_bonus_ptrs+bx]',h)
        self.assertIn('mov byte ptr [test_phase],62',T)
        self.assertEqual(3906, 80*(96//2)+264//4)
    def test_real_mode_has_all_new_phases(self):
        for i in range(59,64):
            self.assertIn('mov byte ptr [test_phase],'+str(i),T)

if __name__=='__main__':unittest.main()
