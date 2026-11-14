/* v0.31: 15,000-point extra lives, three HUD flashes and rising point
 * sprites. Pure 8086/8088 CGA; no BIOS calls, no additional 16x12 atlas.
 * The four exact 11x3 blue source badges (100/200/300/400) are encoded
 * directly from the supplied RGB image as one bit per pixel, LSB first.
 * Four independent kill popups support simultaneous explosions. */
.section .text

/* AX=awarded points (100..400), BX=destroyed enemy slot 0..3.
 * The counter is kept modulo 15000, independently of 16-bit score wrap. */
score31_award:
    push ax
    push bx
    push dx
    add word ptr [score],ax
    add word ptr [score31_progress],ax
    cmp word ptr [score31_progress],15000
    jb score31_no_life
    sub word ptr [score31_progress],15000
    mov byte ptr [score31_hud_flash],24
    cmp byte ptr [lives],9
    jae score31_no_p1
    inc byte ptr [lives]
score31_no_p1:
    cmp byte ptr [coop_mode],0
    je score31_no_life
    cmp byte ptr [coop_lives],9
    jae score31_no_life
    inc byte ptr [coop_lives]
score31_no_life:
    mov dl,[enemy_px+bx]
    add dl,2
    mov [score31_x+bx],dl
    mov dh,[enemy_py+bx]
    add dh,4
    mov [score31_y+bx],dh
    mov al,[enemy_type+bx]
    mov [score31_kind+bx],al
    mov byte ptr [score31_timer+bx],24
    pop dx
    pop bx
    pop ax
    ret

score31_tick:
    push bx
    cmp byte ptr [score31_hud_flash],0
    je score31_tick_popups
    dec byte ptr [score31_hud_flash]
    call draw_hud              /* refresh only during rare 15k animation */
score31_tick_popups:
    xor bx,bx
score31_tick_next:
    cmp byte ptr [score31_timer+bx],0
    je score31_tick_skip
    dec byte ptr [score31_timer+bx]
score31_tick_skip:
    inc bx
    cmp bx,4
    jb score31_tick_next
    pop bx
    ret

/* Previous popup positions always get restored, including when the final
 * flash expires. The current popup position is marked separately in paint. */
/* mark_old_sprites already clobbers BX/DX; no duplicate saves. */
score31_mark_old:
    xor bx,bx
score31_mark_next:
    cmp byte ptr [score31_paint_valid+bx],0
    je score31_mark_skip
    mov dl,[score31_paint_x+bx]
    mov dh,[score31_paint_y+bx]
    call mark_dirty_rect
    mov byte ptr [score31_paint_valid+bx],0
score31_mark_skip:
    inc bx
    cmp bx,4
    jb score31_mark_next
    ret

/* Called only by render_frame, which already saves AX/BX/DX. */
score31_paint:
    xor bx,bx
score31_paint_next:
    mov al,[score31_timer+bx]
    test al,4               /* visible 4 ticks, hidden 4; three flashes */
    jz score31_paint_skip
    mov dl,[score31_x+bx]
    mov dh,[score31_y+bx]
    cmp al,16
    jae score31_rise_ready
    dec dh                  /* second appearance rises one pixel */
    cmp al,8
    jae score31_rise_ready
    dec dh                  /* third appearance rises another pixel */
score31_rise_ready:
    mov [score31_paint_x+bx],dl
    mov [score31_paint_y+bx],dh
    mov byte ptr [score31_paint_valid+bx],1
    call mark_dirty_rect
    call score31_draw
score31_paint_skip:
    inc bx
    cmp bx,4
    jb score31_paint_next
    ret

/* BX=slot, DL/DH=screen pixel. 11x3 author artwork decoded on the fly. */
score31_draw:
    push bx
    push cx
    push dx
    push si
    push bp
    xor ax,ax
    mov al,[score31_kind+bx]
    mov cl,6
    mul cl
    mov si,offset score31_masks
    add si,ax
    mov bl,1                 /* cyan in CGA palette 1 */
    mov bp,3
score31_row:
    mov ax,[si]
    add si,2
    mov cx,11
score31_pixel:
    test ax,1
    jz score31_pixel_skip
    call gun27_pixel
score31_pixel_skip:
    shr ax,1
    inc dl
    loop score31_pixel
    sub dl,11
    inc dh
    dec bp
    jnz score31_row
    pop bp
    pop si
    pop dx
    pop cx
    pop bx
    ret

.section .data
score31_progress: .word 0
score31_hud_flash: .byte 0
score31_timer: .space 4
score31_kind: .space 4
score31_x: .space 4
score31_y: .space 4
score31_paint_valid: .space 4
score31_paint_x: .space 4
score31_paint_y: .space 4
score31_masks:
    .word 0x03ba,0x02aa,0x03ba /* 100 */
    .word 0x0777,0x0552,0x0777 /* 200 */
    .word 0x0777,0x0556,0x0777 /* 300 */
    .word 0x0775,0x0557,0x0774 /* 400 */
.section .text
