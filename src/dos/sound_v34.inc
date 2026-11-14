/* v0.34 - folk melody "Korobeiniki" (Russian traditional, circa 1898,
 * public domain) from its unaccompanied 4/4 four-bar ABC folk transcription:
 * K:Am L:1/8
 * E2 B,C D2 CB, | A,2 A,C E2 DC | B,3 C D2 E2 | C2 A,2 A,4
 * https://portenotes.lacultureataporte.fr/composition/repertoire/korobeiniki
 *
 * NOT the protected 1989 Game Boy Tetris arrangement. Folk melody has the
 * actual historical pitches and rhythm. AdLib FM lead ch1, root bass ch2
 * and independent YM3812 hardware-noise percussion on ch6/ch7. All voices
 * play together; 6-tick quarter pulse (approx 182 BPM). No music on the
 * speaker, no PCM, software-generated noise, interrupt or IRQ0 hook.
 */
.section .text

/* YM3812 rhythm mode: melodic channels 0-5 remain intact; 6-8 become
 * hardware bass drum/snare/hi-hat etc. BD=0x20 enables the noise mixer.
 * Drum slots 0x10/13 (bass) and 0x11/14 (HH/snare), tuned f7:f8~3:1.
 * This setup is done ONCE at boot after successful AdLib probe. */
sound34_rhythm_setup:
    push ax
    push cx
    push si
    mov si,offset sound34_drum_patch
    mov cx,24
sound34_setup_next:
    lodsw
    call adlib_write
    loop sound34_setup_next
    pop si
    pop cx
    pop ax
    ret

music33_start:
    cmp byte ptr [adlib_present],0
    je music33_start_done
    cmp byte ptr [sound_muted],0
    jne music33_start_done
    push ax
    push cx
    push si
    mov si,offset music34_fm_patch
    mov cx,18
music34_init_loop:
    lodsw
    call adlib_write
    loop music34_init_loop
    mov byte ptr [music33_active],1
    mov byte ptr [music33_div],1
    mov byte ptr [music33_pos],0
    mov byte ptr [music34_pulse],5
    mov byte ptr [music34_beat],0
    mov byte ptr [music34_bass_state],0
    mov ax,0xa2b7         /* E3 bass, first Am/E dominant folk bar */
    call adlib_write
    mov ax,0xb22d
    call adlib_write
    pop si
    pop cx
    pop ax
music33_start_done:
    ret

music33_tick:
    cmp byte ptr [music33_active],0
    je music33_tick_done
    push ax
    push bx
    dec byte ptr [music33_div]
    jnz music34_rhythm
    xor bx,bx
    mov bl,[music33_pos]
    cmp bl,19
    jb music34_note_valid
    xor bx,bx
    mov byte ptr [music33_pos],0
music34_note_valid:
    mov al,[music34_durations+bx]
    mov [music33_div],al
    inc byte ptr [music33_pos]
    mov bl,[music34_notes+bx] /* five-note palette A B C D E */
    xor bh,bh
    mov ax,0xb112          /* stop lead before each note */
    call adlib_write
    mov al,[music34_freq_lo+bx]
    mov ah,0xa1
    call adlib_write
    mov al,[music34_freq_key+bx]
    mov ah,0xb1
    call adlib_write

music34_rhythm:
    inc byte ptr [music34_pulse]
    cmp byte ptr [music34_pulse],6
    jb music34_tick_end
    mov byte ptr [music34_pulse],0
    /* Big consistent beat: bass drum+hat, then snare+hat. OPL chip
     * generates random noise itself; CPU only toggles two registers. */
    mov ax,0xbd20
    call adlib_write
    mov ax,0xbd31         /* BD + HH + mode */
    test byte ptr [music34_beat],1
    jz music34_strike
    mov ax,0xbd29         /* snare + HH + mode */
music34_strike:
    call adlib_write
    inc byte ptr [music34_beat]
    test byte ptr [music34_beat],3
    jnz music34_tick_end
    /* Alternate familiar E3 / A3 drone roots once every 4 beats,
     * independent of the original public-domain folk melody. */
    xor byte ptr [music34_bass_state],1
    mov ax,0xb20d
    call adlib_write
    cmp byte ptr [music34_bass_state],0
    je music34_bass_E
    mov ax,0xa244       /* A3: FNUM 0x244, block 3 */
    call adlib_write
    mov ax,0xb22e
    jmp music34_bass_on
music34_bass_E:
    mov ax,0xa2b7       /* E3: FNUM 0x1b7, block 3 */
    call adlib_write
    mov ax,0xb22d
music34_bass_on:
    call adlib_write
music34_tick_end:
    pop bx
    pop ax
music33_tick_done:
    ret

music33_stop:
    cmp byte ptr [music33_active],0
    je music33_stop_done
    mov byte ptr [music33_active],0
    push ax
    mov ax,0xb112
    call adlib_write
    mov ax,0xb20d
    call adlib_write
    mov ax,0xbd20       /* clear drums: no hanging snare after any key */
    call adlib_write
    pop ax
music33_stop_done:
    ret

.section .data
music33_active: .byte 0
music33_div: .byte 0
music33_pos: .byte 0
music34_pulse: .byte 0
music34_beat: .byte 0
music34_bass_state: .byte 0

/* Two distinct FM instrument voices; lead: bright arcade bell/synth,
 * bass: darker staccato plucked note. Both 2-operator OPL2 voices. */
music34_fm_patch:
    .word 0x2102,0x2401,0x411d,0x4429,0x61f4
    .word 0x64f5,0x8133,0x8434,0xc106
    .word 0x2201,0x2501,0x4224,0x452b,0x62f4
    .word 0x65f4,0x8225,0x8526,0xc204

/* 24 register/value pairs for OPL2's own RHYTHM+NOISE generator.
 * Black-box FM chip handles all waves and envelope computations. */
sound34_drum_patch:
    .word 0x3001,0x3301,0x5014,0x5320,0x70f7
    .word 0x73f9,0x9046,0x9335,0xc60c,0xa6a0
    .word 0xb60d,0x3101,0x3411,0x510f,0x540f
    .word 0x71f6,0x74f8,0x9126,0x9426,0xa7a0
    .word 0xb70c,0xa855,0xb808,0xbd20

/* 4 bars of the public-domain 19th-century melody. Pitch-class:
 * A=0 B=1 C=2 D=3 E=4 in octave 4/5 (not Tanaka's 1989 arrangement).
 * Each duration counts BIOS ticks; exactly 96 ticks = 32 eighth-notes.
 * Every measure 24 ticks. Restating the folk line from the 1898 tune. */
music34_notes:
    .byte 4,1,2,3,2,1, 0,0,2,4,3,2, 1,2,3,4, 2,0,0
music34_durations:
    .byte 6,3,3,6,3,3, 6,3,3,6,3,3, 9,3,6,6, 6,6,12
/* YM3812 FNUM chosen for A4=440, B4=493.88, C5=523.25,
 * D5=587.33, E5=659.26 at common block 4. */
music34_freq_lo:
    .byte 0x44,0x8b,0xb2,0x05,0x65
music34_freq_key:
    .byte 0x32,0x32,0x32,0x33,0x33
.section .text
