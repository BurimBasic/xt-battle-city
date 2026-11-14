/* v0.32 original 8086/CGA opening sequence; invoked only at DOS start.
 * Brick letters are rendered from 5x7 bitmap rows as 3x2 CGA pixel bricks,
 * with 1px black grout. Real approved 12x12 tanks move slowly toward
 * one another. Two barrel-tip shots collide and both tanks burst.
 * BIOS keyboard polling happens before IRQ1 installation: ANY key skips.
 * No new frame-sized bitmap or runtime file; unchanged 18.2 Hz gameplay.
 */
.section .text
title32_intro:
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    push bp
    push es
    mov ax,[frame_seg]
    mov [title32_oldseg],ax
    mov word ptr [frame_seg],0xb800
    mov byte ptr [title32_skip],0
    mov byte ptr [title32_frame],0
    mov byte ptr [title32_x1],69
    mov byte ptr [title32_x2],169
    mov ax,0x0004
    int 0x10
    mov ax,0x0b00
    mov bx,0x0101
    int 0x10
    call apply_cga_palette
    call title32_bricks
    call title32_text
    xor ah,ah
    int 0x1a
    mov [title32_clock],dx
title32_loop:
    mov ah,1
    int 0x16
    jz title32_no_key
    xor ah,ah
    int 0x16
    mov byte ptr [title32_skip],1
    jmp title32_done
title32_no_key:
    xor ah,ah
    int 0x1a
    cmp dx,[title32_clock]
    je title32_loop
    mov [title32_clock],dx
    call title32_clear_battle
    /* Tanks disappear as their explosion begins, not under the blast. */
    cmp byte ptr [title32_frame],42
    jae title32_no_tanks
    call title32_tanks
title32_no_tanks:
    cmp byte ptr [title32_frame],37
    jb title32_advance
    cmp byte ptr [title32_frame],42
    jae title32_explosions
    call title32_projectiles
    jmp title32_advance
title32_explosions:
    cmp byte ptr [title32_frame],53
    jae title32_advance
    mov bl,2
    test byte ptr [title32_frame],1
    jz title32_blast_color
    inc bl
title32_blast_color:
    mov dl,[title32_x1]
    add dl,8
    mov dh,77
    call title32_burst
    mov dl,[title32_x2]
    add dl,8
    mov dh,77
    call title32_burst
title32_advance:
    cmp byte ptr [title32_frame],37
    jae title32_stationary
    inc byte ptr [title32_x1]
    dec byte ptr [title32_x2]
title32_stationary:
    inc byte ptr [title32_frame]
    cmp byte ptr [title32_frame],57
    jae title32_done
    jmp title32_loop         /* 8086 near JMP, not 386 near conditional */
title32_done:
    mov ax,[title32_oldseg]
    mov [frame_seg],ax
    pop es
    pop bp
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

/* Keep the title and controls intact. Clear ONLY the 256x28 battle strip
 * at y64..91 in both alternating CGA banks (nothing outside a sprite). */
title32_clear_battle:
    push ax
    push bx
    push cx
    push di
    push es
    mov ax,0xb800
    mov es,ax
    xor ax,ax
    mov di,2560                /* 64/2*80 */
    mov bx,14
title32_clear_row:
    push di
    mov cx,32
    rep stosw
    pop di
    push di
    add di,0x2000
    mov cx,32
    rep stosw
    pop di
    add di,80
    dec bx
    jnz title32_clear_row
    pop es
    pop di
    pop cx
    pop bx
    pop ax
    ret

title32_tanks:
    mov dl,[title32_x1]
    mov dh,72
    mov si,[smooth_player_ptrs+2]   /* RIGHT, exact user 12x12 */
    call draw_smooth_sprite
    mov dl,[title32_x2]
    mov dh,72
    mov si,[smooth_enemy_ptrs+6]    /* LEFT, enemy 12x12 */
    call draw_smooth_sprite
    ret

title32_projectiles:
    mov al,[title32_frame]
    sub al,37
    shl al,1
    mov dl,[title32_x1]
    add dl,13
    add dl,al
    mov dh,78
    mov bl,3
    call gun27_pixel
    mov dl,[title32_x2]
    add dl,2
    sub dl,al
    call gun27_pixel
    ret

/* Centered 5-pixel burst, magenta/white alternate each tick. */
title32_burst:
    call gun27_pixel
    add dl,2
    call gun27_pixel
    sub dl,4
    call gun27_pixel
    add dl,2
    inc dh
    call gun27_pixel
    dec dh
    dec dh
    call gun27_pixel
    ret

/* Five manually designed 5x7 glyphs. Each bit is a 3x2 brick;
 * 1-pixel vertical and horizontal black mortar joins. */
title32_bricks:
    mov si,offset title32_font
    mov dh,12
    mov bp,7
title32_font_row:
    mov dl,100
    mov cx,5
title32_font_letter:
    mov ah,[si]
    inc si
    shl ah,1
    shl ah,1
    shl ah,1
    mov di,5
title32_font_bit:
    shl ah,1
    jnc title32_empty_brick
    push ax
    /* Each brick is a FULL 3x3 solid pixel block with 1px black mortar
       all around, not the prior loose horizontal dash. White top edge
       and magenta 2-row body match original arcade masonry shading. */
    mov bl,3
    call gun27_pixel
    inc dl
    call gun27_pixel
    inc dl
    call gun27_pixel
    sub dl,2
    mov bl,2
    inc dh
    call gun27_pixel
    inc dl
    call gun27_pixel
    inc dl
    call gun27_pixel
    sub dl,2
    inc dh
    call gun27_pixel
    inc dl
    call gun27_pixel
    inc dl
    call gun27_pixel
    sub dl,2
    sub dh,2
    pop ax
title32_empty_brick:
    add dl,4
    dec di
    jnz title32_font_bit
    add dl,4
    loop title32_font_letter
    add dh,4
    dec bp
    jnz title32_font_row
    ret

title32_text:
    mov bp,8
    mov di,offset title32_lines
title32_text_next:
    mov dl,[di]
    mov dh,[di+1]
    call cursor_at
    mov si,[di+2]
    call bios_string
    add di,4
    dec bp
    jnz title32_text_next
    ret

.section .data
title32_oldseg: .word 0
title32_clock: .word 0
title32_x1: .byte 69
title32_x2: .byte 169
title32_skip: .byte 0
title32_frame: .byte 0
title32_font:
    .byte 31,14,17,17,15
    .byte 4,17,25,18,16
    .byte 4,17,21,20,16
    .byte 4,31,19,24,14
    .byte 4,17,17,20,1
    .byte 4,17,17,18,1
    .byte 4,17,17,17,30
title32_lines:
    .byte 4,13
    .word title32_help1
    .byte 4,14
    .word title32_help2
    .byte 4,16
    .word title32_help3
    .byte 4,17
    .word title32_help4
    .byte 3,18
    .word title32_help5
    .byte 3,19
    .word title32_help6
    .byte 11,22
    .word title32_help7
    .byte 15,24
    .word title32_copyright
title32_help1: .asciz "1P ARROWS MOVE     SPACE FIRE"
title32_help2: .asciz "2P WASD MOVE       CTRL FIRE"
title32_help3: .asciz "TAB AUTO/MAN   V ALLY   P PAUSE"
title32_help4: .asciz "PGUP/PGDN LEVEL (WHEN PAUSED)"
title32_help5: .asciz "C PALETTE   M SOUND   R RESTART"
title32_help6: .asciz "ESC EXIT SPACE NEXT(WIN) COOP:2P KEYS"
title32_help7: .asciz "ANY KEY TO START"
title32_copyright: .asciz "1982 BURIM"
.section .text
