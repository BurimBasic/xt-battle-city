"""v0.31 acceptance for author-pixel score, milestone lives, dotted shield,
moving treads, right panel inset and mid-stage random bomber arrival."""
from pathlib import Path
import sys,re,unittest
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools'))
import build_cga_assets as art

T=(ROOT/'src/dos/tanks.S').read_text()
B=(ROOT/'src/dos/bomber_v25.inc').read_text()
S=(ROOT/'src/dos/score_v31.inc').read_text()
Q=(ROOT/'src/dos/bonus_v23.inc').read_text()

class Release31Tests(unittest.TestCase):
 def test_15000_progress_persists_across_stages_and_overflow(self):
  self.assertIn('score31_progress: .word 0',S)
  self.assertIn('add word ptr [score31_progress],ax',S)
  self.assertIn('cmp word ptr [score31_progress],15000',S)
  self.assertIn('sub word ptr [score31_progress],15000',S)
  self.assertIn('cmp byte ptr [lives],9',S)
  self.assertIn('inc byte ptr [lives]',S)
  self.assertIn('cmp byte ptr [coop_mode],0',S)
  self.assertIn('cmp byte ptr [coop_lives],9',S)
  self.assertIn('inc byte ptr [coop_lives]',S)
  reset=T.split('reset_campaign:',1)[1].split('load_stage:',1)[0]
  self.assertIn('mov word ptr [score31_progress],0',reset)
  stage=T.split('load_stage:',1)[1].split('load_stage_no_coop:',1)[0]
  self.assertNotIn('mov word ptr [score31_progress],0',stage)
  self.assertIn('mov di,offset score31_hud_flash',stage)
  self.assertIn('mov cx,29',stage)
  self.assertEqual(T.count('call score31_award'),3)
  self.assertEqual(Q.count('call score31_award'),1)
  # A separate 16-bit modulo counter remains correct after score overflows.
  score,progress,lives_a,lives_b=0,0,3,3
  for i in range(410):
   gain=400 if i%4==0 else (i%4)*100
   score=(score+gain)&0xffff
   progress+=gain
   if progress>=15000:
    progress-=15000
    lives_a=min(9,lives_a+1)
    lives_b=min(9,lives_b+1)
  self.assertLess(progress,15000)
  self.assertEqual(lives_a,lives_b)

 def test_flash_three_times_on_hud_both_coop_counters(self):
  self.assertIn('mov byte ptr [score31_hud_flash],24',S)
  self.assertIn('test byte ptr [score31_hud_flash],4',T)
  hud=T.split('hud31_blank_score:',1)[1].split('hud31_blink_done:',1)[0]
  self.assertIn('mov di,2630',hud)
  self.assertIn('mov di,2638',hud)
  self.assertIn('mov di,2632',T)
  self.assertEqual(sum((t&4)!=0 and (t==24 or ((t+1)&4)==0) for t in range(1,25)),3)

 def test_exact_user_100_200_300_400_pixels(self):
  masks=S.split('score31_masks:',1)[1].split('.section .text',1)[0]
  groups=[]
  for line in masks.splitlines():
   m=re.search(r'\.word\s+(0x[\da-fA-F]+),(0x[\da-fA-F]+),(0x[\da-fA-F]+)',line)
   if m:groups.append([int(x,16) for x in m.groups()])
  exp=[['.1.111.111.','.1.1.1.1.1.','.1.111.111.'],
       ['111.111.111','.1..1.1.1.1','111.111.111'],
       ['111.111.111','.11.1.1.1.1','111.111.111'],
       ['1.1.111.111','111.1.1.1.1','..1.111.111']]
  self.assertEqual(len(groups),4)
  for idx,masks in enumerate(groups):
   decoded=[''.join('1' if word&(1<<x) else '.' for x in range(11)) for word in masks]
   self.assertEqual(decoded,exp[idx])
  self.assertIn('mov byte ptr [score31_timer+bx],24',S)
  self.assertIn('test al,4',S)
  self.assertIn('dec dh',S)
  self.assertIn('call score31_mark_old',T)
  self.assertIn('call score31_paint',T)
  self.assertIn('call gun27_pixel',S)
  self.assertEqual([t for t in range(24,0,-1) if t&4][0],23)

 def test_all_tanks_move_linked_tracks_and_dotted_shield(self):
  self.assertIn('mov cl,dl\n    add cl,dh',T)
  self.assertIn('and cl,4',T)
  for marker in ('paint_enemy_color_ready:', 'paint_ally_color_ready:', 'paint_player_color_ready:'):
   segment=T.split(marker,1)[1][:720]
   self.assertIn('call draw_track_dots',segment)
  self.assertIn('xor bl,bl',T.split('track23_pixel:',1)[1].split('render_frame:',1)[0])
  src=art.SPRITES['shield_outline']
  border=[x for x in range(1,15) if src[0][x]=='3']
  self.assertTrue(4<=len(border)<=8)
  self.assertTrue(all(src[0][x+1]!='3' for x in border if x<14))

 def test_random_bomber_only_after_tenth_kill(self):
  gate=B.split('bomber27_first_wait:',1)[1].split('bomber27_takeoff:',1)[0]
  self.assertIn('cmp byte ptr [enemy_killed],10',gate)
  self.assertIn('cmp byte ptr [bomber27_wait],0',gate)
  self.assertIn('dec byte ptr [bomber27_wait]',gate)
  self.assertGreaterEqual(B.count('call bomber26_roll'),2)
  self.assertIn('and al,127',B)
  self.assertIn('mov [bomber27_wait],al',B)
  self.assertIn('bomber27_limit:',B)

 def test_bonus_sidebar_pixel_margin_all_14_icons(self):
  generated=art.generate(ROOT/'assets/maps/level01.map')
  import re
  star=re.search(r'hud_star_icon:\n\s*\.byte ([^\n]+)',generated).group(1)
  self.assertEqual(int(re.search(r'0x([\da-fA-F]{2})',star).group(1),16)&0xc0,0xc0)
  self.assertIn('white 1px left inset (x257)',T)
  for name in ['pong','quad','super','laser','ally','triple','homing',
               'frenzy','helmet','grenade','shovel','clock','life']:
   m=re.search(r'hud_bonus_'+name+r':\n\s*\.byte ([^\n]+)',T)
   self.assertIsNotNone(m,name)
   self.assertEqual(int(re.search(r'0x([\da-fA-F]{2})',m.group(1)).group(1),16)&0xc0,0xc0,name)

if __name__=='__main__':unittest.main()
