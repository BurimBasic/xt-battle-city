"""Compatibility checks: v0.33's low-cost speaker/AdLib interfaces survive
the public-domain melody and OPL2 hardware-noise sound rework in v0.34."""
from pathlib import Path
import unittest
ROOT=Path(__file__).resolve().parents[1]
T=(ROOT/"src/dos/tanks.S").read_text()
F=(ROOT/"src/dos/sound_v34.inc").read_text()
INTRO=(ROOT/"src/dos/title_v32.inc").read_text()

class Sound33Compat(unittest.TestCase):
 def test_speaker_still_very_short_and_nonblocking(self):
  game=T.split("sound_play:",1)[1].split("/* A full brick starts",1)[0]
  for phrase in ("mov byte ptr [sound_ticks],1","mov byte ptr [sound_ticks],2",
                 "out 0x43,al","out 0x42,al","out 0x61,al","and al,0xfc",
                 "call sound_stop"):
   self.assertIn(phrase,game)
  self.assertNotIn("int 0x21",game)
  self.assertNotIn("rep ",game)
  self.assertNotIn("out 0x42",F)
  self.assertNotIn("out 0x61",F)

 def test_fm_effects_remain_separate_from_music(self):
  self.assertIn("sound33_opl0:",T)
  self.assertIn("mov ax,0xb010",T)
  self.assertIn("mov ax,0xb02d",T)
  self.assertIn("mov ax,0xb00d",T)
  self.assertIn("mov ax,0xa040",T)
  self.assertIn("cmp byte ptr [adlib_present],0",T)
  self.assertIn("call sound34_rhythm_setup",T)
  writer=T.split("adlib_write:",1)[1].split("/* v0.33:",1)[0]
  for phrase in ("mov dx, 0x0388","in al, dx","out dx, al"):
   self.assertIn(phrase,writer)

 def test_any_key_stops_fm_and_does_not_change_movement_speed(self):
  self.assertIn("call music33_start",INTRO)
  self.assertIn("call music33_tick",INTRO)
  self.assertIn("title32_done:\n    call music33_stop",INTRO)
  self.assertIn("cmp byte ptr [title32_frame],112",INTRO)
  self.assertIn("cmp byte ptr [title32_frame],74",INTRO)
  self.assertIn("test byte ptr [title32_frame],1\n    jnz title32_stationary",INTRO)
  self.assertIn("mov byte ptr [title32_skip],1",INTRO)
  self.assertIn("music33_active: .byte 0",F)
  self.assertIn("mov ax,0xb112",F)
  self.assertIn("mov ax,0xb20d",F)
  self.assertIn("mov ax,0xbd20",F)
  self.assertIn('.include "src/dos/sound_v34.inc"',T)

if __name__=="__main__":unittest.main()
