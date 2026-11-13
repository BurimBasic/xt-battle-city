/* v0.13 tactical director, entirely 8086-safe integer arithmetic.
 * No dynamic allocation, no recursion, no DOS or BIOS work in decisions.
 * AI runs at most once per four 18.2Hz ticks. Directions 0=up,
 * 1=right, 2=down, 3=left, held keys bits 1,2,4,8.
 * Slot-based squad plan: 0 assaults HQ, 1 flanks left, 2 flanks right,
 * 3 tracks the player. They share the player's last revealed position.
 */
.section .text

tactical_player_tick:
    /* Normal strategic decisions remain every 4 ticks. On the intervening
       even ticks perform ONLY an emergency shell scan (including spread
       weapons), so a 2px/tick player can start dodging earlier. */
    test byte ptr [game_tick],3
    jz tactical_player_decide
    test byte ptr [game_tick],1
    jnz tactical_player_idle
    cmp byte ptr [player_shield],0
    jne tactical_player_idle
    push ax
    push bx
    push cx
    push dx
    push si
    /* React mid-cadence only if impact is imminent; long-range shells
       remain the 4-tick strategic dodge and must not divert the hunter. */
    mov byte ptr [tactical_threat_range],24
    call tactical_find_threat
    mov byte ptr [tactical_threat_range],72
    jc tactical_player_quick_escape
    jmp tactical_player_leave
tactical_player_quick_escape:
    mov byte ptr [tactical_fire_request],0
    jmp tactical_player_steer
tactical_player_idle:
    ret
tactical_player_decide:
    push ax
    push bx
    push cx
    push dx
    push si
    mov byte ptr [tactical_fire_request], 0
    cmp byte ptr [player_shield],0
    jne tactical_dodge_done
    call tactical_find_threat
    jnc tactical_dodge_done
    jmp tactical_player_steer
tactical_dodge_done:
    /* Laser is an assault window: pursue the nearest reachable enemy
       instead of holding the HQ indefinitely. Closing distance also
       improves the instant laser's line of fire. */
    cmp byte ptr [laser_ticks],0
    je tactical23_check_final
    /* Laser outranks distant bonus detours: close for the kill now. */
    call tactical_find_target
    jnc tactical23_check_final
    call tactical_player_aim_if_aligned
    jnc 9f
    jmp tactical_player_hold_and_fire
9:
    call tactical23_hunt
    jnc 9f
    jmp tactical_player_steer
9:
tactical23_check_final:
    /* A sole defender hidden behind steel must not cause deadlock.
       Navigate around the obstacle using the cached reverse BFS. */
    cmp byte ptr [enemy_spawned],20
    jne tactical23_normal_orders
    cmp byte ptr [enemy_killed],19
    jb tactical23_normal_orders
    cmp byte ptr [bonus_active],0
    jne tactical23_normal_orders
    call tactical_find_target
    jnc tactical23_normal_orders
    call tactical_player_aim_if_aligned
    jnc 9f
    jmp tactical_player_hold_and_fire
9:
    call tactical23_hunt
    jnc 9f
    jmp tactical_player_steer
9:
tactical23_normal_orders:
    /* Freeze creates an offensive window: chase the immobilized enemy. */
    cmp byte ptr [freeze_ticks],0
    je tactical_defense_orders
    call tactical_find_target
    jc tactical27_freeze_target
    jmp tactical_bonus_objective
tactical27_freeze_target:
    call tactical_player_aim_if_aligned
    jnc tactical_freeze_seek
    jmp tactical_player_hold_and_fire
tactical_freeze_seek:
    mov al,[enemy_px+bx]
    sub al,[player_px]
    add al,9
    cmp al,19
    jbe tactical_freeze_vertical
    mov al,1
    mov dl,[enemy_px+bx]
    cmp dl,[player_px]
    ja tactical_freeze_go
    mov al,3
    jmp tactical_freeze_go
tactical_freeze_vertical:
    mov al,0
    mov dl,[enemy_py+bx]
    cmp dl,[player_py]
    jb tactical_freeze_go
    mov al,2
tactical_freeze_go:
    jmp tactical_player_steer
tactical_defense_orders:
    /* Powerful pickups beat routine combat ONLY while base defense is safe:
       2 = destroy all enemies, 6 = laser, 5 = extra life.  The BFS
       explicitly vetoes dangerous detours near HQ. */
    cmp byte ptr [bonus_active],0
    je tactical27_normal_orders
    cmp byte ptr [tactical23_hunting],0
    jne tactical27_normal_orders
    mov al,[bonus_type]
    cmp al,2
    je tactical27_priority_pickup
    cmp al,6
    je tactical27_priority_pickup
    cmp al,5
    jne tactical27_normal_orders
tactical27_priority_pickup:
    call strategy_bonus_heading
    jnc tactical27_normal_orders
    mov byte ptr [tactical_fire_request],0
    jmp tactical_player_steer
tactical27_normal_orders:
    /* A real clear firing lane outranks even an attractive pickup.
       A steel-blocked shot does NOT hold our player in place. */
    call tactical_find_target
    jnc tactical_bonus_objective
    call tactical_player_aim_if_aligned
    jnc tactical23_defend_route
    jmp tactical_player_hold_and_fire
tactical23_defend_route:
    cmp byte ptr [enemy_py+bx],136
    jae tactical_no_bonus_route
    cmp byte ptr [enemy_py+bx],76
    jb tactical_bonus_objective
    mov al,[enemy_px+bx]
    cmp al,72
    jb tactical_bonus_objective
    cmp al,168
    jbe tactical_no_bonus_route
tactical_bonus_objective:
    /* Chase a reachable pickup even in an upper-row enemy wreck.
       strategy_bonus_heading already vetoes immediate threats to HQ. */
tactical21_bonus_try:
    call strategy_bonus_heading
    jnc tactical_no_bonus_route
    mov byte ptr [tactical_fire_request],0
    jmp tactical_player_steer
 tactical_no_bonus_route:
    call tactical_find_target
    jc 1f
    jmp tactical_patrol
1:
    /* If an opponent is on our firing axis, shoot now — even if it has
       not yet crossed the defensive threshold. This fixes the inert
       defender staring at a visible enemy during automatic play. */
    call tactical_player_aim_if_aligned
    jnc tactical_target_not_aligned
    jmp tactical_player_hold_and_fire
tactical_target_not_aligned:
    /* First leave the HQ brick pocket and occupy the defensive line.
       The first auto orders must not try horizontal pursuit behind walls. */
    cmp byte ptr [player_py],136
    jbe tactical_defense_position_ready
    mov al,0
    jmp tactical_player_steer
tactical_defense_position_ready:
    /* Defensive doctrine: hold a useful lane near the HQ until there is
       a genuine breach, instead of chasing every distant enemy. */
    cmp byte ptr [enemy_py+bx],96
    jae tactical_player_engage
    /* During a quiet opening establish a forward firing line, and then
       engage a reachable raider rather than watching a frozen screen. */
    cmp byte ptr [player_py],116
    jbe 1f
    jmp tactical_patrol
1:
    cmp byte ptr [enemy_py+bx],16
    jae tactical_player_engage
    jmp tactical_patrol
 tactical_player_engage:
    /* Shot failed range or steel-line check. Close or change lane;
       do not hold forever firing into an indestructible barrier. */
    mov al,[enemy_px+bx]
    sub al,[player_px]
    add al,9
    cmp al,19
    ja tactical_player_try_row
    cmp byte ptr [enemy_py+bx],112
    jb tactical_engage_forward
    cmp byte ptr [player_py],136
    jb tactical_engage_down
    jmp tactical_player_guard
 tactical_engage_down:
    mov al,2
    jmp tactical_player_steer
 tactical_engage_forward:
    mov al,0
    jmp tactical_player_steer
 tactical_player_try_row:
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
    /* Outer raiders are not worth abandoning the HQ until they breach. */
    cmp byte ptr [enemy_py+bx],136
    jae tactical_seek_flank_breach
    cmp byte ptr [enemy_px+bx],64
    jb tactical_player_guard
    cmp byte ptr [enemy_px+bx],176
    ja tactical_player_guard
 tactical_seek_flank_breach:
    /* Keep the intercept column near HQ; chasing a side-lane decoy can
       leave the entire base unguarded. Expand only in a real breach. */
    mov dl,[enemy_px+bx]
    /* Always keep an emergency blocking position in the central
       corridor: a flank tank at y159 is NOT worth leaving x208 open. */
    cmp dl,80
    jae tactical_seek_clip_right
    mov dl,80
 tactical_seek_clip_right:
    cmp dl,144
    jbe tactical_seek_compare
    mov dl,144
 tactical_seek_compare:
    cmp dl,[player_px]
    ja tactical_seek_right
    jb tactical_seek_left
    /* We are at our intercept column. Follow the threat vertically only
       within the line in front of the HQ; don't oscillate left/right. */
    cmp byte ptr [enemy_py+bx],128
    jb tactical_seek_move_up
    cmp byte ptr [player_py],140
    jb tactical_seek_move_down
    jmp tactical_player_guard
 tactical_seek_move_down:
    mov al,2
    jmp tactical_player_steer
 tactical_seek_move_up:
    cmp byte ptr [player_py],108
    jbe tactical_player_guard
    mov al,0
    jmp tactical_player_steer
 tactical_seek_left:
    mov al,3
    jmp tactical_player_steer
 tactical_seek_right:
    mov al,1
    jmp tactical_player_steer
 tactical_patrol:
    /* Main stage's center x112 lane contains STEEL at row 8. Patrol
       from x96 instead, where real shots can reach attacking tanks. */
    cmp byte ptr [player_py],120
    jbe tactical_patrol_column
    mov al,0
    jmp tactical_player_steer
 tactical_patrol_column:
    cmp byte ptr [player_px],96
    je tactical_player_guard
    ja tactical_patrol_left
    mov al,1
    jmp tactical_player_steer
 tactical_patrol_left:
    mov al,3
    jmp tactical_player_steer
 tactical_player_guard:
    mov byte ptr [held_keys],0
    mov byte ptr [player_dir],0
    jmp tactical_player_leave
 tactical_player_hold_and_fire:
    /* An aligned defender shoots from cover; pursuing an aligned target
       is the old source of repeated sideways/up-down oscillation. */
    mov byte ptr [held_keys],0
    mov [player_dir],al
    cmp byte ptr [bullet_active],0
    je 1f
    jmp tactical_player_leave
1:
    cmp byte ptr [tactical_fire_request],0
    je tactical_player_leave
    call do_fire
    jmp tactical_player_leave
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
    call tactical_player_path_open
    jnc tactical_player_apply
    mov al, [tactical_heading]
    add al, 2
    and al, 3
    call tactical_player_path_open
    jnc tactical_player_apply
    /* No passable heading. Avoid queuing impossible movement. */
    mov byte ptr [held_keys],0
    jmp tactical_player_leave
 tactical_player_apply:
    call tactical24_player_unloop
    xor ah, ah
    mov si, ax
    mov al, [tactical_key_bits+si]
    mov [held_keys], al
    mov ax, si
    mov [player_dir], al
    cmp byte ptr [tactical_fire_request], 0
    jne 1f
    jmp tactical_player_leave
1:
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
    je 1f
    jmp tactical_player_leave
1:
    call do_fire
 tactical_player_leave:
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
 tactical_player_done:
    ret

/* Six-pixel advance lookahead for the defending AUTO tank. This avoids
 * committing to a lane when the second/third step is already blocked. */
/* BX targeted enemy; CF=1 if on a valid horizontal/vertical shot lane;
   AL points the gun towards target. CF=0 if it is offset from both axes.
   Aimed shots remove brick cover, while a free lane hits the tank. */
tactical_player_aim_if_aligned:
    mov al,[enemy_px+bx]
    sub al,[player_px]
    add al,9            /* same width as physics collision */
    cmp al,19
    ja tactical_aim_row
    /* Long-range axis alignment should not immobilize our defender:
       shoot from an actual effective position, advance while distant. */
    mov al,[enemy_py+bx]
    sub al,[player_py]
    jnc tactical_aim_vertical_abs
    neg al
 tactical_aim_vertical_abs:
    cmp al,136
    ja tactical_aim_fail
    mov [tactical_aim_distance],al
    mov al,2
    mov ah,[enemy_py+bx]
    cmp ah,[player_py]
    ja tactical_aim_ready
    mov al,0
    jmp tactical_aim_ready
 tactical_aim_row:
    mov al,[enemy_py+bx]
    sub al,[player_py]
    add al,7
    cmp al,15
    ja tactical_aim_fail
    mov al,[enemy_px+bx]
    sub al,[player_px]
    jnc tactical_aim_horizontal_abs
    neg al
 tactical_aim_horizontal_abs:
    cmp al,136
    ja tactical_aim_fail
    mov [tactical_aim_distance],al
    mov al,1
    mov ah,[enemy_px+bx]
    cmp ah,[player_px]
    ja tactical_aim_ready
    mov al,3
 tactical_aim_ready:
    /* A missed southbound shot from the HQ pocket destroys our base. */
    cmp al,2
    jne tactical_aim_check_cover
    cmp byte ptr [player_py],132
    jb tactical_aim_check_cover
    cmp byte ptr [player_px],96
    jb tactical_aim_check_cover
    cmp byte ptr [player_px],128
    jbe tactical_aim_fail
 tactical_aim_check_cover:
    call tactical_player_line_clear
    jnc tactical_aim_fail
    mov byte ptr [tactical_fire_request],1
    stc
    ret
 tactical_aim_fail:
    clc
    ret

/* Independent fire control runs after movement each tick, even while
 * driving to a pickup. Choose the deepest aligned hostile shot. */
tactical_player_autofire:
    cmp byte ptr [bullet_active],0
    je tactical_autofire_start
    /* Triple-shot AUTO fills both spare slots while existing bullets fly. */
    cmp byte ptr [multi_ticks],0
    je tactical_autofire_skip
    cmp byte ptr [extra_active],0
    je tactical_autofire_start
    cmp byte ptr [extra_active+1],0
    je tactical_autofire_start
tactical_autofire_skip:
    ret
 tactical_autofire_start:
    push ax
    push bx
    push cx
    push dx
    push si
    mov byte ptr [tactical_best_shot_dir],0xff
    mov byte ptr [tactical_best_shot_score],0
    xor bx,bx
 tactical_autofire_scan:
    cmp byte ptr [enemy_active+bx],0
    je tactical_autofire_next
    call tactical_player_aim_if_aligned
    jnc tactical_autofire_next
    mov cl,[enemy_py+bx]
    cmp cl,[tactical_best_shot_score]
    jb tactical_autofire_next
    mov [tactical_best_shot_score],cl
    mov [tactical_best_shot_dir],al
 tactical_autofire_next:
    inc bx
    cmp bx,4
    jb tactical_autofire_scan
    cmp byte ptr [tactical_best_shot_dir],0xff
    je tactical_autofire_done
    mov al,[tactical_best_shot_dir]
    mov [player_dir],al
    call do_fire
 tactical_autofire_done:
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

/* The shell may chip brick, but never penetrate steel or HQ.
 * Scan the first up to 72 pixels of its actual center trajectory and
 * stop before the target (to ignore walls located BEHIND it). */
/* Fast and complete steel guard. The actor and target share a row or
 * column (checked by caller). Convert to map-cell indices ONCE, then
 * walk 1 tile per step; no per-pixel DIV and no repeated sprite probes.
 * Steel and HQ interrupt the ray; destructible bricks do not. */
tactical_player_line_clear:
    push ax
    push bx
    push cx
    push dx
    push si
    mov [tactical_lane_dir],al
    cmp byte ptr [tactical_aim_distance],8
    ja 1f
    stc
    jmp tactical_lane_done
1:
    mov dl,[player_px]
    add dl,8
    shr dl,1
    shr dl,1
    shr dl,1
    shr dl,1
    mov al,[player_py]
    add al,6
    xor ah,ah
    mov ch,12
    div ch
    mov dh,al
    xor ah,ah
    shl ax,1
    shl ax,1
    shl ax,1
    shl ax,1
    add al,dl
    mov si,offset level_data
    add si,ax
    mov al,[tactical_lane_dir]
    cmp al,0
    je tactical_lane_up
    cmp al,1
    je tactical_lane_right
    cmp al,2
    je tactical_lane_down
    jmp tactical_lane_left
tactical_lane_up:
    mov al,[enemy_py+bx]
    add al,6
    xor ah,ah
    div ch
    mov cl,al
    cmp dh,cl
    ja 1f
    jmp tactical_lane_clear
1:
    sub si,16
    dec dh
    cmp byte ptr [si],'T'
    je tactical_lane_up_blocked
    cmp byte ptr [si],'B'
    je tactical_lane_up_blocked
    cmp dh,cl
    jne 1b
    jmp tactical_lane_clear
tactical_lane_up_blocked:
    jmp tactical_lane_blocked
tactical_lane_right:
    mov al,[enemy_px+bx]
    add al,8
    shr al,1
    shr al,1
    shr al,1
    shr al,1
    mov cl,al
    cmp dl,cl
    jb 1f
    jmp tactical_lane_clear
1:
    inc si
    inc dl
    cmp byte ptr [si],'T'
    je tactical_lane_right_blocked
    cmp byte ptr [si],'B'
    je tactical_lane_right_blocked
    cmp dl,cl
    jne 1b
    jmp tactical_lane_clear
tactical_lane_right_blocked:
    jmp tactical_lane_blocked
tactical_lane_down:
    mov al,[enemy_py+bx]
    add al,6
    xor ah,ah
    div ch
    mov cl,al
    cmp dh,cl
    jb 1f
    jmp tactical_lane_clear
1:
    add si,16
    inc dh
    cmp byte ptr [si],'T'
    je tactical_lane_down_blocked
    cmp byte ptr [si],'B'
    je tactical_lane_down_blocked
    cmp dh,cl
    jne 1b
    jmp tactical_lane_clear
tactical_lane_down_blocked:
    jmp tactical_lane_blocked
tactical_lane_left:
    mov al,[enemy_px+bx]
    add al,8
    shr al,1
    shr al,1
    shr al,1
    shr al,1
    mov cl,al
    cmp dl,cl
    ja 1f
    jmp tactical_lane_clear
1:
    dec si
    dec dl
    cmp byte ptr [si],'T'
    je tactical_lane_blocked
    cmp byte ptr [si],'B'
    je tactical_lane_blocked
    cmp dl,cl
    jne 1b
tactical_lane_clear:
    stc
    jmp tactical_lane_done
tactical_lane_blocked:
    clc
tactical_lane_done:
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

tactical_player_path_open:
    push ax
    push cx
    push dx
    mov dl, [player_px]
    mov dh, [player_py]
    mov cl, 6
 tactical_player_probe_loop:
    call step_pixel
    jc tactical_player_path_done
    call rect_passable
    jc tactical_player_path_done
    dec cl
    jnz tactical_player_probe_loop
    clc
 tactical_player_path_done:
    pop dx
    pop cx
    pop ax
    ret

/* Pick nearest objective threatening our headquarters, priority by y. */
/* Threat score: horizontal distance from the base matters MORE than
 * absolute depth. Outer wing decoys used to pull AUTO all the way to x208,
 * leaving a central breacher to kill HQ. Small target inertia only. */
tactical_find_target:
    push ax
    push cx
    push dx
    xor bx,bx
    mov cl,0xff
    mov ch,0
 tactical_find_priority_scan:
 tactical_find_next:
    cmp byte ptr [enemy_active+bx],0
    je tactical_find_skip
    mov al,[enemy_py+bx]
    cmp byte ptr [enemy_px+bx],80
    jb tactical_target_wide
    cmp byte ptr [enemy_px+bx],160
    ja tactical_target_wide
    add al,64                  /* center HQ corridor */
    jnc tactical_target_sticky
    mov al,255
    jmp tactical_target_sticky
 tactical_target_wide:
    cmp byte ptr [enemy_px+bx],64
    jb tactical_target_outer
    cmp byte ptr [enemy_px+bx],176
    ja tactical_target_outer
    add al,12                  /* nearby flanks, less dangerous */
    jnc tactical_target_sticky
    mov al,255
    jmp tactical_target_sticky
 tactical_target_outer:
    sub al,24
    jnc tactical_target_sticky
    xor al,al
 tactical_target_sticky:
    cmp bl,[tactical_player_target]
    jne tactical_target_scored
    add al,8                   /* modest persistence, not blind fixation */
    jnc tactical_target_scored
    mov al,255
 tactical_target_scored:
    cmp al,ch
    jb tactical_find_skip
    mov ch,al
    mov cl,bl
 tactical_find_skip:
    inc bx
    cmp bx,4
    jb tactical_find_next
    cmp cl,0xff
    jne tactical_find_found
    mov byte ptr [tactical_player_target],0xff
    clc
    jmp tactical_find_ret
 tactical_find_found:
    mov [tactical_player_target],cl
    xor bx,bx
    mov bl,cl
    stc
 tactical_find_ret:
    pop dx
    pop cx
    pop ax
    ret

/* Return CF, AL perpendicular escape heading if an approaching enemy shell
 * enters the tank's projected 48px trajectory. Four cheap AABB checks. */
tactical_find_threat:
    push bx
    push dx
    xor bx,bx
 tactical_threat_loop:
    cmp byte ptr [shot_active+bx], 0
    jne tactical_threat_live
    jmp tactical_threat_next
 tactical_threat_live:
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
    cmp al,[tactical_threat_range]
    ja tactical_threat_next
    /* Pick the side with more maneuvering room, not always right. */
    mov al,1
    cmp byte ptr [player_px],128
    jb tactical_threat_found
    mov al,3
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
    cmp al,[tactical_threat_range]
    ja tactical_threat_next
    mov al, 0
    cmp byte ptr [player_py], 15
    ja tactical_threat_found
    mov al, 2
 tactical_threat_found:
    /* Never commit to an impossible dodge. Try both perpendicular sides. */
    mov [tactical_heading],al
    call tactical_player_path_open
    jnc tactical_threat_escape
    mov al,[tactical_heading]
    xor al,2
    call tactical_player_path_open
    jc tactical_threat_next
 tactical_threat_escape:
    stc
    jmp tactical_threat_done
 tactical_threat_next:
    inc bx
    /* Extra enemy projectiles from spread weapons occupy slots 4..6. */
    cmp bx,7
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
    /* Priority one: a tank failing to move must yield a corridor.  The
       actual collision probe prevents backing into a teammate or wall. */
    cmp byte ptr [enemy_blocked+bx],6
    jb tactical_enemy_not_jammed
    mov al,[enemy_dir+bx]
    xor al,2
    call tactical_enemy_probe6
    jc tactical_enemy_not_jammed
    jmp tactical_enemy_assign
 tactical_enemy_not_jammed:
    call tactical_enemy_evade
    jnc tactical_enemy_plan
    /* Emergency dodge must itself be traversable. Otherwise continue
       planning; running into a wall wastes the entire dodge window. */
    call tactical_enemy_probe6
    jc tactical_enemy_plan
    jmp tactical_enemy_assign
tactical_enemy_plan:
    /* Any enemy can break formation for a nearby usable bonus. */
    cmp byte ptr [bonus_active],0
    je tactical_enemy_orders
    cmp byte ptr [bonus_type],5
    je tactical_enemy_orders
    cmp byte ptr [bonus_type],7
    je tactical_enemy_orders
    mov dl,[bonus_col]
    shl dl,1
    shl dl,1
    shl dl,1
    shl dl,1
    mov al,[enemy_px+bx]
    cmp al,dl
    jae 1f
    xchg al,dl
1:
    sub al,dl
    cmp al,48
    ja tactical_enemy_orders
    mov al,[bonus_row]
    mov cl,12
    mul cl
    mov dl,al
    mov al,[enemy_py+bx]
    cmp al,dl
    jae 1f
    xchg al,dl
1:
    sub al,dl
    cmp al,36
    ja tactical_enemy_orders
    mov dl,[bonus_col]
    shl dl,1
    shl dl,1
    shl dl,1
    shl dl,1
    mov al,[bonus_row]
    mov cl,12
    mul cl
    mov dh,al
    call tactical_route_choose
    jmp tactical_enemy_assign
tactical_enemy_orders:
    /* Three agents receive a shared, staged HQ operation; the interceptor
       alone hunts the exposed player. This prevents all four from randomly
       chasing the player while leaving the base unharmed. */
    mov word ptr [route_active_field],offset route_base
    mov dl,112
    mov dh,168
    cmp bx,0
    je tactical_goal_ready
    cmp bx,1
    jne tactical_role_flank_right
    cmp byte ptr [squad_phase],0
    jne tactical_goal_ready
    mov word ptr [route_active_field],offset route_left
    mov dl,48
    mov dh,132
    jmp tactical_goal_ready
 tactical_role_flank_right:
    cmp bx,2
    jne tactical_role_hunter
    cmp byte ptr [squad_phase],0
    jne tactical_goal_ready
    mov word ptr [route_active_field],offset route_right
    mov dl,192
    mov dh,132
    jmp tactical_goal_ready
 tactical_role_hunter:
    /* Independent raider doctrine: deny a valuable pickup when it appears;
       otherwise intercept at the last disclosed P1 position, not omniscient
       live coordinates. When idle, guard the central base approach lane. */
    cmp byte ptr [bonus_active],0
    je tactical_hunter_no_bonus
    cmp byte ptr [bonus_type],5
    je tactical_hunter_no_bonus
    cmp byte ptr [bonus_type],7
    je tactical_hunter_no_bonus
    mov dl,[bonus_col]
    shl dl,1
    shl dl,1
    shl dl,1
    shl dl,1
    mov al,[bonus_row]
    mov cl,12
    mul cl
    mov dh,al
    jmp tactical_goal_ready
 tactical_hunter_no_bonus:
    cmp byte ptr [squad_alert],0
    je tactical_hunter_patrol
    mov dl,[squad_target_x]
    mov dh,[squad_target_y]
    jmp tactical_goal_ready
 tactical_hunter_patrol:
    mov dl,112
    cmp byte ptr [squad_doctrine],3
    jne tactical_hunter_patrol_ready
    mov dl,192          /* denial doctrine screens right-side passage */
 tactical_hunter_patrol_ready:
    mov dh,132
 tactical_goal_ready:
    /* Flankers first travel to rally points. Once both are there (or the
       team clock expires) they push toward the HQ from opposite wings. */
    cmp bx,3
    jne tactical_goal_path
    /* The interceptor can establish a short fire ambush only if the player
       occupies its row or column. Other roles do not abandon their order. */
    mov al,[enemy_px+bx]
    sub al,[player_px]
    add al,8
    cmp al,16
    ja tactical_ambush_horizontal
    mov al,[enemy_py+bx]
    sub al,[player_py]
    add al,64
    cmp al,128
    ja tactical_goal_path
    mov al,2
    mov ah,[player_py]
    cmp byte ptr [enemy_py+bx],ah
    jb tactical_ambush_hold
    mov al,0
    jmp tactical_ambush_hold
 tactical_ambush_horizontal:
    mov al,[enemy_py+bx]
    sub al,[player_py]
    add al,6
    cmp al,12
    ja tactical_goal_path
    mov al,1
    mov ah,[player_px]
    cmp byte ptr [enemy_px+bx],ah
    jb tactical_ambush_hold
    mov al,3
 tactical_ambush_hold:
    mov byte ptr [enemy_hold+bx],20
    jmp tactical_enemy_assign
 tactical_goal_path:
    cmp bx,3
    je tactical_interceptor_seek
    /* If a squad tank enters the HQ firing lane, it digs in and fires
       toward the base instead of oscillating around the last waypoint. */
    mov al,[enemy_px+bx]
    sub al,104
    cmp al,16
    ja tactical_squad_route
    cmp byte ptr [enemy_py+bx],132
    jb tactical_squad_route
    cmp byte ptr [squad_phase],0
    jne tactical_hq_bombard
    cmp bx,0
    jne tactical_squad_route
 tactical_hq_bombard:
    /* Do not dig in behind a teammate where every round is suppressed. */
    mov byte ptr [enemy_dir+bx],2
    call tactical_safe_fire
    jnc tactical_squad_route
    mov al,2
    mov byte ptr [enemy_hold+bx],24
    jmp tactical_enemy_assign
 tactical_squad_route:
    call strategy_route_heading
    jmp tactical_enemy_assign
 tactical_interceptor_seek:
    call tactical_route_choose
    jmp tactical_enemy_assign
 tactical_enemy_assign:
    call tactical24_enemy_unloop
    mov [enemy_dir+bx],al
    pop dx
    pop cx
    pop ax
    ret

/* The route evaluator is bounded: 4 directions x 6 pixel samples.
 * Runs once per enemy AI decision (normally every 32 ticks), not per frame.
 * BX: enemy index, DL/DH: waypoint. Returns best legal direction in AL.
 * 8086: uses only 8-bit axes and a 16-bit Manhattan score. No search heap.
 */
tactical_route_choose:
    push bx
    push cx
    push dx
    push si
    mov [tactical_goal_x], dl
    mov [tactical_goal_y], dh
    mov word ptr [tactical_best_score], 0xffff
    mov al, [enemy_dir+bx]
    xor al,2
    mov [tactical_best_dir], al /* escape rather than repeat blocked order */
    xor si, si
 tactical_route_next:
    mov ax, si
    call tactical_enemy_probe6
    jc tactical_route_skip
    /* |nextX-goalX| + |nextY-goalY|. */
    mov al, [tactical_probe_x]
    sub al, [tactical_goal_x]
    jnc tactical_x_abs
    neg al
 tactical_x_abs:
    xor ah, ah
    mov cx, ax
    mov al, [tactical_probe_y]
    sub al, [tactical_goal_y]
    jnc tactical_y_abs
    neg al
 tactical_y_abs:
    xor ah, ah
    add ax, cx
    /* Hysteresis: continuing is preferred if equally good, reversing
       without a reason is costly (prevents wall-corner ping-pong). */
    mov cl, [enemy_dir+bx]
    cmp cl, 0xff
    je tactical_score_ready
    cmp si, cx
    jne tactical_score_turn
    cmp ax, 4
    jb tactical_score_ready
    sub ax, 4
    jmp tactical_score_ready
 tactical_score_turn:
    add cl, 2
    and cl, 3
    cmp si, cx
    jne tactical_score_ready
    add ax, 18
 tactical_score_ready:
    cmp ax, [tactical_best_score]
    jae tactical_route_skip
    mov [tactical_best_score], ax
    mov ax, si
    mov [tactical_best_dir], al
 tactical_route_skip:
    inc si
    cmp si, 4
    jb tactical_route_next
    mov al, [tactical_best_dir]
    pop si
    pop dx
    pop cx
    pop bx
    ret

/* Candidate direction AL, enemy BX; 6 pixel clearance, top-left sprite
 * hull from the actual CGA collision engine. CF=0 clear, CF=1 obstructed.
 * AX/DX and CX preserved, collision-probe coordinates saved on success.
 */
tactical_enemy_probe6:
    push ax
    push cx
    push dx
    push si
    mov dl, [enemy_px+bx]
    mov dh, [enemy_py+bx]
    mov cl, 6
 tactical_probe_next:
    call step_pixel
    jc tactical_probe_blocked
    call rect_passable
    jc tactical_probe_blocked
    dec cl
    jnz tactical_probe_next
    /* The old probe saw only tiles: four tanks could select the same
       impassable lane forever. Compare predicted hull against live bodies. */
    xor si,si
 tactical_probe_actor:
    cmp si,bx
    je tactical_probe_other
    cmp byte ptr [enemy_active+si],0
    je tactical_probe_other
    mov al,dl
    sub al,[enemy_px+si]
    add al,15
    cmp al,30
    ja tactical_probe_other
    mov al,dh
    sub al,[enemy_py+si]
    add al,11
    cmp al,22
    jbe tactical_probe_blocked
 tactical_probe_other:
    inc si
    cmp si,4
    jb tactical_probe_actor
    /* Also avoid futile pursuit straight through the defending tank. */
    mov al,dl
    sub al,[player_px]
    add al,15
    cmp al,30
    ja tactical_probe_clear
    mov al,dh
    sub al,[player_py]
    add al,11
    cmp al,22
    jbe tactical_probe_blocked
 tactical_probe_clear:
    mov [tactical_probe_x], dl
    mov [tactical_probe_y], dh
    clc
    jmp tactical_probe_finish
 tactical_probe_blocked:
    stc
 tactical_probe_finish:
    pop si
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
    /* A teammate anywhere ahead on this row/column blocks fire. Old code
       only checked 56 px, so tanks shot team members farther downrange. */
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
    /* Vertical shot: protect every ally whose hull intersects the ray. */
    mov al,[enemy_px+bx]
    sub al,[enemy_px+si]
    add al,12
    cmp al,24
    ja tactical_fire_friend_next
    mov dl,[enemy_py+si]
    cmp byte ptr [enemy_dir+bx],0
    je tactical_fire_up
    cmp dl,[enemy_py+bx]       /* downward: ally must be below shooter */
    jae tactical_fire_friend_block
    jmp tactical_fire_friend_next
 tactical_fire_up:
    cmp dl,[enemy_py+bx]       /* upward: ally must be above shooter */
    jbe tactical_fire_friend_block
    jmp tactical_fire_friend_next
 tactical_fire_horizontal:
    mov al,[enemy_py+bx]
    sub al,[enemy_py+si]
    add al,9
    cmp al,18
    ja tactical_fire_friend_next
    mov dl,[enemy_px+si]
    cmp byte ptr [enemy_dir+bx],3
    je tactical_fire_left
    cmp dl,[enemy_px+bx]       /* rightward: ally must be to the right */
    jae tactical_fire_friend_block
    jmp tactical_fire_friend_next
 tactical_fire_left:
    cmp dl,[enemy_px+bx]       /* leftward: ally must be to the left */
    jbe tactical_fire_friend_block
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
tactical_threat_range: .byte 72 /* 24px early warning, 72px planned */
/* v0.12 route selection scratch: tiny bounded, per-decision only. */
tactical_goal_x: .byte 0
tactical_goal_y: .byte 0
tactical_probe_x: .byte 0
tactical_probe_y: .byte 0
tactical_best_dir: .byte 0
tactical_best_score: .word 0xffff
tactical_fire_request: .byte 0
tactical_aim_distance: .byte 0
tactical_lane_dir: .byte 0
tactical_best_shot_dir: .byte 0xff
tactical_best_shot_score: .byte 0
tactical_key_bits: .byte 1,2,4,8
.section .text
