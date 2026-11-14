/* v0.30: exact user-authored companion pixels without a second atlas.
 * P1 and P2 differ in exactly four pixels: core row 10, columns 4..7,
 * magenta overlay replacing P1's cyan/gray pixels. All four headings are
 * exact 12x12 rotations, offset by the existing 2px left atlas padding.
 * 8086 only, no shaders, no glow, no additional reserve memory. */
.section .text
ally21_draw_mark:
    push ax
    push bx
    push cx
    push dx
    mov bl,2
    mov dl,[ally_px]
    mov dh,[ally_py]
    mov al,[ally_dir]
    cmp al,0
    jne ally30_right
    add dl,6
    add dh,10
    jmp ally30_horizontal
ally30_right:
    cmp al,1
    jne ally30_down
    add dl,3
    add dh,4
    jmp ally30_vertical
ally30_down:
    cmp al,2
    jne ally30_left
    add dl,6
    inc dh
    jmp ally30_horizontal
ally30_left:
    add dl,12
    add dh,4
ally30_vertical:
    mov cx,4
ally30_v_loop:
    call gun27_pixel
    inc dh
    loop ally30_v_loop
    jmp ally30_done
ally30_horizontal:
    mov cx,4
ally30_h_loop:
    call gun27_pixel
    inc dl
    loop ally30_h_loop
ally30_done:
    pop dx
    pop cx
    pop bx
    pop ax
    ret
