"""Release v0.10 art acceptance: measurable readability at native CGA size.

These tests prevent common regressions; final artistic quality still needs manual
judgement in each of the four hardware palettes and on CRT-like displays.
"""
import sys
from pathlib import Path
import unittest
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools'))
import build_cga_assets as a

class ReadabilityTests(unittest.TestCase):
    def test_brick_uses_no_unrelated_cyan_green_accents(self):
        self.assertTrue(set(''.join(a.BRICK)) <= set('.23'))
        # Full-length dark mortar and regular offset brick courses.
        for y in (3,7,11):self.assertEqual(a.BRICK[y],'.'*16)
        self.assertNotEqual(a.BRICK[1],a.BRICK[5])

    def test_materials_have_distinct_silhouettes_and_large_shapes(self):
        mats=[a.BRICK,a.STEEL,a.WATER,a.FOREST,a.ICE]
        self.assertEqual(len({tuple(x) for x in mats}),5)
        self.assertGreater(sum(r.count('.') for r in a.WATER),55)
        self.assertTrue(all(row[0]=='3' and row[-1]=='3' for row in a.ICE))
        self.assertTrue(all(ch!='.' for ch in a.STEEL[0]))

    def test_tank_gun_tracks_and_distinct_class_geometry(self):
        names=['player_up','enemy_up','fast_up','power_up','armor_up']
        silhouettes=[]
        for name in names:
            rows=a.SPRITES[name]
            # A distinct central muzzle and left/right treads are present.
            for y in (0,1):self.assertNotEqual(rows[y][7:9],'..',name)
            self.assertTrue(any(rows[y][3]!='.' for y in range(2,11)),name)
            self.assertTrue(any(rows[y][12]!='.' for y in range(2,11)),name)
            silhouettes.append(tuple(''.join('X' if c!='.' else '.' for c in row) for row in rows))
        self.assertGreaterEqual(len(set(silhouettes)),4)
        self.assertNotEqual(a.SPRITES['enemy_up'],a.SPRITES['player_up'])

    def test_pickups_centered_and_unique(self):
        all_shapes=[]
        for kind in a.BONUS_LETTERS:
            tile=a.SPRITES['bonus_'+kind]
            # Bounding-box coordinates count only central icon white pixels.
            xy=[(x,y) for y in range(3,9) for x in range(4,12) if tile[y][x]=='3']
            self.assertTrue(xy,kind)
            xs=[x for x,y in xy];ys=[y for x,y in xy]
            self.assertLessEqual(abs(min(xs)+max(xs)-15),1,kind)
            self.assertLessEqual(abs(min(ys)+max(ys)-11),1,kind)
            all_shapes.append(tuple(tile))
        self.assertEqual(len(set(all_shapes)),14)

    def test_shield_has_symmetric_solid_external_arc_without_hiding_tank(self):
        for direction in ('up','right','down','left'):
            plain=a.SPRITES['player_'+direction]
            shield=a.SPRITES['player_shield_'+direction]
            added=[]
            for y in range(12):
                for x in range(16):
                    if plain[y][x]!='.':self.assertEqual(plain[y][x],shield[y][x])
                    if plain[y][x]=='.' and shield[y][x]!='.':added.append((x,y))
            self.assertGreaterEqual(len(added),20,direction)

    def test_packed_assets_and_8088_binary_size(self):
        for k,asset in a.SPRITES.items():
            if k in a.WIDE_PLANES:
                self.assertEqual(len(a.pack_wide_plane(asset)),384,k)
                continue
            self.assertEqual(len(a.pack(asset)),48,k)
            if k in a.SMOOTH_SPRITES:
                self.assertEqual(len(a.pack_smooth(asset)),480,k)
        p=ROOT/'build'/'TANKS.COM'
        if p.exists():self.assertLess(p.stat().st_size,57344)

if __name__=='__main__':unittest.main()
