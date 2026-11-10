"""v0.17 expanded bonus coverage; physical behavior lives in DOS /TEST 66–71."""
from pathlib import Path
import sys
import unittest

R=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(R/'tools'))
import build_cga_assets as art
GAME=(R/'src/dos/tanks.S').read_text()
EXT=(R/'src/dos/bonuses_v17.inc').read_text()
AI=(R/'src/dos/tactics.inc').read_text()

class TacticalBonusV17(unittest.TestCase):
    def test_eleven_unique_pickups(self):
        self.assertEqual(len(art.BONUS_LETTERS),14)
        names=('laser','ally','triple','homing','frenzy')
        for name in names:
            self.assertIn('bonus_'+name,art.SMOOTH_SPRITES)
            self.assertIn('hud_bonus_'+name+':',GAME)
        self.assertEqual(len({tuple(art.SPRITES['bonus_'+n]) for n in art.BONUS_LETTERS}),14)
    def test_timing_and_hud_seconds(self):
        self.assertIn('mov byte ptr [bonus_flash_ticks],180',GAME)
        self.assertIn('bonus17_tick:',EXT)
        self.assertIn('div bl',GAME[GAME.index('draw_bonus_indicator:'):GAME.index('draw_mode_indicator:')])
        self.assertIn('mov di,3908',GAME)
        self.assertIn('mov di,3910',GAME)
    def test_instant_laser_and_triple_fire(self):
        self.assertIn('laser17_fire:',EXT)
        self.assertIn('call advance_bullet_smooth',EXT[EXT.index('laser17_fire:'):EXT.index('ally17_spawn:')])
        self.assertIn('call extra17_advance',GAME)
        self.assertIn('cmp byte ptr [multi_ticks],0',AI)
        self.assertIn('call extra17_player_fire',GAME)
        self.assertIn('mov byte ptr [test_phase],67',GAME)
    def test_homing_is_independent_of_multishot(self):
        self.assertIn('extra17_home_direction:',EXT)
        self.assertIn('call extra17_home_direction',GAME)
        self.assertIn('mov byte ptr [test_phase],68',GAME)
    def test_aggressive_companion_and_friendly_frenzy(self):
        self.assertIn('ally17_tick:',EXT)
        self.assertIn('call extra17_ally_fire',EXT)
        self.assertIn('call frenzy17_target',GAME)
        self.assertIn('call shot_hits_other_enemy',GAME)
        self.assertIn('mov byte ptr [test_phase],70',GAME)
    def test_grenade_uses_four_animated_deaths(self):
        self.assertIn('grenade17_fx_tick:',EXT)
        self.assertIn('grenade17_fx_paint:',EXT)
        self.assertIn('mov byte ptr [grenade_fx_ticks+bx],12',GAME)
        self.assertIn('mov byte ptr [test_phase],71',GAME)

if __name__=='__main__': unittest.main()
