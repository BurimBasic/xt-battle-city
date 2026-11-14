"""v0.32 exactly clipped 12x12 treads and native, any-key title sequence."""
from pathlib import Path
import sys,re,unittest
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools'))
from approved_art_v030 import ART,directions
T=(ROOT/'src/dos/tanks.S').read_text()
INTRO=(ROOT/'src/dos/title_v32.inc').read_text()

class V32Tests(unittest.TestCase):
 def test_all_160_tread_marks_inside_actual_opaque_user_pixels(self):
  # Simulate the actual four-pixel assembly coordinate choices, for both
  # phases, every class, and all four mathematically rotated art matrices.
  for name in ('player','light','medium','assault','heavy'):
   span=8 if name in ('light','assault') else 9
   for heading,frame in enumerate(directions(name)):
    for phase in (0,1):
     if heading==0:
      pts=[(3,4+phase),(3,7+phase),(3+span,4+phase),(3+span,7+phase)]
     elif heading==2:
      left=4 if span==8 else 3
      pts=[(left,3+phase),(left,6+phase),(left+span,3+phase),(left+span,6+phase)]
     elif heading==1:
      pts=[(6-phase,1),(9-phase,1),(6-phase,1+span),(9-phase,1+span)]
     else:
      top=2 if span==8 else 1
      pts=[(6+phase,top),(9+phase,top),(6+phase,top+span),(9+phase,top+span)]
     for x,y in pts:
      self.assertTrue(2<=x<=13 and 0<=y<12,(name,heading,phase,x,y))
      self.assertNotEqual(frame[y][x],'.',(name,heading,phase,x,y))
  self.assertIn('mov ah,[enemy_type+bx]',T)
  self.assertIn('or ah,[enemy_track_damage+bx]',T)
  self.assertIn('mov byte ptr [track32_span],9',T)
  self.assertIn('cmp ah,2',T)
  self.assertIn('cmp ah,6',T)
  self.assertIn('mov cl,dl\n    add cl,dh',T)
  self.assertNotIn('add dh,9\n    call track23_pixel',T)

 def test_intro_has_complete_controls_and_40_column_bios_text(self):
  strings=re.findall(r'^title32_help\d+: \.asciz "([^"]+)"$',INTRO,re.M)
  self.assertEqual(len(strings),7)
  for text in strings:self.assertLessEqual(len(text),40)
  full=' '.join(strings)
  for key in ('ARROWS','SPACE','WASD','CTRL','TAB','AUTO/MAN','V ALLY',
              'P PAUSE','PGUP/PGDN','C PALETTE','M SOUND','R RESTART','ESC EXIT'):
   self.assertIn(key,full,key)
  self.assertIn('title32_copyright: .asciz "1982 BURIM"',INTRO)
  self.assertIn('ANY KEY TO START',INTRO)
  self.assertIn('title32_font:',INTRO)
  fonts=INTRO.split('title32_font:',1)[1].split('title32_lines:',1)[0]
  self.assertEqual(sum(len(re.findall(r'\b\d+\b',line)) for line in fonts.splitlines() if '.byte' in line),35)

 def test_approach_fires_explodes_and_any_key_skips_before_irq_install(self):
  self.assertIn('call title32_intro\n    call refresh_screen\n    call install_keyboard',T)
  self.assertIn('title32_loop:',INTRO)
  self.assertIn('mov ah,1\n    int 0x16',INTRO)
  self.assertIn('xor ah,ah\n    int 0x16',INTRO)
  self.assertIn('mov byte ptr [title32_skip],1',INTRO)
  self.assertIn('cmp byte ptr [title32_frame],57',INTRO)
  self.assertIn('call title32_projectiles',INTRO)
  self.assertIn('call title32_burst',INTRO)
  self.assertIn('add byte ptr [title32_x1],2',INTRO)
  self.assertIn('sub byte ptr [title32_x2],2',INTRO)
  self.assertIn('mov si,[smooth_player_ptrs+2]',INTRO)
  self.assertIn('mov si,[smooth_enemy_ptrs+6]',INTRO)
  self.assertIn('cmp byte ptr [title32_skip],0',T)
  self.assertIn('mov byte ptr [title32_skip],0',T)

 def test_no_title_rendering_in_game_ticks_and_memory_safety(self):
  tick=T.split('game_tick_step:',1)[1].split('/*',1)[0]
  self.assertNotIn('title32_',tick)
  self.assertIn('mov word ptr [frame_seg],0xb800',INTRO)
  self.assertIn('mov [frame_seg],ax',INTRO)
  self.assertIn('bss_start:',T)
  self.assertIn('bss_end:',T)
  self.assertIn('program_end:',T)
  self.assertIn('mov cx,offset bss_end-bss_start',T)
  self.assertIn('rep stosb',T)
  for name in ('brick_masks','dirty_tiles','upload_tiles','level_data'):
   self.assertIn(name+': .space 256',T)
  self.assertIn('.include "src/dos/title_v32.inc"',T)

if __name__=='__main__':unittest.main()
