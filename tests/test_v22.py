"""v0.22 regression checks: nearby bonus ownership, frozen AUTO, steel LOS."""
from pathlib import Path
import unittest

ROOT=Path(__file__).resolve().parents[1]
GAME=(ROOT/"src/dos/tanks.S").read_text()
TACTICS=(ROOT/"src/dos/tactics.inc").read_text()
PICKUPS=(ROOT/"src/dos/enemy_pickups_v21.inc").read_text()

class BonusFreezeSteelV22(unittest.TestCase):
    def test_p1_collects_within_one_and_half_cells_even_when_stationary(self):
        body=GAME.split("bonus_can_collect:",1)[1].split("bonus_pickup_done:",1)[0]
        self.assertIn("cmp al,24",body)
        self.assertIn("cmp al,18",body)
        self.assertIn("cmp al,dl",body)
        self.assertIn("call bonus20_apply",body)
        self.assertIn("call move_player_smooth\n    /* Pickups can appear when the tank is not moving. */\n    call check_bonus_pickup",GAME)
    def test_enemy_claims_nearby_but_not_life_or_v(self):
        self.assertIn("cmp byte ptr [bonus_type],5",PICKUPS)
        self.assertIn("cmp byte ptr [bonus_type],7",PICKUPS)
        radius=PICKUPS.split("enemy21_live:",1)[1].split("enemy21_row_ok:",1)[0]
        self.assertIn("cmp al,24",radius)
        self.assertIn("cmp al,18",radius)
        self.assertIn("xchg al,dl",radius)
        detour=TACTICS.split("tactical_enemy_plan:",1)[1].split("tactical_enemy_orders:",1)[0]
        self.assertIn("call tactical_route_choose",detour)
        self.assertIn("cmp byte ptr [bonus_type],5",detour)
        self.assertIn("cmp byte ptr [bonus_type],7",detour)
    def test_defender_pursues_upper_row_bonus(self):
        body=TACTICS.split("tactical_bonus_objective:",1)[1].split("tactical_no_bonus_route:",1)[0]
        self.assertNotIn("cmp byte ptr [bonus_row],8",body)
        self.assertIn("call strategy_bonus_heading",body)
    def test_frozen_enemy_triggers_offensive_auto(self):
        body=TACTICS.split("tactical_dodge_done:",1)[1].split("tactical_defense_orders:",1)[0]
        self.assertIn("cmp byte ptr [freeze_ticks],0",body)
        self.assertIn("call tactical_find_target",body)
        self.assertIn("call tactical_player_aim_if_aligned",body)
        self.assertIn("jmp tactical_player_steer",body)
    def test_full_ray_checks_steel_even_after_brick(self):
        body=TACTICS.split("tactical_player_line_clear:",1)[1].split("tactical_player_path_open:",1)[0]
        self.assertNotIn("cmp cl,72",body)
        self.assertNotIn("cmp al,1\n    je tactical_lane_clear",body)
        self.assertIn("mov si,offset level_data",body)
        self.assertIn("sub si,16",body)
        self.assertIn("add si,16",body)
        self.assertIn("inc si",body)
        self.assertIn("dec si",body)
        self.assertIn("cmp byte ptr [si],'T'",body)
        self.assertIn("cmp byte ptr [si],'B'",body)
        self.assertNotIn("call projectile_probe",body)
    def test_bonus_pursuit_preserves_hq_and_legacy_safe_search(self):
        flow=(ROOT/"src/dos/strategy_v13.inc").read_text()
        body=flow.split("bonus_route_check_threat:",1)[1].split("bonus_route_threat_loop:",1)[0]
        self.assertNotIn("cmp al,48",body)
        self.assertIn("whole-map BFS",body)
        threats=flow.split("bonus_route_threat_loop:",1)[1].split("bonus_route_next_threat:",1)[0]
        self.assertIn("cmp byte ptr [enemy_py+bx],140",threats)
        self.assertIn("jmp bonus_route_fail",threats)
    def test_native_8086_pickup_phases(self):
        for number in (94,95):
            self.assertIn(f"mov byte ptr [test_phase],{number}",GAME)
        self.assertIn("brand_version_glyphs: .word hud_v_char, hud_digit_0, hud_dot_char, hud_digit_2, hud_digit_3",GAME)

if __name__ == "__main__":
    unittest.main()
