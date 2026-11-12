"""CGA v0.18 visual acceptance: tile silhouettes, flash overlays, HUD branding."""
import unittest
from pathlib import Path
import sys
R=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(R/'tools'))
import build_cga_assets as a
SRC=(R/'src/dos/tanks.S').read_text()

class VisualV18(unittest.TestCase):
    def test_simplified_wave_pattern(self):
        w=a.WATER
        self.assertEqual(w[0],'.'*16)
        self.assertEqual(w[-1],'.'*16)
        self.assertGreaterEqual(sum(row.count('.') for row in w),130)
        self.assertEqual(sum(row.count('1') for row in w),48)
        self.assertFalse(any('3' in row or '2' in row for row in w))
    def test_forest_is_a_tree_pair_not_rounded_circles(self):
        f=a.FOREST
        self.assertEqual(f[0].count('1'),2)
        self.assertGreaterEqual(sum(row.count('3') for row in f),4)
        self.assertEqual(f[-1],'.'*16)
        self.assertNotEqual(tuple(f),tuple(a.WATER))
    def test_ice_facets_read_as_light_slab(self):
        ice=a.ICE
        self.assertEqual(ice[0],'3'*16)
        self.assertEqual(ice[-1],'3'*16)
        self.assertGreaterEqual(sum(row.count('3') for row in ice),65)
        self.assertTrue(all(row[0]=='3' and row[-1]=='3' for row in ice))
    def test_bonus_frame_shrunk_right_one_pixel(self):
        for name in a.BONUS_LETTERS:
            tile=a.SPRITES['bonus_'+name]
            for y in range(1,11):
                self.assertEqual(tile[y][2],'3')
                self.assertEqual(tile[y][12],'3')
                self.assertEqual(tile[y][13],'.')
            self.assertEqual(tile[1][2:13],'3'*11)
            self.assertEqual(tile[10][2:13],'3'*11)
    def test_frame_only_flashes_without_masking_icon(self):
        erase=a.BONUS_FRAME_ERASE
        for y,row in enumerate(erase):
            for x,p in enumerate(row):
                expected=('0' if 1<=y<=10 and 2<=x<=12 and
                          (x in (2,12) or y in (1,10)) else '.')
                self.assertEqual(p,expected,(x,y))
        data=a.pack_smooth(erase)
        self.assertEqual(len(data),480)
        self.assertIn('cmp byte ptr [bonus_timer],27',SRC)
        self.assertIn('mov si,offset smooth_bonus_frame_erase',SRC)
    def test_shield_blinks_but_plain_tank_stays(self):
        segment=SRC[SRC.index('/* Player\'s tank. */'):SRC.index('/* Player projectile and up to four enemy projectiles. */')]
        self.assertIn('test byte ptr [game_tick],4',segment)
        self.assertIn('jnz paint_player_no_shield',segment)
        self.assertIn('mov si, [smooth_player_ptrs+bx]',segment)
    def test_brand_and_centered_auto(self):
        self.assertIn('hud_blank_icon, hud_blank_icon, hud_a_char, hud_u_char',SRC)
        self.assertIn('brand_tanks_glyphs:',SRC)
        self.assertIn('brand_copyright_glyphs:',SRC)
        self.assertIn('brand_basic_glyphs:',SRC)
        self.assertIn('brand_version_glyphs:',SRC)
        self.assertRegex(SRC, r'brand_version_glyphs:.*hud_digit_2, hud_digit_5')
        self.assertIn('call draw_branding',SRC)
        self.assertIn('draw_hud_glyph_inverted:',SRC)
        for ch in ('k','i','c','v','.'):
            self.assertIn('hud_'+('dot' if ch=='.' else ch)+'_char:',a.generate_hud()[-1] if False else '\n'.join(a.generate_hud()))
    def test_8086_branding_dos_phase(self):
        self.assertIn('mov byte ptr [test_phase],72',SRC)
        self.assertIn('mov byte ptr [test_phase],73',SRC)

if __name__=='__main__': unittest.main()
