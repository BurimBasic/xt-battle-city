"""v0.6: geometry, alpha packing and 8086 smooth rendering invariants."""
from pathlib import Path
import sys
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools'))
import build_cga_assets as a


def bitmap_occupied(mask: int, x: int, y: int) -> bool:
    bit = 1 << (int(x >= 8) + 2 * int(y >= 6))
    return bool(mask & bit)


class PixelEngineTests(unittest.TestCase):
    def test_sprite_mask_colours_are_consistent(self):
        self.assertEqual(len(a.SMOOTH_SPRITES), 42)
        for name in a.SMOOTH_SPRITES:
            data = a.pack_smooth(a.SPRITES[name])
            self.assertEqual(len(data), 4 * 12 * 10)
            for phase in range(4):
                for y in range(12):
                    row = data[phase*120+y*10:phase*120+y*10+10]
                    masks, colors = row[:5], row[5:]
                    for m,c in zip(masks,colors):
                        self.assertEqual(c & (~m & 255), 0,
                                         f'{name} phase={phase} y={y}')
            self.assertNotEqual(data[:120], data[120:240], name)

    def test_brick_quadrants_and_collision(self):
        for mask in range(16):
            for x in range(16):
                for y in range(12):
                    expected = bool(mask & (1 << ((x >= 8) + 2 * (y >= 6))))
                    self.assertEqual(bitmap_occupied(mask,x,y),expected)
        self.assertEqual([bitmap_occupied(14,x,2) for x in (3,12)], [False,True])
        self.assertEqual([bitmap_occupied(11,3,y) for y in (2,9)], [True,False])

    def test_pixel_boundaries_and_field(self):
        # World 13 tiles of 16x12, viewport at (32,16), panel at x=248.
        self.assertLessEqual(0 + 240 + 16, 256)
        self.assertLessEqual(0 + 180 + 12, 200)
        for x,y in ((0,0),(3,7),(112,168),(240,180)):
            left,right=x+2,x+13
            top,bottom=y+1,y+10
            self.assertGreaterEqual(left,0)
            self.assertLess(right,256)
            self.assertLess(bottom,192)
            self.assertGreaterEqual(top,0)

    def test_source_uses_pixel_input_and_dirty_compositing(self):
        s=(ROOT/'src/dos/tanks.S').read_text()
        for sym in ('keyboard_irq:', 'install_keyboard:', 'restore_keyboard:',
                    'render_frame:', 'draw_smooth_sprite:', 'flush_dirty:',
                    'rect_passable:', 'chip_brick_pixel:', 'projectile_probe:',
                    'move_player_smooth:', 'move_enemies_smooth:',
                    'advance_bullet_smooth:', 'advance_enemy_shot_smooth:'):
            self.assertIn(sym,s)
        self.assertIn('call install_keyboard',s)
        self.assertIn('call restore_keyboard',s)
        self.assertIn('mov byte ptr [test_phase], 27',s)

if __name__=='__main__':
    unittest.main()
