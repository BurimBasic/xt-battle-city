"""Behavioral invariants for 8088 mapwide tactics (DOS /TEST phases 44-51)."""
import unittest
from pathlib import Path
from collections import deque

ROOT = Path(__file__).resolve().parents[1]
SRC = (ROOT/'src/dos/tanks.S').read_text()
AI = (ROOT/'src/dos/tactics.inc').read_text()
NAV = (ROOT/'src/dos/strategy_v13.inc').read_text()


def flood(rows, x, y):
    q = deque([(x, y)])
    dist = {(x,y): 0}
    while q:
        x,y = q.popleft()
        for xx,yy in ((x-1,y),(x+1,y),(x,y-1),(x,y+1)):
            if not (0<=xx<16 and 0<=yy<16) or (xx,yy) in dist:
                continue
            if rows[yy][xx] not in '.FIEP':
                continue
            dist[xx,yy] = dist[x,y] + 1
            q.append((xx,yy))
    return dist


class StrategicV13(unittest.TestCase):
    def test_every_stage_has_global_hq_and_flank_routes(self):
        for stage in range(1,36):
            rows = (ROOT/'assets/maps'/f'level{stage:02}.map').read_text().splitlines()
            self.assertEqual(len(rows),16)
            for goal in ((7,14),(3,11),(12,11)):
                dist=flood(rows,*goal)
                for col in (1,7,13):
                    self.assertIn((col,0),dist,(stage,goal,col))
                self.assertEqual(dist[goal],0)

    def test_true_flow_field_not_six_pixel_greedy_for_squad(self):
        self.assertIn('route_base: .space 256',NAV)
        self.assertIn('route_left: .space 256',NAV)
        self.assertIn('route_right: .space 256',NAV)
        self.assertIn('strategy_fill:', NAV)
        self.assertIn('strategy_route_heading:', NAV)
        self.assertIn('call strategy_route_heading',AI)
        self.assertIn('call strategy_tick',SRC)
        self.assertIn('call strategy_reset',SRC)
        self.assertIn('squad_phase: .byte 0',NAV)
        self.assertIn('tactical_hq_bombard:',AI)
        self.assertIn('mov byte ptr [route_dirty], 1',SRC)

    def test_never_mix_keyboard_state_with_autopilot(self):
        self.assertIn('manual_key_event:',SRC)
        self.assertIn('manual_keys: .byte 0',SRC)
        self.assertIn('mov al, [manual_keys]',SRC)
        self.assertNotIn('or [held_keys], ah',SRC)
        self.assertIn('mov byte ptr [test_phase],44',SRC)
        self.assertIn('hud_dash_char',SRC)
        self.assertIn('hud_b_char',SRC)
        self.assertIn('mov cx, 8',SRC)

    def test_allied_units_can_damage_each_other_without_player_score(self):
        hits=SRC[SRC.index('shot_hits_other_enemy:'):SRC.index('/* ========= CGA smooth engine')]
        self.assertIn('dec byte ptr [enemy_hp+si]',hits)
        self.assertIn('inc byte ptr [enemy_killed]',hits)
        self.assertIn('call tactical_safe_fire',SRC)
        self.assertIn('cmp dl,[enemy_py+bx]',AI)
        self.assertIn('cmp dl,[enemy_px+bx]',AI)
        self.assertIn('mov byte ptr [test_phase],50',SRC)
        self.assertIn('mov byte ptr [test_phase],51',SRC)

    def test_defender_has_stable_hq_position_and_persistent_target(self):
        self.assertIn('tactical_player_guard:',AI)
        self.assertIn('tactical_player_hold_and_fire:',AI)
        self.assertIn('tactical_player_target',AI)
        self.assertIn('tactical_find_priority_scan:',AI)

    def test_memory_and_isa_budget(self):
        binfile=ROOT/'build/TANKS.COM'
        if not binfile.exists():binfile=ROOT/'dist/TANKS.COM'
        if binfile.exists():self.assertLess(binfile.stat().st_size, 49152)
        self.assertIn('.code16',SRC)
        self.assertIn('strategy_v13.inc',SRC)
        self.assertEqual(SRC.count('.ifdef TRACE_BUILD'), 3)
        self.assertIn('trace_run:',SRC)
        self.assertIn('build/TANKS-TRACE.COM', (ROOT/'Makefile').read_text())

if __name__=='__main__': unittest.main()
