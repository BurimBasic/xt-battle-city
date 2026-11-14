/* v0.23: compact 8086-only hazardous ricochet and new live weapon modes.
 * All quantities are RAM only; 180 BIOS ticks = roughly ten seconds.
 * Quad and super use the real P1 shell collision path. The independent
 * ping-pong projectile never borrows a team-owned bullet slot.
 */
.section .text
bonus23_tick:
    cmp byte ptr [quad_ticks],0
    je b23_no_quad
    dec byte ptr [quad_ticks]
b23_no_quad:
    cmp byte ptr [super_ticks],0
    je b23_no_super
    dec byte ptr [super_ticks]
b23_no_super:
    cmp byte ptr [pong_ticks],0
    je b23_pong_done
    dec byte ptr [pong_ticks]
    jnz b23_pong_move
    mov byte ptr [pong_active],0
    ret
b23_pong_move:
    cmp byte ptr [pong_active],0
    je b23_pong_done
    call pong23_step
b23_pong_done:
    ret

/* AL is zero for P1 or one for the enemy in BX. */
pong23_launch:
    push ax
    push dx
    cmp byte ptr [pong_active],0
    jne pong23_launch_done
    cmp al,2
    je pong24_coop_origin
    cmp al,0
    jne pong23_enemy_origin
    mov dl,[player_px]
    mov dh,[player_py]
    mov al,[player_dir]
    jmp pong23_origin_ready
pong24_coop_origin:
    mov dl,[ally_px]
    mov dh,[ally_py]
    mov al,[ally_dir]
    jmp pong23_origin_ready
pong23_enemy_origin:
    mov dl,[enemy_px+bx]
    mov dh,[enemy_py+bx]
    mov al,[enemy_dir+bx]
pong23_origin_ready:
    /* v0.30: diagonal ricochet also leaves the barrel, not the hull. */
    call gun29_muzzle
    mov [pong_px],dl
    mov [pong_py],dh
    /* Four diagonal directions, both axes always move. */
    mov byte ptr [pong_dx],1
    mov byte ptr [pong_dy],1
    cmp al,2
    jb pong23_x_positive
    mov byte ptr [pong_dx],-1
pong23_x_positive:
    cmp al,1
    je pong23_vel_ready
    cmp al,2
    je pong23_vel_ready
    mov byte ptr [pong_dy],-1
pong23_vel_ready:
    mov byte ptr [pong_active],1
    mov byte ptr [pong_grace],8
pong23_launch_done:
    pop dx
    pop ax
    ret

/* Three diagonal pixels per BIOS tick (4.24px ballistic speed).
 * Reflect the x/y components independently off blocking tank terrain,
 * headquarters and the hard 256x192 field boundary. */
pong23_step:
    push ax
    push bx
    push cx
    push dx
    mov cl,3
pong23_substep:
    mov dl,[pong_px]
    add dl,[pong_dx]
    cmp dl,240
    ja pong23_bounce_x
    mov dh,[pong_py]
    call rect_passable
    jc pong23_bounce_x
    mov [pong_px],dl
    jmp pong23_try_y
pong23_bounce_x:
    neg byte ptr [pong_dx]
pong23_try_y:
    mov dh,[pong_py]
    add dh,[pong_dy]
    cmp dh,180
    ja pong23_bounce_y
    mov dl,[pong_px]
    call rect_passable
    jc pong23_bounce_y
    mov [pong_py],dh
    jmp pong23_after_y
pong23_bounce_y:
    neg byte ptr [pong_dy]
pong23_after_y:
    dec cl
    jnz pong23_substep
    cmp byte ptr [pong_grace],0
    je pong23_check_hits
    dec byte ptr [pong_grace]
pong23_check_hits:
    xor bx,bx
pong23_enemy_scan:
    cmp byte ptr [enemy_active+bx],0
    je pong23_next_enemy
    mov al,[pong_px]
    sub al,[enemy_px+bx]
    add al,8
    cmp al,16
    ja pong23_next_enemy
    mov al,[pong_py]
    sub al,[enemy_py+bx]
    add al,6
    cmp al,12
    ja pong23_next_enemy
    /* Any contact is fatal, even for fully armoured enemies. */
    mov byte ptr [enemy_active+bx],0
    mov byte ptr [shot_active+bx],0
    inc byte ptr [enemy_killed]
    push bx
    call maybe_drop_bonus
    pop bx
    xor ax,ax
    mov al,[enemy_type+bx]
    push bx
    mov bl,al
    inc byte ptr [kills_by_type+bx]
    pop bx
    inc al
    mov dl,100
    mul dl
    add [score],ax
    call draw_hud
pong23_next_enemy:
    inc bx
    cmp bx,4
    jb pong23_enemy_scan
    /* Own ricochet is also lethal; a short launch grace prevents the
       initial projectile from instantly hitting the firing hull. */
    cmp byte ptr [pong_grace],0
    jne pong23_ally_check
    mov al,[pong_px]
    sub al,[player_px]
    add al,8
    cmp al,16
    ja pong23_ally_check
    mov al,[pong_py]
    sub al,[player_py]
    add al,6
    cmp al,12
    ja pong23_ally_check
    cmp byte ptr [player_shield],0
    jne pong23_ally_check
    dec byte ptr [lives]
    jz pong23_player_lost
    mov byte ptr [player_px],112
    mov byte ptr [player_py],168
    mov byte ptr [player_col],7
    mov byte ptr [player_row],14
    mov byte ptr [player_shield],40
    call draw_hud
    jmp pong23_ally_check
pong23_player_lost:
    cmp byte ptr [coop_mode],0
    je 1f
    cmp byte ptr [coop_lives],0
    jne pong23_ally_check
1:
    mov byte ptr [game_state],2
pong23_ally_check:
    cmp word ptr [ally_ticks],0
    je pong23_done
    mov al,[pong_px]
    sub al,[ally_px]
    add al,8
    cmp al,16
    ja pong23_done
    mov al,[pong_py]
    sub al,[ally_py]
    add al,6
    cmp al,12
    ja pong23_done
    cmp byte ptr [coop_mode],0
    je pong24_ordinary_ally
    cmp byte ptr [ally_shield],0
    jne pong23_done
    cmp byte ptr [coop_lives],0
    je pong23_done
    dec byte ptr [coop_lives]
    mov word ptr [ally_ticks],0
    call draw_hud
    cmp byte ptr [lives],0
    jne pong23_done
    mov byte ptr [game_state],2
    jmp pong23_done
pong24_ordinary_ally:
    cmp byte ptr [coop_mode],0
    je pong23_auto_ally_dead
    call coop25_hit_p2
    jmp pong23_done
pong23_auto_ally_dead:
    mov word ptr [ally_ticks],0
pong23_done:
    pop dx
    pop cx
    pop bx
    pop ax
    ret

/* Full 4-way barrage uses the third spare shell slot; do_fire() launches
 * the primary in the selected direction then fills the other three.
 * No cheating damage: all four advance via normal bullet collisions. */
quad23_spawn:
    push ax
    push bx
    push dx
    xor bx,bx
quad23_fill:
    mov dl,[player_px]
    mov dh,[player_py]
    mov al,[player_dir]
    add al,bl
    inc al
    and al,3
    mov [extra_dir+bx],al
    call gun29_muzzle
    mov [extra_px+bx],dl
    mov [extra_py+bx],dh
    mov byte ptr [extra_active+bx],1
    mov byte ptr [extra_homing+bx],0
    inc bx
    cmp bx,3
    jb quad23_fill
    pop dx
    pop bx
    pop ax
    ret

/* The hyper-shell can destroy tiles and pass on; only the map boundary
 * ends it.  The calling standard projectile routine handles enemies.
 * AL=1 brick, 2 steel, 3 HQ, SI=tile address from projectile_probe. */
super23_terrain:
    cmp al,1
    jne super23_not_brick
    call chip_brick_pixel
    ret
super23_not_brick:
    cmp al,2
    jne super23_done
    mov byte ptr [si],'.'
    mov byte ptr [route_dirty],1
    mov dl,[probe_col]
    mov dh,[probe_row]
    call draw_cell
super23_done:
    ret

/* Actor and projectile rendering uses an existing original bright
 * alternating pair of CGA bullet stamps. Dirty rectangles are restored. */
pong23_paint:
    cmp byte ptr [pong_active],0
    je pong23_paint_done
    mov dl,[pong_px]
    mov dh,[pong_py]
    mov [paint_pong_x],dl
    mov [paint_pong_y],dh
    mov byte ptr [paint_pong_valid],1
    mov si,offset smooth_bullet
    test byte ptr [game_tick],1
    jz pong23_paint_ready
    mov si,offset smooth_enemy_bullet
pong23_paint_ready:
    call draw_smooth_sprite
pong23_paint_done:
    ret

/* Reuse the cached 16x16 bonus distance field to intercept the final
 * hidden tank (and to exploit a powerful laser). This is not a blind
 * Manhattan chase through steel. Recompute at most every 16 ticks. */
tactical23_hunt:
    push bx
    push cx
    push dx
    push si
    push di
    mov dl,[enemy_px+bx]
    add dl,8
    shr dl,1
    shr dl,1
    shr dl,1
    shr dl,1
    mov al,[enemy_py+bx]
    add al,6
    xor ah,ah
    mov cl,12
    div cl
    mov dh,al
    mov [tactical23_hunt_col],dl
    mov [tactical23_hunt_row],dh
    shl al,1
    shl al,1
    shl al,1
    shl al,1
    add al,dl
    cmp al,[tactical23_last_cell]
    jne tactical23_rebuild_route
    test byte ptr [game_tick],15
    jnz tactical23_route_valid
tactical23_rebuild_route:
    mov [tactical23_last_cell],al
    mov di,offset route_hunt
    call strategy_fill
tactical23_route_valid:
    mov byte ptr [tactical23_hunting],1
    call strategy_bonus_heading
    pushf
    mov [tactical23_heading],al
    mov byte ptr [tactical23_hunting],0
    popf
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    mov al,[tactical23_heading]
    ret

/* Enemies keep the actual stolen weapon for 180 BIOS ticks, rather
 * than a misleading permanent tank-class upgrade. One mode per unit. */
enemy23_tick:
    push bx
    xor bx,bx
enemy23_timer_loop:
    cmp byte ptr [enemy_weapon_ticks+bx],0
    je enemy23_next_timer
    dec byte ptr [enemy_weapon_ticks+bx]
enemy23_next_timer:
    inc bx
    cmp bx,4
    jb enemy23_timer_loop
    pop bx
    cmp byte ptr [player_slow_ticks],0
    je enemy23_clock_done
    dec byte ptr [player_slow_ticks]
enemy23_clock_done:
    ret

/* Enemy's real three-way/four-way fire, not a cosmetic class change.
 * Primary enemy shot uses the normal slot 0..3. Auxiliary slots 4..6
 * share the original physical collision, friendly fire and rendering. */
enemy23_burst:
    push ax
    push bx
    push cx
    push dx
    push si
    mov cl,1
    mov si,4
enemy23_burst_loop:
    cmp cl,2
    jne enemy23_burst_slot
    cmp byte ptr [enemy_weapon_kind+bx],12
    jne enemy23_burst_skip
enemy23_burst_slot:
    cmp byte ptr [shot_active+si],0
    jne enemy23_burst_skip
    /* Every spread projectile emerges from the ORIGINAL barrel muzzle,
       then acquires its own spread direction; no center-of-hull start. */
    mov dl,[enemy_px+bx]
    mov dh,[enemy_py+bx]
    mov al,[enemy_dir+bx]
    call gun29_muzzle
    mov [shot_px+si],dl
    mov [shot_py+si],dh
    mov al,[enemy_dir+bx]
    add al,cl
    and al,3
    mov [shot_dir+si],al
    mov byte ptr [shot_active+si],1
    mov byte ptr [shot_super+si],0
    mov [shot_owner+si],bl
    inc si
enemy23_burst_skip:
    inc cl
    cmp cl,4
    jb enemy23_burst_loop
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

/* Real enemy laser: instantaneous normal collision trace, including
 * walls and friendly tanks. Use the existing CGA alternating beam paint. */
enemy23_laser:
    push ax
    push cx
    /* Beam begins at the same muzzle as the normal enemy shell. */
    mov al,[shot_px+bx]
    mov [laser_start_x],al
    mov al,[shot_py+bx]
    mov [laser_start_y],al
    mov al,[enemy_dir+bx]
    mov [laser_dir],al
    mov byte ptr [laser_flash_ticks],7  /* visibly held ~0.38 s */
    mov cx,95
enemy23_laser_loop:
    cmp byte ptr [shot_active+bx],0
    je enemy23_laser_end
    push cx
    call advance_enemy_shot_smooth
    pop cx
    loop enemy23_laser_loop
enemy23_laser_end:
    mov al,[shot_px+bx]
    mov [laser_end_x],al
    mov al,[shot_py+bx]
    mov [laser_end_y],al
    pop cx
    pop ax
    ret

/* Guided enemy shot periodically re-aims at P1 using actual positions. */
enemy23_home:
    push ax
    push bx
    push dx
    push si
    mov si,bx
    xor bx,bx
    mov bl,[shot_owner+si]
    cmp byte ptr [enemy_weapon_kind+bx],9
    jne enemy23_home_done
    cmp byte ptr [enemy_weapon_ticks+bx],0
    je enemy23_home_done
    mov dl,[player_px]
    sub dl,[shot_px+si]
    jnc enemy23_dx_ok
    neg dl
enemy23_dx_ok:
    mov dh,[player_py]
    sub dh,[shot_py+si]
    jnc enemy23_dy_ok
    neg dh
enemy23_dy_ok:
    cmp dl,dh
    jb enemy23_home_vertical
    mov al,1
    mov dl,[player_px]
    cmp dl,[shot_px+si]
    ja enemy23_home_assign
    mov al,3
    jmp enemy23_home_assign
enemy23_home_vertical:
    mov al,0
    mov dl,[player_py]
    cmp dl,[shot_py+si]
    jb enemy23_home_assign
    mov al,2
enemy23_home_assign:
    mov [shot_dir+si],al
enemy23_home_done:
    pop si
    pop dx
    pop bx
    pop ax
    ret

.section .data
tactical23_hunting: .byte 0
tactical23_last_cell: .byte 0xff
tactical23_hunt_col: .byte 0
tactical23_hunt_row: .byte 0
tactical23_heading: .byte 0
quad_ticks: .byte 0
super_ticks: .byte 0
super_bullet_active: .byte 0
pong_ticks: .byte 0
pong_active: .byte 0
pong_grace: .byte 0
pong_px: .byte 0
pong_py: .byte 0
pong_dx: .byte 1
pong_dy: .byte 1
player_slow_ticks: .byte 0
enemy_weapon_kind: .space 4
enemy_weapon_ticks: .space 4
shot_owner: .space 7
shot_super: .space 7
paint_pong_valid: .byte 0
paint_pong_x: .byte 0
paint_pong_y: .byte 0
.section .text
