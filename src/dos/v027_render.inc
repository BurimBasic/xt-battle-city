/* v0.27: compact 32x24 CGA plane and two-tick barrel kick.
 * Intel 8086 only. All visuals are RAM-free and fully tile-dirty. */
.section .text
/* DL/DH = 32x24 upper left. Mark four 16x12 tile-sized regions. */
wide27_dirty:
    /* Directly mark the full 32x24 aircraft tile rectangle, in one pass.
       Avoid the old 4x mark_dirty_rect calls every video frame. */
    push ax
    push bx
    push cx
    push dx
    push si
    mov al,dl
    shr al,1
    shr al,1
    shr al,1
    shr al,1
    mov cl,al
    mov al,dl
    add al,31
    shr al,1
    shr al,1
    shr al,1
    shr al,1
    mov ch,al
    xor bx,bx
    mov bl,dh
    mov al,[pixel_y_tile_lookup+bx]
    shr al,1
    shr al,1
    shr al,1
    shr al,1
    mov dl,al
    add bl,23
    mov al,[pixel_y_tile_lookup+bx]
    shr al,1
    shr al,1
    shr al,1
    shr al,1
    mov dh,al
wide27_dirty_row:
    xor bx,bx
    mov bl,dl
    shl bx,1
    shl bx,1
    shl bx,1
    shl bx,1
    xor ax,ax
    mov al,cl
wide27_dirty_col:
    cmp al,16
    jae wide27_dirty_skip
    mov si,bx
    add si,ax
    mov byte ptr [dirty_tiles+si],1
    mov byte ptr [upload_tiles+si],1
wide27_dirty_skip:
    inc al
    cmp al,ch
    jbe wide27_dirty_col
    inc dl
    cmp dl,dh
    jbe wide27_dirty_row
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

/* SI: packed 384-byte wide_plane frame (8 masks then 8 colors per row).
 * DL/DH: origin; source palette and transparent mask are CGA mode 4.
 * Preserves caller's registers; aircraft x is pixel-aligned to 4 for
 * fast 8086 byte blits; movement/physics still uses 2px/tick. */
wide27_draw:
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    push bp
    push es
    call wide27_dirty
    mov [wide27_origin],dx
    mov ax,[frame_seg]
    mov es,ax
    mov bp,24
wide27_row:
    mov dx,[wide27_origin]
    mov bx,0
    mov bl,dh
    shl bx,1
    mov di,[cga_scanline_offsets+bx]
    xor bx,bx
    mov bl,dl
    shr bx,1
    shr bx,1
    add di,bx
    /* Four 16-bit RMW mask+color pairs instead of eight byte writes. */
    mov cx,4
wide27_byte:
    mov ax,es:[di]
    mov bx,[si]
    not bx
    and ax,bx
    or ax,[si+8]
    mov es:[di],ax
    add si,2
    add di,2
    loop wide27_byte
    add si,8
    inc byte ptr [wide27_origin+1]
    dec bp
    jnz wide27_row
    pop es
    pop bp
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

/* BL CGA color 0..3, DL/DH screen pixel. Byte RMW, one pixel only. */
gun27_pixel:
    push ax
    push bx
    push cx
    push dx
    push di
    push es
    cmp dh,192
    jae gun27_pixel_done
    mov ax,[frame_seg]
    mov es,ax
    xor ax,ax
    mov al,dh
    shl ax,1
    mov di,ax
    mov di,[cga_scanline_offsets+di]
    xor ax,ax
    mov al,dl
    shr al,1
    shr al,1
    add di,ax
    mov cl,dl
    and cl,3
    shl cl,1
    mov al,6
    sub al,cl
    mov cl,al
    mov al,3
    shl al,cl
    not al
    and es:[di],al
    mov al,bl
    shl al,cl
    or es:[di],al
gun27_pixel_done:
    pop es
    pop di
    pop dx
    pop cx
    pop bx
    pop ax
    ret

/* Move one pixel inward along the selected gun's direction. */
gun27_inward:
    cmp byte ptr [gun27_dir],0
    jne 1f
    inc dh
    ret
1:
    cmp byte ptr [gun27_dir],1
    jne 2f
    dec dl
    ret
2:
    cmp byte ptr [gun27_dir],2
    jne 3f
    dec dh
    ret
3:
    inc dl
    ret

/* AL recoil phase 3/2/1, BL heading 0..3, DL/DH tank origin.
 * Blackens 2/1 tip pixels to give visible kickback; one rounded 2px
 * flash at the muzzle on phase 3. Sprite is redrawn before each frame. */
gun27_draw:
    cmp al,0
    jne 1f
    ret
1:
    push ax
    push bx
    push dx
    mov [gun27_phase],al
    mov [gun27_dir],bl
    cmp bl,0
    jne gun27_right
    add dl,7
    jmp gun27_blacken
gun27_right:
    cmp bl,1
    jne gun27_down
    add dl,13
    add dh,5
    jmp gun27_blacken
gun27_down:
    cmp bl,2
    jne gun27_left
    add dl,7
    add dh,11
    jmp gun27_blacken
gun27_left:
    add dl,2
    add dh,5
gun27_blacken:
    xor bx,bx
    call gun27_pixel
    cmp byte ptr [gun27_phase],1
    je gun27_done
    call gun27_inward
    call gun27_pixel
    cmp byte ptr [gun27_phase],3
    jne gun27_done
    call gun27_inward
    mov bl,3
    call gun27_pixel
    inc dl
    call gun27_pixel
gun27_done:
    pop dx
    pop bx
    pop ax
    ret

gun27_tick:
    cmp byte ptr [gun27_p1],0
    je 1f
    dec byte ptr [gun27_p1]
1:
    cmp byte ptr [gun27_p2],0
    je 2f
    dec byte ptr [gun27_p2]
2:
    ret

/* Two discrete spinning propeller tips, 1px amplitude, one per engine.
 * World coordinates are 32x24 wide-plane origin. */
wide27_propellers:
    push ax
    push bx
    push dx
    mov bl,3
    cmp byte ptr [bomber25_axis],0
    jne wide27_vertical_props
    add dl,14
    add dh,5
    test byte ptr [game_tick],2
    jz 1f
    inc dl
1:
    call gun27_pixel
    add dh,13
    call gun27_pixel
    jmp wide27_props_done
wide27_vertical_props:
    add dl,7
    add dh,4  /* twin engine propellers ahead of the wings */
    test byte ptr [game_tick],2
    jz 2f
    inc dh
2:
    call gun27_pixel
    add dl,18
    call gun27_pixel
wide27_props_done:
    pop dx
    pop bx
    pop ax
    ret

.section .data
wide27_origin: .word 0
gun27_p1: .byte 0
gun27_p2: .byte 0
gun27_phase: .byte 0
gun27_dir: .byte 0
