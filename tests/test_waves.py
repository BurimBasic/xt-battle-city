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
        maps = [sprites.get_map(ROOT / 'assets' / 'maps' / f'level{i:02}.map') for i in (1, 2, 3)]
        self.assertEqual(len({tuple(m) for m in maps}), 3)
        for stage, rows in enumerate(maps, 1):
            with self.subTest(stage=stage):
                self.assertEqual(rows[0][0], 'E')
                self.assertEqual(rows[0][6], 'E')
                self.assertEqual(rows[0][12], 'E')
                self.assertEqual(rows[11][6], 'P')
                self.assertEqual(rows[12][6], 'B')
                self.assertEqual(rows[11][5], '#')
                self.assertEqual(rows[11][7], '#')
                self.assertEqual(rows[12][5], '#')
                self.assertEqual(rows[12][7], '#')

    def test_usable_enemy_direction_sprites(self):
        for name in ('enemy_up', 'enemy_right', 'enemy', 'enemy_left', 'enemy_bullet'):
            self.assertIn(name, sprites.SPRITES)
            self.assertEqual(len(sprites.pack(sprites.SPRITES[name])), 48)
        self.assertNotEqual(sprites.SPRITES['enemy_right'], sprites.SPRITES['enemy_left'])
        self.assertNotEqual(sprites.SPRITES['enemy_up'], sprites.SPRITES['enemy'])

    def test_hud_digit_offsets(self):
        source = (ROOT / 'src' / 'dos' / 'tanks.S').read_text()
        match = re.search(r'^status_string: \.asciz "([^"]+)"', source, re.M)
        self.assertIsNotNone(match)
        status = match.group(1)
        self.assertEqual(status[3], '1')
        self.assertEqual(status[14:16], '20')
        self.assertEqual(status[24], '3')
        self.assertEqual(status[33:38], '00000')
        self.assertLessEqual(len(status), 40)
        self.assertIn('cmp byte ptr [enemy_spawned], 20', source)
        self.assertIn('cmp byte ptr [enemy_killed], 20', source)

if __name__ == '__main__':
    unittest.main()
