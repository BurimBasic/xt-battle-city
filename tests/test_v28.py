"""v0.28 regression: canonical aircraft rotations, visible props, muzzle flash and fast AUTO dodge."""
from pathlib import Path
import sys
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
import build_cga_assets as art

T = (ROOT / "src/dos/tanks.S").read_text()
R = (ROOT / "src/dos/v027_render.inc").read_text()
AI = (ROOT / "src/dos/tactics.inc").read_text()
C = (ROOT / "src/dos/coop_v24.inc").read_text()


class V28Tests(unittest.TestCase):
    def test_one_master_plane_generates_all_headings(self):
        self.assertEqual(art.PLANE_V_DOWN, tuple(row[::-1] for row in reversed(art.PLANE_V)))
        self.assertEqual(art.PLANE_H, art.plane_turn_right(art.PLANE_V))
        self.assertEqual(art.PLANE_H_LEFT, tuple(row[::-1] for row in art.PLANE_H))
        for name in art.WIDE_PLANES:
            self.assertEqual(len(art.pack_wide_plane(art.SPRITES[name])), 384)

    def test_twin_engine_and_wings_remain_legible(self):
        p = art.PLANE_V
        self.assertEqual(len(p), 24)
        self.assertTrue(all(len(r) == 32 for r in p))
        self.assertEqual(p[0][15:17], "22")
        self.assertGreaterEqual(p[12].count("1"), 22)
        self.assertGreaterEqual(sum(row.count("3") for row in p), 26)

    def test_propellers_animate_in_all_four_directions(self):
        self.assertIn("wide27_horizontal_hubs:", R)
        self.assertIn("wide27_vertical_hubs:", R)
        self.assertIn("wide27_props_left:", R)
        self.assertIn("wide27_props_up:", R)
        self.assertIn("test byte ptr [game_tick],1", R)
        self.assertGreaterEqual(R.count("call gun27_pixel"), 10)

    def test_flash_survives_update_before_first_paint(self):
        self.assertIn("fire_primary:\n    mov byte ptr [gun27_p1],4", T)
        self.assertEqual(C.count("mov byte ptr [gun27_p2],4"), 2)
        self.assertIn("gun27_outward:", R)
        self.assertIn("call gun27_outward", R)
        self.assertIn("cmp byte ptr [gun27_phase],3", R)

    def test_auto_dodge_is_prompt_and_considers_spread_shells(self):
        self.assertIn("tactical_player_quick_escape:", AI)
        self.assertIn("tactical_player_idle:", AI)
        self.assertIn("call tactical_find_threat", AI)
        self.assertIn("cmp bx,7\n    jae tactical_threat_clear", AI)
        self.assertIn("mov byte ptr [tactical_threat_range],24", AI)
        self.assertIn("mov byte ptr [tactical_threat_range],72", AI)
        self.assertIn("cmp byte ptr [player_px],128", AI)


if __name__ == "__main__":
    unittest.main()
