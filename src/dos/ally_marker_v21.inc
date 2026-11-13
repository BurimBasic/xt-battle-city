/* v0.29: companion uses exactly the approved cyan P1 hull, plus TWO
 * magenta 5px stripes flanking its turret. Rotation follows ally_dir.
 * No misleading permanent shield and no extra smooth atlas (saves 1920B).
 * 8086: ten bounded 2bpp pixel writes, no allocation or BIOS calls.
 */
.section .text
ally21_draw_mark:
    push ax
    push bx
    push cx
    push dx
    push si
    xor si,si
    mov bl,2                 /* CGA magenta */
ally29_next_stripe:
    mov dl,[ally_px]
    mov dh,[ally_py]
    mov al,[ally_dir]
    test al,1
    jz ally29_vertical
    /* Horizontal heading: two short horizontal chassis/roof bars
       above and below the white turret. */
    add dl,6
    add dh,3
    test si,1
    jz ally29_draw_horizontal
    add dh,6
ally29_draw_horizontal:
    mov cx,5
ally29_h_loop:
    call gun27_pixel
    inc dl
    loop ally29_h_loop
    jmp ally29_stripe_done
ally29_vertical:
    /* Vertical heading: same two magenta roof bars, rotated 90deg. */
    add dl,4
    add dh,3
    test si,1
    jz ally29_draw_vertical
    add dl,7
ally29_draw_vertical:
    mov cx,5
ally29_v_loop:
    call gun27_pixel
    inc dh
    loop ally29_v_loop
ally29_stripe_done:
    inc si
    cmp si,2
    jb ally29_next_stripe
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret
