/* v0.25 one bomber fly-by per stage: 2px/tick, horizontal on odd
 * stages, vertical on even stages. Checkerboard impacts across a
 * three-lane strip every 16/12px. No falling-bomb sprite. HQ is immune.
 * All rendering is tile-dirty and 8086 only. */
.section .text

bomber25_reset:
    mov byte ptr [bomber25_state],0
    mov byte ptr [bomber25_step],0
    mov byte ptr [bomber25_timer],0
    mov byte ptr [bomber25_fx_ticks],0
    mov byte ptr [bomber25_fx_ticks+1],0
    mov byte ptr [paint_bomber25_valid],0
    mov byte ptr [paint_bomber25_fx_valid],0
    mov byte ptr [paint_bomber25_fx_valid+1],0
    mov byte ptr [bonus25_flash_ticks],0
    mov byte ptr [paint_bonus25_valid],0
    ret

/* Apply to human pickup, allied pickup and enemy pickup alike. */
bonus25_collected:
    push ax
    mov al,[bonus_col]
    shl al,1
    shl al,1
    shl al,1
    shl al,1
    mov [bonus25_flash_x],al
    mov al,[bonus_row]
    mov ah,12
    mul ah
    mov [bonus25_flash_y],al
    mov byte ptr [bonus25_flash_ticks],14
    pop ax
    ret

bomber25_tick:
    cmp byte ptr [bonus25_flash_ticks],0
    je bomber25_fx_tick
    dec byte ptr [bonus25_flash_ticks]
bomber25_fx_tick:
    cmp byte ptr [bomber25_fx_ticks],0
    je 1f
    dec byte ptr [bomber25_fx_ticks]
1:
    cmp byte ptr [bomber25_fx_ticks+1],0
    je bomber25_state_tick
    dec byte ptr [bomber25_fx_ticks+1]
bomber25_state_tick:
    cmp byte ptr [game_state],0
    je 1f
    ret
1:
    cmp byte ptr [bomber25_state],2
    jne 1f
    ret
1:
    cmp byte ptr [bomber25_state],1
    je bomber25_flying
    cmp byte ptr [game_tick],72
    jae 1f
    ret
1:
    mov byte ptr [bomber25_state],1
    mov byte ptr [bomber25_step],0
    mov byte ptr [bomber25_timer],0
    mov al,[stage]
    and al,7
    add al,3
    mov [bomber25_lane],al
    test byte ptr [stage],1
    jz bomber25_vertical_start
    /* horizontal: y is a 12px grid lane, x moves from left to right */
    mov ah,12
    mul ah
    mov [bomber25_y],al
    mov byte ptr [bomber25_x],0
    mov byte ptr [bomber25_axis],0
    jmp bomber25_flying
bomber25_vertical_start:
    shl al,1
    shl al,1
    shl al,1
    shl al,1
    mov [bomber25_x],al
    mov byte ptr [bomber25_y],0
    mov byte ptr [bomber25_axis],1
bomber25_flying:
    cmp byte ptr [bomber25_axis],0
    jne bomber25_vertical_move
    cmp byte ptr [bomber25_x],240
    jb 1f
    jmp bomber25_finished
1:
    add byte ptr [bomber25_x],2
    inc byte ptr [bomber25_timer]
    cmp byte ptr [bomber25_timer],8
    jae 1f
    ret
1:
    mov byte ptr [bomber25_timer],0
    mov al,[bomber25_x]
    sub al,16
    shr al,1
    shr al,1
    shr al,1
    shr al,1
    mov [bomber25_base_col],al
    mov al,[bomber25_lane]
    mov [bomber25_base_row],al
    jmp bomber25_wave
bomber25_vertical_move:
    cmp byte ptr [bomber25_y],180
    jae bomber25_finished
    add byte ptr [bomber25_y],2
    inc byte ptr [bomber25_timer]
    cmp byte ptr [bomber25_timer],6
    jae 1f
    ret
1:
    mov byte ptr [bomber25_timer],0
    mov al,[bomber25_y]
    sub al,12
    xor ah,ah
    mov cl,12
    div cl
    mov [bomber25_base_row],al
    mov al,[bomber25_lane]
    mov [bomber25_base_col],al
bomber25_wave:
    /* Along-track parity selects alternate squares in three lanes.
       Even columns: two bombs (lanes 0 and 2), odd: one (lane 1). */
    mov dl,[bomber25_base_col]
    mov dh,[bomber25_base_row]
    test byte ptr [bomber25_step],1
    jz bomber25_first_impact
    cmp byte ptr [bomber25_axis],0
    jne 1f
    inc dh
    jmp bomber25_first_impact
1:
    inc dl
bomber25_first_impact:
    xor bx,bx
    call bomber25_impact
    test byte ptr [bomber25_step],1
    jnz bomber25_wave_done
    mov dl,[bomber25_base_col]
    mov dh,[bomber25_base_row]
    cmp byte ptr [bomber25_axis],0
    jne bomber25_second_col
    add dh,2
    jmp bomber25_second_impact
bomber25_second_col:
    add dl,2
bomber25_second_impact:
    mov bx,1
    call bomber25_impact
bomber25_wave_done:
    inc byte ptr [bomber25_step]
bomber25_done:
    ret
bomber25_finished:
    mov byte ptr [bomber25_state],2
    ret

/* DL/DH tile grid, BX 0/1 blast visual slot. One ordinary shot worth
 * of damage. Bombs never clear bonus_active, nor hurt the base 'B'. */
bomber25_impact:
    push ax
    push bx
    push cx
    push dx
    push si
    cmp dl,15
    ja bomber25_impact_done
    cmp dh,15
    ja bomber25_impact_done
    call get_tile
    cmp al,'B'
    je bomber25_impact_done
    cmp al,'#'
    jne bomber25_no_brick
    mov al,2
    call damage_brick
    call draw_cell
bomber25_no_brick:
    mov al,dl
    shl al,1
    shl al,1
    shl al,1
    shl al,1
    mov [bomber25_hit_x],al
    mov [bomber25_fx_x+bx],al
    mov al,dh
    mov ah,12
    mul ah
    mov [bomber25_hit_y],al
    mov [bomber25_fx_y+bx],al
    mov byte ptr [bomber25_fx_ticks+bx],8
    call bomber25_hit_enemies
    call bomber25_hit_players
    mov ax,1500
    call sound_play
bomber25_impact_done:
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

bomber25_hit_enemies:
    push ax
    push bx
    xor bx,bx
bomber25_enemy_loop:
    cmp byte ptr [enemy_active+bx],0
    je bomber25_enemy_next
    mov al,[bomber25_hit_x]
    sub al,[enemy_px+bx]
    add al,8
    cmp al,16
    ja bomber25_enemy_next
    mov al,[bomber25_hit_y]
    sub al,[enemy_py+bx]
    add al,6
    cmp al,12
    ja bomber25_enemy_next
    cmp byte ptr [enemy_hp+bx],1
    jbe bomber25_enemy_killed
    dec byte ptr [enemy_hp+bx]
    cmp byte ptr [enemy_type+bx],3
    jne bomber25_enemy_next
    mov byte ptr [enemy_track_damage+bx],1
    jmp bomber25_enemy_next
bomber25_enemy_killed:
    mov byte ptr [enemy_active+bx],0
    mov byte ptr [shot_active+bx],0
    inc byte ptr [enemy_killed]
    call maybe_drop_bonus
    call draw_hud
bomber25_enemy_next:
    inc bx
    cmp bx,4
    jb bomber25_enemy_loop
    pop bx
    pop ax
    ret

bomber25_hit_players:
    push ax
    cmp byte ptr [lives],0
    je bomber25_check_p2
    cmp byte ptr [player_shield],0
    jne bomber25_check_p2
    mov al,[bomber25_hit_x]
    sub al,[player_px]
    add al,8
    cmp al,16
    ja bomber25_check_p2
    mov al,[bomber25_hit_y]
    sub al,[player_py]
    add al,6
    cmp al,12
    ja bomber25_check_p2
    dec byte ptr [lives]
    jz bomber25_p1_last_life
    mov byte ptr [player_px],112
    mov byte ptr [player_py],168
    mov byte ptr [player_col],7
    mov byte ptr [player_row],14
    mov byte ptr [player_dir],0
    mov byte ptr [player_shield],60
    call draw_hud
    jmp bomber25_check_p2
bomber25_p1_last_life:
    call draw_hud
    cmp byte ptr [coop_mode],0
    je bomber25_game_over
    cmp byte ptr [coop_lives],0
    jne bomber25_check_p2
bomber25_game_over:
    mov byte ptr [game_state],2
bomber25_check_p2:
    cmp byte ptr [coop_mode],0
    je bomber25_players_done
    cmp byte ptr [coop_lives],0
    je bomber25_players_done
    cmp word ptr [ally_ticks],0
    je bomber25_players_done
    cmp byte ptr [ally_shield],0
    jne bomber25_players_done
    mov al,[bomber25_hit_x]
    sub al,[ally_px]
    add al,8
    cmp al,16
    ja bomber25_players_done
    mov al,[bomber25_hit_y]
    sub al,[ally_py]
    add al,6
    cmp al,12
    ja bomber25_players_done
    call coop25_hit_p2
bomber25_players_done:
    pop ax
    ret

/* Restore stale silhouettes BEFORE new sprite painting. */
bomber25_mark_old:
    push ax
    push bx
    push dx
    cmp byte ptr [paint_bomber25_valid],0
    je 1f
    mov dl,[paint_bomber25_x]
    mov dh,[paint_bomber25_y]
    call mark_dirty_rect
1:
    mov byte ptr [paint_bomber25_valid],0
    xor bx,bx
bomber25_old_fx:
    cmp byte ptr [paint_bomber25_fx_valid+bx],0
    je 1f
    mov dl,[paint_bomber25_fx_x+bx]
    mov dh,[paint_bomber25_fx_y+bx]
    call mark_dirty_rect
1:
    mov byte ptr [paint_bomber25_fx_valid+bx],0
    inc bx
    cmp bx,2
    jb bomber25_old_fx
    cmp byte ptr [paint_bonus25_valid],0
    je bomber25_old_end
    mov dl,[paint_bonus25_x]
    mov dh,[paint_bonus25_y]
    call mark_dirty_rect
bomber25_old_end:
    mov byte ptr [paint_bonus25_valid],0
    pop dx
    pop bx
    pop ax
    ret

bomber25_paint:
    push ax
    push bx
    push dx
    push si
    cmp byte ptr [bomber25_state],1
    jne bomber25_paint_fx
    mov dl,[bomber25_x]
    mov dh,[bomber25_y]
    mov [paint_bomber25_x],dl
    mov [paint_bomber25_y],dh
    mov byte ptr [paint_bomber25_valid],1
    mov si,offset smooth_plane_horizontal
    cmp byte ptr [bomber25_axis],0
    je 1f
    mov si,offset smooth_plane_vertical
1:
    call draw_smooth_sprite
bomber25_paint_fx:
    xor bx,bx
bomber25_paint_fx_loop:
    cmp byte ptr [bomber25_fx_ticks+bx],0
    je bomber25_paint_fx_next
    mov dl,[bomber25_fx_x+bx]
    mov dh,[bomber25_fx_y+bx]
    mov [paint_bomber25_fx_x+bx],dl
    mov [paint_bomber25_fx_y+bx],dh
    mov byte ptr [paint_bomber25_fx_valid+bx],1
    mov si,offset smooth_explosion_1
    test byte ptr [game_tick],2
    jz 1f
    mov si,offset smooth_explosion_2
1:
    push bx
    call draw_smooth_sprite
    pop bx
bomber25_paint_fx_next:
    inc bx
    cmp bx,2
    jb bomber25_paint_fx_loop
    cmp byte ptr [bonus25_flash_ticks],0
    je bomber25_paint_done
    test byte ptr [game_tick],2
    jnz bomber25_paint_done
    mov dl,[bonus25_flash_x]
    mov dh,[bonus25_flash_y]
    mov [paint_bonus25_x],dl
    mov [paint_bonus25_y],dh
    mov byte ptr [paint_bonus25_valid],1
    mov si,offset smooth_shield_outline
    call draw_smooth_sprite
bomber25_paint_done:
    pop si
    pop dx
    pop bx
    pop ax
    ret

.section .data
bomber25_state: .byte 0   /* 0 not started, 1 flying, 2 done */
bomber25_axis: .byte 0    /* 0 horizontal, 1 vertical */
bomber25_x: .byte 0
bomber25_y: .byte 0
bomber25_lane: .byte 0
bomber25_timer: .byte 0
bomber25_step: .byte 0
bomber25_base_col: .byte 0
bomber25_base_row: .byte 0
bomber25_hit_x: .byte 0
bomber25_hit_y: .byte 0
bomber25_fx_ticks: .space 2
bomber25_fx_x: .space 2
bomber25_fx_y: .space 2
paint_bomber25_valid: .byte 0
paint_bomber25_x: .byte 0
paint_bomber25_y: .byte 0
paint_bomber25_fx_valid: .space 2
paint_bomber25_fx_x: .space 2
paint_bomber25_fx_y: .space 2
bonus25_flash_ticks: .byte 0
bonus25_flash_x: .byte 0
bonus25_flash_y: .byte 0
paint_bonus25_valid: .byte 0
paint_bonus25_x: .byte 0
paint_bonus25_y: .byte 0
.section .text
