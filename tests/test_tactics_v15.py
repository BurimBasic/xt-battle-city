"""v0.15 physical-bound alignment, HUD icon and variable doctrine regressions."""
import unittest
from pathlib import Path
R=Path(__file__).resolve().parents[1]
T=(R/'src/dos/tanks.S').read_text()
A=(R/'src/dos/tactics.inc').read_text()
N=(R/'src/dos/strategy_v13.inc').read_text()

class V15Tests(unittest.TestCase):
    def test_grazing_treads_shares_collision_bounds_with_aim(self):
        # Enemy relative top-left offset; shot center is player + (8,6).
        for delta in range(-32,33):
            self.assertEqual(0 <= (delta+9) <= 19,-2 <= (8-delta) <= 17,delta)
            self.assertEqual(0 <= (delta+7) <= 15,-2 <= (6-delta) <= 13,delta)
        self.assertIn('add al,9',A)
        self.assertIn('cmp al,19',A)
        self.assertIn('add al,9            /* same width as physics collision */',A)
        self.assertIn('cmp al,15',A)
        self.assertIn('add al, 2           /* includes both tread edges */',T)
        self.assertIn('cmp al, 20',T)
    def test_dodge_checks_opposite_if_first_blocked(self):
        p=A[A.index(' tactical_threat_found:'):A.index(' tactical_threat_next:')]
        self.assertIn('xor al,2',p)
        self.assertEqual(p.count('call tactical_player_path_open'),2)
        self.assertIn('cmp al, 72',A)
    def test_base_breach_precedes_bonus(self):
        self.assertIn('cmp byte ptr [enemy_py+bx],140',N)
        self.assertIn('cmp byte ptr [enemy_py+bx],96',A)
        self.assertIn('tactical_target_wide:',A)
        self.assertIn('tactical_seek_flank_breach:',A)
    def test_specific_collected_icon_blinks_in_sidebar_without_number(self):
        for name in ('helmet','grenade','shovel','clock','life'):
            self.assertIn('hud_bonus_'+name+':',T)
        self.assertIn('hud_bonus_ptrs: .word hud_star_icon',T)
        self.assertIn('mov [bonus_flash_type],al',T)
        self.assertIn('mov byte ptr [bonus_flash_ticks],112',T)
        self.assertIn('test byte ptr [game_tick],8',T)
        self.assertIn('mov di,3906',T)
        self.assertIn('mov di, 4224',T)  # preserve TAB-AUTO
        indicator=T[T.index('draw_bonus_indicator:'):T.index('draw_mode_indicator:')]
        self.assertIn('call draw_hud_digit',indicator)  # countdown seconds
    def test_multiple_doctrines_and_initial_entropy(self):
        self.assertIn('squad_doctrine: .byte 0',N)
        self.assertIn('and al,3',N)
        self.assertIn('xor word ptr [rng_state],dx',T)
        self.assertIn('cmp byte ptr [squad_doctrine],2',N)
        self.assertIn('cmp byte ptr [squad_doctrine],3',A)
        self.assertIn('cmp al,1',N)

if __name__=='__main__': unittest.main()
