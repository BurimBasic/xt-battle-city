"""v0.11 tactical director acceptance: assets, 8088 budget, and state hooks.

These tests are NOT a substitute for DOS /TEST and human tactical playtests.
"""
from pathlib import Path
import sys
import unittest
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools'))
import build_cga_assets as a

class TacticalTests(unittest.TestCase):
    def setUp(self):
        self.src=(ROOT/'src'/'dos'/'tanks.S').read_text()
        self.ai=(ROOT/'src'/'dos'/'tactics.inc').read_text()

    def test_demo_and_manual_takeover(self):
        for s in ('auto_mode: .byte 1','auto_toggle_pending: .byte 0',
                  'tactical_player_tick:','tactical_find_threat:',
                  'tactical_find_target:','tactical_player_path_open:'):
            self.assertIn(s,self.ai)
        self.assertIn('call tactical_player_tick',self.src)
        self.assertIn('mov byte ptr [auto_mode],0',self.src)
        self.assertIn('cmp al, 0x0f',self.src)  # Tab: switch mode
        self.assertIn('demo_timer',self.src)
        self.assertIn('cmp byte ptr [demo_timer], 72',self.src)
        self.assertIn('call draw_mode_indicator',self.src)

    def test_squad_coordination_and_dodge(self):
        for label in ('tactical_enemy_turn:','tactical_enemy_evade:',
                      'tactical_safe_fire:','tactical_report_player:'):
            self.assertIn(label,self.ai)
        for label in ('tactical_role_flank_left:', 'tactical_role_flank_right:',
                      'tactical_role_hunter:','tactical_ambush_hold:'):
            self.assertIn(label,self.ai)
        self.assertIn('call tactical_enemy_turn',self.src)
        self.assertIn('call tactical_safe_fire',self.src)
        self.assertIn('call tactical_report_player',self.src)
        self.assertIn('call shot_hits_other_enemy',self.src)

    def test_8088_int_budget(self):
        self.assertNotIn('.386',self.ai)
        self.assertNotIn('fpu',self.ai.lower())
        binary=ROOT/'build'/'TANKS.COM'
        if not binary.exists():binary=ROOT/'dist'/'TANKS.COM'
        if binary.exists():self.assertLess(binary.stat().st_size,57344)
        self.assertIn('mov byte ptr [test_phase], 40',self.src)

    def test_readable_distinct_water_and_ice(self):
        water=a.SPRITES['water']; ice=a.SPRITES['ice'];forest=a.SPRITES['forest']
        self.assertEqual(len(water),12)
        self.assertEqual(len(ice),12)
        self.assertEqual(water[0],'.'*16)
        self.assertIn('.'*16,water)
        self.assertGreater(sum(r.count('.') for r in water),50)
        self.assertEqual(ice[0],'3'*16)
        self.assertEqual(ice[-1],'3'*16)
        self.assertNotEqual(water,forest)
        self.assertNotEqual(water,ice)
        self.assertNotEqual(ice,forest)

    def test_hud_auto_indicator_font(self):
        hud=a.generate_hud()
        for c in 'automn':
            self.assertIn('hud_'+c+'_char:',hud)
        self.assertIn('tactical_auto_glyphs:',self.src)
        self.assertIn('tactical_manual_glyphs:',self.src)
        self.assertIn('mov di, 4225',self.src)

if __name__=='__main__':unittest.main()
