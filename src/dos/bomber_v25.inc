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
    call bomber26_roll
    ret

/* Random 4 entry points (left/right/top/bottom) and launch delay.
 * normal_play reseeds the RNG from BIOS timer before calling this on L1;
 * subsequent levels already have gameplay-driven RNG state. */
bomber26_roll:
    call random_byte
    and al,3
    mov [bomber26_direction],al
    mov [bomber25_axis],al
    shr byte ptr [bomber25_axis],1
    mov al,[bomber26_direction]
    and al,1
    mov [bomber26_reverse],al
    call random_byte
    and al,7
    add al,4       /* lanes 4..11 allow symmetrical +/-1 bombs */
    mov [bomber25_lane],al
    call random_byte
    and al,127
    add al,48      /* one pass begins after 48..175 ticks */
    mov [bomber26_departure],al
    ret

/* v0.26: only real contact between visible 12x12 tank chassis and the
 * bonus's opaque 11x10 frame. Input DL/DH top-left pixel of collector.
 * Returns CF=1 for overlap; no player/enemy register side effects. */
bonus26_touch:
    push ax
    push bx
    mov bl,[bonus_col]
    shl bl,1
    shl bl,1
    shl bl,1
    shl bl,1
    mov al,dl
    add al,13
    mov bh,bl
    add bh,2
    cmp al,bh
    jb bonus26_not_touching
    mov al,dl
    add al,2
    add bl,12
    cmp al,bl
    ja bonus26_not_touching
    mov al,[bonus_row]
    mov bl,12
    mul bl
    mov bl,al
    inc bl
    mov al,dh
    add al,11
    cmp al,bl
    jb bonus26_not_touching
    mov al,dh
    add bl,9
    cmp al,bl
    ja bonus26_not_touching
    stc
    jmp bonus26_touch_done
bonus26_not_touching:
    clc
bonus26_touch_done:
    pop bx
    pop ax
    ret

/* Apply to human pickup, allied pickup and enemy pickup alike. */
bonus25_collected:
    /* AL = collector 0=P1, 1=P2/ally, 2..5=enemy slot.  Flash
       the collector's tank only, never the background pickup tile. */
    mov [bonus26_flash_owner],al
    mov byte ptr [bonus25_flash_ticks],14
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
    mov al,[game_tick]
    cmp al,[bomber26_departure]
    jae 1f
    ret
1:
    mov byte ptr [bomber25_state],1
    mov byte ptr [bomber25_step],0
    mov byte ptr [bomber25_timer],0
    cmp byte ptr [bomber25_axis],0
    jne bomber25_vertical_start
    mov al,[bomber25_lane]
    mov ah,12
    mul ah
    mov [bomber25_y],al
    mov byte ptr [bomber25_x],0
    cmp byte ptr [bomber26_reverse],0
    je bomber25_flying
    mov byte ptr [bomber25_x],240
    jmp bomber25_flying
bomber25_vertical_start:
    mov al,[bomber25_lane]
    shl al,1
    shl al,1
    shl al,1
    shl al,1
    mov [bomber25_x],al
    mov byte ptr [bomber25_y],0
    cmp byte ptr [bomber26_reverse],0
    je bomber25_flying
    mov byte ptr [bomber25_y],180
bomber25_flying:
    cmp byte ptr [bomber25_axis],0
    jne bomber25_vertical_move
    cmp byte ptr [bomber26_reverse],0
    jne bomber26_left_move
    cmp byte ptr [bomber25_x],240
    jb 1f
    jmp bomber25_finished
1:
    add byte ptr [bomber25_x],2
    jmp bomber26_x_advanced
bomber26_left_move:
    cmp byte ptr [bomber25_x],0
    jne 1f
    jmp bomber25_finished
1:
    sub byte ptr [bomber25_x],2
bomber26_x_advanced:
    inc byte ptr [bomber25_timer]
    cmp byte ptr [bomber25_timer],8
    jae 1f
    ret
1:
    mov byte ptr [bomber25_timer],0
    mov al,[bomber25_x]
    cmp byte ptr [bomber26_reverse],0
    jne 1f
    sub al,16
    jmp 2f
1:
    add al,16
2:
    shr al,1
    shr al,1
    shr al,1
    shr al,1
    mov [bomber25_base_col],al
    mov al,[bomber25_lane]
    mov [bomber25_base_row],al
    jmp bomber25_wave
bomber25_vertical_move:
    cmp byte ptr [bomber26_reverse],0
    jne bomber26_up_move
    cmp byte ptr [bomber25_y],180
    jb 1f
    jmp bomber25_finished
1:
    add byte ptr [bomber25_y],2
    jmp bomber26_y_advanced
bomber26_up_move:
    cmp byte ptr [bomber25_y],0
    jne 1f
    jmp bomber25_finished
1:
    sub byte ptr [bomber25_y],2
bomber26_y_advanced:
    inc byte ptr [bomber25_timer]
    cmp byte ptr [bomber25_timer],6
    jae 1f
    ret
1:
    mov byte ptr [bomber25_timer],0
    mov al,[bomber25_y]
    cmp byte ptr [bomber26_reverse],0
    jne 1f
    sub al,12
    jmp 2f
1:
    add al,12
2:
    xor ah,ah
    mov cl,12
    div cl
    mov [bomber25_base_row],al
    mov al,[bomber25_lane]
    mov [bomber25_base_col],al
bomber25_wave:
    /* Alternating ONE bomb per step: axis-1, axis+1, axis-1 ...
       behind current flight position. Exactly symmetrical on both sides,
       with a one-cell along-track stagger (true checkerboard). */
    mov dl,[bomber25_base_col]
    mov dh,[bomber25_base_row]
    xor bx,bx
    test byte ptr [bomber25_step],1
    jz bomber26_bomb_left
    mov bx,1
    cmp byte ptr [bomber25_axis],0
    jne bomber26_bomb_right_vertical
    inc dh
    jmp bomber26_bomb_single
bomber26_bomb_right_vertical:
    inc dl
    jmp bomber26_bomb_single
bomber26_bomb_left:
    cmp byte ptr [bomber25_axis],0
    jne bomber26_bomb_left_vertical
    dec dh
    jmp bomber26_bomb_single
bomber26_bomb_left_vertical:
    dec dl
bomber26_bomb_single:
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

/* Restore old aircraft and explosion silhouettes; NO pickup-cell overlay. */
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
    jne bomber26_vertical_sprite
    cmp byte ptr [bomber26_reverse],0
    je bomber26_sprite_ready
    mov si,offset smooth_plane_horizontal_left
    jmp bomber26_sprite_ready
bomber26_vertical_sprite:
    mov si,offset smooth_plane_vertical_down
    cmp byte ptr [bomber26_reverse],0
    je bomber26_sprite_ready
    mov si,offset smooth_plane_vertical
bomber26_sprite_ready:
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
bomber25_paint_done:
    pop si
    pop dx
    pop bx
    pop ax
    ret

.section .data
bomber25_state: .byte 0   /* 0 not started, 1 flying, 2 done */
bomber25_axis: .byte 0    /* 0 horizontal, 1 vertical */
bomber26_reverse: .byte 0  /* 0 right/down, 1 left/up */
bomber26_direction: .byte 0
bomber26_departure: .byte 90
bonus26_flash_owner: .byte 0
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
