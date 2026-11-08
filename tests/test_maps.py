import unittest
from pathlib import Path
import sys
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools"))
from validate_map import validate


class MapTests(unittest.TestCase):
    def test_reference_level(self):
        data = (Path(__file__).resolve().parents[1] / "assets/maps/level01.map").read_text(encoding="ascii")
        self.assertEqual(validate(data), [])

    def test_bad_shape(self):
        self.assertTrue(validate("P.BE"))

    def test_missing_base(self):
        self.assertTrue(any("'B'" in m for m in validate("P" + "." * 12 + "\n" + "." * 13 + "\n" * 11)))

    def test_unknown_tile(self):
        self.assertTrue(any("invalid" in m for m in validate("?" * 13 + "\n" + "." * 13 + "\n" * 11)))


if __name__ == "__main__":
    unittest.main()
