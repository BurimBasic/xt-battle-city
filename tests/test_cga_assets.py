import pathlib
import sys
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools'))
import build_cga_assets as assets


class SpriteTests(unittest.TestCase):
    def test_sprite_dimensions(self):
        for name, art in assets.SPRITES.items():
            with self.subTest(name=name):
                self.assertEqual(len(art), 12)
                self.assertTrue(all(len(row) == 16 for row in art))
                self.assertEqual(len(assets.pack(art)), 48)

    def test_game_map_and_origin(self):
        rows = assets.get_map(ROOT / 'assets/maps/level01.map')
        self.assertEqual(rows[11][6], 'P')
        self.assertEqual(rows[9][9], '#')
        self.assertEqual(''.join(rows).count('E'), 3)
        self.assertEqual(''.join(rows).count('B'), 1)

    def test_video_boundaries(self):
        # x=32+12*16=224 and y=16+12*12=160; map ends x240.
        self.assertLessEqual(32 + 13*16, 248)
        self.assertLessEqual(16 + 13*12, 200)
        self.assertLess(648 + 12*480 + 5*80 + 0x2000 + 4*12 + 4, 16384)

    def test_generated_include_is_current(self):
        expected = assets.generate(ROOT / 'assets/maps/level01.map')
        got = (ROOT / 'src/dos/cga_assets.inc').read_text(encoding='ascii')
        self.assertEqual(got, expected)


if __name__ == '__main__':
    unittest.main()
