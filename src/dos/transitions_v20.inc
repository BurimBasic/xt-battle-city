/* v0.20 Arcade-style stage transitions: three short original CGA wipes.
 * 0 = top-to-bottom scan; 1 = left-to-right sweep;
 * 2 = symmetric curtains from the edges toward the HQ. A stage's exit
 * picks the next pattern. Only active at stage boundaries, never per tick.
 * No bitmap allocation, no files, no graphics beyond standard CGA. */
.section .text

transition20_open:
    cmp byte ptr [transition_pending],0
    je trans20_return   /* unpause / HUD refresh is not a new stage */
    mov byte ptr [transition_pending],0
    cmp byte ptr [test_mode],0
    jne trans20_return
    /* A real off-screen CGA buffer is needed to reveal a composed frame.
       Low-memory direct B800 fallback gracefully skips the entrance. */
    cmp word ptr [frame_seg],0xb800
    je trans20_return
    call transition20_blank_field
    mov byte ptr [trans20_reveal],1
    jmp transition20_run
transition20_close:
    cmp byte ptr [test_mode],0
    jne trans20_return
    mov byte ptr [trans20_reveal],0
    jmp transition20_run
trans20_return:
    ret

transition20_run:
    push ax
    push bx
    push cx
    push dx
    mov al,[stage]
    xor ah,ah
    mov bl,3
    div bl
    mov [trans20_style],ah
    cmp byte ptr [trans20_reveal],1
    je trans20_style_ready
    inc byte ptr [trans20_style]
    cmp byte ptr [trans20_style],3
    jb trans20_style_ready
    mov byte ptr [trans20_style],0
trans20_style_ready:
    mov byte ptr [trans20_step],0
trans20_pass:
    mov byte ptr [trans20_inner],0
trans20_cell:
    cmp byte ptr [trans20_style],0
    jne trans20_column
    mov dl,[trans20_inner]
    mov dh,[trans20_step]
    jmp trans20_cell_draw
trans20_column:
    mov dl,[trans20_step]
    cmp byte ptr [trans20_style],2
    jne trans20_column_ready
    shr dl,1
    test byte ptr [trans20_step],1
    jz trans20_column_ready
    mov al,15
    sub al,dl
    mov dl,al
trans20_column_ready:
    mov dh,[trans20_inner]
trans20_cell_draw:
    cmp byte ptr [trans20_reveal],0
    je trans20_draw_dark
    call copy_tile_to_cga
    jmp trans20_cell_next
trans20_draw_dark:
    call transition20_blank_tile
trans20_cell_next:
    inc byte ptr [trans20_inner]
    cmp byte ptr [trans20_inner],16
    jb trans20_cell
    /* 20 visible BIOS-tick intervals per wipe (~1.1 seconds), rather
       than eight intervals too fast to recognize. Never in game loop. */
    test byte ptr [trans20_step],3
    jnz trans20_one_wait
    call transition20_wait_tick
trans20_one_wait:
    call transition20_wait_tick
    inc byte ptr [trans20_step]
    cmp byte ptr [trans20_step],16
    jb trans20_pass
    pop dx
    pop cx
    pop bx
    pop ax
    ret

/* Blank only the 256x192 battlefield; leave white HUD and retro signature. */
transition20_blank_field:
    push ax
    push bx
    push cx
    push di
    push es
    mov ax,0xb800
    mov es,ax
    xor bx,bx
trans20_black_line:
    mov di,[cga_scanline_offsets+bx]
    xor ax,ax
    mov cx,32             /* 256px = 64 bytes/scanline */
    rep stosw
    add bx,2
    cmp bx,384
    jb trans20_black_line
    pop es
    pop di
    pop cx
    pop bx
    pop ax
    ret

/* Clear exactly one 16x12 tile in CGA's two interleaved banks. */
transition20_blank_tile:
    push ax
    push bx
    push cx
    push di
    push es
    mov ax,0xb800
    mov es,ax
    xor bx,bx
    mov bl,dh
    shl bx,1
    mov di,[tile_row_offsets+bx]
    xor bx,bx
    mov bl,dl
    shl bx,1
    shl bx,1
    add di,bx
    xor ax,ax
    mov cx,6
trans20_tile_line:
    mov es:[di],ax
    mov es:[di+2],ax
    mov es:[di+0x2000],ax
    mov es:[di+0x2002],ax
    add di,80
    loop trans20_tile_line
    pop es
    pop di
    pop cx
    pop bx
    pop ax
    ret

transition20_wait_tick:
    push ax
    push cx
    push dx
    mov ah,0
    int 0x1a
    mov cx,dx
trans20_wait:
    mov ah,0
    int 0x1a
    cmp cx,dx
    je trans20_wait
    pop dx
    pop cx
    pop ax
    ret

.section .data
trans20_style: .byte 0
trans20_reveal: .byte 0
trans20_step: .byte 0
trans20_inner: .byte 0
transition_done: .byte 0
transition_pending: .byte 1
.section .text
