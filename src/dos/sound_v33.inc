/* v0.33 — ORIGINAL arcade FM title cue, not a transcription of
 * Harold Faltermeyer's copyrighted "Axel F".
 * Uses AdLib/YM3812 channels 1 (syncopated FM lead) and 2 (bass) ONLY
 * while the opening title is visible. Ch0 is dedicated to game effects.
 * Speaker has no title melody and only 1–2-tick game noises.
 * Everything runs on the existing BIOS 18.2Hz title clock, no PCM,
 * IRQ, busy loops, config files or software mixing; safe for 8086 XT.
 */
.section .text
music33_start:
    cmp byte ptr [adlib_present],0
    je music33_start_done
    cmp byte ptr [sound_muted],0
    jne music33_start_done
    push ax
    push cx
    push si
    mov si,offset music33_patch
    mov cx,18
music33_setup_loop:
    lodsw
    call adlib_write
    loop music33_setup_loop
    mov byte ptr [music33_active],1
    mov byte ptr [music33_div],2  /* first tone next BIOS tick */
    mov byte ptr [music33_pos],0
    pop si
    pop cx
    pop ax
music33_start_done:
    ret

music33_tick:
    cmp byte ptr [music33_active],0
    je music33_tick_done
    inc byte ptr [music33_div]
    cmp byte ptr [music33_div],3
    jb music33_tick_done
    mov byte ptr [music33_div],0
    push ax
    push bx
    xor bx,bx
    mov bl,[music33_pos]
    mov al,bl
    inc al
    and al,15
    mov [music33_pos],al
    mov ax,0xb112           /* lead ch1 KEY OFF; each note articulated */
    call adlib_write
    mov al,[music33_lead+bx]
    or al,al
    jz music33_bass_check
    mov ah,0xa1
    call adlib_write
    mov ax,0xb132           /* lead ch1 KEY ON, block4 */
    call adlib_write
music33_bass_check:
    test bl,3
    jnz music33_note_done
    shr bx,1
    shr bx,1
    mov ax,0xb20d           /* bass ch2 KEY OFF */
    call adlib_write
    mov al,[music33_bass+bx]
    mov ah,0xa2
    call adlib_write
    mov ax,0xb22d           /* bass ch2 KEY ON, block3 */
    call adlib_write
music33_note_done:
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
    pop ax
music33_stop_done:
    ret

.section .data
music33_active: .byte 0
music33_div: .byte 0
music33_pos: .byte 0
/* 9 register pairs per OPL2 voice, two different organic FM timbres. */
music33_patch:
    .word 0x2111,0x2401,0x4126,0x441a,0x61f4
    .word 0x64f3,0x8157,0x8434,0xc104
    .word 0x2211,0x2501,0x4220,0x451a,0x62f3
    .word 0x65f4,0x8234,0x8523,0xc204
/* Original 16-step bluesy synth motif, 3 title ticks per step.
 * 0 = intentional rhythmic rest; the notes are not Axel F notes. */
music33_lead:
    .byte 0x54,0x78,0xad,0,0x98,0x78,0x54,0
    .byte 0x44,0x69,0x98,0x82,0x69,0x44,0,0
music33_bass:
    .byte 0xc0,0xb2,0xd0,0xa0
.section .text
