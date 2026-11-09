"""v0.12 tactical route constraints and deterministic scoring model.

The *actual* 8086 routines are tested by `TANKS.COM /TEST` phases 41–43.
This host-side test verifies the documented bounded-score invariants.
"""
from pathlib import Path
import unittest
ROOT=Path(__file__).resolve().parents[1]
AI=(ROOT/'src/dos/tactics.inc').read_text()
SRC=(ROOT/'src/dos/tanks.S').read_text()

def choice(position, goal, heading, blocked=()):
    dirs=((0,-6),(6,0),(0,6),(-6,0))
    values=[]
    for d,(dx,dy) in enumerate(dirs):
        if d in blocked:continue
        x,y=position[0]+dx,position[1]+dy
        score=abs(x-goal[0])+abs(y-goal[1])
        if d==heading and score>=4:score-=4
        if d==((heading+2)&3):score+=18
        values.append((score,d))
    return min(values)[1] if values else heading

class LookaheadTests(unittest.TestCase):
    def test_priority_route_and_obstacle_detour(self):
        self.assertEqual(choice((16,12),(200,12),1),1)
        self.assertNotEqual(choice((16,12),(200,12),1,blocked={1}),1)
    def test_reverse_penalty_avoids_ping_pong(self):
        self.assertNotEqual(choice((100,100),(100,100),1),3)
    def test_six_pixel_physical_probe_and_fallback(self):
        for item in ('tactical_route_choose:','tactical_enemy_probe6:',
                     'mov cl, 6','call rect_passable','tactical_player_probe_loop:',
                     'tactical_player_path_open:','tactical_player_leave:'):
            self.assertIn(item,AI)
        self.assertIn('call tactical_enemy_probe6',AI)
        self.assertIn('call tactical_route_choose',AI)
    def test_actual_dos_route_regressions(self):
        for item in ('mov byte ptr [test_phase],41','mov byte ptr [test_phase],42',
                     'mov byte ptr [test_phase],43',"mov byte ptr [level_data+18],'T'",
                     "mov byte ptr [level_data+18],'.'"):
            self.assertIn(item,SRC)
    def test_8088_bounded_work_and_state(self):
        self.assertIn('cmp si, 4',AI)
        self.assertIn('tactical_best_score: .word 0xffff',AI)
        self.assertNotIn('imul ',AI)
        self.assertNotIn('int 0x21',AI)
        self.assertNotIn('int 0x10',AI)

if __name__=='__main__':unittest.main()
