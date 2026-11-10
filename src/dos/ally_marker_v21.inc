/* v0.21: two-by-two magenta cockpit marker. Distinguishes the
 * attacking ally after its temporary shield has expired, without
 * giving it a fake permanent protective silhouette. Only 4 pixel
 * writes into the same frame buffer as the ordinary player chassis.
 * CGA palette index 1 is the contrasting magenta/green accent.
 */
.section .text
ally21_draw_mark:
    push ax
    push bx
    push cx
    push dx
    push di
    push es
    mov ax,[frame_seg]
    mov es,ax
    mov dl,[ally_px]
    add dl,7
    mov dh,[ally_py]
    add dh,3
    call ally21_dot
    inc dl
    call ally21_dot
    dec dl
    inc dh
    call ally21_dot
    inc dl
    call ally21_dot
    pop es
    pop di
    pop dx
    pop cx
    pop bx
    pop ax
    ret

ally21_dot:
    xor bx,bx
    mov bl,dl
    and bl,3
    mov cl,[laser19_masks+bx]
    not cl
    mov ah,[laser19_color1+bx]
    xor bx,bx
    mov bl,dh
    shl bx,1
    mov di,[cga_scanline_offsets+bx]
    xor bx,bx
    mov bl,dl
    shr bx,1
    shr bx,1
    add di,bx
    mov al,es:[di]
    and al,cl
    or al,ah
    mov es:[di],al
    ret
