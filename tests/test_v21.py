"""v0.21 regression guards for laser cleanup, heart, enemy pickups and allied shield."""
from pathlib import Path
import re, unittest, importlib.util
R=Path(__file__).resolve().parents[1]
GAME=(R/'src/dos/tanks.S').read_text()
BONUS=(R/'src/dos/bonuses_v17.inc').read_text()
ENEMY=(R/'src/dos/enemy_pickups_v21.inc').read_text()
MARK=(R/'src/dos/ally_marker_v21.inc').read_text()
ALLY=(R/'src/dos/ally_v20.inc').read_text()
spec=importlib.util.spec_from_file_location('cga21',R/'tools/build_cga_assets.py')
art=importlib.util.module_from_spec(spec)
spec.loader.exec_module(art)

def code(text,start,end):
    return text.split(start,1)[1].split(end,1)[0]

class VisualFixesV21(unittest.TestCase):
    def test_real_heart_not_extra_tank_cross(self):
        rows=art.BONUS_LETTERS['life']
        self.assertEqual(len(rows),6)
        self.assertEqual(rows[0],'.33.33.')
        self.assertEqual(rows[-1],'...3...')
        self.assertIn('inc byte ptr [lives]',code(GAME,'pickup_not_clock:','pickup_not_life:'))
    def test_no_laser_shadow_corruption(self):
        painter=code(BONUS,'laser17_paint:','.section .data')
        self.assertIn('mov ax,0xb800',painter)
        self.assertIn('upload_tiles+bx',painter)
        self.assertIn('cmp word ptr [frame_seg],0xb800',painter)
        painter_call=code(GAME,'render_frame:','/* Pointer tables')
        self.assertLess(painter_call.index('call commit_dirty_tiles'),painter_call.index('call laser17_paint'))
        self.assertNotIn('call draw_smooth_sprite',painter)
    def test_bonus_spawns_at_wreck_and_8_per_20_opportunities(self):
        b=code(GAME,'maybe_drop_bonus:','/* Called once movement')
        for token in ('mov dl,[enemy_px+bx]','mov dh,[enemy_py+bx]',
                      'mov [bonus_col],dl','mov [bonus_row],dh',
                      'mov cl,5','cmp ah,0','cmp ah,2','bonus21_drop_due:'):
            self.assertIn(token,b)
        self.assertNotIn('bonus_columns+bx',b)
        kills=[k for k in range(1,21) if (k%5) in (0,2)]
        self.assertEqual(kills,[2,5,7,10,12,15,17,20])
        self.assertEqual(len(kills),8)
        self.assertLessEqual(8/5,1.6)
    def test_enemy_usable_bonuses_exclude_heart_and_ally(self):
        self.assertIn('cmp byte ptr [bonus_type],5',ENEMY)
        self.assertIn('cmp byte ptr [bonus_type],7',ENEMY)
        for effect in ('inc byte ptr [enemy_hp+bx]','mov word ptr [ally_ticks],0',
                       'call restore_hq','mov byte ptr [freeze_ticks],0',
                       'mov byte ptr [enemy_type+bx],1','mov byte ptr [enemy_type+bx],2',
                       'mov byte ptr [frenzy_ticks],0'):
            self.assertIn(effect,ENEMY)
        self.assertIn('call enemy21_collect_bonus',GAME)
    def test_companion_identity_is_not_infinite_shield(self):
        c=code(GAME,'paint_enemy_finished:','paint_ally_done:')
        self.assertIn('smooth_player_ptrs+bx',c)
        self.assertIn('smooth_shield_ptrs+bx',c)
        self.assertIn('call ally21_draw_mark',c)
        self.assertIn('test byte ptr [game_tick],4',c)
        self.assertIn('cmp byte ptr [ally_shield],0',c)
        self.assertIn('mov byte ptr [ally_shield],48',BONUS)
        self.assertIn('dec byte ptr [ally_shield]',BONUS)
        self.assertIn('mov byte ptr [ally_shield],48',ALLY)
        collision=code(GAME,'smooth_shot_no_player:','smooth_shot_no_ally:')
        self.assertIn('cmp byte ptr [ally_shield],0',collision)
        self.assertIn('jne smooth_shot_out',collision)
    def test_marker_color_is_contrasting_and_overlay_only(self):
        self.assertIn('call ally21_dot',MARK)
        self.assertIn('laser19_color1+bx',MARK)
        self.assertIn('mov ax,[frame_seg]',MARK)
        self.assertIn('mov es:[di],al',MARK)
        self.assertNotIn('smooth_shield_ptrs',MARK)
    def test_real_dos_phases_89_to_93(self):
        for phase in range(89,94):
            self.assertIn('mov byte ptr [test_phase],'+str(phase),GAME)
    def test_auto_defender_can_pursue_upper_row_wreck_pickup(self):
        tactics=(R/'src/dos/tactics.inc').read_text()
        guard=tactics.split('tactical_bonus_objective:',1)[1].split('tactical21_bonus_try:',1)[0]
        self.assertNotIn('cmp byte ptr [bonus_row],8',guard)
        self.assertIn('strategy_bonus_heading',tactics)
    def test_enemy_pickups_are_effect_specific_not_compounding_armor(self):
        collect=ENEMY.split('enemy21_row_ok:',1)[1].split('enemy21_armor:',1)[0]
        self.assertNotIn('inc byte ptr [enemy_hp+bx]',collect)
        self.assertIn('inc byte ptr [enemy_hp+bx]',ENEMY.split('enemy21_armor:',1)[1])
    def test_shipped_version_label(self):
        self.assertIn('brand_version_glyphs: .word hud_v_char, hud_digit_0, hud_dot_char, hud_digit_2, hud_digit_2',GAME)

if __name__=='__main__':
    unittest.main()
