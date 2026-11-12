/* v0.24 two-human cooperative mode, RAM-only. Reuses the ally hull/shot
 * collider but NEVER the autonomous ally brain. Keyboard ISR only writes
 * held-key bits; game logic runs outside interrupt context. 8086 only. */
.section .text

/* Called after an actual P2 W/A/S/D/Ctrl make event from poll_controls. */
coop24_join:
    push ax
    cmp byte ptr [game_state],0
    jne coop24_join_done
    cmp byte ptr [coop_mode],0
    jne coop24_join_done
    call ally17_spawn
    jc coop24_join_done
    mov byte ptr [coop_mode],1
    /* Joining co-op hands BOTH tanks to their humans. */
    mov byte ptr [auto_mode],0
    mov byte ptr [held_keys],0
    mov byte ptr [manual_keys],0
    mov byte ptr [coop_lives],3
    mov byte ptr [lives],3
    mov byte ptr [coop25_respawn_pending],0
    mov word ptr [ally_ticks],0x7fff
    mov byte ptr [ally_shield],30
    mov byte ptr [ally_cooldown],0
    mov byte ptr [ally_stock],0
    call draw_hud
    call draw_mode_indicator
    call draw_bonus_indicator
coop24_join_done:
    pop ax
    ret

/* Stage clear keeps each player's remaining lives; no AI ally can spawn. */
coop24_spawn_stage:
    mov byte ptr [coop25_respawn_pending],0
    cmp byte ptr [coop_lives],0
    je coop24_stage_dead
    call coop25_try_respawn
    ret
coop24_stage_dead:
    mov word ptr [ally_ticks],0
    ret

/* AH key mask, BL=scan code with 80h break; 1/2/4/8 = WASD,
 * 10h = Ctrl. No BIOS or DOS calls inside the keyboard IRQ. */
coop24_key_event:
    push ax
    test bl,0x80
    jnz coop24_key_released
    or byte ptr [coop_keys],ah
    mov byte ptr [coop_join_pending],1
    jmp coop24_key_done
coop24_key_released:
    not ah
    and byte ptr [coop_keys],ah
coop24_key_done:
    pop ax
    ret

/* P2 moves two pixels per frame and uses the SAME terrain/collision system.
 * Only P2's keys affect P2; arrow/space remain exclusively P1 controls. */
coop24_tick:
    cmp byte ptr [coop_mode],0
    jne coop24_entered
    ret
coop24_entered:
    cmp byte ptr [coop25_respawn_pending],0
    je coop24_pending_checked
    call coop25_try_respawn
coop24_pending_checked:
    cmp byte ptr [game_state],0
    jne coop24_done
    cmp byte ptr [coop_lives],0
    je coop24_done
    cmp word ptr [ally_ticks],0
    je coop24_done
    cmp byte ptr [ally_cooldown],0
    je coop24_ready
    dec byte ptr [ally_cooldown]
coop24_ready:
    mov al,[coop_keys]
    test al,1
    jnz coop24_up
    test al,2
    jnz coop24_right
    test al,4
    jnz coop24_down
    test al,8
    jnz coop24_left
    jmp coop24_shoot
coop24_up:
    xor al,al
    jmp coop24_move
coop24_right:
    mov al,1
    jmp coop24_move
coop24_down:
    mov al,2
    jmp coop24_move
coop24_left:
    mov al,3
coop24_move:
    mov [ally_dir],al
    call coop24_pixel
    mov al,[ally_dir]
    call coop24_pixel
coop24_shoot:
    test byte ptr [coop_keys],16
    jz coop24_pickup_now
    cmp byte ptr [ally_cooldown],0
    jne coop24_pickup_now
    cmp byte ptr [pong_ticks],0
    je coop24_normal_fire
    cmp byte ptr [pong_active],0
    jne coop24_pickup_now
    mov al,2
    call pong23_launch
    mov byte ptr [ally_cooldown],12
    jmp coop24_pickup_now
coop24_normal_fire:
    call extra17_ally_fire
coop24_pickup_now:
    call coop24_pickup
coop24_done:
    ret

/* AL = direction, preserves all general registers. Test terrain and full
 * 16x12 hulls; player 1 and P2 can never pass through one another. */
coop24_pixel:
    push ax
    push bx
    push dx
    mov dl,[ally_px]
    mov dh,[ally_py]
    call step_pixel
    jc coop24_pixel_done
    mov [ally_candidate_x],dl
    mov [ally_candidate_y],dh
    call rect_passable
    jc coop24_pixel_done
    cmp byte ptr [lives],0
    je coop24_no_p1
    mov al,dl
    sub al,[player_px]
    add al,15
    cmp al,30
    ja coop24_no_p1
    mov al,dh
    sub al,[player_py]
    add al,11
    cmp al,22
    jbe coop24_pixel_done
coop24_no_p1:
    xor bx,bx
coop24_check_enemy:
    cmp byte ptr [enemy_active+bx],0
    je coop24_next_enemy
    mov al,[ally_candidate_x]
    sub al,[enemy_px+bx]
    add al,15
    cmp al,30
    ja coop24_next_enemy
    mov al,[ally_candidate_y]
    sub al,[enemy_py+bx]
    add al,11
    cmp al,22
    jbe coop24_pixel_done
coop24_next_enemy:
    inc bx
    cmp bx,4
    jb coop24_check_enemy
    mov al,[ally_candidate_x]
    mov [ally_px],al
    mov al,[ally_candidate_y]
    mov [ally_py],al
coop24_pixel_done:
    pop dx
    pop bx
    pop ax
    ret

/* Both human tanks can collect within 1.5 tiles. The heart belongs to
 * the human who takes it; other team-wide powerups are shared. */
coop24_pickup:
    push ax
    push bx
    push dx
    cmp byte ptr [coop_mode],0
    je coop24_pickup_done
    cmp byte ptr [coop_lives],0
    je coop24_pickup_done
    cmp byte ptr [bonus_active],0
    je coop24_pickup_done
    mov dl,[ally_px]
    mov dh,[ally_py]
    call bonus26_touch
    jnc coop24_pickup_done
    cmp byte ptr [bonus_type],5
    jne coop24_team_power
    mov al,1
    call bonus25_collected
    mov byte ptr [bonus_active],0
    mov byte ptr [bonus_timer],0
    mov byte ptr [bonus_flash_type],5
    mov byte ptr [bonus_flash_ticks],112
    cmp byte ptr [coop_lives],9
    jae coop24_pickup_done
    inc byte ptr [coop_lives]
    call draw_hud
    jmp coop24_pickup_done
coop24_team_power:
    mov al,1
    call bonus20_apply
coop24_pickup_done:
    pop dx
    pop bx
    pop ax
    ret

/* A human P2 comes back beside HQ when there is at least one life.
   Occupied exits are retried on subsequent ticks without consuming lives. */
coop25_try_respawn:
    cmp byte ptr [coop_lives],0
    je coop25_no_spawn
    call ally17_spawn
    jc coop25_spawn_wait
    mov word ptr [ally_ticks],0x7fff
    mov byte ptr [ally_shield],48
    mov byte ptr [coop25_respawn_pending],0
    ret
coop25_spawn_wait:
    mov byte ptr [coop25_respawn_pending],1
coop25_no_spawn:
    mov word ptr [ally_ticks],0
    ret

/* Hit accounting is shared by enemy shells, ricochets, and aircraft.
   No artificial game over while P1 remains alive. */
coop25_hit_p2:
    push ax
    push bx
    push dx
    cmp byte ptr [coop_mode],0
    je coop25_hit_done
    cmp byte ptr [coop_lives],0
    je coop25_hit_done
    dec byte ptr [coop_lives]
    mov word ptr [ally_ticks],0
    cmp byte ptr [coop_lives],0
    je coop25_hit_last
    call coop25_try_respawn
    jmp coop25_hit_hud
coop25_hit_last:
    cmp byte ptr [lives],0
    jne coop25_hit_hud
    mov byte ptr [game_state],2
coop25_hit_hud:
    call draw_hud
coop25_hit_done:
    pop dx
    pop bx
    pop ax
    ret

.section .data
coop_mode: .byte 0
coop_lives: .byte 0
coop_keys: .byte 0
coop_join_pending: .byte 0
coop25_respawn_pending: .byte 0
.section .text
