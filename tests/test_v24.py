"""v0.24 cooperative play, only-damaged-armour graphics, AI escape and stolen weapons."""
from pathlib import Path
import unittest
ROOT=Path(__file__).resolve().parents[1]
T=(ROOT/'src/dos/tanks.S').read_text()
B=(ROOT/'src/dos/bonuses_v17.inc').read_text()
A=(ROOT/'src/dos/ally_v20.inc').read_text()
E=(ROOT/'src/dos/enemy_pickups_v21.inc').read_text()
W=(ROOT/'src/dos/bonus_v23.inc').read_text()
C=(ROOT/'src/dos/coop_v24.inc').read_text()
L=(ROOT/'src/dos/anti_loop_v24.inc').read_text()
TACT=(ROOT/'src/dos/tactics.inc').read_text()

class NewFeaturesV24(unittest.TestCase):
    def test_hud_only_damaged_armour_black_treads(self):
        renderer=T.split('paint_enemy_selected:',1)[1].split('paint_enemy_next:',1)[0]
        self.assertIn('cmp byte ptr [enemy_type+bx],3',renderer)
        self.assertIn('cmp byte ptr [enemy_track_damage+bx],0',renderer)
        self.assertIn('call draw_track_dots',renderer)
        player=T.split('paint_player_normal:',1)[1].split('paint_no_bullet:',1)[0]
        self.assertNotIn('call draw_track_dots',player)
        self.assertNotIn('or al,[laser19_color3+bx]',T.split('track23_pixel:',1)[1].split('render_frame:',1)[0])
    def test_true_half_speed_for_cracked_armour(self):
        segment=T.split('move_enemies_smooth:',1)[1].split('choose_enemy_turn:',1)[0]
        self.assertIn('cmp byte ptr [enemy_type+bx], 3',segment)
        self.assertIn('cmp byte ptr [enemy_track_damage+bx],0',segment)
        self.assertIn('test byte ptr [game_tick],3',segment)
    def test_keyboard_p2_wasd_ctrl_does_not_takeover_p1(self):
        irq=T.split('keyboard_irq:',1)[1].split('irq_ack:',1)[0]
        for sc in ('0x11','0x1e','0x1f','0x20','0x1d'):
            self.assertIn('cmp al,'+sc,irq)
        self.assertIn('call coop24_key_event',irq)
        self.assertIn('call coop24_join',T.split('poll_controls:',1)[1].split('cycle_cga_palette:',1)[0])
        self.assertIn('or byte ptr [coop_keys],ah',C)
        self.assertIn('mov byte ptr [auto_mode],0',C)
        self.assertIn('cmp byte ptr [coop_mode],0',T.split('controls_no_ally_call:',1)[1].split('controls_no_auto_toggle:',1)[0])
    def test_coop_independent_lives_movement_firing(self):
        self.assertIn('mov byte ptr [coop_lives],3',C)
        self.assertIn('mov byte ptr [lives],3',C)
        self.assertIn('mov word ptr [ally_ticks],0x7fff',C)
        self.assertIn('call coop24_pixel',C)
        self.assertIn('call extra17_ally_fire',C)
        self.assertIn('call advance_enemy_shot_smooth',T)
        self.assertIn('call coop25_hit_p2',T)
        self.assertIn('cmp byte ptr [coop_lives],0',T)
        self.assertIn('call coop24_tick',T)
        self.assertIn('call coop24_pickup',A)
    def test_no_automated_ally_in_coop_and_half_drops(self):
        self.assertIn('cmp byte ptr [coop_mode],0',A.split('ally20_try_call:',1)[1].split('ally20_spawn:',1)[0])
        self.assertIn('cmp byte ptr [coop_mode],0',B.split('b21_no_shield:',1)[1].split('b17_done:',1)[0])
        self.assertIn('cmp byte ptr [coop_mode],0',T.split('bonus21_check_due:',1)[1].split('bonus21_drop_due:',1)[0])
        self.assertIn('jne bonus21_drop_done',T)
    def test_life_row_p1_and_p2_and_coop_status(self):
        hud=T.split('draw_hud:',1)[1].split('draw_bonus_indicator:',1)[0]
        for pos in (2624,2626,2628,2630,2632,2634,2636,2638):
            self.assertIn('mov di,'+str(pos),hud)
        self.assertIn('tactical_coop_glyphs:',T)
        self.assertIn('bonus24_coop_hud:',T)
        self.assertIn('brand_version_glyphs: .word hud_v_char, hud_digit_0, hud_dot_char, hud_digit_2, hud_digit_6',T)
    def test_enemy_laser_is_real_and_visible(self):
        self.assertIn('mov [enemy_weapon_kind+bx],al',E)
        self.assertIn('mov byte ptr [enemy_weapon_ticks+bx],180',E)
        fire=T.split('enemy_fire_cycle:',1)[1].split('do_fire:',1)[0]
        self.assertIn('call enemy23_laser',fire)
        self.assertIn('cmp byte ptr [enemy_weapon_ticks+bx],0',fire)
        self.assertIn('jne enemy_fire_now',fire)
        self.assertIn('mov byte ptr [laser_flash_ticks],7',W)
        self.assertIn('call advance_enemy_shot_smooth',W)
        self.assertIn('mov byte ptr [test_phase],105',T)
    def test_two_way_action_history_works_for_own_tank_and_foes(self):
        self.assertIn('call tactical24_player_unloop',TACT)
        self.assertIn('call tactical24_enemy_unloop',TACT)
        self.assertIn('cmp dl,[p_loop_prev]',L)
        self.assertIn('cmp dl,[enemy_loop_prev+bx]',L)
        self.assertIn('call tactical_player_path_open',L)
        self.assertIn('call tactical_enemy_probe6',L)
        self.assertIn('mov byte ptr [enemy_escape_ticks+bx],3',L)
        self.assertIn('call tactical24_reset',T)
    def test_dos_smoke_has_real_coop_and_enemy_laser(self):
        for i in range(100,110):
            self.assertIn(f'mov byte ptr [test_phase],{i}',T)
        self.assertIn('call coop24_join',T)
        self.assertIn('call coop24_key_event',T)
        self.assertIn('call enemy21_collect_bonus',T)
        self.assertIn('cmp byte ptr [laser_flash_ticks],7',T)

if __name__=='__main__':unittest.main()
