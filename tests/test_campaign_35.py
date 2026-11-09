"""35-stage campaign: uniqueness, safe spawn, walkable center route."""
from collections import deque
from pathlib import Path
import sys
import unittest
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools'))
import build_cga_assets as assets
def route_ok(rows):
    q=deque([(6,11)]);seen={(6,11)}
    while q:
        x,y=q.popleft()
        if (x,y)==(6,0):return True
        for xx,yy in ((x+1,y),(x-1,y),(x,y+1),(x,y-1)):
            if not(0<=xx<13 and 0<=yy<13) or (xx,yy) in seen:continue
            if rows[yy][xx] not in '.FIEP':continue
            seen.add((xx,yy));q.append((xx,yy))
    return False
class CampaignTests(unittest.TestCase):
    def test_35_valid_unique_maps(self):
        maps=[]
        for n in range(1,36):
            f=ROOT/'assets'/'maps'/f'level{n:02}.map'
            self.assertTrue(f.is_file(),n)
            rows=assets.get_map(f)
            self.assertEqual(rows[0],'E.....E.....E',n)
            self.assertEqual(rows[11][5:8],'#P#',n)
            self.assertEqual(rows[12][5:8],'#B#',n)
            maps.append(tuple(rows))
            if n>=10:self.assertTrue(route_ok(rows),f'blocked level {n}')
        self.assertEqual(len(set(maps)),35)
    def test_pointer_table_and_quick_selection(self):
        src=(ROOT/'src'/'dos'/'tanks.S').read_text()
        self.assertIn('cmp byte ptr [stage], 35',src)
        self.assertIn('controls_stage_jump:',src)
        self.assertIn('mov byte ptr [test_phase], 28',src)
        inc=(ROOT/'src'/'dos'/'cga_assets.inc').read_text(encoding='ascii')
        self.assertIn('level35_template:',inc)
        self.assertEqual(inc.count('.ascii "E.....E.....E"'),35)
if __name__=='__main__':unittest.main()
