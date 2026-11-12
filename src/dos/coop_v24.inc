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
    mov byte ptr [coop_lives],1
    mov byte ptr [lives],1
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
    cmp byte ptr [coop_lives],0
    je coop24_stage_dead
    call ally17_spawn
    jc coop24_stage_dead
    mov word ptr [ally_ticks],0x7fff
    mov byte ptr [ally_shield],30
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
    je coop24_done
    cmp byte ptr [game_state],0
    jne coop24_done
    cmp byte ptr [coop_lives],0
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
    mov dl,[bonus_col]
    shl dl,1
    shl dl,1
    shl dl,1
    shl dl,1
    mov al,[ally_px]
    cmp al,dl
    jae 1f
    xchg al,dl
1:
    sub al,dl
    cmp al,24
    ja coop24_pickup_done
    mov al,[bonus_row]
    mov bl,12
    mul bl
    mov dl,al
    mov al,[ally_py]
    cmp al,dl
    jae 1f
    xchg al,dl
1:
    sub al,dl
    cmp al,18
    ja coop24_pickup_done
    cmp byte ptr [bonus_type],5
    jne coop24_team_power
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
    call bonus20_apply
coop24_pickup_done:
    pop dx
    pop bx
    pop ax
    ret

.section .data
coop_mode: .byte 0
coop_lives: .byte 0
coop_keys: .byte 0
coop_join_pending: .byte 0
.section .text
