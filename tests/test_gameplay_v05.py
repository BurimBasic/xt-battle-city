"""Structural and asset invariants. Real game-logic integration runs in DOS /TEST."""
from pathlib import Path
import sys
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools'))
import build_cga_assets as a


class GameplayWave5(unittest.TestCase):
    def test_six_distinct_original_bonus_sprites(self):
        self.assertEqual(len(a.BONUS_LETTERS), 6)
        names = [f'bonus_{kind}' for kind in a.BONUS_LETTERS]
        self.assertEqual(len({tuple(a.SPRITES[n]) for n in names}), 6)
        self.assertTrue(all(len(a.pack(a.SPRITES[n])) == 48 for n in names))

    def test_brick_mask_preserves_quadrants(self):
        self.assertEqual(a.SPRITES['brick_mask_0'], a.EMPTY)
        self.assertEqual(a.SPRITES['brick_mask_15'], a.BRICK)
        self.assertEqual(len({tuple(a.SPRITES[f'brick_mask_{n}']) for n in range(16)}), 16)
        # A projectile moving right removes left-side bits (1,4): 15 -> 10 -> 0.
        old = 15
        after_first = old & ~5
        after_second = after_first & ~15
        self.assertEqual((after_first, after_second), (10, 0))
        self.assertEqual(a.SPRITES['brick_mask_10'][2][:8], '.' * 8)
        self.assertNotEqual(a.SPRITES['brick_mask_10'][2][8:], '.' * 8)

    def test_thirty_five_independent_levels_and_two_new_terrains(self):
        seen = set()
        terrain = set()
        for n in range(1, 36):
            rows = a.get_map(ROOT / 'assets' / 'maps' / f'level{n:02}.map')
            self.assertEqual(len(rows), 13)
            self.assertTrue(all(len(row) == 13 for row in rows))
            self.assertEqual(rows[0][0::6], 'EEE')
            self.assertEqual(rows[11][6], 'P')
            self.assertEqual(rows[12][6], 'B')
            seen.add(tuple(rows))
            terrain.update(''.join(rows))
        self.assertEqual(len(seen), 35)
        self.assertIn('F', terrain)
        self.assertIn('I', terrain)
        generated = a.generate(ROOT / 'assets' / 'maps' / 'level01.map')
        self.assertIn('stage_ptrs:', generated)
        self.assertIn('level35_template', generated)

    def test_8088_safe_core_effect_entrypoints(self):
        src = (ROOT / 'src' / 'dos' / 'tanks.S').read_text(encoding='utf-8')
        for name in ('damage_brick:', 'maybe_drop_bonus:', 'check_bonus_pickup:',
                     'grenade_all_enemies:', 'protect_hq:', 'restore_hq:',
                     'tick_powerups:', 'sound_play:', 'sound_tick:',
                     'slide_player:', 'bullet_vs_shot_loop:', 'shot_no_bullet_collision:'):
            self.assertIn(name, src)
        self.assertIn('cmp byte ptr [stage], 35', src)
        self.assertIn('mov byte ptr [test_phase], 19', src)

    def test_stage_results_are_separate_and_count_types(self):
        src=(ROOT / 'src' / 'dos' / 'tanks.S').read_text()
        for symbol in ('stage_clear_hud:', 'draw_stage_result_box:', 'format_tally:',
                       'kills_by_type:', 'tally1:', 'tally2:', 'tally3:', 'tally4:',
                       'pause_hud:'):
            self.assertIn(symbol, src)
        self.assertIn('mov byte ptr [test_phase], 20', src)

    def test_cga_memory_layout_with_many_sprites(self):
        self.assertEqual(len(a.SPRITES), 55)
        self.assertLessEqual(len(a.SPRITES) * 48, 4096)
        self.assertLess(648 + 12*480 + 5*80 + 0x2000 + 4*12+4, 16384)


if __name__ == '__main__':
    unittest.main()
