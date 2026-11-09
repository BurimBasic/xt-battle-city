"""Source-level invariants for the physical congestion breaker."""
import unittest
from pathlib import Path
R=Path(__file__).resolve().parents[1]
T=(R/'src/dos/tanks.S').read_text()
A=(R/'src/dos/tactics.inc').read_text()

class CongestionTests(unittest.TestCase):
    def test_dynamic_hulls_block_route_probe(self):
        probe=A[A.index('tactical_enemy_probe6:'):A.index('tactical_enemy_evade:')]
        self.assertIn('tactical_probe_actor:',probe)
        self.assertIn('enemy_px+si',probe)
        self.assertIn('enemy_py+si',probe)
        self.assertIn('player_px',probe)
        self.assertIn('player_py',probe)
        self.assertIn('pop si',probe)
        self.assertIn('mov byte ptr [test_phase],56',T)
    def test_yield_when_repeatedly_blocked(self):
        self.assertIn('cmp byte ptr [enemy_blocked+bx],6',A)
        self.assertIn('xor al,2',A)
        self.assertIn('mov byte ptr [test_phase],57',T)
        self.assertIn('call tactical_enemy_turn',T)
    def test_player_moves_to_forward_sentry(self):
        self.assertIn('cmp byte ptr [player_py],120',A)
        self.assertIn('mov byte ptr [test_phase],58',T)
        self.assertIn('tactical_player_guard:',A)

if __name__=='__main__':unittest.main()
