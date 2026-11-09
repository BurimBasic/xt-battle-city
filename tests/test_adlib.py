"""AdLib is optional; 8088-compatible OPL2 probe and safe speaker fallback."""
from pathlib import Path
import unittest
S=(Path(__file__).resolve().parents[1]/'src/dos/tanks.S').read_text()
class AudioTests(unittest.TestCase):
    def test_optional_opl2_and_speaker_fallback(self):
        for label in ('adlib_detect:', 'adlib_write:', 'adlib_timer_wait:',
                      'adlib_setup:', 'sound_speaker_fallback:', 'adlib_present:',
                      'speaker_stopped:'):
            self.assertIn(label,S)
        self.assertIn('call adlib_detect',S)
        self.assertIn('audio_not_detected:', S)
        self.assertIn('cmp byte ptr [adlib_present], 0',S)
        self.assertIn('mov ax, 0x4c00',S)
    def test_isa_port_access(self):
        self.assertIn('mov dx, 0x0388',S)
        self.assertIn('in al, dx',S)
        self.assertIn('out dx, al',S)
        self.assertIn('mov ax, 0xb011',S)  # end FM note on exit/mute
if __name__=='__main__': unittest.main()
