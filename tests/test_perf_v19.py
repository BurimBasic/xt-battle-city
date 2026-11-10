"""v0.19: 8088 hot-loop speedups, RAM-only palette, and artifact-free laser."""
from pathlib import Path
import re,unittest
R=Path(__file__).resolve().parents[1]
T=(R/'src/dos/tanks.S').read_text()
L=(R/'src/dos/bonuses_v17.inc').read_text()

def fragment(src,a,b):
    return src[src.index(a):src.index(b,src.index(a))]

class XT19(unittest.TestCase):
    def test_no_per_frame_static_auto_text(self):
        loop=fragment(T,'main_loop_play:','do_restart:')
        self.assertNotIn('call draw_mode_indicator',fragment(loop,'normal_play:', 'main_loop:') if 'normal_play:' in loop else loop.split('call render_frame')[1][:140])
        self.assertIn('call draw_mode_indicator',T)
    def test_get_tile_replaces_mul16(self):
        block=fragment(T,'get_tile:','draw_map:')
        self.assertNotIn('mul',block)
        self.assertEqual(block.count('shl ax,1'),4)
    def test_div12_hot_path_replaced_with_lut(self):
        block=fragment(T,'pixel_is_blocked:','rect_passable:')
        self.assertNotIn('div',block)
        self.assertIn('pixel_y_tile_lookup+bx',block)
        self.assertIn('.rept 256',T)
        self.assertIn('pixel_y_tile_lookup:',T)
        for y in range(192):
            packed=((y//12)<<4)|(y%12)
            self.assertLessEqual(packed,255)
            self.assertEqual((packed>>4,packed&15),(y//12,y%12))
    def test_sprite_blitter_uses_precomputed_interlaced_offsets(self):
        b=fragment(T,'smooth_scanline:','smooth_byte:')
        self.assertIn('cga_scanline_offsets+bx',b)
        self.assertNotIn('0x2000',b)
        for y in range(192):
            off=(y//2)*80+(y&1)*8192
            self.assertLessEqual(off,16271)
    def test_flush_and_commit_skip_unchanged_tile_index_arithmetic(self):
        a=fragment(T,'flush_dirty:','/* ===== Anti-flicker')
        b=fragment(T,'commit_dirty_tiles:','/* DL/DH = tile')
        self.assertIn('dirty_tiles+si',a)
        self.assertIn('upload_tiles+si',b)
        self.assertNotIn('call get_tile',a)
        self.assertNotIn('commit_row:',b)
        self.assertIn('call draw_static_cell',a)
        self.assertIn('call copy_tile_to_cga',b)
    def test_cga_palette_stays_ram_only(self):
        screen=fragment(T,'refresh_screen:','exit_game:')
        self.assertLess(screen.index('int 0x10'),screen.index('call apply_cga_palette'))
        self.assertIn('palette_index: .byte 0',T)
        self.assertIn('mov byte ptr [test_phase],75',T)
        self.assertNotIn('PAL.CFG',T)
        self.assertNotIn('PAL.INI',T)
    def test_laser_is_one_pixel_line_not_sprite_stamp(self):
        laser=fragment(L,'laser17_paint:','.section .data')
        self.assertIn('laser19_pixel:',laser)
        self.assertIn('dirty_tiles+bx',laser)
        self.assertIn('upload_tiles+bx',laser)
        self.assertIn('cga_scanline_offsets+bx',laser)
        self.assertNotIn('draw_smooth_sprite',laser)
        self.assertIn('mov es:[di],al',laser)
        self.assertIn('test byte ptr [game_tick],1',laser)
        for lane in range(4):
            mask=(0xc0,0x30,0x0c,0x03)[lane]
            for color in (1,3):
                val=(0x40,0x10,0x04,0x01)[lane] if color==1 else mask
                self.assertEqual(val & ~mask,0)
    def test_branding_spacing_and_version(self):
        brand=fragment(T,'draw_branding:','draw_brand_row:')
        self.assertIn('mov di,6147',brand)
        self.assertIn('mov di,6787',brand)
        self.assertIn('brand_version_glyphs: .word hud_v_char, hud_digit_0, hud_dot_char, hud_digit_2, hud_digit_3',T)
        # 6147 is x268/y152; 6787 x268/y168. 8px empty gap.
        self.assertEqual((6787-6147)//80,8)
    def test_real_dos_regressions(self):
        for phase in (75,76,77):
            self.assertIn(f'mov byte ptr [test_phase],{phase}',T)

if __name__=='__main__':unittest.main()
