"""v0.35 regression gates: title centered and keyboard input cardinal-only.
These inspect executable source invariants; integration also runs via DOS /TEST.
"""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[1] / "src" / "dos"
TITLE = (ROOT / "title_v32.inc").read_text()
CORE = (ROOT / "tanks.S").read_text()
COOP = (ROOT / "coop_v24.inc").read_text()


def body(text, start, end):
    return text.split(start + ":", 1)[1].split(end + ":", 1)[0]


class CardinalControlsAndTitle(unittest.TestCase):
    def test_title_projectiles_meet_at_center_not_left_quarter(self):
        left = int(re.search(r"mov byte ptr \[title32_x1\],(\d+)", TITLE).group(1))
        right = int(re.search(r"mov byte ptr \[title32_x2\],(\d+)", TITLE).group(1))
        self.assertEqual((left, right), (105, 205))
        for frame in range(74, 80):
            travel = 37
            lshot = left + travel + 13 + 2 * (frame - 74)
            rshot = right - travel + 2 - 2 * (frame - 74)
            if abs(lshot-rshot) <= 1:
                self.assertLessEqual(abs((lshot+rshot)//2 - 160), 4)
                break
        else:
            self.fail("Shots do not converge before explosion")

    def test_p1_directions_exclusive_fire_independent(self):
        src = body(CORE, "manual_key_event", "irq_ack")
        self.assertIn("cmp ah,16", src)
        self.assertIn("and al,16", src)
        self.assertIn("mov [manual_keys],al", src)
        self.assertIn("manual_key_fire_make:", src)
        self.assertIn("or byte ptr [manual_keys],ah", src)
        self.assertIn("and byte ptr [manual_keys], ah", src)

    def test_p2_directions_exclusive_ctrl_independent(self):
        src = body(COOP, "coop24_key_event", "coop24_tick")
        self.assertIn("cmp ah,16", src)
        self.assertIn("and al,16", src)
        self.assertIn("mov [coop_keys],al", src)
        self.assertIn("coop24_fire_make:", src)
        self.assertIn("or byte ptr [coop_keys],ah", src)
        self.assertIn("and byte ptr [coop_keys],ah", src)

    def test_single_axis_pixel_step_for_all_tanks(self):
        s = body(CORE, "step_pixel", "pixel_is_blocked")
        self.assertIn("dec dh", s)
        self.assertIn("inc dl", s)
        self.assertIn("inc dh", s)
        self.assertIn("dec dl", s)
        for label in ("step_pixel_not_up", "step_pixel_not_right", "step_pixel_not_down"):
            self.assertIn(label, s)
        self.assertGreaterEqual(s.count("clc\n    ret"), 4)


if __name__ == "__main__":
    unittest.main()
