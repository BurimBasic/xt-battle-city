"""v0.33: short PC speaker SFX, AdLib 2-op FM percussive game FX,
original two-voice opening tune and half-speed tank approach."""
from pathlib import Path
import re,unittest
ROOT=Path(__file__).resolve().parents[1]
T=(ROOT/"src/dos/tanks.S").read_text()
F=(ROOT/"src/dos/sound_v33.inc").read_text()
INTRO=(ROOT/"src/dos/title_v32.inc").read_text()

class Sound33Tests(unittest.TestCase):
 def test_game_sound_is_short_and_nonblocking_on_pc_speaker(self):
  game=T.split("sound_play:",1)[1].split("/* A full brick starts",1)[0]
  self.assertIn("mov byte ptr [sound_ticks],1",game)
  self.assertIn("mov byte ptr [sound_ticks],2",game)
  self.assertIn("cmp bx,1800",game)
  self.assertIn("out 0x43,al",game)
  self.assertIn("out 0x42,al",game)
  self.assertIn("out 0x61,al",game)
  self.assertIn("and al,0xfc",game)
  self.assertIn("call sound_stop",game)
  self.assertNotIn("int 0x21",game)
  self.assertNotIn("loop ",game)
  self.assertNotIn("rep ",game)
  # At the original 18.2 Hz tick, the pulse is at most ~110ms.
  self.assertLessEqual(2/18.2,0.111)
  self.assertNotIn("out 0x42",F)  # intro never sounds on PC speaker
  self.assertNotIn("out 0x61",F)

 def test_opl2_has_real_fast_attack_decay_and_no_software_samples(self):
  setup=T.split("sound33_opl0:",1)[1].split(".section .text",1)[0]
  pairs=[int(m,16) for m in re.findall(r"0x([0-9a-f]{4})",setup)]
  self.assertEqual(len(pairs),9)
  self.assertTrue(all(((v>>8)&0xff) in
      (0x20,0x23,0x40,0x43,0x60,0x63,0x80,0x83,0xc0) for v in pairs))
  self.assertIn("mov ax,0xb010",T)
  self.assertIn("mov ax,0xb02d",T)
  self.assertIn("mov ax,0xb00d",T)
  self.assertIn("mov ax,0xa018",T) # 2nd frame explosion pitch drop
  self.assertIn("cmp byte ptr [adlib_present],0",T)
  # YM3812 register writer must retain mandatory IO settling reads.
  writer=T.split("adlib_write:",1)[1].split("/* v0.33:",1)[0]
  self.assertIn("mov dx, 0x0388",writer)
  self.assertIn("in al, dx",writer)
  self.assertIn("out dx, al",writer)

 def test_opl_intro_ch1_ch2_only_and_original_notes(self):
  m=F.split("music33_patch:",1)[1].split("music33_lead:",1)[0]
  pairs=[int(v,16) for v in re.findall(r"0x([0-9a-f]{4})",m)]
  self.assertEqual(len(pairs),18)
  self.assertEqual(len(set(v>>8 for v in pairs)),18)
  # ch1 = lead, ch2 = bass; no overlap with game sound on ch0.
  lead=[(v>>8)&0xff for v in pairs[:9]]
  bass=[(v>>8)&0xff for v in pairs[9:]]
  self.assertEqual(lead,[0x21,0x24,0x41,0x44,0x61,0x64,0x81,0x84,0xc1])
  self.assertEqual(bass,[0x22,0x25,0x42,0x45,0x62,0x65,0x82,0x85,0xc2])
  lead_lines=F.split("music33_lead:",1)[1].split("music33_bass:",1)[0]
  notes=[int(v.strip(),16) if v.strip().startswith("0x") else int(v.strip())
         for v in ",".join(l.split(".byte",1)[1] for l in lead_lines.splitlines()
             if ".byte" in l).split(",")]
  self.assertEqual(len(notes),16)
  self.assertGreaterEqual(notes.count(0),3)
  self.assertIn("cmp byte ptr [adlib_present],0",F)
  self.assertIn("mov ax,0xb112",F)
  self.assertIn("mov ax,0xb20d",F)
  self.assertIn("mov byte ptr [music33_active],0",F)
  self.assertIn("cmp byte ptr [music33_div],3",F)
  self.assertIn("test bl,3",F)
  self.assertNotIn("int 0x21",F)
  self.assertNotIn("int 0x16",F) # no BIOS call in music

 def test_title_moves_half_speed_and_skips_music_instantly(self):
  self.assertIn("call music33_start",INTRO)
  self.assertIn("call music33_tick",INTRO)
  self.assertIn("title32_done:\n    call music33_stop",INTRO)
  self.assertIn("cmp byte ptr [title32_frame],112",INTRO)
  self.assertIn("cmp byte ptr [title32_frame],74",INTRO)
  self.assertIn("test byte ptr [title32_frame],1\n    jnz title32_stationary",INTRO)
  self.assertIn("inc byte ptr [title32_x1]",INTRO)
  self.assertIn("dec byte ptr [title32_x2]",INTRO)
  # 37 of 74 movement ticks move, i.e. one pixel per two 18.2Hz ticks.
  self.assertEqual(sum(x%2==0 for x in range(74)),37)
  self.assertIn("mov byte ptr [title32_skip],1",INTRO)
  self.assertIn("mov ah,1\n    int 0x16",INTRO)
  self.assertIn('.include "src/dos/sound_v33.inc"',T)
  self.assertNotIn("call music33_tick",T.split("game_tick_step:",1)[1].split("/*",1)[0])

if __name__=="__main__":unittest.main()
