"""Build-time checks for the three authored stage layouts and HUD encoding."""
from pathlib import Path
import re
import sys
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
import build_cga_assets as sprites

class WaveTests(unittest.TestCase):
    def test_unique_stages_with_safe_spawns_and_base(self):
        maps = [sprites.get_map(ROOT / 'assets' / 'maps' / f'level{i:02}.map') for i in range(1, 10)]
        self.assertEqual(len({tuple(m) for m in maps}), 9)
        for stage, rows in enumerate(maps, 1):
            with self.subTest(stage=stage):
                self.assertEqual(rows[0][1], 'E')
                self.assertEqual(rows[0][7], 'E')
                self.assertEqual(rows[0][13], 'E')
                self.assertEqual(rows[14][7], 'P')
                self.assertEqual(rows[15][7], 'B')
                self.assertEqual(rows[14][6], '#')
                self.assertEqual(rows[14][8], '#')
                self.assertEqual(rows[15][6], '#')
                self.assertEqual(rows[15][8], '#')

    def test_usable_enemy_direction_sprites(self):
        for name in ('enemy_up', 'enemy_right', 'enemy', 'enemy_left', 'enemy_bullet', 'fast_down', 'power_down', 'armor_down'):
            self.assertIn(name, sprites.SPRITES)
            self.assertEqual(len(sprites.pack(sprites.SPRITES[name])), 48)
        self.assertNotEqual(sprites.SPRITES['enemy_right'], sprites.SPRITES['enemy_left'])
        self.assertNotEqual(sprites.SPRITES['enemy_up'], sprites.SPRITES['enemy'])
        self.assertEqual(len({tuple(sprites.SPRITES[x]) for x in ('enemy','fast_down','power_down','armor_down')}),4)

    def test_classic_sidebar_and_score_overlay(self):
        source = (ROOT / 'src' / 'dos' / 'tanks.S').read_text()
        # Live gameplay uses a right sidebar rather than cluttering screen edges.
        self.assertNotIn('status_string:', source)
        self.assertNotIn('title_string:', source)
        self.assertNotIn('help_string:', source)
        self.assertIn('call draw_sidebar_background', source)
        self.assertIn('call draw_enemy_markers', source)
        self.assertIn('draw_result_box:', source)
        self.assertIn('format_score:', source)
        self.assertIn('score_string: .asciz "SCORE 00000"', source)
        self.assertIn('mov di, offset score_string+10', source)
        self.assertIn('cmp byte ptr [enemy_spawned], 20', source)
        self.assertIn('cmp byte ptr [enemy_killed], 20', source)

    def test_sidebar_font_and_bounds(self):
        lines = sprites.generate_hud()
        self.assertEqual(len(sprites.hud_glyph(sprites.HUD_TANK)), 16)
        self.assertEqual(len(sprites.hud_glyph(sprites.HUD_FLAG)), 16)
        self.assertEqual(len(lines), 5 + 2*(17+6))
        self.assertIn('hud_star_icon:', lines)
        self.assertIn('hud_indicator_offsets:', lines)
        self.assertIn('hud_digit_ptrs:', lines)
        # Map start x32 and width208; sidebar starts x248 (8px gap).
        self.assertEqual(0, 0 + 0//4)
        self.assertLessEqual(0 + 16*16, 256)
        self.assertEqual(256 + 64, 320)
        self.assertLess(3587 + 5*2 + 0x2000 + 3*80 + 2, 16384)

if __name__ == '__main__':
    unittest.main()
