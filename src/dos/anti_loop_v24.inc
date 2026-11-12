/* v0.24: short action-history feedback, only on tactical decisions.
 * Count A,B,A,B reversals and repeated no-progress orders, then escape
 * through a verified sideways corridor. No heavy BFS or per-frame scan. */
.section .text

tactical24_player_unloop:
    push bx
    push dx
    mov dl,al
    cmp byte ptr [p_loop_escape],0
    je p_loop_history
    dec byte ptr [p_loop_escape]
    mov al,[p_loop_escape_dir]
    call tactical_player_path_open
    jc 1f
    jmp p_loop_return
1:
    mov byte ptr [p_loop_escape],0
p_loop_history:
    mov al,[p_loop_last]
    cmp al,0xff
    je p_loop_store
    cmp dl,al
    je p_loop_same
    cmp dl,[p_loop_prev]
    jne p_loop_reset
    inc byte ptr [p_loop_count]
    jmp p_loop_check
p_loop_same:
    /* Repeating an order without moving a single coarse cell is a trap. */
    mov al,[player_px]
    shr al,1
    shr al,1
    shr al,1
    shr al,1
    cmp al,[p_loop_last_x]
    jne p_loop_reset
    mov al,[player_py]
    xor ah,ah
    mov bl,12
    div bl
    cmp al,[p_loop_last_y]
    jne p_loop_reset
    inc byte ptr [p_loop_count]
    jmp p_loop_check
p_loop_reset:
    mov byte ptr [p_loop_count],0
p_loop_check:
    cmp byte ptr [p_loop_count],4
    jb p_loop_store
    mov al,dl
    inc al
    and al,3
    call tactical_player_path_open
    jnc p_loop_escaped
    mov al,dl
    add al,3
    and al,3
    call tactical_player_path_open
    jc p_loop_store
p_loop_escaped:
    mov [p_loop_escape_dir],al
    mov byte ptr [p_loop_escape],5
    mov byte ptr [p_loop_count],0
    mov dl,al
p_loop_store:
    mov al,[p_loop_last]
    mov [p_loop_prev],al
    mov [p_loop_last],dl
    mov al,[player_px]
    shr al,1
    shr al,1
    shr al,1
    shr al,1
    mov [p_loop_last_x],al
    mov al,[player_py]
    xor ah,ah
    mov bl,12
    div bl
    mov [p_loop_last_y],al
    mov al,dl
p_loop_return:
    pop dx
    pop bx
    ret

/* BX=enemy slot, AL=chosen direction; if A-B-A-B repeats or same
 * position persists for four tactical turns, choose a legal escape.
 * Enemy AI's explicit firing ambush hold remains an intentional state. */
tactical24_enemy_unloop:
    push cx
    push dx
    mov dl,al
    cmp byte ptr [enemy_hold+bx],0
    je 1f
    jmp e_loop_return_original
1:
    cmp byte ptr [enemy_escape_ticks+bx],0
    je e_loop_history
    dec byte ptr [enemy_escape_ticks+bx]
    mov al,[enemy_escape_dir+bx]
    call tactical_enemy_probe6
    jc 1f
    jmp e_loop_return
1:
    mov byte ptr [enemy_escape_ticks+bx],0
e_loop_history:
    mov al,[enemy_loop_last+bx]
    cmp al,0xff
    je e_loop_store
    cmp al,dl
    je e_loop_same
    cmp dl,[enemy_loop_prev+bx]
    jne e_loop_reset
    inc byte ptr [enemy_loop_count+bx]
    jmp e_loop_check
e_loop_same:
    mov al,[enemy_px+bx]
    shr al,1
    shr al,1
    shr al,1
    shr al,1
    cmp al,[enemy_loop_x+bx]
    jne e_loop_reset
    mov al,[enemy_py+bx]
    xor ah,ah
    mov cl,12
    div cl
    cmp al,[enemy_loop_y+bx]
    jne e_loop_reset
    inc byte ptr [enemy_loop_count+bx]
    jmp e_loop_check
e_loop_reset:
    mov byte ptr [enemy_loop_count+bx],0
e_loop_check:
    cmp byte ptr [enemy_loop_count+bx],3
    jb e_loop_store
    mov al,dl
    inc al
    and al,3
    call tactical_enemy_probe6
    jnc e_loop_escaped
    mov al,dl
    add al,3
    and al,3
    call tactical_enemy_probe6
    jc e_loop_store
e_loop_escaped:
    mov [enemy_escape_dir+bx],al
    mov byte ptr [enemy_escape_ticks+bx],3
    mov byte ptr [enemy_loop_count+bx],0
    mov dl,al
e_loop_store:
    mov al,[enemy_loop_last+bx]
    mov [enemy_loop_prev+bx],al
    mov [enemy_loop_last+bx],dl
    mov al,[enemy_px+bx]
    shr al,1
    shr al,1
    shr al,1
    shr al,1
    mov [enemy_loop_x+bx],al
    mov al,[enemy_py+bx]
    xor ah,ah
    mov cl,12
    div cl
    mov [enemy_loop_y+bx],al
e_loop_return_original:
    mov al,dl
e_loop_return:
    pop dx
    pop cx
    ret

/* No reset across audio/video modes; clear only at stage load. */
tactical24_reset:
    push ax
    push cx
    push di
    mov byte ptr [p_loop_last],0xff
    mov byte ptr [p_loop_prev],0xff
    mov byte ptr [p_loop_count],0
    mov byte ptr [p_loop_escape],0
    mov di,offset enemy_loop_last
    mov al,0xff
    mov cx,8
    rep stosb
    xor al,al
    mov di,offset enemy_loop_count
    mov cx,20
    rep stosb
    pop di
    pop cx
    pop ax
    ret

.section .data
p_loop_last: .byte 0xff
p_loop_prev: .byte 0xff
p_loop_count: .byte 0
p_loop_escape: .byte 0
p_loop_escape_dir: .byte 0
p_loop_last_x: .byte 0
p_loop_last_y: .byte 0
enemy_loop_last: .space 4
enemy_loop_prev: .space 4
enemy_loop_count: .space 4
enemy_escape_ticks: .space 4
enemy_escape_dir: .space 4
enemy_loop_x: .space 4
enemy_loop_y: .space 4
.section .text
