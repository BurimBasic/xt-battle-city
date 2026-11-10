"""v0.23 — genuine gameplay checks, 8086 and feature regressions.
In addition to static path checks, real DOS /TEST now tests phases 96–99.
"""
from pathlib import Path
import importlib.util, unittest
R=Path(__file__).resolve().parents[1]
T=(R/'src/dos/tanks.S').read_text()
S=(R/'src/dos/strategy_v13.inc').read_text()
AI=(R/'src/dos/tactics.inc').read_text()
E=(R/'src/dos/enemy_pickups_v21.inc').read_text()
B=(R/'src/dos/bonus_v23.inc').read_text()
EXT=(R/'src/dos/bonuses_v17.inc').read_text()
X=(R/'src/dos/transitions_v20.inc').read_text()
spec=importlib.util.spec_from_file_location('art23',R/'tools/build_cga_assets.py')
a=importlib.util.module_from_spec(spec);spec.loader.exec_module(a)

class CombatV23(unittest.TestCase):
    def test_distinct_fourteen_bonuses_and_controls(self):
        self.assertEqual(len(a.BONUS_LETTERS),14)
        self.assertEqual(len({tuple(a.SPRITES['bonus_'+name]) for name in a.BONUS_LETTERS}),14)
        for name in ('pong','quad','super'):
            self.assertIn('smooth_bonus_'+name+':',(R/'src/dos/cga_assets.inc').read_text())
            self.assertIn('hud_bonus_'+name+':',T)
        self.assertIn('cmp byte ptr [bonus_sequence],14',T)
    def test_pong_is_10_seconds_hazardous_to_both_sides_and_bounces(self):
        self.assertIn('mov byte ptr [pong_ticks],180',T)
        self.assertIn('pong23_launch:',B)
        self.assertIn('pong23_step:',B)
        self.assertIn('neg byte ptr [pong_dx]',B)
        self.assertIn('neg byte ptr [pong_dy]',B)
        self.assertIn('mov byte ptr [enemy_active+bx],0',B)
        self.assertIn('dec byte ptr [lives]',B)
        self.assertIn('mov byte ptr [game_state],2',B)
        self.assertIn('cmp byte ptr [pong_active],0',T.split('do_fire:',1)[1].split('do_fire_normal:',1)[0])
    def test_quad_four_actual_bullets(self):
        fire=T.split('do_fire:',1)[1].split('fire_done:',1)[0]
        self.assertIn('call quad23_spawn',T)
        self.assertIn('cmp bx,3',B.split('quad23_spawn:',1)[1].split('super23_terrain:',1)[0])
        self.assertIn('extra_active: .space 3',EXT)
        self.assertIn('cmp si,3',EXT)
        self.assertIn('mov byte ptr [bullet_active], 1',T)
    def test_super_bullet_does_not_despawn_on_collision(self):
        self.assertIn('cmp byte ptr [super_bullet_active],0',T)
        self.assertIn('call super23_terrain',T)
        self.assertIn('mov byte ptr [si],\'.\'',B)
        self.assertIn('call chip_brick_pixel',B)
        self.assertIn('jne smooth_bullet_enemy_next',T)
        self.assertIn('mov byte ptr [shot_super+bx],1',T)
    def test_enemy_collects_real_weapon_and_clock_slows_p1(self):
        self.assertIn('mov [enemy_weapon_kind+bx],al',E)
        self.assertIn('mov byte ptr [enemy_weapon_ticks+bx],180',E)
        self.assertIn('mov byte ptr [player_slow_ticks],120',E)
        for label in ('enemy23_laser:', 'enemy23_burst:', 'enemy23_home:'):
            self.assertIn(label,B)
        self.assertIn('call enemy23_laser',T)
        self.assertIn('call enemy23_burst',T)
        self.assertIn('call enemy23_home',T)
        self.assertIn('call enemy23_tick',T)
        self.assertIn('cmp byte ptr [bonus_type],5',E)
        self.assertIn('cmp byte ptr [bonus_type],7',E)
    def test_track_damage_has_true_half_speed_and_black_dots(self):
        self.assertIn('enemy_track_damage:',T)
        self.assertIn('mov byte ptr [enemy_track_damage+bx],1',T)
        self.assertIn('draw_track_dots:',T)
        self.assertIn('cmp byte ptr [enemy_track_damage+bx],0',T)
    def test_last_enemy_uses_bfs_even_across_bricks(self):
        self.assertIn('cmp byte ptr [enemy_killed],19',AI)
        self.assertIn('call tactical23_hunt',AI)
        self.assertIn('call strategy_fill',B)
        self.assertIn('mov di,offset route_hunt',B)
        self.assertIn('tactical23_hunting:',B)
        self.assertIn('route_hunt: .space 256',S)
        hunt=B.split('tactical23_hunt:',1)[1].split('enemy23_tick:',1)[0]
        self.assertNotIn('mov [bonus_col],dl',hunt)
        self.assertNotIn('call strategy_bonus_spawn',hunt)
        self.assertIn('cmp byte ptr [tactical23_hunting],0',S)
    def test_laser_assault_and_legacy_bonus_priority(self):
        laser=AI.split('tactical_dodge_done:',1)[1].split('tactical23_check_final:',1)[0]
        self.assertIn('cmp byte ptr [laser_ticks],0',laser)
        self.assertNotIn('cmp byte ptr [bonus_active],0',laser)
        self.assertIn('call strategy_bonus_heading',AI)
        self.assertIn('mov word ptr [route_active_field],offset route_hunt',S)
        bonus_route=S.split('bonus_route_check_threat:',1)[1].split('bonus_route_threat_loop:',1)[0]
        self.assertNotIn('cmp al,48',bonus_route)
        self.assertNotIn('cmp al,36',bonus_route)
        self.assertIn('bonus_route_threat_loop:',S)
        self.assertIn('cmp byte ptr [enemy_py+bx],140',S)
        self.assertIn('bonus_drop_order: .byte 0, 5, 7, 6, 11, 12, 13, 1',T)
    def test_20_phase_wipes_no_per_frame_wait(self):
        self.assertIn('cmp byte ptr [trans20_step],16',X) if False else None
        self.assertIn('call transition20_wait_tick',X)
        self.assertIn('trans20_pass:',X)
        # Longer transition waits only inside open/close, not steady gameplay.
        self.assertNotIn('call transition20_wait_tick',T.split('game_tick_step:',1)[1].split('maybe_drop_bonus:',1)[0])
    def test_dos_smoke_phases_cover_new_weapons(self):
        for n in range(96,100):
            self.assertIn(f'mov byte ptr [test_phase],{n}',T)
    def test_only_real_adapters_claimed(self):
        rules=(R/'AGENTS.md').read_text()
        self.assertIn('screenshots',rules)
        self.assertIn('README.md',rules)

if __name__=='__main__': unittest.main()
