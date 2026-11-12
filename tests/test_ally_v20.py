"""v0.20 companion calls, stock/life integrity, 15s AI ally and bounded wipes."""
from pathlib import Path
import unittest

ROOT=Path(__file__).resolve().parents[1]
T=(ROOT/"src/dos/tanks.S").read_text()
A=(ROOT/"src/dos/ally_v20.inc").read_text()
B=(ROOT/"src/dos/bonuses_v17.inc").read_text()
W=(ROOT/"src/dos/transitions_v20.inc").read_text()
RULES=(ROOT/"AGENTS.md").read_text()

def body(source,start,stop):
    return source.split(start,1)[1].split(stop,1)[0]

class AllyAndTransitions(unittest.TestCase):
    def test_free_token_and_campaign_scope(self):
        self.assertIn("mov byte ptr [ally_stock],1",body(T,"reset_campaign:","load_stage:"))
        self.assertNotIn("mov byte ptr [ally_stock]",body(T,"load_stage:","poll_keyboard:"))
        self.assertIn("ally_stock: .byte 1",T)
        self.assertIn("cmp byte ptr [ally_stock],9",A)
    def test_v_keyboard_is_latched_by_irq(self):
        self.assertIn("cmp al,0x2f",body(T,"keyboard_irq:","irq_up:"))
        self.assertIn("or byte ptr [ally_call_pending],1",T)
        self.assertIn("mov dl,[ally_call_pending]",T)
        self.assertIn("call ally20_try_call",body(T,"poll_controls:","cycle_cga_palette:"))
    def test_can_not_spend_last_life(self):
        c=body(A,"ally20_try_call:","ally20_collect:")
        self.assertIn("cmp byte ptr [lives],1",c)
        self.assertIn("jbe ally20_done",c)
        self.assertIn("call ally17_spawn",c)
        self.assertLess(c.index("call ally17_spawn"),c.index("dec byte ptr [lives]"))
        self.assertIn("mov byte ptr [ally_life_flash],18",c)
    def test_timed_companion_lasts_15_seconds_and_is_damageable(self):
        self.assertIn("mov word ptr [ally_ticks],270",B)
        self.assertIn("dec word ptr [ally_ticks]",B)
        self.assertIn("cmp word ptr [ally_ticks],0",T)
        self.assertIn("mov word ptr [ally_ticks],0",T)
        self.assertIn("call extra17_ally_fire",B)
        self.assertIn("call ally17_tick",B)
    def test_bonus_auto_immediate_and_manual_stock_only(self):
        c=body(A,"ally20_collect:","ally20_pickup:")
        self.assertIn("inc byte ptr [ally_stock]",c)
        self.assertIn("cmp byte ptr [auto_mode],0",c)
        self.assertIn("call ally20_try_call",c)
        self.assertIn("mov word ptr [ally_ticks],270",c)
        self.assertIn("call ally20_collect",T)
    def test_allied_tank_picks_up_shared_effect(self):
        self.assertIn("call ally20_pickup",body(T,"game_tick_step:","maybe_drop_bonus:"))
        self.assertIn("call bonus20_apply",A)
        self.assertEqual(T.count("bonus20_apply:"),1)
        self.assertIn("call bonus20_apply",body(T,"check_bonus_pickup:","grenade_all_enemies:"))
    def test_hud_left_icon_center_seconds_right_v_stock(self):
        h=body(T,"draw_bonus_indicator:","draw_mode_indicator:")
        for x in (3904,3908,3910,3914,3916,3918):
            self.assertIn("mov di,"+str(x),h)
        self.assertIn("mov ax,[ally_ticks]",h)
        self.assertIn("mov al,[ally_stock]",h)
        self.assertIn("mov si,offset hud_v_char",h)
        self.assertIn("test byte ptr [game_tick],2",h)
        self.assertIn("mov si,offset hud_x_char",h)
    def test_companion_spawn_at_hq_and_no_player_overlap(self):
        self.assertIn("ally20_spawn_x: .byte 112,96,128,112",B)
        self.assertIn("ally20_spawn_y: .byte 144,144,144,132",B)
        self.assertIn("call rect_passable",B)
        self.assertIn("sub al,[player_px]",B)
        self.assertIn("sub al,[player_py]",B)
    def test_3_original_transition_styles_only_stage_boundaries(self):
        for tag in ("transition20_open:","transition20_close:","transition20_blank_field:","transition20_blank_tile:","transition20_wait_tick:"):
            self.assertIn(tag,W)
        self.assertIn("cmp byte ptr [trans20_style],2",W)
        self.assertIn("call copy_tile_to_cga",W)
        self.assertIn("call transition20_blank_tile",W)
        self.assertIn("call transition20_close",T)
        self.assertIn("call transition20_open",T)
        game=body(T,"game_tick_step:","maybe_drop_bonus:")
        self.assertNotIn("transition20",game)
    def test_respects_cassette_and_baseline_speed(self):
        self.assertIn("40.051 seconds",RULES)
        self.assertIn("384",RULES)
        self.assertIn("240 cycles/ms",RULES)
        self.assertIn("5% regression",RULES)
        self.assertIn("cannot depend on files",RULES)
        self.assertIn("57344",RULES.replace(",",""))
    def test_dos_real_mode_tests_to_88(self):
        for i in range(79,89):
            self.assertIn("mov byte ptr [test_phase],"+str(i),T)
    def test_version_footer(self):
        self.assertIn("brand_version_glyphs: .word hud_v_char, hud_digit_0, hud_dot_char, hud_digit_2, hud_digit_7",T)

if __name__=="__main__":
    unittest.main()
