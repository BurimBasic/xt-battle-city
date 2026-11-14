"""v0.34: verified Korobeiniki public-domain folk notation, multi-voice FM,
YM3812's *hardware* rhythm/noise and 8086-low-load short SFX."""
from pathlib import Path
import re,unittest
ROOT=Path(__file__).resolve().parents[1]
S=(ROOT/"src/dos/sound_v34.inc").read_text()
T=(ROOT/"src/dos/tanks.S").read_text()

def bytes_under(label,stop):
 body=S.split(label+":",1)[1].split(stop+":",1)[0]
 return [int(x.strip(),16) if x.strip().startswith("0x") else int(x.strip())
         for line in body.splitlines() if ".byte" in line
         for x in line.split(".byte",1)[1].split(",") if x.strip()]
def words_under(label,stop):
 body=S.split(label+":",1)[1].split(stop,1)[0]
 return [int(x,16) for x in re.findall(r"0x([0-9a-fA-F]{4})",body)]

class FolkFM34Tests(unittest.TestCase):
 def test_actual_four_bar_public_domain_korobeiniki_abc(self):
  self.assertIn("E2 B,C D2 CB,",S)
  self.assertIn("A,2 A,C E2 DC",S)
  self.assertIn("B,3 C D2 E2",S)
  self.assertIn("C2 A,2 A,4",S)
  notes=bytes_under("music34_notes","music34_durations")
  durations=bytes_under("music34_durations","music34_freq_lo")
  self.assertEqual(notes,[4,1,2,3,2,1,0,0,2,4,3,2,1,2,3,4,2,0,0])
  self.assertEqual(durations,[6,3,3,6,3,3,6,3,3,6,3,3,9,3,6,6,6,6,12])
  self.assertEqual(len(notes),19)
  self.assertEqual(sum(durations),96)
  # All four folk bars are 24 18.2 Hz ticks = 8 eighth notes each.
  for start,end in [(0,6),(6,12),(12,16),(16,19)]:
   self.assertEqual(sum(durations[start:end]),24)
  self.assertIn("public domain",S)
  self.assertIn("NOT the protected 1989 Game Boy Tetris arrangement",S)

 def test_3_voice_music_plus_native_drum_noise(self):
  leadbass=words_under("music34_fm_patch","sound34_drum_patch:")
  self.assertEqual(len(leadbass),18)
  self.assertEqual([(x>>8) for x in leadbass[:9]],
     [0x21,0x24,0x41,0x44,0x61,0x64,0x81,0x84,0xc1])
  self.assertEqual([(x>>8) for x in leadbass[9:]],
     [0x22,0x25,0x42,0x45,0x62,0x65,0x82,0x85,0xc2])
  self.assertIn("music34_bass_state",S)
  self.assertIn("0xa2b7",S)
  self.assertIn("0xa244",S)
  self.assertIn("mov ax,0xbd31",S)  # BD + HH + RHYTHM
  self.assertIn("mov ax,0xbd29",S)  # SD + HH + RHYTHM
  self.assertIn("cmp byte ptr [music34_pulse],6",S)
  self.assertIn("test byte ptr [music34_beat],3",S)
  self.assertIn("mov byte ptr [music33_active],0",S)
  self.assertNotIn("int 0x16",S)
  self.assertNotIn("int 0x21",S)
  self.assertNotIn("out 0x61",S)

 def test_yamaha_hardware_noise_drum_registers(self):
  drums=words_under("sound34_drum_patch","music34_notes:")
  self.assertEqual(len(drums),24)
  regs=[x>>8 for x in drums]
  self.assertEqual(drums[-1],0xbd20)   # enable mode no trigger
  for reg in (0x30,0x33,0x50,0x53,0x70,0x73,0x90,0x93,0xc6,
              0xa6,0xb6,0x31,0x34,0x51,0x54,0x71,0x74,0x91,
              0x94,0xa7,0xb7,0xa8,0xb8,0xbd):
   self.assertIn(reg,regs)
  self.assertIn("mov cx,24",S)
  self.assertIn("call sound34_rhythm_setup",T)
  self.assertIn("mov ax,0xbd38",T)  # bass+snare on explosive hit
  self.assertIn("mov ax,0xbd21",T)  # airy hi-hat shot
  self.assertIn("mov ax,0xbd20",T)  # release hardware drum triggers
  self.assertNotIn("int 0x08",S)    # no IRQ0 samples
  self.assertNotIn("rep ",S)       # no software PCM mixing

 def test_dos_stack_clamps_before_64k_overflow_in_large_trace_build(self):
  startup=T.split("_start:",1)[1].split("buffer_unavailable:",1)[0]
  self.assertIn("add ax, 0x0fff",startup)
  self.assertIn("jnc stack34_within_segment",startup)
  self.assertIn("mov ax,0xfff0",startup)
  self.assertIn("stack34_end_position:",startup)
  self.assertIn("mov sp, ax",startup)
  # The previous 59,560-byte trace image placed BSS end at F0AEh.
  # F0AE+FFFh wraps to 00ADh, inside the DOS PSP command line at 0080h.
  trace_end=0xf0ae
  self.assertGreater(trace_end+0xfff,0xffff)
  stack=0xfff0 if trace_end+0xfff>0xffff else (trace_end+0xfff)&0xfff0
  self.assertGreaterEqual(stack-trace_end,0xf00)
  self.assertGreaterEqual(stack,0xf000)

 def test_very_short_speaker_and_adlib_patches_are_event_driven(self):
  for marker in ("sound33_speaker:","sound33_opl_pitch:","sound34_play_drum:",
                 "sound33_sweep_pit:","sound_stop:"):
   self.assertIn(marker,T)
  self.assertIn("cmp bx,1100",T)
  self.assertIn("cmp bx,1800",T)
  self.assertIn("mov byte ptr [sound_ticks],1",T)
  self.assertIn("mov byte ptr [sound_ticks],2",T)
  self.assertIn("cmp byte ptr [adlib_present],0",T)
  self.assertNotIn("0x388,ax",T)

if __name__=="__main__":unittest.main()
