/* v0.13 bounded 16x16 whole-map routing for the 4.77 MHz 8088.
 * Flow fields are compiled at stage setup, not recomputed every frame.
 * One global reverse BFS for the HQ and one per flank staging location.
 * Shared route scratch is never accessed inside IRQ1.
 * Traversal: floor, forest, ice, cleared bricks. Steel/water/brick/HQ block.
 */
.section .text

strategy_reset:
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    mov byte ptr [squad_phase],0
    mov byte ptr [squad_clock],0
    mov byte ptr [tactical_player_target],0xff
    mov byte ptr [route_dirty],0
    mov di,offset route_base
    mov al,0xe7                /* player-side approach to HQ (7,14) */
    call strategy_fill
    mov di,offset route_left
    mov al,0xb3                /* flank rally (3,11) */
    call strategy_fill
    mov di,offset route_right
    mov al,0xbc                /* flank rally (12,11) */
    call strategy_fill
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

strategy_tick:
    /* Update squad orders after both flanks stage or after 7 seconds.
       Rebuild routes only after a wall is destroyed, and off the 18 Hz
       per-frame hot path. */
    cmp byte ptr [route_dirty],0
    je strategy_clock
    test byte ptr [game_tick],31
    jnz strategy_clock
    call strategy_reset_routes
strategy_clock:
    cmp byte ptr [squad_phase],0
    jne strategy_tick_done
    inc byte ptr [squad_clock]
    cmp byte ptr [squad_clock],126
    jae strategy_assault
    cmp byte ptr [enemy_active+1],0
    je strategy_tick_done
    cmp byte ptr [enemy_active+2],0
    je strategy_tick_done
    cmp byte ptr [enemy_py+1],126
    jb strategy_tick_done
    cmp byte ptr [enemy_py+2],126
    jb strategy_tick_done
strategy_assault:
    mov byte ptr [squad_phase],1
strategy_tick_done:
    ret

strategy_reset_routes:
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    mov di,offset route_base
    mov al,0xe7
    call strategy_fill
    mov di,offset route_left
    mov al,0xb3
    call strategy_fill
    mov di,offset route_right
    mov al,0xbc
    call strategy_fill
    mov byte ptr [route_dirty],0
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

/* AL = target tile index, DI = pointer to 256-byte output field.
 * Reusable 256-byte FIFO; each square enters at most once.
 * Queue head and tail wrap safely because frontier is always <256.
 */
strategy_fill:
    mov [route_goal_cell],al
    mov [route_field_ptr],di
    mov cx,256
    mov al,0xff
strategy_fill_clear:
    mov [di],al
    inc di
    loop strategy_fill_clear
    mov byte ptr [route_head],0
    mov byte ptr [route_tail],1
    mov al,[route_goal_cell]
    mov [route_queue],al
    xor bx,bx
    mov bl,al
    mov di,[route_field_ptr]
    mov byte ptr [di+bx],0
strategy_fill_loop:
    mov al,[route_head]
    cmp al,[route_tail]
    je strategy_fill_done
    xor bx,bx
    mov bl,al
    mov al,[route_queue+bx]
    inc byte ptr [route_head]
    mov [route_cur_cell],al
    mov bl,al
    mov di,[route_field_ptr]
    mov al,[di+bx]
    inc al
    mov [route_cur_distance],al
    mov al,[route_cur_cell]
    and al,15
    je strategy_fill_noleft
    mov al,[route_cur_cell]
    dec al
    call strategy_visit
strategy_fill_noleft:
    mov al,[route_cur_cell]
    and al,15
    cmp al,15
    je strategy_fill_noright
    mov al,[route_cur_cell]
    inc al
    call strategy_visit
strategy_fill_noright:
    cmp byte ptr [route_cur_cell],16
    jb strategy_fill_noup
    mov al,[route_cur_cell]
    sub al,16
    call strategy_visit
strategy_fill_noup:
    cmp byte ptr [route_cur_cell],240
    jae strategy_fill_loop
    mov al,[route_cur_cell]
    add al,16
    call strategy_visit
    jmp strategy_fill_loop
strategy_fill_done:
    ret

/* Visit candidate cell AL if open and not already in the flow field. */
strategy_visit:
    push ax
    push bx
    push si
    mov ah,al
    xor bx,bx
    mov bl,al
    mov al,[level_data+bx]
    cmp al,'#'
    je strategy_visit_skip
    cmp al,'T'
    je strategy_visit_skip
    cmp al,'~'
    je strategy_visit_skip
    cmp al,'B'
    je strategy_visit_skip
    mov si,[route_field_ptr]
    add si,bx
    cmp byte ptr [si],0xff
    jne strategy_visit_skip
    mov al,[route_cur_distance]
    mov [si],al
    xor bx,bx
    mov bl,[route_tail]
    mov [route_queue+bx],ah
    inc byte ptr [route_tail]
strategy_visit_skip:
    pop si
    pop bx
    pop ax
    ret

/* BX enemy index. DL/DH fallback target pixel. AL=selected heading.
 * Use a cached global field to choose a genuinely connected tile,
 * with a physical 6-pixel hull probe to avoid nearby dynamic collisions.
 * When blocked by another tank, wait for the next order rather than
 * repeatedly choosing an impossible route.
 */
strategy_route_heading:
    push bx
    push cx
    push dx
    push si
    push di
    mov byte ptr [route_best_dir],0xff
    mov word ptr [route_best_score],0xffff
    /* Convert actor top-left pixel into map cell (16x12). */
    mov al,[enemy_px+bx]
    shr al,1
    shr al,1
    shr al,1
    shr al,1
    mov [route_actor_col],al
    mov al,[enemy_py+bx]
    xor ah,ah
    mov cl,12
    div cl
    mov [route_actor_row],al
    shl al,1
    shl al,1
    shl al,1
    shl al,1
    add al,[route_actor_col]
    mov [route_actor_cell],al
    xor si,si
strategy_route_next:
    mov ax,si
    call tactical_enemy_probe6
    jnc strategy_route_probe_ok
    jmp strategy_route_skip
strategy_route_probe_ok:
    mov al,[route_actor_cell]
    cmp si,0
    jne strategy_route_not_up
    cmp byte ptr [route_actor_row],0
    je strategy_route_skip
    sub al,16
    jmp strategy_route_eval
strategy_route_not_up:
    cmp si,1
    jne strategy_route_not_right
    cmp byte ptr [route_actor_col],15
    je strategy_route_skip
    inc al
    jmp strategy_route_eval
strategy_route_not_right:
    cmp si,2
    jne strategy_route_not_down
    cmp byte ptr [route_actor_row],15
    je strategy_route_skip
    add al,16
    jmp strategy_route_eval
strategy_route_not_down:
    cmp byte ptr [route_actor_col],0
    je strategy_route_skip
    dec al
strategy_route_eval:
    xor ah,ah
    mov di,[route_active_field]
    add di,ax
    mov al,[di]
    cmp al,0xff
    je strategy_route_skip
    xor ah,ah
    shl ax,1
    shl ax,1
    shl ax,1                   /* eight points per tile of distance */
    mov cl,[enemy_dir+bx]
    cmp cl,0xff
    je strategy_route_compare
    cmp si,cx
    jne strategy_route_turn
    cmp ax,3
    jb strategy_route_compare
    sub ax,3                   /* persist in current heading */
    jmp strategy_route_compare
strategy_route_turn:
    add cl,2
    and cl,3
    cmp si,cx
    jne strategy_route_compare
    add ax,4                   /* small penalty; BFS progress still wins */
strategy_route_compare:
    cmp ax,[route_best_score]
    jae strategy_route_skip
    mov [route_best_score],ax
    mov ax,si
    mov [route_best_dir],al
strategy_route_skip:
    inc si
    cmp si,4
    jae strategy_route_end_loop
    jmp strategy_route_next
strategy_route_end_loop:
    mov al,[route_best_dir]
    cmp al,0xff
    jne strategy_route_ready
    /* No open global route from this tile: use the local corner planner.
       It can choose a brick to breach, without making every unit freeze. */
    call tactical_route_choose
strategy_route_ready:
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    ret

.section .data
squad_phase: .byte 0
squad_clock: .byte 0
route_dirty: .byte 0
tactical_player_target: .byte 0xff
route_goal_cell: .byte 0
route_field_ptr: .word 0
route_active_field: .word 0
route_head: .byte 0
route_tail: .byte 0
route_cur_cell: .byte 0
route_cur_distance: .byte 0
route_actor_cell: .byte 0
route_actor_row: .byte 0
route_actor_col: .byte 0
route_best_dir: .byte 0xff
route_best_score: .word 0xffff
route_base: .space 256
route_left: .space 256
route_right: .space 256
route_queue: .space 256
.section .text
