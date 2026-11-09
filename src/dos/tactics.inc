/* v0.11 tactical director, entirely 8086-safe integer arithmetic.
 * No dynamic allocation, no recursion, no DOS or BIOS work in decisions.
 * AI runs at most once per four 18.2Hz ticks. Directions 0=up,
 * 1=right, 2=down, 3=left, held keys bits 1,2,4,8.
 * Slot-based squad plan: 0 assaults HQ, 1 flanks left, 2 flanks right,
 * 3 tracks the player. They share the player's last revealed position.
 */
.section .text

tactical_player_tick:
    test byte ptr [game_tick], 3
    jz tactical_player_decide
    ret
tactical_player_decide:
    push ax
    push bx
    push cx
    push dx
    push si
    mov byte ptr [tactical_fire_request], 0
    call tactical_find_threat
    jc tactical_player_steer
    call tactical_find_target
    jnc tactical_patrol
    /* BX = enemy nearest our HQ (highest y). Aim before repositioning. */
    mov al, [enemy_px+bx]
    sub al, [player_px]
    add al, 8
    cmp al, 16
    ja tactical_player_try_row
    mov al, 0
    mov dl, [enemy_py+bx]
    cmp dl, [player_py]
    jb tactical_aligned_vertical
    mov al, 2
 tactical_aligned_vertical:
    mov byte ptr [tactical_fire_request], 1
    jmp tactical_player_steer
 tactical_player_try_row:
    mov al, [enemy_py+bx]
    sub al, [player_py]
    add al, 6
    cmp al, 12
    ja tactical_player_seek_column
    mov al, 3
    mov dl, [enemy_px+bx]
    cmp dl, [player_px]
    jb tactical_aligned_horizontal
    mov al, 1
 tactical_aligned_horizontal:
    mov byte ptr [tactical_fire_request], 1
    jmp tactical_player_steer
 tactical_player_seek_column:
    /* Defender stays in the central two thirds until an enemy crosses
       the middle of the map. Keeps HQ cover from disappearing in demos. */
    cmp byte ptr [enemy_py+bx],120
    ja tactical_player_seek_unrestricted
    mov al,[player_px]
    cmp al,78
    jae 1f
    mov al,1
    jmp tactical_player_steer
1:
    cmp al,168
    jbe tactical_player_seek_unrestricted
    mov al,3
    jmp tactical_player_steer
 tactical_player_seek_unrestricted:
    mov al, [enemy_px+bx]
    cmp al, [player_px]
    ja tactical_seek_right
    mov al, 3
    jmp tactical_player_steer
 tactical_seek_right:
    mov al, 1
    jmp tactical_player_steer
 tactical_patrol:
    /* If all three enemy lanes are quiet, patrol towards centre. */
    mov al, 0
    jmp tactical_player_steer
 tactical_player_steer:
    mov [tactical_heading], al
    call tactical_player_path_open
    jnc tactical_player_apply
    /* Fire on a blocked lane (e.g. chip the brick), then try a side. */
    mov byte ptr [tactical_fire_request], 1
    mov al, [tactical_heading]
    add al, 1
    and al, 3
    call tactical_player_path_open
    jnc tactical_player_apply
    mov al, [tactical_heading]
    add al, 3
    and al, 3
 tactical_player_apply:
    xor ah, ah
    mov si, ax
    mov al, [tactical_key_bits+si]
    mov [held_keys], al
    mov ax, si
    mov [player_dir], al
    cmp byte ptr [tactical_fire_request], 0
    je tactical_player_leave
    /* Do not fire southward through our HQ when defending its last lane. */
    cmp byte ptr [player_dir], 2
    jne tactical_fire_hq_clear
    cmp byte ptr [player_py], 130
    jbe tactical_fire_hq_clear
    mov al,[player_px]
    cmp al,96
    jb tactical_fire_hq_clear
    cmp al,128
    jbe tactical_player_leave
 tactical_fire_hq_clear:
    cmp byte ptr [bullet_active], 0
    jne tactical_player_leave
    call do_fire
 tactical_player_leave:
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
 tactical_player_done:
    ret

/* AL = desired heading; carry=blocked; preserve AL & DX. */
tactical_player_path_open:
    push ax
    push dx
    mov dl, [player_px]
    mov dh, [player_py]
    call step_pixel
    jc tactical_player_path_done
    call rect_passable
 tactical_player_path_done:
    pop dx
    pop ax
    ret

/* Pick nearest objective threatening our headquarters, priority by y. */
tactical_find_target:
    push cx
    push dx
    xor bx,bx
    mov cl, 0xff
    mov ch, 0
 tactical_find_next:
    cmp byte ptr [enemy_active+bx], 0
    je tactical_find_skip
    mov al, [enemy_py+bx]
    cmp al, ch
    jb tactical_find_skip
    mov ch, al
    mov cl, bl
 tactical_find_skip:
    inc bx
    cmp bx, 4
    jb tactical_find_next
    cmp cl, 0xff
    jne tactical_find_found
    clc
    jmp tactical_find_ret
 tactical_find_found:
    xor bx,bx
    mov bl,cl
    stc
 tactical_find_ret:
    pop dx
    pop cx
    ret

/* Return CF, AL perpendicular escape heading if an approaching enemy shell
 * enters the tank's projected 48px trajectory. Four cheap AABB checks. */
tactical_find_threat:
    push bx
    push dx
    xor bx,bx
 tactical_threat_loop:
    cmp byte ptr [shot_active+bx], 0
    je tactical_threat_next
    mov dl, [shot_dir+bx]
    test dl, 1
    jnz tactical_threat_horizontal
    /* Vertical: projectile x must overlap us within 8px. */
    mov al, [shot_px+bx]
    sub al, [player_px]
    add al, 8
    cmp al, 16
    ja tactical_threat_next
    cmp dl, 2
    jne tactical_threat_up
    mov al, [player_py]
    sub al, [shot_py+bx]
    jmp tactical_threat_vertical_range
 tactical_threat_up:
    mov al, [shot_py+bx]
    sub al, [player_py]
 tactical_threat_vertical_range:
    cmp al, 48
    ja tactical_threat_next
    mov al, 1
    cmp byte ptr [player_px], 210
    jb tactical_threat_found
    mov al, 3
    jmp tactical_threat_found
 tactical_threat_horizontal:
    mov al, [shot_py+bx]
    sub al, [player_py]
    add al, 6
    cmp al, 12
    ja tactical_threat_next
    cmp dl, 1
    jne tactical_threat_left
    mov al, [player_px]
    sub al, [shot_px+bx]
    jmp tactical_threat_horizontal_range
 tactical_threat_left:
    mov al, [shot_px+bx]
    sub al, [player_px]
 tactical_threat_horizontal_range:
    cmp al, 48
    ja tactical_threat_next
    mov al, 0
    cmp byte ptr [player_py], 15
    ja tactical_threat_found
    mov al, 2
 tactical_threat_found:
    stc
    jmp tactical_threat_done
 tactical_threat_next:
    inc bx
    cmp bx, 4
    jae tactical_threat_clear
    jmp tactical_threat_loop
tactical_threat_clear:
    clc
 tactical_threat_done:
    pop dx
    pop bx
    ret

/* Shared targeting report when the human/autopilot fires. Nonomniscient:
 * flankers move to the position disclosed by firing, not the live player. */
tactical_report_player:
    mov al, [player_px]
    mov [squad_target_x], al
    mov al, [player_py]
    mov [squad_target_y], al
    mov byte ptr [squad_alert], 96
    ret

/* BX=enemy actor. Refresh a squad role every 32 ticks or when blocked.
 * CF from tactical_enemy_evade signals urgent dodge priority. */
tactical_enemy_turn:
    push ax
    push cx
    push dx
    mov byte ptr [enemy_hold+bx], 0
    call tactical_enemy_evade
    jnc tactical_enemy_plan
    jmp tactical_enemy_assign
tactical_enemy_plan:
    cmp bx, 0
    jne tactical_role_flank_left
    mov dl, 112              /* HQ raider */
    mov dh, 170
    jmp tactical_goal_ready
 tactical_role_flank_left:
    cmp bx, 1
    jne tactical_role_flank_right
    mov dl, 48               /* left wing */
    mov dh, 150
    cmp byte ptr [squad_alert], 0
    je tactical_goal_ready
    mov dl, [squad_target_x]
    cmp dl, 40
    jae 1f
    mov dl, 40
1:
    sub dl, 32
    mov dh, [squad_target_y]
    jmp tactical_goal_ready
 tactical_role_flank_right:
    cmp bx, 2
    jne tactical_role_hunter
    mov dl, 190              /* right wing */
    mov dh, 150
    cmp byte ptr [squad_alert], 0
    je tactical_goal_ready
    mov dl, [squad_target_x]
    cmp dl, 199
    jbe 1f
    mov dl, 199
1:
    add dl, 32
    mov dh, [squad_target_y]
    jmp tactical_goal_ready
 tactical_role_hunter:
    mov dl, [player_px]      /* interceptor */
    mov dh, [player_py]
 tactical_goal_ready:
    /* Ambush: if aligned with the player's lane, stop for an aimed shot. */
    cmp bx, 0
    je tactical_goal_path
    mov al, [enemy_px+bx]
    sub al, [player_px]
    add al, 8
    cmp al, 16
    ja tactical_ambush_horizontal
    mov al, [enemy_py+bx]
    sub al, [player_py]
    add al, 64
    cmp al, 128
    ja tactical_goal_path
    mov al, 2
    cmp byte ptr [enemy_py+bx], dh
    jb tactical_ambush_hold
    mov al, 0
    jmp tactical_ambush_hold
 tactical_ambush_horizontal:
    mov al, [enemy_py+bx]
    sub al, [player_py]
    add al, 6
    cmp al, 12
    ja tactical_goal_path
    mov al, 1
    cmp byte ptr [enemy_px+bx], dl
    jb tactical_ambush_hold
    mov al, 3
 tactical_ambush_hold:
    mov byte ptr [enemy_hold+bx], 20
    jmp tactical_enemy_assign
 tactical_goal_path:
    /* Make a directional plan with an intentional lane destination. */
    mov al, [enemy_px+bx]
    sub al, dl
    add al, 10
    cmp al, 20
    jbe tactical_goal_vertical
    mov al, 3
    cmp byte ptr [enemy_px+bx], dl
    ja tactical_enemy_assign
    mov al, 1
    jmp tactical_enemy_assign
 tactical_goal_vertical:
    mov al, 2
    cmp byte ptr [enemy_py+bx], dh
    jb tactical_enemy_assign
    mov al, 0
 tactical_enemy_assign:
    mov [enemy_dir+bx],al
    pop dx
    pop cx
    pop ax
    ret

/* AL is a perpendicular dodge when our shell is about to hit this enemy. */
tactical_enemy_evade:
    cmp byte ptr [bullet_active],0
    jne 1f
    clc
    ret
1:
    mov al,[bullet_dir]
    test al, 1
    jnz tactical_dodge_horizontal
    mov al,[bullet_px]
    sub al,[enemy_px+bx]
    add al,8
    cmp al,16
    ja tactical_dodge_none
    cmp byte ptr [bullet_dir],2
    jne tactical_dodge_up
    mov al,[enemy_py+bx]
    sub al,[bullet_py]
    jmp tactical_dodge_vrange
 tactical_dodge_up:
    mov al,[bullet_py]
    sub al,[enemy_py+bx]
 tactical_dodge_vrange:
    cmp al, 48
    ja tactical_dodge_none
    mov al, 1
    test bl,1
    jz tactical_dodge_found
    mov al,3
    jmp tactical_dodge_found
 tactical_dodge_horizontal:
    mov al,[bullet_py]
    sub al,[enemy_py+bx]
    add al,6
    cmp al,12
    ja tactical_dodge_none
    cmp byte ptr [bullet_dir],1
    jne tactical_dodge_left
    mov al,[enemy_px+bx]
    sub al,[bullet_px]
    jmp tactical_dodge_hrange
 tactical_dodge_left:
    mov al,[bullet_px]
    sub al,[enemy_px+bx]
 tactical_dodge_hrange:
    cmp al,48
    ja tactical_dodge_none
    mov al,0
    test bl,1
    jz tactical_dodge_found
    mov al,2
 tactical_dodge_found:
    stc
    ret
 tactical_dodge_none:
    clc
    ret

/* Avoid firing down a friendly's current lane if they are in front of us.
 * Doesn't eliminate emergent friendly fire when a teammate crosses a shell. */
tactical_safe_fire:
    push ax
    push dx
    push si
    xor si,si
 tactical_fire_friend_loop:
    cmp si,bx
    je tactical_fire_friend_next
    cmp byte ptr [enemy_active+si],0
    je tactical_fire_friend_next
    mov al,[enemy_dir+bx]
    test al,1
    jnz tactical_fire_horizontal
    mov al,[enemy_px+bx]
    sub al,[enemy_px+si]
    add al,10
    cmp al,20
    ja tactical_fire_friend_next
    mov dl,[enemy_py+bx]
    sub dl,[enemy_py+si]
    cmp byte ptr [enemy_dir+bx],0
    je tactical_fire_up
    neg dl
 tactical_fire_up:
    cmp dl,56
    jb tactical_fire_friend_block
    jmp tactical_fire_friend_next
 tactical_fire_horizontal:
    mov al,[enemy_py+bx]
    sub al,[enemy_py+si]
    add al,6
    cmp al,12
    ja tactical_fire_friend_next
    mov dl,[enemy_px+bx]
    sub dl,[enemy_px+si]
    cmp byte ptr [enemy_dir+bx],3
    je tactical_fire_left
    neg dl
 tactical_fire_left:
    cmp dl,56
    jb tactical_fire_friend_block
 tactical_fire_friend_next:
    inc si
    cmp si,4
    jb tactical_fire_friend_loop
    stc
    jmp tactical_fire_friend_done
 tactical_fire_friend_block:
    clc
 tactical_fire_friend_done:
    pop si
    pop dx
    pop ax
    ret

.section .data
.tactics_data_begin:
/* Keep all state in 64KB COM data segment, no far pointers/allocations. */
auto_mode: .byte 1
auto_toggle_pending: .byte 0
demo_timer: .byte 0
squad_alert: .byte 0
squad_target_x: .byte 112
squad_target_y: .byte 168
enemy_hold: .space 4
enemy_blocked: .space 4
tactical_heading: .byte 0
tactical_fire_request: .byte 0
tactical_key_bits: .byte 1,2,4,8
.section .text
