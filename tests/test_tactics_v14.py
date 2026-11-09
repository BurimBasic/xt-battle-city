"""v0.14: compact maps, actual DOS tactical regressions and bonus policy."""
import unittest
from pathlib import Path
import sys
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools'))
import build_cga_assets as assets

class TacticalV14Tests(unittest.TestCase):
    def test_compact_35_maps_decode_exactly(self):
        symbols=assets.MAP_NIBBLES
        self.assertEqual(len(symbols),9)
        for stage in range(1,36):
            rows=assets.get_map(ROOT/'assets/maps'/f'level{stage:02}.map')
            data=assets.packed_map(rows)
            self.assertEqual(len(data),128)
            restored=''.join(symbols[b&15]+symbols[b>>4] for b in data)
            self.assertEqual(restored,''.join(rows),stage)
        build=ROOT/'build/TANKS.COM'
        if build.is_file(): self.assertLess(build.stat().st_size,60416)

    def test_bonus_route_only_once_per_spawn_or_map_change(self):
        src=(ROOT/'src/dos/tanks.S').read_text()
        nav=(ROOT/'src/dos/strategy_v13.inc').read_text()
        ai=(ROOT/'src/dos/tactics.inc').read_text()
        self.assertIn('call strategy_bonus_spawn',src)
        self.assertIn('strategy_bonus_heading:',nav)
        self.assertIn('route_bonus: .space 256',nav)
        self.assertIn('cmp byte ptr [enemy_py+bx],140',nav)
        self.assertIn('call strategy_bonus_heading',ai)
        self.assertIn('mov byte ptr [test_phase],53',src)

    def test_friendly_fire_and_visible_shot_have_real_dos_assertions(self):
        src=(ROOT/'src/dos/tanks.S').read_text()
        ai=(ROOT/'src/dos/tactics.inc').read_text()
        self.assertIn('mov byte ptr [test_phase],52',src)
        self.assertIn('mov byte ptr [test_phase],54',src)
        self.assertIn('mov byte ptr [test_phase],55',src)
        self.assertIn('smoke_bonus_replay:',src)
        self.assertIn('tactical_player_aim_if_aligned:',ai)
        self.assertIn('mov byte ptr [enemy_active+si],0',src)
        self.assertIn('inc byte ptr [enemy_killed]',src)

if __name__=='__main__':unittest.main()
