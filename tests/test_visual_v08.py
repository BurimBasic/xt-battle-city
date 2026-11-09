"""CGA pixel art, palette compatibility and bounded effects (not FPS proof)."""
import unittest
from pathlib import Path
import sys
ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools'))
import build_cga_assets as a

class VisualV08Tests(unittest.TestCase):
    def test_directional_treads_have_distinct_frames(self):
        self.assertEqual(len(a.TRACK_SPRITES),8)
        for direction in range(4):
            a0=a.TRACK_SPRITES[f'tread_{direction}_0']
            a1=a.TRACK_SPRITES[f'tread_{direction}_1']
            self.assertNotEqual(a0,a1)
            self.assertEqual(len(a.pack_smooth(a0)),480)
            self.assertEqual(len(a.pack_smooth(a1)),480)
    def test_explosions_separate_original_frames(self):
        self.assertEqual(len(a.EXPLOSIONS),4)
        self.assertEqual(len({tuple(x) for x in a.EXPLOSIONS.values()}),4)
        for v in a.EXPLOSIONS.values():
            self.assertGreater(sum(x!='.' for line in v for x in line),3)
    def test_palette_and_friendly_fire_source(self):
        s=(ROOT/'src/dos/tanks.S').read_text()
        for k in ('cycle_cga_palette:', 'apply_cga_palette:',
                  'cga_palettes: .byte 0x20, 0x00, 0x30, 0x10',
                  'shot_hits_other_enemy:', 'friendly_target_loop:',
                  'spawn_explosion:', 'tick_explosion:',
                  'smooth_tread_ptrs:', 'smooth_explosion_ptrs:',
                  'mov byte ptr [test_phase], 29',
                  'mov byte ptr [test_phase], 30'):
            self.assertIn(k,s)
    def test_binary_size_budget_and_8088_compatibility(self):
        p=ROOT/'build/TANKS.COM'
        if p.exists():self.assertLess(p.stat().st_size, 49152)

if __name__=='__main__': unittest.main()
