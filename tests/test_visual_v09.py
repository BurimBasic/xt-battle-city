"""Pixel-cluster quality, centered pickups, and anti-flicker memory architecture."""
from pathlib import Path
import unittest
import sys
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools'))
import build_cga_assets as art

class ArtistTests(unittest.TestCase):
    def test_six_centered_pickups(self):
        for name in art.BONUS_LETTERS:
            badge=art.SPRITES['bonus_'+name]
            # Distinct symbol is white, inside the 10x6 dark inset.
            coords=[(x,y) for y in range(3,9) for x in range(3,13)
                    if badge[y][x]=='3']
            self.assertTrue(coords,name)
            lo_x,hi_x=min(x for x,y in coords),max(x for x,y in coords)
            lo_y,hi_y=min(y for x,y in coords),max(y for x,y in coords)
            self.assertLessEqual(abs((lo_x+hi_x)-15),2,name)
            self.assertLessEqual(abs((lo_y+hi_y)-11),2,name)
    def test_shield_preserves_player_body(self):
        for direction in ('up','right','down','left'):
            original=art.SPRITES['player_'+direction]
            shield=art.SPRITES['player_shield_'+direction]
            for y in range(12):
                for x in range(16):
                    if original[y][x]!='.':
                        self.assertEqual(shield[y][x],original[y][x])
            self.assertGreater(sum(a!='.' and b=='.' for a,b in zip(''.join(shield),''.join(original))),6)
    def test_tank_classes_have_different_silhouettes(self):
        sprites=[art.SPRITES[k] for k in ('player_up','enemy_up','fast_up','power_up','armor_up')]
        silhouettes={tuple(''.join('1' if p!='.' else '.' for p in row) for row in sprite) for sprite in sprites}
        self.assertGreaterEqual(len(silhouettes),3)
    def test_blitter_uses_composed_frame(self):
        source=(ROOT/'src/dos/tanks.S').read_text()
        for marker in ('present_full_field:', 'copy_tile_to_cga:',
                       'commit_dirty_tiles:', 'frame_seg: .word 0xb800',
                       'upload_tiles: .space 256',
                       'call commit_dirty_tiles',
                       'mov byte ptr [test_phase], 33'):
            self.assertIn(marker,source)
    def test_bounded_binary_size(self):
        binary=ROOT/'build/TANKS.COM'
        if binary.exists():self.assertLess(binary.stat().st_size,49152)

if __name__=='__main__':unittest.main()
