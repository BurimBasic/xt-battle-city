/* XT Battle City v0.13: original CGA tile arcade for DOS, 8086/8088.
 * Gameplay: 20-enemy waves, 4 tank classes, segmented bricks, 6 pickups,
 * destructible bricks, lives, headquarters, score and stage transitions.
 * 16x12 CGA cells, 16x16 battlefield. Original artwork and stage layouts.
 * This is NOT the Poisk-1 native version and is NOT a pixel-perfect NES port.
 */
.code16
.intel_syntax noprefix
.section .text
.global _start
_start:
    push cs
    pop ds
    push ds
    pop es
    cld
    /* DOS .COM occupies one allocation. Shrink it and reserve 16 KiB
       conventional RAM for the composed CGA bitmap. Keep a 4 KiB stack
       inside our program block. If either DOS call fails, fall back to
       the original direct-VRAM drawing path. No extra adapter is required. */
    mov ax, offset program_end
    add ax, 0x0fff
    and ax, 0xfff0
    mov sp, ax
    mov bx, ax
    shr bx, 1
    shr bx, 1
    shr bx, 1
    shr bx, 1
    push cs
    pop es
    mov ah, 0x4a
    int 0x21
    jc buffer_unavailable
    mov bx, 0x0400            /* 1024 paragraphs = 16384 bytes */
    mov ah, 0x48
    int 0x21
    jc buffer_unavailable
    mov [frame_seg], ax
buffer_unavailable:
    push cs
    pop es
    call reset_campaign
    call adlib_detect            /* OPL2 is optional; PC Speaker fallback */
    mov ax, 0x0004
    int 0x10
    mov ax, 0x0b00
    mov bx, 0x0101
    int 0x10
    mov byte ptr [palette_index], 0
    call apply_cga_palette
    call draw_map
    call present_full_field
    call draw_sidebar_background
    call draw_hud
    call draw_mode_indicator
    call draw_bonus_indicator /* initial Vx1 is visible before first tick */
    /* /AUDIO: DOS errorlevel 0 when OPL2 detected, 1 for speaker fallback.
       Safe to use for emulator acceptance without playing a stage. */
    cmp byte ptr [0x80], 7
    jne check_smoke_test
    cmp byte ptr [0x82], '/'
    jne check_smoke_test
    cmp byte ptr [0x83], 'A'
    jne check_smoke_test
    cmp byte ptr [0x84], 'U'
    jne check_smoke_test
    mov ax, 0x0003
    int 0x10
    cmp byte ptr [adlib_present], 0
    je audio_not_detected
    mov ax, 0x4c00
    int 0x21
audio_not_detected:
    mov ax, 0x4c01
    int 0x21
check_smoke_test:
    /* Invocation: TANKS.COM /TEST (six command-line chars). */
    cmp byte ptr [0x80], 6
    jne normal_start
    cmp byte ptr [0x82], '/'
    jne normal_start
    cmp byte ptr [0x83], 'T'
    jne normal_start
    jmp smoke_test
normal_start:
.ifdef TRACE_BUILD
    /* TANKS.COM /TRACE: reproduce 128 real simulation frames on DOS,
       save eight 16-byte squad snapshots for offline tactical inspection. */
    cmp byte ptr [0x80],7
    jne normal_play
    cmp byte ptr [0x82],'/'
    jne normal_play
    cmp byte ptr [0x83],'T'
    jne normal_play
    cmp byte ptr [0x84],'R'
    jne normal_play
    jmp trace_run
.endif
normal_play:
    /* The opening doctrine changes across runs, not only between stages. */
    mov ah,0
    int 0x1a
    xor word ptr [rng_state],dx
    call bomber26_roll
    call random_byte
    and al,3
    mov [squad_doctrine],al
    mov byte ptr [squad_phase],0
    cmp al,1
    jne normal_play_doctrine_ready
    mov byte ptr [squad_phase],1
normal_play_doctrine_ready:
    call render_frame
    call transition20_open
    call install_keyboard
    mov ah, 0
    int 0x1a
    mov word ptr [last_tick], dx
main_loop:
    call poll_controls
    mov ah, 0
    int 0x1a
    cmp dx, [last_tick]
    je main_loop
    mov [last_tick], dx
    cmp byte ptr [game_state], 0
    je main_loop_play
    cmp byte ptr [auto_mode], 0
    je main_loop
    cmp byte ptr [game_state], 3
    je main_loop
    inc byte ptr [demo_timer]
    cmp byte ptr [demo_timer], 72    /* 4s to appreciate the result */
    jb main_loop
    mov byte ptr [demo_timer], 0
    cmp byte ptr [game_state], 1
    jne main_loop_auto_restart
    inc byte ptr [stage]
    cmp byte ptr [stage], 35
    jbe main_loop_auto_next
    mov byte ptr [stage], 1
main_loop_auto_next:
    call load_stage
    call refresh_screen
    jmp main_loop
main_loop_auto_restart:
    call reset_campaign
    call refresh_screen
    jmp main_loop
main_loop_play:
    call game_tick_step
    call render_frame
    call draw_bonus_indicator
    /* Animate once, AFTER the last frame, BEFORE the result text. */
    cmp byte ptr [game_state],0
    je no_stage_overlay
    cmp byte ptr [transition_done],0
    jne no_stage_overlay
    mov byte ptr [transition_done],1
    call transition20_close
    cmp byte ptr [game_state],2
    jne stage_out_clear
    call game_over_hud
    jmp no_stage_overlay
stage_out_clear:
    cmp byte ptr [game_state],1
    jne no_stage_overlay
    call stage_clear_hud
no_stage_overlay:
    jmp main_loop

/* State: 0 playing, 1 won stage, 2 lost. */
reset_campaign:
    mov byte ptr [ally_stock],1   /* one free V summon per campaign */
    mov byte ptr [stage], 1
    mov byte ptr [lives], 3
    mov word ptr [score], 0
    mov byte ptr [bonus_sequence], 0
    mov byte ptr [coop_mode],0
    mov byte ptr [coop_lives],0
    mov byte ptr [coop_keys],0
    mov byte ptr [coop_join_pending],0
    mov byte ptr [sound_muted], 0
    call load_stage
    ret
load_stage:
    push es
    push ds
    pop es
    xor bx, bx
    mov bl, [stage]
    dec bx
    shl bx, 1
    mov si, [stage_ptrs+bx]
    mov di, offset level_data
    mov cx,256
unpack_stage_loop:
    lodsb
    mov dh,al             /* run length minus one, high nibble */
    and al,15
    xor bx,bx
    mov bl,al
    mov al,[stage_tile_codes+bx]
    mov dl,dh
    shr dl,1
    shr dl,1
    shr dl,1
    shr dl,1
    inc dl
unpack_stage_repeat:
    stosb
    dec cx
    jz unpack_stage_done
    dec dl
    jnz unpack_stage_repeat
    jmp unpack_stage_loop
unpack_stage_done:
    pop es
    /* Strip static E/P markers, replace with dynamic entities. */
    mov di, offset level_data
    mov cx, 256
clear_markers:
    cmp byte ptr [di], 'E'
    je clear_marker
    cmp byte ptr [di], 'P'
    jne marker_next
clear_marker:
    mov byte ptr [di], '.'
marker_next:
    inc di
    loop clear_markers
    mov byte ptr [player_col], 7
    mov byte ptr [player_row], 14
    mov byte ptr [player_dir], 0
    mov byte ptr [player_shield], 24
    mov byte ptr [bullet_active], 0
    mov byte ptr [bullet_delay], 0
    mov byte ptr [enemy_spawned], 0
    mov byte ptr [enemy_killed], 0
    mov byte ptr [game_state], 0
    mov byte ptr [demo_timer], 0
    mov byte ptr [game_tick], 0
    mov byte ptr [transition_done],0
    mov byte ptr [transition_pending],1
    mov byte ptr [ally_life_flash],0
    mov byte ptr [enemy_ai_phase], 0
    mov byte ptr [squad_alert], 0
    mov byte ptr [squad_target_x], 112
    mov byte ptr [squad_target_y], 168
    mov byte ptr [player_upgrade], 0
    mov byte ptr [bonus_active], 0
    mov byte ptr [bonus_timer], 0
    mov byte ptr [bonus_flash_ticks], 0
    mov byte ptr [ally_shield],0
    mov byte ptr [laser_ticks], 0
    mov byte ptr [multi_ticks], 0
    mov byte ptr [homing_ticks], 0
    mov byte ptr [frenzy_ticks], 0
    mov byte ptr [quad_ticks],0
    mov byte ptr [super_ticks],0
    mov byte ptr [super_bullet_active],0
    mov byte ptr [pong_ticks],0
    mov byte ptr [pong_active],0
    mov byte ptr [player_slow_ticks],0
    mov byte ptr [paint_pong_valid],0
    mov byte ptr [laser_flash_ticks], 0
    mov word ptr [ally_ticks], 0
    mov byte ptr [coop_keys],0
    mov byte ptr [coop_join_pending],0
    mov byte ptr [extra_active], 0
    mov byte ptr [extra_active+1], 0
    mov byte ptr [extra_active+2], 0
    mov byte ptr [freeze_ticks], 0
    mov byte ptr [hq_shield], 0
    mov byte ptr [slide_ticks], 0
    mov byte ptr [sound_ticks], 0
    mov byte ptr [held_keys], 0
    mov byte ptr [manual_keys], 0
    mov byte ptr [pending_commands], 0
    mov byte ptr [auto_toggle_pending], 0
    mov byte ptr [ally_call_pending],0
    mov byte ptr [player_px], 112
    mov byte ptr [player_py], 168
    mov byte ptr [paint_player_valid], 0
    mov byte ptr [paint_bullet_valid], 0
    mov byte ptr [paint_extra_valid], 0
    mov byte ptr [paint_extra_valid+1], 0
    mov byte ptr [paint_extra_valid+2], 0
    mov byte ptr [shot_active+4],0
    mov byte ptr [shot_active+5],0
    mov byte ptr [shot_active+6],0
    mov byte ptr [paint_ally_valid], 0
    mov byte ptr [paint_bonus_valid], 0
    mov di,offset grenade_fx_ticks
    mov cx,4
    xor al,al
    rep stosb
    mov di,offset paint_grenade_valid
    mov cx,4
    rep stosb
    mov di, offset paint_enemy_valid
    mov cx, 4
    xor al, al
    rep stosb
    mov di, offset paint_shot_valid
    mov cx, 7
    rep stosb
    mov di, offset dirty_tiles
    mov cx, 256
    rep stosb
    mov di, offset upload_tiles
    mov cx, 256
    rep stosb
    mov si, offset level_data
    mov di, offset brick_masks
    mov cx, 256
init_bricks:
    xor al, al
    cmp byte ptr [si], '#'
    jne init_brick_store
    mov al, 15
init_brick_store:
    mov [di], al
    inc si
    inc di
    loop init_bricks
    call strategy_reset
    call tactical24_reset
    call bomber25_reset
    /* 2P uses the existing ally sprite but not its autonomous brain. */
    cmp byte ptr [coop_mode],0
    je load_stage_no_coop
    call coop24_spawn_stage
load_stage_no_coop:
    mov di, offset enemy_active
    mov cx, 4
    xor al, al
    rep stosb
    mov di, offset enemy_hold
    mov cx, 4
    rep stosb
    mov di, offset enemy_blocked
    mov cx, 4
    rep stosb
    mov di, offset shot_active
    mov cx, 4
    rep stosb
    mov di, offset kills_by_type
    mov cx, 4
    rep stosb
    mov cx, 3
spawn_initial:
    push cx
    call spawn_enemy
    pop cx
    loop spawn_initial
    ret

/* Legacy BIOS polling was dead after the XT IRQ1 held-key handler.
 * Keep label for diagnostics; input arrives through poll_controls. */
poll_keyboard:
    ret

do_restart:
    call reset_campaign
    call refresh_screen
    ret
refresh_screen:
    mov ax, 0x0004
    int 0x10
    mov ax, 0x0b00
    mov bx, 0x0101
    int 0x10
    /* BIOS video reinitialization resets 3D9h. Restore the user choice
       from RAM after every stage/reset; never use a DOS settings file. */
    call apply_cga_palette
    call draw_map
    call present_full_field
    call draw_sidebar_background
    call draw_hud
    call render_frame
    call draw_mode_indicator
    call draw_bonus_indicator
    call transition20_open     /* only once per level / restarts */
    ret
exit_game:
    call restore_keyboard
    call sound_stop
    mov ax, 0x0003
    int 0x10
    mov ax, 0x4c00
    int 0x21

/* The old grid-step keyboard handlers were unused by pixel movement;
 * retained try_move below for stage/brick DOS smoke checks. */
/* Target DL/DH: player move only if floor and no enemy. */
try_move:
    push dx
    call get_tile
    cmp al, '.'
    je move_tile_ok
    cmp al, 'F'
    je move_tile_ok
    cmp al, 'I'
    je move_tile_ok
    jmp blocked_move
move_tile_ok:
    pop dx
    push dx
    call enemy_at
    cmp al, 0xff
    jne blocked_move
    pop dx
    mov [next_col], dl
    mov [next_row], dh
    mov dl, [player_col]
    mov dh, [player_row]
    mov al, [next_col]
    mov [player_col], al
    mov al, [next_row]
    mov [player_row], al
    push dx
    mov dl, [player_col]
    mov dh, [player_row]
    call player_enter_tile
    pop dx
    call draw_cell
    mov dl, [player_col]
    mov dh, [player_row]
    call draw_cell
    ret
blocked_move:
    pop dx
    mov dl, [player_col]
    mov dh, [player_row]
    call draw_cell
    ret


/* Entering ordinary terrain ends the slide; ice continues for a few ticks.
 * Pickups are independent entities and can be collected from any floor type.
 */
player_enter_tile:
    push ax
    push bx
    push dx
    call get_tile
    cmp al, 'I'
    jne player_ice_end
    mov byte ptr [slide_ticks], 2
    jmp player_check_pickup
player_ice_end:
    mov byte ptr [slide_ticks], 0
player_check_pickup:
    call check_bonus_pickup
    pop dx
    pop bx
    pop ax
    ret

slide_player:
    cmp byte ptr [slide_ticks], 0
    je slide_done
    test byte ptr [game_tick], 3
    jnz slide_done
    mov dl, [player_col]
    mov dh, [player_row]
    mov [slide_old_col], dl
    mov [slide_old_row], dh
    mov al, [player_dir]
    call step_position
    jc slide_end
    call try_move
    mov al, [slide_old_col]
    cmp al, [player_col]
    jne slide_done
    mov al, [slide_old_row]
    cmp al, [player_row]
    jne slide_done
    /* The next tile was blocked, so do not repeat futile slide steps. */
    jmp slide_end
slide_end:
    mov byte ptr [slide_ticks], 0
slide_done:
    ret

/* 18.2 Hz game tick, no busy-wait dependent on CPU MHz. */
game_tick_step:
    inc byte ptr [game_tick]
    call strategy_tick
    cmp byte ptr [auto_mode],0
    je game_tick_no_autopilot
    cmp byte ptr [coop_mode],0
    je game_tick_auto_alive
    cmp byte ptr [lives],0
    je game_tick_no_autopilot
game_tick_auto_alive:
    call tactical_player_tick
 game_tick_no_autopilot:
    cmp byte ptr [squad_alert],0
    je game_tick_no_alert
    dec byte ptr [squad_alert]
 game_tick_no_alert:
    call move_player_smooth
    call coop24_tick
    /* Pickups can appear when the tank is not moving. */
    cmp byte ptr [coop_mode],0
    je tick_p1_pickup
    cmp byte ptr [lives],0
    je tick_p1_pickup_done
tick_p1_pickup:
    call check_bonus_pickup
tick_p1_pickup_done:
    /* Autopilot shoots independently of navigation objectives and keeps
       aiming even when traveling directly toward a power-up. */
    cmp byte ptr [auto_mode],0
    je game_tick_no_autofire
    call tactical_player_autofire
 game_tick_no_autofire:
    call sound_tick
    call tick_explosion
    call grenade17_fx_tick
    call tick_powerups
    call bonus17_tick
    call bonus23_tick
    call gun27_tick
    call bomber25_tick
    call enemy23_tick
    call ally20_pickup
    call slide_player_smooth
    cmp byte ptr [player_shield], 0
    je tick_no_shield
    dec byte ptr [player_shield]
    jnz tick_no_shield
    mov dl, [player_col]
    mov dh, [player_row]
    call draw_cell
tick_no_shield:
    /* Homing works by itself, not only when triple-fire is also active. */
    cmp byte ptr [homing_ticks],0
    je bullet17_standard
    cmp byte ptr [bullet_active],0
    je bullet17_standard
    call extra17_home_direction
bullet17_standard:
    call advance_bullet_smooth
    call extra17_advance
    cmp byte ptr [freeze_ticks], 0
    jne tick_frozen
    call update_enemy_shots_smooth
    call move_enemies_smooth
    test byte ptr [game_tick], 15
    jnz tick_no_ai
    call enemy_fire_cycle
tick_no_ai:
    test byte ptr [game_tick], 15
    jnz tick_no_spawn
    call spawn_enemy
tick_no_spawn:
tick_frozen:
    /* Four-tick cadence: even the fastest tank takes >=8 ticks to
       cross a 16px tile. Avoid bonus AABB loops on 75% of frames. */
    test byte ptr [game_tick],3
    jnz tick21_pickup_skipped
    call enemy21_collect_bonus
tick21_pickup_skipped:
    call check_stage_complete
    ret

/* Power-up sequence: 0 star, 1 helmet, 2 grenade, 3 shovel,
 * 4 clock, 5 extra life. All spawn positions are open in authored maps.
 */
maybe_drop_bonus:
    /* 8 candidates in 20 kills, exactly 1.6x the old five.  The
       dropped pickup belongs to the destroyed enemy's actual cell.
       BX is the killed enemy slot, preserved for scoring. */
    push ax
    push bx
    push cx
    push dx
    push si
    cmp byte ptr [bonus_active],0
    je bonus21_check_due
    jmp bonus21_drop_done
bonus21_check_due:
    mov al,[enemy_killed]
    xor ah,ah
    mov cl,5
    div cl
    cmp ah,0
    je bonus21_drop_due
    cmp byte ptr [coop_mode],0
    jne bonus21_drop_done /* 4 rather than 8 gifts per 20 kills */
    cmp ah,2
    jne bonus21_drop_done
bonus21_drop_due:
    mov dl,[enemy_px+bx]
    add dl,8
    shr dl,1
    shr dl,1
    shr dl,1
    shr dl,1
    mov dh,[enemy_py+bx]
    add dh,6
    xor ax,ax
    mov al,dh
    mov cl,12
    div cl
    mov dh,al
    call get_tile
    cmp al,'.'
    je bonus21_drop_open
    cmp al,'F'
    je bonus21_drop_open
    cmp al,'I'
    jne bonus21_drop_done
bonus21_drop_open:
    mov [bonus_col],dl
    mov [bonus_row],dh
    xor bx,bx
    mov bl,[bonus_sequence]
    mov al,[bonus_drop_order+bx]
    cmp byte ptr [test_mode],0
    je bonus21_type_ok
    xor al,al
bonus21_type_ok:
    mov [bonus_type],al
    inc byte ptr [bonus_sequence]
    cmp byte ptr [bonus_sequence],14
    jb bonus21_sequence_ok
    mov byte ptr [bonus_sequence],0
bonus21_sequence_ok:
    mov byte ptr [bonus_active],1
    mov byte ptr [bonus_timer],220
    call strategy_bonus_spawn
    call draw_cell
bonus21_drop_done:
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

/* Called once movement has committed. Registers preserved. */
check_bonus_pickup:
    push ax
    push bx
    push cx
    push dx
    cmp byte ptr [bonus_active], 0
    jne bonus_can_collect
    jmp bonus_pickup_done
bonus_can_collect:
    mov dl,[player_px]
    mov dh,[player_py]
    call bonus26_touch
    jnc bonus_pickup_done
    xor al,al          /* collector = P1 */
    call bonus20_apply
bonus_pickup_done:
    pop dx
    pop cx
    pop bx
    pop ax
    ret

/* Shared pickup applies equally to main tank and autonomous companion. */
bonus20_apply:
    call bonus25_collected
    mov byte ptr [bonus_active], 0
    mov byte ptr [bonus_timer], 0
    mov al,[bonus_type]
    mov [bonus_flash_type],al
    mov byte ptr [bonus_flash_ticks],112
    mov ax, 880
    call sound_play
    mov al, [bonus_type]
    cmp al, 0
    jne pickup_not_star
    cmp byte ptr [player_upgrade], 3
    jb 1f
    jmp bonus20_applied
1:
    inc byte ptr [player_upgrade]
    call draw_hud
    jmp bonus20_applied
pickup_not_star:
    cmp al, 1
    jne pickup_not_helmet
    mov byte ptr [player_shield], 150
    mov byte ptr [bonus_flash_ticks],150
    jmp bonus20_applied
pickup_not_helmet:
    cmp al, 2
    jne pickup_not_grenade
    call grenade_all_enemies
    jmp bonus20_applied
pickup_not_grenade:
    cmp al, 3
    jne pickup_not_shovel
    call protect_hq
    mov byte ptr [bonus_flash_ticks],160
    jmp bonus20_applied
pickup_not_shovel:
    cmp al, 4
    jne pickup_not_clock
    mov byte ptr [freeze_ticks], 120
    mov byte ptr [bonus_flash_ticks],120
    jmp bonus20_applied
pickup_not_clock:
    cmp al,5
    jne pickup_not_life
    cmp byte ptr [lives], 9
    jb 1f
    jmp bonus20_applied
1:
    inc byte ptr [lives]
    call draw_hud
    jmp bonus20_applied
pickup_not_life:
    cmp al,6
    jne pickup_not_laser
    mov byte ptr [laser_ticks],180
    jmp bonus17_timed
pickup_not_laser:
    cmp al,7
    jne pickup_not_ally
    call ally20_collect
    jmp bonus20_applied
pickup_not_ally:
    cmp al,8
    jne pickup_not_triple
    mov byte ptr [multi_ticks],180
    jmp bonus17_timed
pickup_not_triple:
    cmp al,9
    jne pickup_not_homing
    mov byte ptr [homing_ticks],180
    jmp bonus17_timed
pickup_not_homing:
    cmp al,10
    jne pickup23_not_frenzy
    mov byte ptr [frenzy_ticks],180
    jmp bonus17_timed
pickup23_not_frenzy:
    cmp al,11
    jne pickup23_not_pong
    mov byte ptr [pong_ticks],180
    mov byte ptr [pong_active],0
    jmp bonus17_timed
pickup23_not_pong:
    cmp al,12
    jne pickup23_not_quad
    mov byte ptr [quad_ticks],180
    jmp bonus17_timed
pickup23_not_quad:
    mov byte ptr [super_ticks],180
bonus17_timed:
    mov byte ptr [bonus_flash_ticks],180
bonus20_applied:
    ret

grenade_all_enemies:
    push ax
    push bx
    push dx
    xor bx, bx
grenade_next:
    cmp byte ptr [enemy_active+bx], 0
    je grenade_skip
    mov al,[enemy_px+bx]
    mov [grenade_fx_x+bx],al
    mov al,[enemy_py+bx]
    mov [grenade_fx_y+bx],al
    mov byte ptr [grenade_fx_ticks+bx],12
    mov byte ptr [enemy_active+bx], 0
    mov byte ptr [shot_active+bx], 0
    inc byte ptr [enemy_killed]
    xor ax, ax
    mov al, [enemy_type+bx]
    push bx
    xor ah, ah
    mov bl, al
    inc byte ptr [kills_by_type+bx]
    pop bx
    inc al
    mov dl, 100
    mul dl
    add [score], ax
    mov dl, [enemy_col+bx]
    mov dh, [enemy_row+bx]
    call draw_cell
grenade_skip:
    inc bx
    cmp bx, 4
    jb grenade_next
    call draw_hud
    pop dx
    pop bx
    pop ax
    ret

/* Shovel: preserve the exact four original barrier cells/masks, turn them
 * into steel, and restore on expiry without resetting the level map.
 */
protect_hq:
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    cmp byte ptr [hq_shield], 0
    jne hq_refresh_timer
    xor bx, bx
hq_save_next:
    xor si, si
    mov si, bx
    shl si, 1
    mov si, [hq_wall_indices+si]
    mov al, [level_data+si]
    mov [hq_originals+bx], al
    mov al, [brick_masks+si]
    mov [hq_original_masks+bx], al
    mov byte ptr [level_data+si], 'T'
    mov byte ptr [brick_masks+si], 0
    push bx
    call draw_hq_wall
    pop bx
    inc bx
    cmp bx, 4
    jb hq_save_next
hq_refresh_timer:
    mov byte ptr [hq_shield], 160
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

restore_hq:
    push ax
    push bx
    push dx
    push si
    xor bx, bx
hq_restore_next:
    mov si, bx
    shl si, 1
    mov si, [hq_wall_indices+si]
    mov al, [hq_originals+bx]
    mov [level_data+si], al
    mov al, [hq_original_masks+bx]
    mov [brick_masks+si], al
    push bx
    call draw_hq_wall
    pop bx
    inc bx
    cmp bx, 4
    jb hq_restore_next
    pop si
    pop dx
    pop bx
    pop ax
    ret

/* BX is the index 0..3 in the four corners around the HQ. */
draw_hq_wall:
    mov dl, [hq_wall_columns+bx]
    mov dh, [hq_wall_rows+bx]
    call draw_cell
    ret

tick_powerups:
    push ax
    push dx
    cmp byte ptr [bonus_flash_ticks],0
    je tick_bonus_flash_done
    dec byte ptr [bonus_flash_ticks]
tick_bonus_flash_done:
    cmp byte ptr [bonus_active], 0
    je tick_no_bonus
    dec byte ptr [bonus_timer]
    jnz tick_no_bonus
    mov byte ptr [bonus_active], 0
    mov dl, [bonus_col]
    mov dh, [bonus_row]
    call draw_cell
tick_no_bonus:
    cmp byte ptr [freeze_ticks], 0
    je tick_no_clock
    dec byte ptr [freeze_ticks]
tick_no_clock:
    cmp byte ptr [hq_shield], 0
    je tick_power_done
    dec byte ptr [hq_shield]
    jnz tick_power_done
    call restore_hq
tick_power_done:
    pop dx
    pop ax
    ret

/* Short nonblocking PC Speaker effects. No TSR, driver, DOS service or FPU.
 * Input AX = PIT divisor (larger value means lower pitch).
 * An AdLib detection and OPL2 layer can be plugged in later.
 */
/* AdLib OPL2 timer-status detection (classic FM/OPL2 probe).
 * Reads only the AdLib status port; a disconnected ISA bus returns FFh.
 * No mandatory sound card; no external ROM or driver is needed.
 */
adlib_detect:
    push ax
    push bx
    push cx
    push dx
    mov byte ptr [adlib_present], 0
    mov ax, 0x0460
    call adlib_write
    mov ax, 0x0480
    call adlib_write
    mov dx, 0x0388
    in al, dx
    and al, 0xe0
    mov bl, al
    mov ax, 0x02ff
    call adlib_write
    mov ax, 0x0421
    call adlib_write
    mov dx, 0x0388
    mov cx, 200
adlib_timer_wait:
    in al, dx
    loop adlib_timer_wait
    in al, dx
    and al, 0xe0
    mov bh, al
    mov ax, 0x0460
    call adlib_write
    mov ax, 0x0480
    call adlib_write
    cmp bl, 0
    jne adlib_detect_done
    cmp bh, 0xc0
    jne adlib_detect_done
    mov byte ptr [adlib_present], 1
    call adlib_setup
adlib_detect_done:
    pop dx
    pop cx
    pop bx
    pop ax
    ret

/* AH=OPL register, AL=value; explicit ISA timing for 4.77 MHz XT. */
adlib_write:
    push ax
    push bx
    push cx
    push dx
    mov bx, ax
    mov dx, 0x0388
    mov al, bh
    out dx, al
    mov cx, 6
adlib_addr_delay:
    in al, dx
    loop adlib_addr_delay
    inc dx
    mov al, bl
    out dx, al
    dec dx
    mov cx, 35
adlib_data_delay:
    in al, dx
    loop adlib_data_delay
    pop dx
    pop cx
    pop bx
    pop ax
    ret

/* Basic original one-channel percussive tone, not an existing soundtrack. */
adlib_setup:
    push ax
    mov ax, 0x2001       /* channel 0 modulator and carrier */
    call adlib_write
    mov ax, 0x2301
    call adlib_write
    mov ax, 0x403f       /* suppress modulator for simple sine-like tone */
    call adlib_write
    mov ax, 0x4308
    call adlib_write
    mov ax, 0x60f0
    call adlib_write
    mov ax, 0x63f0
    call adlib_write
    mov ax, 0x8077
    call adlib_write
    mov ax, 0x8377
    call adlib_write
    mov ax, 0xc000
    call adlib_write
    mov ax, 0xb011
    call adlib_write
    pop ax
    ret

/* Game sound API: AX=PC speaker divider. Prefer OPL2 when detected. */
sound_play:
    push ax
    push bx
    push dx
    cmp byte ptr [sound_muted], 0
    jne sound_play_done
    mov bx, ax
    cmp byte ptr [adlib_present], 0
    je sound_speaker_fallback
    mov ax, 0xb011      /* key off before new tone */
    call adlib_write
    mov ax, 0xa0c0
    cmp bx, 1100
    jb adlib_fx_ready
    mov ax, 0xa080
    cmp bx, 2000
    jb adlib_fx_ready
    mov ax, 0xa030
adlib_fx_ready:
    call adlib_write
    mov ax, 0xb031      /* octave 4, key on */
    call adlib_write
    mov byte ptr [sound_ticks], 2
    jmp sound_play_done
sound_speaker_fallback:
    mov al, 0xb6
    out 0x43, al
    mov ax, bx
    out 0x42, al
    mov al, ah
    out 0x42, al
    in al, 0x61
    or al, 3
    out 0x61, al
    mov byte ptr [sound_ticks], 2
sound_play_done:
    pop dx
    pop bx
    pop ax
    ret
sound_tick:
    cmp byte ptr [sound_ticks], 0
    je sound_tick_done
    dec byte ptr [sound_ticks]
    jnz sound_tick_done
    call sound_stop
sound_tick_done:
    ret
sound_stop:
    push ax
    in al, 0x61
    and al, 0xfc
    out 0x61, al
    cmp byte ptr [adlib_present], 0
    je speaker_stopped
    mov ax, 0xb011
    call adlib_write
speaker_stopped:
    mov byte ptr [sound_ticks], 0
    pop ax
    ret

/* A full brick starts with four 8x6 quarters. Shots chip the nearest
 * half first. This grid-based prototype does not yet model pixel-accurate
 * half-brick collision, but damage/graphics persist per quadrant.
 * Input SI points into level_data, AL gives projectile direction.
 */
damage_brick:
    push ax
    push bx
    push dx
    push si
    sub si, offset level_data
    mov bl, [brick_masks+si]
    mov dl, 0x0c                /* upward shot arrives from below */
    cmp al, 0
    je damage_mask_ready
    mov dl, 0x05                /* rightward arrives from left */
    cmp al, 1
    je damage_mask_ready
    mov dl, 0x03                /* downward arrives from top */
    cmp al, 2
    je damage_mask_ready
    mov dl, 0x0a                /* leftward arrives from right */
damage_mask_ready:
    mov dh, bl
    and dh, dl
    jnz damage_front
    mov dl, 0x0f                /* remaining rear half */
damage_front:
    not dl
    and bl, dl
    mov [brick_masks+si], bl
    test bl, bl
    jnz damage_done
    mov byte ptr [level_data+si], '.'
    mov byte ptr [route_dirty], 1
damage_done:
    pop si
    pop dx
    pop bx
    pop ax
    ret

/* Seeded simple 16-bit pseudo-random sequence, deterministic per DOS start. */
random_byte:
    mov ax, [rng_state]
    rol ax, 1
    xor ax, 0xb400
    add ax, 0x1021
    mov [rng_state], ax
    ret

/* Spawn a maximum of three visible enemies from alternating top lanes. */
spawn_enemy:
    cmp byte ptr [enemy_spawned], 20
    jb spawn_has_reserves
    ret
spawn_has_reserves:
    xor bx, bx
spawn_find_slot:
    cmp byte ptr [enemy_active+bx], 0
    je spawn_slot_found
    inc bx
    cmp bx, 4
    jb spawn_find_slot
    ret
spawn_slot_found:
    mov [temp_slot], bl
    mov al, [enemy_spawned]
    xor ah, ah
    mov cl, 3
    div cl
    xor bx, bx
    mov bl, ah
    mov dl, [spawn_columns+bx]
    xor dh, dh
    call get_tile
    cmp al, '.'
    je spawn_tile_open
    jmp spawn_abort
spawn_tile_open:
    call enemy_at
    cmp al, 0xff
    je spawn_slot_free
    jmp spawn_abort
spawn_slot_free:
    cmp dl, [player_col]
    jne spawn_ready
    cmp dh, [player_row]
    jne spawn_ready
    jmp spawn_abort
spawn_ready:
    xor bx, bx
    mov bl, [temp_slot]
    mov [enemy_col+bx], dl
    mov [enemy_row+bx], dh
    mov byte ptr [enemy_dir+bx], 2
    mov al, dl
    shl al, 1
    shl al, 1
    shl al, 1
    shl al, 1
    mov [enemy_px+bx], al
    mov al, dh
    push bx
    mov bl, 12
    mul bl
    pop bx
    mov [enemy_py+bx], al
    /* Later stages gradually favor power and armor tanks. */
    mov al, [enemy_spawned]
    mov ah, [stage]
    dec ah
    add al, ah
    and al, 3
    cmp byte ptr [stage], 12
    jb spawn_class_ready
    cmp al, 0
    jne spawn_class_harder
    mov al, 2
spawn_class_harder:
    cmp byte ptr [stage], 24
    jb spawn_class_ready
    cmp al, 1
    jne spawn_class_ready
    mov al, 3
spawn_class_ready:
    mov [enemy_type+bx], al
    mov byte ptr [enemy_hp+bx], 1
    cmp al, 3
    jne spawn_basic_health
    mov byte ptr [enemy_hp+bx], 4
spawn_basic_health:
    mov byte ptr [enemy_active+bx], 1
    mov byte ptr [enemy_hold+bx], 0
    mov byte ptr [enemy_track_damage+bx],0
    mov byte ptr [enemy_blocked+bx], 0
    mov byte ptr [enemy_loop_last+bx],0xff
    mov byte ptr [enemy_loop_prev+bx],0xff
    mov byte ptr [enemy_loop_count+bx],0
    mov byte ptr [enemy_escape_ticks+bx],0
    mov byte ptr [shot_active+bx], 0
    mov byte ptr [enemy_weapon_kind+bx],0
    mov byte ptr [enemy_weapon_ticks+bx],0
    mov byte ptr [shot_owner+bx],bl
    mov byte ptr [shot_super+bx],0
    inc byte ptr [enemy_spawned]
    call draw_cell
spawn_abort:
    ret

/* Return AL: 0,1,2 or ff if no enemy. Preserves BX, DX, SI. */
enemy_at:
    push bx
    xor bx, bx
enemy_at_loop:
    cmp byte ptr [enemy_active+bx], 0
    je enemy_at_continue
    cmp dl, [enemy_col+bx]
    jne enemy_at_continue
    cmp dh, [enemy_row+bx]
    jne enemy_at_continue
    mov ax, bx
    pop bx
    ret
enemy_at_continue:
    inc bx
    cmp bx, 4
    jb enemy_at_loop
    mov al, 0xff
    pop bx
    ret

/* Enemies generally head toward the HQ but change direction at walls. */
move_enemies:
    xor bx, bx
enemy_move_loop:
    cmp byte ptr [enemy_active+bx], 0
    jne enemy_move_active
    jmp enemy_move_next
enemy_move_active:
    cmp byte ptr [only_fast], 0
    je enemy_move_unfiltered
    cmp byte ptr [enemy_type+bx], 1
    je enemy_move_unfiltered
    jmp enemy_move_next
enemy_move_unfiltered:
    call random_byte
    and al, 15
    cmp al, 11
    jb enemy_keep_direction
    cmp al, 16
    jae enemy_random_dir
    mov al, 2
    jmp enemy_direction_chosen
enemy_keep_direction:
    mov al, [enemy_dir+bx]
    jmp enemy_direction_chosen
enemy_random_dir:
    and al, 3
enemy_direction_chosen:
    mov [enemy_dir+bx], al
    mov dl, [enemy_col+bx]
    mov dh, [enemy_row+bx]
    cmp al, 0
    jne enemy_not_up
    test dh, dh
    jz enemy_move_next
    dec dh
    jmp enemy_target
enemy_not_up:
    cmp al, 1
    jne enemy_not_right
    cmp dl, 15
    je enemy_move_next
    inc dl
    jmp enemy_target
enemy_not_right:
    cmp al, 2
    jne enemy_not_down
    cmp dh, 15
    je enemy_move_next
    inc dh
    jmp enemy_target
enemy_not_down:
    test dl, dl
    jz enemy_move_next
    dec dl
enemy_target:
    mov [next_col], dl
    mov [next_row], dh
    call get_tile
    cmp al, '.'
    je enemy_floor_ok
    cmp al, 'F'
    je enemy_floor_ok
    cmp al, 'I'
    je enemy_floor_ok
    jmp enemy_move_next
enemy_floor_ok:
    mov dl, [next_col]
    mov dh, [next_row]
    cmp dl, [player_col]
    jne enemy_no_player
    cmp dh, [player_row]
    je enemy_move_next
enemy_no_player:
    call enemy_at
    cmp al, 0xff
    jne enemy_move_next
    mov dl, [enemy_col+bx]
    mov dh, [enemy_row+bx]
    mov al, [next_col]
    mov [enemy_col+bx], al
    mov al, [next_row]
    mov [enemy_row+bx], al
    call draw_cell
    mov dl, [enemy_col+bx]
    mov dh, [enemy_row+bx]
    call draw_cell
enemy_move_next:
    inc bx
    cmp bx, 4
    jae enemy_move_finished
    jmp enemy_move_loop
enemy_move_finished:
    ret

enemy_fire_cycle:
    xor bx, bx
enemy_fire_loop:
    cmp byte ptr [enemy_active+bx], 0
    jne 9f
    jmp enemy_fire_next
9:
    cmp byte ptr [shot_active+bx], 0
    je 9f
    jmp enemy_fire_next
9:
    cmp byte ptr [frenzy_ticks],0
    je enemy_fire_normal
    call frenzy17_target
    jnc enemy_fire_normal
    jmp enemy_fire_now
enemy_fire_normal:
    call tactical_safe_fire
    jc 9f
    jmp enemy_fire_next
9:
    /* A weapon-bearing enemy fires on each safe scheduled opening,
       not just when its random 1-in-4 roll happens to succeed. */
    cmp byte ptr [enemy_weapon_ticks+bx],0
    jne enemy_fire_now
    cmp byte ptr [enemy_hold+bx], 0
    jne enemy_fire_now
    cmp byte ptr [enemy_type+bx], 2
    je enemy_fire_now
    call random_byte
    test al, 3
    jnz enemy_fire_next
enemy_fire_now:
    mov al, [enemy_col+bx]
    mov [shot_col+bx], al
    mov al, [enemy_row+bx]
    mov [shot_row+bx], al
    mov al, [enemy_dir+bx]
    mov [shot_dir+bx], al
    mov byte ptr [shot_active+bx], 1
    mov byte ptr [shot_delay+bx], 1
    mov byte ptr [shot_super+bx],0
    mov [shot_owner+bx],bl
    cmp byte ptr [test_mode], 0
    je enemy_fire_smooth_init
    call advance_enemy_shot
    jmp enemy_fire_next
enemy_fire_smooth_init:
    mov al, [enemy_px+bx]
    mov [shot_px+bx], al
    mov al, [enemy_py+bx]
    mov [shot_py+bx], al
    cmp byte ptr [enemy_weapon_ticks+bx],0
    jne 9f
    jmp enemy_fire_next
9:
    mov al,[enemy_weapon_kind+bx]
    cmp al,6
    jne enemy23_fire_not_laser
    call enemy23_laser
    jmp enemy_fire_next
enemy23_fire_not_laser:
    cmp al,8
    je enemy23_fire_spread
    cmp al,12
    jne enemy23_fire_not_spread
enemy23_fire_spread:
    call enemy23_burst
    jmp enemy_fire_next
enemy23_fire_not_spread:
    cmp al,13
    je 9f
    jmp enemy_fire_next
9:
    mov byte ptr [shot_super+bx],1
enemy_fire_next:
    inc bx
    cmp bx, 4
    jae 9f
    jmp enemy_fire_loop
9:
    ret

/* Player projectile: one at a time, one cell per two simulated frames. */
do_fire:
    cmp byte ptr [coop_mode],0
    je fire_alive
    cmp byte ptr [lives],0
    jne fire_alive
    ret
fire_alive:
    cmp byte ptr [pong_ticks],0
    je do_fire_normal
    cmp byte ptr [pong_active],0
    jne fire_done     /* exactly one ricochet until it expires */
    xor al,al
    call pong23_launch
    ret
do_fire_normal:
    cmp byte ptr [bullet_active], 0
    je fire_primary
    call extra17_player_fire
    jmp fire_done
fire_primary:
    mov byte ptr [gun27_p1],3
    mov al, [player_col]
    mov [bullet_col], al
    mov al, [player_row]
    mov [bullet_row], al
    mov al, [player_dir]
    mov [bullet_dir], al
    mov byte ptr [bullet_active], 1
    mov byte ptr [bullet_delay], 1
    call tactical_report_player
    mov ax, 1250
    call sound_play
    cmp byte ptr [test_mode], 0
    je fire_smooth_init
    call advance_bullet
    jmp fire_done
fire_smooth_init:
    mov byte ptr [super_bullet_active],0
    cmp byte ptr [super_ticks],0
    je fire23_standard
    mov byte ptr [super_bullet_active],1
fire23_standard:
    mov al, [player_px]
    mov [bullet_px], al
    mov al, [player_py]
    mov [bullet_py], al
    cmp byte ptr [quad_ticks],0
    je fire23_not_quad
    call quad23_spawn
fire23_not_quad:
    cmp byte ptr [super_bullet_active],0
    je fire27_super_clear
    jmp fire_done
fire27_super_clear:
    cmp byte ptr [laser_ticks],0
    je fire_done
    call laser17_fire
fire_done:
    ret
advance_bullet:
    cmp byte ptr [bullet_active], 0
    jne bullet_ready
    ret
bullet_ready:
    cmp byte ptr [player_upgrade], 0
    jne bullet_step
    xor byte ptr [bullet_delay], 1
    jz bullet_step
    ret
bullet_step:
    mov dl, [bullet_col]
    mov dh, [bullet_row]
    mov [old_col], dl
    mov [old_row], dh
    mov al, [bullet_dir]
    call step_position
    jnc bullet_inside
    jmp bullet_out
bullet_inside:
    mov [next_col], dl
    mov [next_row], dh
    push bx
    xor bx, bx
bullet_vs_shot_loop:
    cmp byte ptr [shot_active+bx], 0
    je bullet_vs_shot_next
    cmp dl, [shot_col+bx]
    jne bullet_vs_shot_next
    cmp dh, [shot_row+bx]
    jne bullet_vs_shot_next
    mov byte ptr [shot_active+bx], 0
    mov byte ptr [bullet_active], 0
    pop bx
    mov dl, [old_col]
    mov dh, [old_row]
    call draw_cell
    mov dl, [next_col]
    mov dh, [next_row]
    call draw_cell
    ret
bullet_vs_shot_next:
    inc bx
    cmp bx, 4
    jb bullet_vs_shot_loop
    pop bx
    call get_tile
    cmp al, '#'
    je bullet_break_brick
    cmp al, 'T'
    jne bullet_not_steel
    cmp byte ptr [player_upgrade], 3
    jae bullet_break_steel
    jmp bullet_out
bullet_break_steel:
    mov byte ptr [si], '.'
    jmp bullet_impact
bullet_not_steel:
    cmp al, 'B'
    je bullet_break_base
    mov dl, [next_col]
    mov dh, [next_row]
    call enemy_at
    cmp al, 0xff
    jne bullet_kill_enemy
    mov [bullet_col], dl
    mov [bullet_row], dh
    mov dl, [old_col]
    mov dh, [old_row]
    call draw_cell
    mov dl, [bullet_col]
    mov dh, [bullet_row]
    call draw_cell
    ret
bullet_break_brick:
    mov al, [bullet_dir]
    call damage_brick
    jmp bullet_impact
bullet_break_base:
    cmp byte ptr [hq_shield], 0
    jne bullet_impact
    mov byte ptr [game_state], 2
    jmp bullet_impact
bullet_kill_enemy:
    xor bx, bx
    mov bl, al
    cmp byte ptr [enemy_hp+bx], 1
    jbe bullet_enemy_destroyed
    dec byte ptr [enemy_hp+bx]
    jmp bullet_impact
bullet_enemy_destroyed:
    mov byte ptr [enemy_active+bx], 0
    mov byte ptr [shot_active+bx], 0
    inc byte ptr [enemy_killed]
    push bx
    call maybe_drop_bonus
    pop bx
    xor ax, ax
    mov al, [enemy_type+bx]
    push bx
    xor ah, ah
    mov bl, al
    inc byte ptr [kills_by_type+bx]
    pop bx
    inc al
    mov cl, 100
    mul cl
    add [score], ax
    call draw_hud
    jmp bullet_impact
bullet_out:
    mov byte ptr [bullet_active], 0
    mov dl, [old_col]
    mov dh, [old_row]
    call draw_cell
    ret
bullet_impact:
    mov ax, 2300
    call sound_play
    mov byte ptr [bullet_active], 0
    mov dl, [old_col]
    mov dh, [old_row]
    call draw_cell
    mov dl, [next_col]
    mov dh, [next_row]
    call draw_cell
    cmp byte ptr [game_state], 2
    jne bullet_end
    call game_over_hud
bullet_end:
    ret

/* Step a tile in direction AL (0 up,1 right,2 down,3 left).
 * Input DL col/DH row, result CF=1 if outside 13x13, else CF=0.
 */
step_position:
    cmp al, 0
    jne pos_not_up
    test dh, dh
    jz pos_off
    dec dh
    clc
    ret
pos_not_up:
    cmp al, 1
    jne pos_not_right
    cmp dl, 15
    je pos_off
    inc dl
    clc
    ret
pos_not_right:
    cmp al, 2
    jne pos_not_down
    cmp dh, 15
    je pos_off
    inc dh
    clc
    ret
pos_not_down:
    test dl, dl
    jz pos_off
    dec dl
    clc
    ret
pos_off:
    stc
    ret

update_enemy_bullets:
    xor bx, bx
shot_tick_loop:
    cmp byte ptr [shot_active+bx], 0
    je shot_tick_next
    call advance_enemy_shot
shot_tick_next:
    inc bx
    cmp bx, 4
    jb shot_tick_loop
    ret
advance_enemy_shot:
    cmp byte ptr [shot_active+bx], 0
    jne shot_ready
    ret
shot_ready:
    xor byte ptr [shot_delay+bx], 1
    jz shot_step
    ret
shot_step:
    mov dl, [shot_col+bx]
    mov dh, [shot_row+bx]
    mov [old_col], dl
    mov [old_row], dh
    mov al, [shot_dir+bx]
    call step_position
    jnc shot_inside
    jmp shot_out
shot_inside:
    mov [next_col], dl
    mov [next_row], dh
    cmp byte ptr [bullet_active], 0
    je shot_no_bullet_collision
    cmp dl, [bullet_col]
    jne shot_no_bullet_collision
    cmp dh, [bullet_row]
    jne shot_no_bullet_collision
    mov byte ptr [shot_active+bx], 0
    mov byte ptr [bullet_active], 0
    mov dl, [old_col]
    mov dh, [old_row]
    call draw_cell
    mov dl, [next_col]
    mov dh, [next_row]
    call draw_cell
    ret
shot_no_bullet_collision:
    call get_tile
    cmp al, '#'
    je shot_break_brick
    cmp al, 'T'
    jne shot_not_steel
    jmp shot_out
shot_not_steel:
    cmp al, 'B'
    je shot_base_hit
    mov dl, [next_col]
    mov dh, [next_row]
    cmp dl, [player_col]
    jne shot_moved
    cmp dh, [player_row]
    jne shot_moved
    cmp byte ptr [player_shield], 0
    jne shot_out
    jmp shot_player_hit
shot_moved:
    mov [shot_col+bx], dl
    mov [shot_row+bx], dh
    mov dl, [old_col]
    mov dh, [old_row]
    call draw_cell
    mov dl, [shot_col+bx]
    mov dh, [shot_row+bx]
    call draw_cell
    ret
shot_break_brick:
    mov al, [shot_dir+bx]
    call damage_brick
    jmp shot_impact
shot_base_hit:
    cmp byte ptr [hq_shield], 0
    jne shot_impact
    mov byte ptr [game_state], 2
    jmp shot_impact
shot_player_hit:
    dec byte ptr [lives]
    cmp byte ptr [lives], 0
    jne player_respawn
    mov byte ptr [game_state], 2
    jmp shot_impact
player_respawn:
    mov dl, [player_col]
    mov dh, [player_row]
    mov byte ptr [player_col], 7
    mov byte ptr [player_row], 14
    mov byte ptr [player_dir], 0
    mov byte ptr [player_shield], 24
    call draw_cell
    mov dl, [player_col]
    mov dh, [player_row]
    call draw_cell
    call draw_hud
shot_out:
    mov byte ptr [shot_active+bx], 0
    mov dl, [old_col]
    mov dh, [old_row]
    call draw_cell
    ret
shot_impact:
    mov ax, 2600
    call sound_play
    mov byte ptr [shot_active+bx], 0
    mov dl, [old_col]
    mov dh, [old_row]
    call draw_cell
    mov dl, [next_col]
    mov dh, [next_row]
    call draw_cell
    cmp byte ptr [game_state], 2
    jne shot_impact_done
    call game_over_hud
shot_impact_done:
    ret

check_stage_complete:
    cmp byte ptr [enemy_spawned], 20
    jne stage_not_done
    cmp byte ptr [enemy_killed], 20
    jne stage_not_done
    mov byte ptr [game_state], 1
    /* Main loop plays exit animation before the result overlay. */
stage_not_done:
    ret
/* Classic-style black-on-blackfield overlay for stage completion/game over.
 * Score is displayed here, not across the action screen (as on NES).
 */
/* The dedicated score tally is only shown once a stage finishes;
 * the gameplay action screen stays clean like the classic NES title.
 */
stage_clear_hud:
    call draw_stage_result_box
    call format_score
    call format_tally
    mov dl, 10
    mov dh, 4
    call cursor_at
    mov si, offset victory_string
    call bios_string
    mov dl, 9
    mov dh, 7
    call cursor_at
    mov si, offset tally1
    call bios_string
    mov dl, 9
    mov dh, 9
    call cursor_at
    mov si, offset tally2
    call bios_string
    mov dl, 9
    mov dh, 11
    call cursor_at
    mov si, offset tally3
    call bios_string
    mov dl, 9
    mov dh, 13
    call cursor_at
    mov si, offset tally4
    call bios_string
    mov dl, 11
    mov dh, 16
    call cursor_at
    mov si, offset score_string
    call bios_string
    mov dl, 10
    mov dh, 18
    call cursor_at
    mov si, offset next_string
    call bios_string
    ret

pause_hud:
    call draw_result_box
    mov dl, 13
    mov dh, 12
    call cursor_at
    mov si, offset pause_string
    call bios_string
    ret

/* Only columns x32..239, y28..155 are cleared; the right-side HUD remains. */
draw_stage_result_box:
    push ax
    push bx
    push cx
    push di
    push es
    mov ax, 0xb800
    mov es, ax
    xor ax, ax
    mov di, 1120             /* y28 /2 *80 + x0 */
    mov bx, 64               /* 128 physical scan lines */
stage_box_row:
    push di
    mov cx, 32
    rep stosw
    pop di
    push di
    add di, 0x2000
    mov cx, 32
    rep stosw
    pop di
    add di, 80
    dec bx
    jnz stage_box_row
    pop es
    pop di
    pop cx
    pop bx
    pop ax
    ret

/* Counts for each of four enemy types, displayed beside their 100-400
 * point weights. The global score is retained across the nine stages.
 */
format_tally:
    push ax
    push bx
    push cx
    push dx
    push si
    xor bx, bx
tally_next:
    xor ax, ax
    mov al, [kills_by_type+bx]
    mov cl, 10
    div cl
    add al, '0'
    add ah, '0'
    push bx
    shl bx, 1
    mov si, [tally_ptrs+bx]
    pop bx
    mov [si+11], al
    mov [si+12], ah
    inc bx
    cmp bx, 4
    jb tally_next
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

game_over_hud:
    call draw_result_box
    call format_score
    mov dl, 11
    mov dh, 10
    call cursor_at
    mov si, offset game_over_string
    call bios_string
    mov dl, 10
    mov dh, 12
    call cursor_at
    mov si, offset score_string
    call bios_string
    mov dl, 10
    mov dh, 14
    call cursor_at
    mov si, offset restart_string
    call bios_string
    ret

/* Clear a centered inset from x32..239, y72..135 in both CGA banks.
 * Since simulation is paused on game over or victory, screen restoration
 * happens only through refresh_screen on next stage/restart.
 */
draw_result_box:
    push ax
    push bx
    push cx
    push di
    push es
    mov ax, 0xb800
    mov es, ax
    xor ax, ax
    mov di, 2880             /* y72 even-bank, x0 */
    mov bx, 32               /* 64 physical scan lines */
result_box_row:
    push di
    mov cx, 32               /* 256 pixels = 64 bytes */
    rep stosw
    pop di
    push di
    add di, 0x2000
    mov cx, 32
    rep stosw
    pop di
    add di, 80
    dec bx
    jnz result_box_row
    pop es
    pop di
    pop cx
    pop bx
    pop ax
    ret

/* Convert the retained 16-bit score to five ASCII digits for result screen. */
format_score:
    push ax
    push bx
    push cx
    push dx
    push di
    mov ax, [score]
    mov bx, 10
    mov cx, 5
    mov di, offset score_string+10
format_score_digit:
    xor dx, dx
    div bx
    add dl, '0'
    mov [di], dl
    dec di
    loop format_score_digit
    pop di
    pop dx
    pop cx
    pop bx
    pop ax
    ret



/* Enemy movement: 1 pixel every frame, fast tanks move 2 pixels per frame,
 * armored tanks only every other frame. A turn takes place after a wall,
 * another tank, or an occasional deterministic decision.
 */
move_enemies_smooth:
    xor bx, bx
move_smooth_enemy_loop:
    cmp byte ptr [enemy_active+bx], 0
    je move_smooth_enemy_next
    cmp byte ptr [enemy_type+bx], 3
    jne move_smooth_enemy_ready
    test byte ptr [game_tick], 1
    jnz move_smooth_enemy_next
move_smooth_enemy_ready:
    /* A crippled track halves the original travel rate. */
    cmp byte ptr [enemy_track_damage+bx],0
    je move_smooth_track_ok
    /* Armoured tank normally moves once / 2 ticks. Damaged armour
       moves once / 4 ticks: an actual 50% reduction, not another
       overlapping odd-tick test that has no effect. */
    test byte ptr [game_tick],3
    jnz move_smooth_enemy_next
move_smooth_track_ok:
    cmp byte ptr [enemy_hold+bx], 0
    je move_smooth_enemy_active
    dec byte ptr [enemy_hold+bx]
    jmp move_smooth_enemy_next
move_smooth_enemy_active:
    mov al, [game_tick]
    and al, 31
    cmp al, 0
    jne move_smooth_no_turn
    call choose_enemy_turn
move_smooth_no_turn:
    call advance_enemy_one_pixel
    cmp byte ptr [enemy_type+bx], 1
    jne move_smooth_enemy_next
    call advance_enemy_one_pixel
move_smooth_enemy_next:
    inc bx
    cmp bx, 4
    jb move_smooth_enemy_loop
    ret
choose_enemy_turn:
    call tactical_enemy_turn
    ret
advance_enemy_one_pixel:
    mov dl, [enemy_px+bx]
    mov dh, [enemy_py+bx]
    mov al, [enemy_dir+bx]
    call step_pixel
    jnc 1f
    jmp enemy_pixel_collision
1:
    mov [candidate_x], dl
    mov [candidate_y], dh
    call rect_passable
    jnc 1f
    jmp enemy_pixel_collision
1:
    /* Collision with the player only when BOTH axes overlap. */
    cmp byte ptr [coop_mode],0
    je enemy_pixel_player_alive
    cmp byte ptr [lives],0
    je enemy_pixel_no_player
enemy_pixel_player_alive:
    mov al, [candidate_x]
    sub al, [player_px]
    cmp al, 16
    jb enemy_pixel_check_player_y
    cmp al, 241
    jae enemy_pixel_check_player_y
    jmp enemy_pixel_no_player
 enemy_pixel_check_player_y:
    mov al, [candidate_y]
    sub al, [player_py]
    cmp al, 12
    jb enemy_pixel_player_blocked
    cmp al, 245
    jae enemy_pixel_player_blocked
    jmp enemy_pixel_no_player
enemy_pixel_player_blocked:
    jmp enemy_pixel_collision
 enemy_pixel_no_player:
    cmp byte ptr [coop_mode],0
    je enemy_pixel_no_coop
    cmp byte ptr [coop_lives],0
    je enemy_pixel_no_coop
    mov al,[candidate_x]
    sub al,[ally_px]
    add al,15
    cmp al,30
    ja enemy_pixel_no_coop
    mov al,[candidate_y]
    sub al,[ally_py]
    add al,11
    cmp al,22
    jbe enemy_pixel_collision
enemy_pixel_no_coop:
    /* Enemy-enemy AABB; BX is our actor index. */
    xor si, si
enemy_pixel_check_others:
    cmp si, bx
    je enemy_pixel_next_other
    cmp byte ptr [enemy_active+si], 0
    je enemy_pixel_next_other
    mov al, [candidate_x]
    sub al, [enemy_px+si]
    cmp al, 16
    jb enemy_pixel_check_y
    cmp al, 241
    jbe enemy_pixel_next_other
    jmp enemy_pixel_check_y
enemy_pixel_check_y:
    mov al, [candidate_y]
    sub al, [enemy_py+si]
    cmp al, 12
    jb enemy_pixel_collision
    cmp al, 245
    jae enemy_pixel_collision
enemy_pixel_next_other:
    inc si
    cmp si, 4
    jb enemy_pixel_check_others
    mov byte ptr [enemy_blocked+bx], 0
    mov al, [candidate_x]
    mov [enemy_px+bx], al
    shr al, 1
    shr al, 1
    shr al, 1
    shr al, 1
    mov [enemy_col+bx], al
    mov al, [candidate_y]
    mov [enemy_py+bx], al
    xor ah, ah
    mov cl, 12
    div cl
    mov [enemy_row+bx], al
    ret
enemy_pixel_collision:
    /* Wait for the next coordinated order instead of executing a visible
       left/right random spin at every obstacle. Only replan periodically. */
    inc byte ptr [enemy_blocked+bx]
    test byte ptr [game_tick],3
    jnz enemy_pixel_wait
    call choose_enemy_turn
enemy_pixel_wait:
    ret

/* Probe a shell's center at DL/DH world pixels.
 * AL 0=empty/forest/water/ice/absent brick fragment, 1=brick,
 * 2=steel, 3=HQ, 4=outside. SI points to the map entry for 1..3.
 * projectile_bit is one of 1,2,4,8 for a specific 8x6 brick quadrant.
 */
projectile_probe:
    push bx
    push cx
    cmp dl, 255
    jae projectile_outside
    cmp dh, 192
    jae projectile_outside
    mov [probe_x_original], dl
    mov al, dl
    shr al, 1
    shr al, 1
    shr al, 1
    shr al, 1
    mov [probe_col], al
    mov al, dh
    xor ah, ah
    mov bl, 12
    div bl
    mov [probe_row], al
    mov [probe_yrem], ah
    mov dl, [probe_col]
    mov dh, [probe_row]
    call get_tile
    cmp al, '#'
    jne projectile_not_brick
    mov bl, 1
    test byte ptr [probe_x_original], 8
    jz projectile_probe_left
    shl bl, 1
projectile_probe_left:
    cmp byte ptr [probe_yrem], 6
    jb projectile_probe_top
    shl bl, 1
    shl bl, 1
projectile_probe_top:
    mov [projectile_bit], bl
    push si
    sub si, offset level_data
    test [brick_masks+si], bl
    pop si
    jz projectile_empty
    mov al, 1
    jmp projectile_done
projectile_not_brick:
    cmp al, 'T'
    je projectile_steel
    cmp al, 'B'
    je projectile_hq
projectile_empty:
    xor al, al
    jmp projectile_done
projectile_steel:
    mov al, 2
    jmp projectile_done
projectile_hq:
    mov al, 3
    jmp projectile_done
projectile_outside:
    mov al, 4
projectile_done:
    pop cx
    pop bx
    ret

/* Hit precisely one 8x6 brick quadrant, allowing passage after removal. */
chip_brick_pixel:
    push ax
    push bx
    push dx
    push si
    sub si, offset level_data
    mov al, [brick_masks+si]
    mov bl, [projectile_bit]
    not bl
    and al, bl
    mov [brick_masks+si], al
    test al, al
    jnz chip_brick_dirty
    mov byte ptr [level_data+si], '.'
    mov byte ptr [route_dirty], 1
chip_brick_dirty:
    mov dl, [probe_col]
    mov dh, [probe_row]
    call draw_cell
    pop si
    pop dx
    pop bx
    pop ax
    ret

/* Single bounded explosion with four animation frames, at most one FX actor.
 * Input DL/DH = impact position; must be in 0..192 / 0..144.
 * Uses masked sprites, so existing CGA background cells survive intact.
 */
spawn_explosion:
    push ax
    cmp dl, 240
    jbe 1f
    mov dl, 240
1:
    cmp dh, 180
    jbe 1f
    mov dh, 180
1:
    mov [explosion_x], dl
    mov [explosion_y], dh
    mov byte ptr [explosion_ticks], 8
    pop ax
    ret

tick_explosion:
    cmp byte ptr [explosion_ticks], 0
    je tick_explosion_done
    dec byte ptr [explosion_ticks]
tick_explosion_done:
    ret

/* Bullet center is at sprite top-left + (8,6); 3px x or 3px y per tick.
 * The step is applied one pixel at a time so a thin brick fragment cannot
 * be jumped over. Moves 3 pixels per game tick; no floating point.
 */
advance_bullet_smooth:
    cmp byte ptr [bullet_active], 0
    jne 1f
    jmp smooth_bullet_done
1:
    mov byte ptr [bullet_substeps], 3
smooth_bullet_substep:
    mov dl, [bullet_px]
    mov dh, [bullet_py]
    mov al, [bullet_dir]
    call step_pixel
    jnc 1f
    jmp smooth_bullet_out
1:
    mov [bullet_px], dl
    mov [bullet_py], dh
    add dl, 8
    add dh, 6
    call projectile_probe
    cmp al, 0
    je 1f
    cmp byte ptr [super_bullet_active],0
    jne 9f
    jmp smooth_bullet_terrain
9:
    call super23_terrain
1:
    /* Hit enemy shell within 3 pixels of both axes. */
    xor bx, bx
smooth_bullet_vs_shot:
    cmp byte ptr [shot_active+bx], 0
    je smooth_bullet_next_shot
    mov al, [bullet_px]
    sub al, [shot_px+bx]
    add al, 3
    cmp al, 6
    ja smooth_bullet_next_shot
    mov al, [bullet_py]
    sub al, [shot_py+bx]
    add al, 3
    cmp al, 6
    ja smooth_bullet_next_shot
    mov byte ptr [shot_active+bx], 0
    cmp byte ptr [super_bullet_active],0
    jne smooth_bullet_next_shot
    jmp smooth_bullet_out
smooth_bullet_next_shot:
    inc bx
    cmp bx, 7
    jb smooth_bullet_vs_shot
    /* Hit an enemy tank, center point inside rectangle. */
    xor bx, bx
smooth_bullet_enemy_check:
    cmp byte ptr [enemy_active+bx], 0
    jne 9f
    jmp smooth_bullet_enemy_next
9:
    mov al, [bullet_px]
    add al, 8
    sub al, [enemy_px+bx]
    add al, 2           /* includes both tread edges */
    cmp al, 20
    jb 9f
    jmp smooth_bullet_enemy_next
9:
    mov al, [bullet_py]
    add al, 6
    sub al, [enemy_py+bx]
    add al, 2
    cmp al, 16
    jb 9f
    jmp smooth_bullet_enemy_next
9:
    cmp byte ptr [enemy_hp+bx], 1
    jbe smooth_enemy_destroyed
    /* Only a true tread-edge strike damages mobility. A durable tank
       keeps fighting, but moves at half speed and gets black tread dots. */
    mov al,[bullet_px]
    add al,8
    sub al,[enemy_px+bx]
    cmp al,5
    jb smooth_enemy_track_hit
    cmp al,11
    jbe smooth_enemy_track_ok
smooth_enemy_track_hit:
    mov byte ptr [enemy_track_damage+bx],1
smooth_enemy_track_ok:
    dec byte ptr [enemy_hp+bx]
    cmp byte ptr [super_bullet_active],0
    jne smooth_bullet_enemy_next
    jmp smooth_bullet_impact
smooth_enemy_destroyed:
    mov byte ptr [enemy_active+bx], 0
    mov byte ptr [shot_active+bx], 0
    inc byte ptr [enemy_killed]
    push bx
    call maybe_drop_bonus
    pop bx
    xor ax, ax
    mov al, [enemy_type+bx]
    push bx
    xor ah, ah
    mov bl, al
    inc byte ptr [kills_by_type+bx]
    pop bx
    inc al
    mov cl, 100
    mul cl
    add [score], ax
    call draw_hud
    cmp byte ptr [super_bullet_active],0
    jne smooth_bullet_enemy_next
    jmp smooth_bullet_impact
smooth_bullet_enemy_next:
    inc bx
    cmp bx, 4
    jae 9f
    jmp smooth_bullet_enemy_check
9:
    dec byte ptr [bullet_substeps]
    jz 1f
    jmp smooth_bullet_substep
1:
smooth_bullet_done:
    ret
smooth_bullet_terrain:
    cmp al, 1
    jne smooth_bullet_not_brick
    call chip_brick_pixel
    jmp smooth_bullet_impact
smooth_bullet_not_brick:
    cmp al, 2
    jne smooth_bullet_not_steel
    cmp byte ptr [player_upgrade], 3
    jb smooth_bullet_impact
    mov byte ptr [si], '.'
    mov dl, [probe_col]
    mov dh, [probe_row]
    call draw_cell
    jmp smooth_bullet_impact
smooth_bullet_not_steel:
    cmp al, 3
    jne smooth_bullet_out
    cmp byte ptr [hq_shield], 0
    jne smooth_bullet_impact
    mov byte ptr [game_state], 2
smooth_bullet_impact:
    mov dl, [bullet_px]
    mov dh, [bullet_py]
    call spawn_explosion
    mov ax, 2100
    call sound_play
smooth_bullet_out:
    mov byte ptr [bullet_active], 0
    mov byte ptr [super_bullet_active],0
    ret

update_enemy_shots_smooth:
    xor bx, bx
smooth_shot_loop:
    cmp byte ptr [shot_active+bx], 0
    je smooth_shot_next
    push bx
    call advance_enemy_shot_smooth
    pop bx
smooth_shot_next:
    inc bx
    cmp bx, 7
    jb smooth_shot_loop
    ret
advance_enemy_shot_smooth:
    /* Projectile may track P1 while enemy homing bonus is active. */
    call enemy23_home
    mov byte ptr [shot_substeps], 2
smooth_shot_substep:
    mov dl, [shot_px+bx]
    mov dh, [shot_py+bx]
    mov al, [shot_dir+bx]
    call step_pixel
    jnc 1f
    jmp smooth_shot_out
1:
    mov [shot_px+bx], dl
    mov [shot_py+bx], dh
    add dl, 8
    add dh, 6
    call projectile_probe
    cmp al, 0
    je 1f
    cmp byte ptr [shot_super+bx],0
    jne 9f
    jmp smooth_shot_terrain
9:
    push bx
    call super23_terrain
    pop bx
1:
    /* Bullet-vs-bullet suppression */
    cmp byte ptr [bullet_active], 0
    je smooth_shot_no_bullet
    mov al, [bullet_px]
    sub al, [shot_px+bx]
    add al, 3
    cmp al, 6
    ja smooth_shot_no_bullet
    mov al, [bullet_py]
    sub al, [shot_py+bx]
    add al, 3
    cmp al, 6
    ja smooth_shot_no_bullet
    mov byte ptr [bullet_active], 0
    cmp byte ptr [shot_super+bx],0
    jne smooth_shot_no_bullet
    jmp smooth_shot_out
smooth_shot_no_bullet:
    call shot_hits_other_enemy
    jnc smooth_shot_no_friend
    cmp byte ptr [shot_super+bx],0
    jne smooth_shot_no_friend
    jmp smooth_shot_out
smooth_shot_no_friend:
    cmp byte ptr [coop_mode],0
    je smooth_p1_alive
    cmp byte ptr [lives],0
    je smooth_shot_no_player
smooth_p1_alive:
    mov al, [shot_px+bx]
    add al, 8
    sub al, [player_px]
    cmp al, 16
    jae smooth_shot_no_player
    mov al, [shot_py+bx]
    add al, 6
    sub al, [player_py]
    cmp al, 12
    jae smooth_shot_no_player
    cmp byte ptr [player_shield], 0
    je 1f
    jmp smooth_shot_out
1:
    dec byte ptr [lives]
    cmp byte ptr [lives], 0
    je smooth_player_dead
    mov byte ptr [player_px], 112
    mov byte ptr [player_py], 168
    mov byte ptr [player_col], 7
    mov byte ptr [player_row], 14
    mov byte ptr [player_dir], 0
    mov byte ptr [player_shield], 60
    call draw_hud
    cmp byte ptr [shot_super+bx],0
    jne smooth_shot_no_player
    jmp smooth_shot_out
smooth_player_dead:
    cmp byte ptr [coop_mode],0
    je smooth_p1_game_over
    cmp byte ptr [coop_lives],0
    je smooth_p1_game_over
    jmp smooth_shot_out
smooth_p1_game_over:
    mov byte ptr [game_state], 2
    jmp smooth_shot_out
smooth_shot_no_player:
    /* Ally is an independent target: enemy shots can destroy it. */
    cmp word ptr [ally_ticks],0
    je smooth_shot_no_ally
    mov al,[shot_px+bx]
    sub al,[ally_px]
    add al,8
    cmp al,16
    jae smooth_shot_no_ally
    mov al,[shot_py+bx]
    sub al,[ally_py]
    add al,6
    cmp al,12
    jae smooth_shot_no_ally
    cmp byte ptr [ally_shield],0
    jne smooth_shot_out
    cmp byte ptr [coop_mode],0
    je smooth_shot_ai_ally_hit
    /* A 2P hit consumes ONLY their own reserve. Never respawn AI. */
    cmp byte ptr [coop_lives],0
    je smooth_shot_out
    call coop25_hit_p2
    jmp smooth_shot_p2_fx
smooth_shot_ai_ally_hit:
    mov word ptr [ally_ticks],0
smooth_shot_p2_fx:
    mov dl,[ally_px]
    mov dh,[ally_py]
    call spawn_explosion
    jmp smooth_shot_out
smooth_shot_no_ally:
    dec byte ptr [shot_substeps]
    jz 1f
    jmp smooth_shot_substep
1:
    ret
smooth_shot_terrain:
    cmp al, 1
    jne smooth_shot_not_brick
    call chip_brick_pixel
    jmp smooth_shot_impact
smooth_shot_not_brick:
    cmp al, 2
    je smooth_shot_impact
    cmp al, 3
    jne smooth_shot_out
    cmp byte ptr [hq_shield], 0
    jne smooth_shot_impact
    mov byte ptr [game_state], 2
smooth_shot_impact:
    mov dl, [shot_px+bx]
    mov dh, [shot_py+bx]
    call spawn_explosion
    mov ax, 2400
    call sound_play
smooth_shot_out:
    mov byte ptr [shot_active+bx], 0
    mov byte ptr [shot_super+bx],0
    ret

/* All enemy shells are live projectiles, including against OTHER enemies.
 * BX = shooter slot; exclude that tank to prevent self damage.
 * Carry set on hit. Friendly kills count toward wave clearance, but the player
 * gets neither points nor a bonus for enemies destroying one another.
 */
shot_hits_other_enemy:
    push ax
    push si
    push dx
    xor si, si
friendly_target_loop:
    mov al,[shot_owner+bx]
    xor ah,ah
    cmp si,ax
    je friendly_target_next
    cmp byte ptr [enemy_active+si], 0
    je friendly_target_next
    mov al, [shot_px+bx]
    add al, 8
    sub al, [enemy_px+si]
    cmp al, 16
    jae friendly_target_next
    mov al, [shot_py+bx]
    add al, 6
    sub al, [enemy_py+si]
    cmp al, 12
    jae friendly_target_next
    /* A stray shot can harm a teammate, despite safe-fire suppression.
       Destroyed friendlies count toward 20 enemies, but do not score for P1. */
friendly_target_hit:
    cmp byte ptr [enemy_hp+si],1
    jbe friendly_target_destroyed
    mov al,[shot_px+bx]
    add al,8
    sub al,[enemy_px+si]
    cmp al,5
    jb friendly_tread_damaged
    cmp al,11
    jbe friendly_tread_ok
friendly_tread_damaged:
    mov byte ptr [enemy_track_damage+si],1
friendly_tread_ok:
    dec byte ptr [enemy_hp+si]
    jmp friendly_target_fx
friendly_target_destroyed:
    mov byte ptr [enemy_active+si],0
    mov byte ptr [shot_active+si],0
    inc byte ptr [enemy_killed]
    push bx
    mov bx,si
    call maybe_drop_bonus
    pop bx
    call draw_hud
friendly_target_fx:
    mov dl, [shot_px+bx]
    mov dh, [shot_py+bx]
    call spawn_explosion
    mov ax, 2600
    call sound_play
    stc
    jmp friendly_target_done
friendly_target_next:
    inc si
    cmp si, 4
    jae 9f
    jmp friendly_target_loop
9:
    clc
friendly_target_done:
    pop dx
    pop si
    pop ax
    ret

/* ========= CGA smooth engine (8086-compatible, no offscreen buffer) =========
 * Sprite x,y are world pixels relative to the 208x156 field at x32,y16.
 * The masked 5-byte-wide CGA sprites allow every horizontal pixel phase.
 * A dirty-cell pass restores the old actors before compositing new ones.
 */

/* Keyboard IRQ1: track make/break scancodes, including held movement keys.
 * Uses XT 8259 EOI and keyboard port-61 ACK; restores old INT09 on exit.
 * No DOS/BIOS calls or non-reentrant game logic inside the ISR.
 */
install_keyboard:
    push ax
    push bx
    push dx
    push es
    mov ax, 0x3509
    int 0x21
    mov [old_int9_off], bx
    mov [old_int9_seg], es
    mov dx, offset keyboard_irq
    mov ax, 0x2509
    int 0x21
    mov byte ptr [keyboard_installed], 1
    pop es
    pop dx
    pop bx
    pop ax
    ret
restore_keyboard:
    cmp byte ptr [keyboard_installed], 0
    je keyboard_restored
    push ax
    push dx
    push ds
    mov dx, [old_int9_off]
    mov ax, [old_int9_seg]
    mov ds, ax
    mov ax, 0x2509
    int 0x21
    pop ds
    mov byte ptr [keyboard_installed], 0
    pop dx
    pop ax
keyboard_restored:
    ret

keyboard_irq:
    push ax
    push bx
    push dx
    push ds
    push cs
    pop ds
    in al, 0x60
    mov bl, al
    cmp bl, 0xe0
    jne 1f
    jmp irq_ack
1:
    and al, 0x7f
    xor ah, ah
    /* P2 has dedicated W/A/S/D + either Ctrl scancodes.
       These must NOT change P1's AUTO/MAN mode. */
    cmp al,0x11
    jne 1f
    jmp irq_p2_up
1:
    cmp al,0x20
    jne 1f
    jmp irq_p2_right
1:
    cmp al,0x1f
    jne 1f
    jmp irq_p2_down
1:
    cmp al,0x1e
    jne 1f
    jmp irq_p2_left
1:
    cmp al,0x1d
    jne 1f
    jmp irq_p2_fire
1:
    cmp al, 0x48
    jne 1f
    jmp irq_up
1:
    cmp al, 0x4d
    jne 1f
    jmp irq_right
1:
    cmp al, 0x50
    jne 1f
    jmp irq_down
1:
    cmp al, 0x4b
    jne 1f
    jmp irq_left
1:
    cmp al, 0x39
    jne 1f
    jmp irq_fire
1:
    test bl, 0x80
    jz irq_is_make
    jmp irq_ack
irq_is_make:
    cmp al, 0x01
    jne irq_not_esc
    or byte ptr [pending_commands], 1
irq_not_esc:
    cmp al, 0x13
    jne irq_not_restart
    or byte ptr [pending_commands], 2
irq_not_restart:
    cmp al, 0x19
    jne irq_not_pause
    or byte ptr [pending_commands], 4
irq_not_pause:
    /* Stage-switch keys are only acted on while paused or at results. */
    cmp al, 0x49
    jne irq_no_pgup
    or byte ptr [pending_commands], 32
    jmp irq_ack
irq_no_pgup:
    cmp al, 0x51
    jne irq_no_pgdn
    or byte ptr [pending_commands], 64
    jmp irq_ack
irq_no_pgdn:
    cmp al,0x2f              /* V = call attacking AUTO companion */
    jne irq_not_ally
    or byte ptr [ally_call_pending],1
    jmp irq_ack
irq_not_ally:
    cmp al, 0x2e             /* C: cycle CGA palette */
    jne irq_not_palette
    or byte ptr [pending_commands], 128
    jmp irq_ack
irq_not_palette:
    cmp al, 0x0f             /* TAB toggles autopilot; A stays WASD-left */
    jne irq_not_auto
    mov byte ptr [auto_toggle_pending], 1
    jmp irq_ack
irq_not_auto:
    cmp al, 0x32
    jne irq_ack
    or byte ptr [pending_commands], 8
    jmp irq_ack
irq_p2_up:
    mov ah,1
    jmp irq_p2_record
irq_p2_right:
    mov ah,2
    jmp irq_p2_record
irq_p2_down:
    mov ah,4
    jmp irq_p2_record
irq_p2_left:
    mov ah,8
    jmp irq_p2_record
irq_p2_fire:
    mov ah,16
irq_p2_record:
    call coop24_key_event
    jmp irq_ack
irq_up:
    mov ah, 1
    jmp irq_set_held
irq_right:
    mov ah, 2
    jmp irq_set_held
irq_down:
    mov ah, 4
    jmp irq_set_held
irq_left:
    mov ah, 8
    jmp irq_set_held
irq_fire:
    mov ah, 16
    test bl, 0x80
    jnz irq_set_held
    or byte ptr [pending_commands], 16
irq_set_held:
    call manual_key_event
    jmp irq_ack
/* AH key mask, BL make/break scancode; no I/O; also used by /TEST. */
manual_key_event:
    /* Physical keys and AI commands never share state. The old takeover
       ORed a human key into the autopilot's last LEFT bit. */
    push ax
    test bl, 0x80
    jnz manual_key_released
    or byte ptr [manual_keys], ah
    mov byte ptr [auto_mode], 0
    mov al, [manual_keys]
    mov [held_keys], al
    jmp manual_key_done
manual_key_released:
    not ah
    and byte ptr [manual_keys], ah
    cmp byte ptr [auto_mode], 0
    jne manual_key_done
    mov al, [manual_keys]
    mov [held_keys], al
manual_key_done:
    pop ax
    ret
irq_ack:
    in al, 0x61
    mov dl, al
    or al, 0x80
    out 0x61, al
    mov al, dl
    out 0x61, al
    mov al, 0x20
    out 0x20, al
    pop ds
    pop dx
    pop bx
    pop ax
    iret

poll_controls:
    pushf
    cli
    mov al, [pending_commands]
    mov byte ptr [pending_commands], 0
    mov ah, [auto_toggle_pending]
    mov byte ptr [auto_toggle_pending], 0
    mov dl,[ally_call_pending]
    mov byte ptr [ally_call_pending],0
    popf
    /* IRQ only flags a join; actual sprite spawning occurs outside IRQ. */
    cmp byte ptr [coop_join_pending],0
    je controls_no_coop_join
    mov byte ptr [coop_join_pending],0
    push ax
    push dx
    call coop24_join
    pop dx
    pop ax
controls_no_coop_join:
    test dl,1
    jz controls_no_ally_call
    call ally20_try_call
controls_no_ally_call:
    test ah, 1
    jz controls_no_auto_toggle
    cmp byte ptr [coop_mode],0
    jne controls_no_auto_toggle
    xor byte ptr [auto_mode],1
    mov byte ptr [held_keys],0
    mov byte ptr [manual_keys],0
    call draw_mode_indicator
controls_no_auto_toggle:
    test al, 1
    jz controls_not_exit
    jmp exit_game
controls_not_exit:
    test al, 2
    jz controls_not_restart
    call do_restart
    ret
controls_not_restart:
    mov bl, al
    test bl, 128
    jz controls_no_palette
    call cycle_cga_palette
controls_no_palette:
    test bl, 8
    jz controls_not_mute
    xor byte ptr [sound_muted], 1
    call sound_stop
controls_not_mute:
    test bl, 4
    jz controls_not_pause
    cmp byte ptr [game_state], 3
    jne controls_pause_now
    mov byte ptr [game_state], 0
    call refresh_screen
    ret
controls_pause_now:
    cmp byte ptr [game_state], 0
    jne controls_not_pause
    mov byte ptr [game_state], 3
    call pause_hud
controls_not_pause:
    /* Stage QA: Page Up / Down on PAUSED, STAGE CLEAR, or GAME OVER. */
    test bl, 96
    jz controls_no_stage_jump
    cmp byte ptr [game_state], 3
    je controls_stage_jump
    cmp byte ptr [game_state], 1
    je controls_stage_jump
    cmp byte ptr [game_state], 2
    jne controls_no_stage_jump
controls_stage_jump:
    test bl, 32
    jz controls_stage_back
    inc byte ptr [stage]
    cmp byte ptr [stage], 35
    jbe controls_stage_apply
    mov byte ptr [stage], 1
    jmp controls_stage_apply
controls_stage_back:
    dec byte ptr [stage]
    jnz controls_stage_apply
    mov byte ptr [stage], 35
controls_stage_apply:
    call load_stage
    call refresh_screen
    ret
controls_no_stage_jump:
    test bl, 16
    jz controls_done
    cmp byte ptr [game_state], 1
    jne controls_fire
    inc byte ptr [stage]
    cmp byte ptr [stage], 35
    jbe controls_next_stage
    mov byte ptr [stage], 1
controls_next_stage:
    call load_stage
    call refresh_screen
    ret
controls_fire:
    cmp byte ptr [game_state], 0
    jne controls_done
    call do_fire
controls_done:
    ret

/* CGA hardware register 3D9h: four legal RGBI palette/intensity pairs.
 * No INT10 mode switch: video RAM is unchanged and cycling is constant time.
 * Classic CGA mode 4, background black; no undocumented colour tricks.
 */
cycle_cga_palette:
    inc byte ptr [palette_index]
    and byte ptr [palette_index], 3
apply_cga_palette:
    push ax
    push bx
    push dx
    xor bx, bx
    mov bl, [palette_index]
    mov al, [cga_palettes+bx]
    mov dx, 0x3d9
    out dx, al
    pop dx
    pop bx
    pop ax
    ret

/* One movement pixel; input AL=direction. Caller loops twice per game tick.
 * AABB movement is checked against four world corners and other tanks.
 */
move_player_smooth:
    cmp byte ptr [coop_mode],0
    je move_player_live
    cmp byte ptr [lives],0
    je player_smooth_done
move_player_live:
    /* An enemy that steals the clock slows P1 for ~6.6 seconds. */
    cmp byte ptr [player_slow_ticks],0
    je move_player_not_slow
    test byte ptr [game_tick],1
    jz move_player_not_slow
    ret
move_player_not_slow:
    cmp byte ptr [game_state], 0
    jne player_smooth_done
    mov al, [held_keys]
    test al, 1
    jnz player_smooth_up
    test al, 2
    jnz player_smooth_right
    test al, 4
    jnz player_smooth_down
    test al, 8
    jnz player_smooth_left
    ret
player_smooth_up:
    xor al, al
    jmp player_smooth_selected
player_smooth_right:
    mov al, 1
    jmp player_smooth_selected
player_smooth_down:
    mov al, 2
    jmp player_smooth_selected
player_smooth_left:
    mov al, 3
player_smooth_selected:
    mov [player_dir], al
    push ax
    call player_move_pixel
    pop ax
    call player_move_pixel
    /* Laser mobility buff: 3 px/tick instead of 2, collisions retained. */
    cmp byte ptr [laser_ticks],0
    je player_smooth_done
    call player_move_pixel
player_smooth_done:
    ret

slide_player_smooth:
    cmp byte ptr [slide_ticks], 0
    je slide_smooth_done
    test byte ptr [held_keys], 15
    jnz slide_smooth_done
    test byte ptr [game_tick], 1
    jnz slide_smooth_done
    mov al, [player_dir]
    call player_move_pixel
slide_smooth_done:
    ret

player_move_pixel:
    mov dl, [player_px]
    mov dh, [player_py]
    call step_pixel
    jc player_pixel_done
    mov [candidate_x], dl
    mov [candidate_y], dh
    call rect_passable
    jc player_pixel_done
    /* AABB vs enemies, 16x12; touching edges is allowed. */
    xor bx, bx
player_pixel_check_enemies:
    cmp byte ptr [enemy_active+bx], 0
    je player_pixel_next_enemy
    mov al, [candidate_x]
    sub al, [enemy_px+bx]
    cmp al, 16
    jb player_pixel_check_y
    cmp al, 241
    jae player_pixel_check_y
    jmp player_pixel_next_enemy
player_pixel_check_y:
    mov al, [candidate_y]
    sub al, [enemy_py+bx]
    cmp al, 12
    jb player_pixel_done
    cmp al, 245
    jae player_pixel_done
player_pixel_next_enemy:
    inc bx
    cmp bx, 4
    jb player_pixel_check_enemies
    cmp byte ptr [coop_mode],0
    je player_pixel_no_p2
    cmp byte ptr [coop_lives],0
    je player_pixel_no_p2
    mov al,[candidate_x]
    sub al,[ally_px]
    add al,15
    cmp al,30
    ja player_pixel_no_p2
    mov al,[candidate_y]
    sub al,[ally_py]
    add al,11
    cmp al,22
    jbe player_pixel_done
player_pixel_no_p2:
    mov al, [candidate_x]
    mov [player_px], al
    mov al, [candidate_y]
    mov [player_py], al
    /* Keep coarse grid coordinates for terrain, bonus and legacy tests. */
    call sync_player_tile
player_pixel_done:
    ret
sync_player_tile:
    push ax
    push bx
    push dx
    mov al, [player_px]
    shr al, 1
    shr al, 1
    shr al, 1
    shr al, 1
    mov [player_col], al
    mov dl, al
    xor ax, ax
    mov al, [player_py]
    mov bl, 12
    div bl
    mov [player_row], al
    mov dh, al
    call player_enter_tile
    pop dx
    pop bx
    pop ax
    ret

/* AL direction, DL/DH pixel. CF=1 when leaving the battlefield. */
step_pixel:
    cmp al, 0
    jne step_pixel_not_up
    test dh, dh
    jz step_pixel_off
    dec dh
    clc
    ret
step_pixel_not_up:
    cmp al, 1
    jne step_pixel_not_right
    cmp dl, 240
    jae step_pixel_off
    inc dl
    clc
    ret
step_pixel_not_right:
    cmp al, 2
    jne step_pixel_not_down
    cmp dh, 180
    jae step_pixel_off
    inc dh
    clc
    ret
step_pixel_not_down:
    test dl, dl
    jz step_pixel_off
    dec dl
    clc
    ret
step_pixel_off:
    stc
    ret

/* DL/DH are pixel coordinates; determine collision at a single point.
 * CF=1 for nonpassable parts of brick/steel/water/HQ, or outside world.
 */
pixel_is_blocked:
    push ax
    push bx
    push cx
    push si
    cmp dl, 255
    jae pixel_blocked
    cmp dh, 192
    jae pixel_blocked
    mov al, dl
    shr al, 1
    shr al, 1
    shr al, 1
    shr al, 1
    mov [probe_col], al
    /* Lookup y/12 and y%12: DIV is especially costly on an 8088. */
    xor bx,bx
    mov bl,dh
    mov al,[pixel_y_tile_lookup+bx]
    mov ah,al
    and ah,15
    mov [probe_yrem],ah
    shr al,1
    shr al,1
    shr al,1
    shr al,1
    mov [probe_row],al
    mov dl,[probe_col]
    mov dh, [probe_row]
    call get_tile
    cmp al, '.'
    je pixel_open
    cmp al, 'F'
    je pixel_open
    cmp al, 'I'
    je pixel_open
    cmp al, '#'
    jne pixel_blocked
    sub si, offset level_data
    mov al, [brick_masks+si]
    mov bl, 1
    mov cl, [probe_x_original]
    test cl, 8
    jz pixel_brick_left
    shl bl, 1
pixel_brick_left:
    cmp byte ptr [probe_yrem], 6
    jb pixel_brick_top
    shl bl, 1
    shl bl, 1
pixel_brick_top:
    test al, bl
    jnz pixel_blocked
pixel_open:
    clc
    jmp pixel_probe_done
pixel_blocked:
    stc
pixel_probe_done:
    pop si
    pop cx
    pop bx
    pop ax
    ret

/* The sprite's collision hull is 12x10, with small side clearance.
 * Input DL/DH = future pixel top-left. Four tests across both edges.
 */
rect_passable:
    push dx
    add dl, 2
    inc dh
    mov [probe_x_original], dl
    call pixel_is_blocked
    jc rect_failed
    pop dx
    push dx
    add dl, 13
    inc dh
    mov [probe_x_original], dl
    call pixel_is_blocked
    jc rect_failed
    pop dx
    push dx
    add dl, 2
    add dh, 10
    mov [probe_x_original], dl
    call pixel_is_blocked
    jc rect_failed
    pop dx
    push dx
    add dl, 13
    add dh, 10
    mov [probe_x_original], dl
    call pixel_is_blocked
    jc rect_failed
    pop dx
    clc
    ret
rect_failed:
    pop dx
    stc
    ret

/* Return the current list of pixel-coordinates to dirty after the last frame.
 * Dirty tiles preserve background and allow sprites to move at any pixel x,y.
 */
mark_dirty_rect:
    push ax
    push bx
    push dx
    push si
    mov al,dl
    shr al,1
    shr al,1
    shr al,1
    shr al,1
    mov [rect_x0],al
    mov al,dl
    add al,15
    shr al,1
    shr al,1
    shr al,1
    shr al,1
    mov [rect_x1],al
    xor bx,bx
    mov bl,dh
    mov al,[pixel_y_tile_lookup+bx]
    shr al,1
    shr al,1
    shr al,1
    shr al,1
    mov [rect_y0],al
    add bl,11
    mov al,[pixel_y_tile_lookup+bx]
    shr al,1
    shr al,1
    shr al,1
    shr al,1
    mov [rect_y1],al
    mov dh,[rect_y0]
mark_rect_row:
    /* Compute row*16 once, then mark only the 1–2 touched columns. */
    xor bx,bx
    mov bl,dh
    shl bx,1
    shl bx,1
    shl bx,1
    shl bx,1
    mov dl,[rect_x0]
mark_rect_col:
    cmp dl,16
    jae mark_rect_next_col
    cmp dh,16
    jae mark_rect_next_col
    mov si,bx
    xor ah,ah
    mov al,dl
    add si,ax
    mov byte ptr [dirty_tiles+si],1
    mov byte ptr [upload_tiles+si],1
mark_rect_next_col:
    inc dl
    cmp dl,[rect_x1]
    jbe mark_rect_col
    inc dh
    cmp dh,[rect_y1]
    jbe mark_rect_row
    pop si
    pop dx
    pop bx
    pop ax
    ret

mark_old_sprites:
    call bomber25_mark_old
    cmp byte ptr [paint_player_valid], 0
    je old_player_done
    mov dl, [paint_player_x]
    mov dh, [paint_player_y]
    call mark_dirty_rect
old_player_done:
    mov byte ptr [paint_player_valid], 0
    cmp byte ptr [paint_pong_valid],0
    je old_pong_done
    mov dl,[paint_pong_x]
    mov dh,[paint_pong_y]
    call mark_dirty_rect
old_pong_done:
    mov byte ptr [paint_pong_valid],0
    cmp byte ptr [paint_bullet_valid], 0
    je old_bullet_done
    mov dl, [paint_bullet_x]
    mov dh, [paint_bullet_y]
    call mark_dirty_rect
old_bullet_done:
    mov byte ptr [paint_bullet_valid], 0
    xor bx,bx
old_extra_loop:
    cmp byte ptr [paint_extra_valid+bx],0
    je old_extra_next
    mov dl,[paint_extra_x+bx]
    mov dh,[paint_extra_y+bx]
    push bx
    call mark_dirty_rect
    pop bx
old_extra_next:
    mov byte ptr [paint_extra_valid+bx],0
    inc bx
    cmp bx,3
    jb old_extra_loop
    cmp byte ptr [paint_ally_valid],0
    je old_ally_done
    mov dl,[paint_ally_x]
    mov dh,[paint_ally_y]
    call mark_dirty_rect
old_ally_done:
    mov byte ptr [paint_ally_valid],0
    xor bx,bx
old_grenade_loop:
    cmp byte ptr [paint_grenade_valid+bx],0
    je old_grenade_next
    mov dl,[paint_grenade_x+bx]
    mov dh,[paint_grenade_y+bx]
    push bx
    call mark_dirty_rect
    pop bx
old_grenade_next:
    mov byte ptr [paint_grenade_valid+bx],0
    inc bx
    cmp bx,4
    jb old_grenade_loop
    cmp byte ptr [paint_bonus_valid], 0
    je old_bonus_done
    mov dl, [paint_bonus_x]
    mov dh, [paint_bonus_y]
    call mark_dirty_rect
old_bonus_done:
    mov byte ptr [paint_bonus_valid], 0
    cmp byte ptr [paint_explosion_valid], 0
    je old_explosion_done
    mov dl, [paint_explosion_x]
    mov dh, [paint_explosion_y]
    call mark_dirty_rect
old_explosion_done:
    mov byte ptr [paint_explosion_valid], 0
    xor bx, bx
old_entities_loop:
    cmp byte ptr [paint_enemy_valid+bx], 0
    je old_enemy_done
    mov dl, [paint_enemy_x+bx]
    mov dh, [paint_enemy_y+bx]
    call mark_dirty_rect
old_enemy_done:
    mov byte ptr [paint_enemy_valid+bx], 0
    cmp byte ptr [paint_shot_valid+bx], 0
    je old_shot_done
    mov dl, [paint_shot_x+bx]
    mov dh, [paint_shot_y+bx]
    call mark_dirty_rect
old_shot_done:
    mov byte ptr [paint_shot_valid+bx], 0
    inc bx
    cmp bx, 4
    jb old_entities_loop
    ret

flush_dirty:
    /* 256 fast byte checks, no 256 get_tile calls per video frame. */
    push ax
    push dx
    push si
    xor si,si
flush_scan:
    cmp byte ptr [dirty_tiles+si],0
    je flush_scan_next
    mov byte ptr [dirty_tiles+si],0
    mov ax,si
    mov dl,al
    and dl,15
    shr ax,1
    shr ax,1
    shr ax,1
    shr ax,1
    mov dh,al
    call draw_static_cell
flush_scan_next:
    inc si
    cmp si,256
    jb flush_scan
    pop si
    pop dx
    pop ax
    ret

/* ===== Anti-flicker shadow composition / tile commits =====
 * 320x200 CGA mode 4: byte(y,x) = (y>>1)*80 + (y&1)*8192 + (x>>2).
 * Static map and actors are first rendered in RAM at frame_seg. Only
 * complete 16x12 tiles then go to B800h, without clearing live actors.
 * When no RAM is available, frame_seg=B800h and this is a no-op.
 */
present_full_field:
    push ax
    push cx
    push di
    mov ax, [frame_seg]
    cmp ax, 0xb800
    je present_all_done
    mov di, offset upload_tiles
    mov al, 1
    mov cx, 256
    rep stosb
    call commit_dirty_tiles
present_all_done:
    pop di
    pop cx
    pop ax
    ret

commit_dirty_tiles:
    push ax
    push dx
    push si
    mov ax,[frame_seg]
    cmp ax,0xb800
    je commit_done
    xor si,si
commit_scan:
    cmp byte ptr [upload_tiles+si],0
    je commit_next
    mov byte ptr [upload_tiles+si],0
    mov ax,si
    mov dl,al
    and dl,15
    shr ax,1
    shr ax,1
    shr ax,1
    shr ax,1
    mov dh,al
    call copy_tile_to_cga
commit_next:
    inc si
    cmp si,256
    jb commit_scan
commit_done:
    pop si
    pop dx
    pop ax
    ret

/* DL/DH = tile col/row, 6 even/odd row pairs x 4 bytes per scanline.
 * DS switches only for the uninterrupted 48-byte transfer; no calls
 * and no interrupts disabled. The keyboard ISR restores DS=CS itself. */
copy_tile_to_cga:
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    push ds
    push es
    xor bx, bx
    mov bl, dh
    shl bx, 1
    mov di, [tile_row_offsets+bx]
    xor bx, bx
    mov bl, dl
    shl bx, 1
    shl bx, 1
    add di, bx
    mov si, di
    mov ax, 0xb800
    mov es, ax
    mov ax, [frame_seg]
    mov ds, ax
    mov cx, 6
copy_tile_pair:
    mov ax, [si]
    mov es:[di], ax
    mov ax, [si+2]
    mov es:[di+2], ax
    mov ax, [si+0x2000]
    mov es:[di+0x2000], ax
    mov ax, [si+0x2002]
    mov es:[di+0x2002], ax
    add si, 80
    add di, 80
    loop copy_tile_pair
    pop es
    pop ds
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

/* SI=smooth sprite asset, DL/DH=world pixel x/y; preserves every register. */
draw_smooth_sprite:
    push bp
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    push es
    mov al, dl
    and al, 3
    mov bl, 120
    mul bl
    add si, ax
    mov [scan_x], dl
    mov al, dh
    mov [scan_y], al
    mov ax, [frame_seg]
    mov es, ax
    /* Every active sprite contributes a freshly composed area. This
       remains dirty for the next frame's background restore. */
    call mark_dirty_rect
    mov bp, 12
smooth_scanline:
    /* Table removes 10 bit-shifts and two branches for every
       row of every masked CGA tank/bullet/explosion sprite. */
    xor bx,bx
    mov bl,[scan_y]
    shl bx,1
    mov di,[cga_scanline_offsets+bx]
    xor bx,bx
    mov bl,[scan_x]
    shr bx,1
    shr bx,1
    add di,bx
    mov cx, 5
smooth_byte:
    mov al, es:[di]
    mov ah, [si]
    not ah
    and al, ah
    or al, [si+5]
    mov es:[di], al
    inc si
    inc di
    loop smooth_byte
    add si, 5
    inc byte ptr [scan_y]
    dec bp
    jnz smooth_scanline
    pop es
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    pop bp
    ret

/* One tiny animated highlight on each physical tread. On a disabled
 * enemy track, the same four points are BLACK damage spots. AL=heading,
 * AH=damage flag, DL/DH=top-left. The active hull already marks dirty.
 * This replaces 3,840 bytes of old 4-phase masked tread sprites. */
draw_track_dots:
    push ax
    push bx
    push cx
    push dx
    mov [track23_mode],ah
    mov bx,ax            /* BL heading, BH damaged flag */
    mov cx,dx            /* CL x, CH y */
    test bl,1
    jnz track23_horizontal
    add dl,2
    add dh,3
    call track23_pixel
    add dl,11
    call track23_pixel
    add dh,5
    call track23_pixel
    sub dl,11
    call track23_pixel
    jmp track23_done
track23_horizontal:
    add dl,3
    add dh,2
    call track23_pixel
    add dh,8
    call track23_pixel
    add dl,8
    call track23_pixel
    sub dh,8
    call track23_pixel
track23_done:
    pop dx
    pop cx
    pop bx
    pop ax
    ret
track23_pixel:
    push ax
    push bx
    push dx
    push di
    push es
    /* Shift one pixel every other frame, but never outside 16x12. */
    mov al,[game_tick]
    and al,1
    add dl,al
    xor ax,ax
    mov al,dh
    shl ax,1
    mov di,ax
    mov di,[cga_scanline_offsets+di]
    xor ax,ax
    mov al,dl
    mov bl,al
    shr al,1
    shr al,1
    xor ah,ah
    add di,ax
    and bl,3
    xor bh,bh
    mov ax,[frame_seg]
    mov es,ax
    mov al,[laser19_masks+bx]
    not al
    and al,es:[di]
    /* No healthy highlights: paint black only on damaged armour. */
    mov es:[di],al
    pop es
    pop di
    pop dx
    pop bx
    pop ax
    ret

/* Called after each simulated tick, and once after switching a stage. */
render_frame:
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    push bp
    call mark_old_sprites
    call flush_dirty
    /* Bonus underneath tanks. */
    cmp byte ptr [bonus_active], 0
    je paint_bonus_done
    xor bx, bx
    mov bl, [bonus_type]
    shl bx, 1
    mov si, [smooth_bonus_ptrs+bx]
    mov al, [bonus_col]
    shl al, 1
    shl al, 1
    shl al, 1
    shl al, 1
    mov dl, al
    mov al, [bonus_row]
    mov cl, 12
    mul cl
    mov dh, al
    mov [paint_bonus_x], dl
    mov [paint_bonus_y], dh
    mov byte ptr [paint_bonus_valid], 1
    call draw_smooth_sprite
    /* Final 1.5 seconds: flash ONLY the right-adjusted frame.  The
       11 distinct pictograms stay visible and usable until collection. */
    cmp byte ptr [bonus_timer],27
    ja paint_bonus_done
    test byte ptr [game_tick],4
    jz paint_bonus_done
    mov si,offset smooth_bonus_frame_erase
    call draw_smooth_sprite
paint_bonus_done:
    /* Four enemy tanks. */
    xor bx, bx
paint_enemy_loop:
    cmp byte ptr [enemy_active+bx], 0
    jne paint_enemy_live
    jmp paint_enemy_next
paint_enemy_live:
    mov dl, [enemy_px+bx]
    mov dh, [enemy_py+bx]
    mov [paint_enemy_x+bx], dl
    mov [paint_enemy_y+bx], dh
    mov byte ptr [paint_enemy_valid+bx], 1
    push bx
    xor cx, cx
    mov cl, [enemy_dir+bx]
    shl cx, 1
    mov si, cx
    cmp byte ptr [enemy_type+bx], 1
    jne paint_enemy_not_fast
    mov si, [smooth_fast_ptrs+si]
    jmp paint_enemy_selected
paint_enemy_not_fast:
    cmp byte ptr [enemy_type+bx], 2
    jne paint_enemy_not_power
    mov si, [smooth_power_ptrs+si]
    jmp paint_enemy_selected
paint_enemy_not_power:
    cmp byte ptr [enemy_type+bx], 3
    jne paint_enemy_standard
    mov si, [smooth_armor_ptrs+si]
    jmp paint_enemy_selected
paint_enemy_standard:
    mov si, [smooth_enemy_ptrs+si]
paint_enemy_selected:
    mov al,[bonus26_flash_owner]
    sub al,2
    cmp al,bl
    jne paint_enemy_color_ready
    cmp byte ptr [bonus25_flash_ticks],0
    je paint_enemy_color_ready
    test byte ptr [bonus25_flash_ticks],2
    jz paint_enemy_color_ready
    mov si,cx
    mov si,[smooth_player_ptrs+si]
paint_enemy_color_ready:
    call draw_smooth_sprite
    /* Black wear only on surviving ARMOUR with an actually damaged tread.
       Healthy enemy tracks and all player tanks retain the original sprite. */
    cmp byte ptr [enemy_type+bx],3
    jne paint_enemy_no_tread_damage
    cmp byte ptr [enemy_track_damage+bx],0
    je paint_enemy_no_tread_damage
    mov dl,[enemy_px+bx]
    mov dh,[enemy_py+bx]
    mov al,[enemy_dir+bx]
    mov ah,1
    call draw_track_dots
paint_enemy_no_tread_damage:
    pop bx
paint_enemy_next:
    inc bx
    cmp bx, 4
    jae paint_enemy_finished
    jmp paint_enemy_loop
paint_enemy_finished:
    /* Attack-oriented allied AUTO tank: same chassis with a bright halo. */
    cmp word ptr [ally_ticks],0
    je paint_ally_done
    mov dl,[ally_px]
    mov dh,[ally_py]
    mov [paint_ally_x],dl
    mov [paint_ally_y],dh
    mov byte ptr [paint_ally_valid],1
    xor bx,bx
    mov bl,[ally_dir]
    shl bx,1
    mov si,[smooth_player_ptrs+bx]
    cmp byte ptr [bonus26_flash_owner],1
    jne paint_ally_color_ready
    cmp byte ptr [bonus25_flash_ticks],0
    je paint_ally_color_ready
    test byte ptr [bonus25_flash_ticks],2
    jz paint_ally_color_ready
    mov si,[smooth_enemy_ptrs+bx]
paint_ally_color_ready:
    call draw_smooth_sprite
    mov al,[gun27_p2]
    mov bl,[ally_dir]
    mov dl,[ally_px]
    mov dh,[ally_py]
    call gun27_draw
    cmp byte ptr [ally_shield],0
    je paint_ally_no_shield
    test byte ptr [game_tick],4
    jnz paint_ally_no_shield
    mov si,offset smooth_shield_outline
    call draw_smooth_sprite
paint_ally_no_shield:
    call ally21_draw_mark
paint_ally_done:
    /* A knocked-out 1P leaves 2P to defend HQ alone. */
    cmp byte ptr [coop_mode],0
    je paint_player_alive
    cmp byte ptr [lives],0
    je paint_player_no_actor
paint_player_alive:
    /* Player's tank. */
    mov dl, [player_px]
    mov dh, [player_py]
    mov [paint_player_x], dl
    mov [paint_player_y], dh
    mov byte ptr [paint_player_valid], 1
    xor bx, bx
    mov bl, [player_dir]
    shl bx, 1
paint_player_normal:
    mov si, [smooth_player_ptrs+bx]
    cmp byte ptr [bonus26_flash_owner],0
    jne paint_player_color_ready
    cmp byte ptr [bonus25_flash_ticks],0
    je paint_player_color_ready
    test byte ptr [bonus25_flash_ticks],2
    jz paint_player_color_ready
    mov si,[smooth_enemy_ptrs+bx] /* brief magenta vs cyan */
paint_player_color_ready:
    call draw_smooth_sprite
    mov al,[gun27_p1]
    mov bl,[player_dir]
    mov dl,[player_px]
    mov dh,[player_py]
    call gun27_draw
    cmp byte ptr [player_shield],0
    je paint_player_no_shield
    test byte ptr [game_tick],4
    jnz paint_player_no_shield
    mov si,offset smooth_shield_outline
    call draw_smooth_sprite
paint_player_no_shield:
    /* Ordinary P1 treads remain part of the unmodified CGA sprite. */
paint_player_no_actor:
    /* Player projectile and up to four enemy projectiles. */
    cmp byte ptr [bullet_active], 0
    je paint_no_bullet
    mov dl, [bullet_px]
    mov dh, [bullet_py]
    mov [paint_bullet_x], dl
    mov [paint_bullet_y], dh
    mov byte ptr [paint_bullet_valid], 1
    mov si, offset smooth_bullet
    cmp byte ptr [super_bullet_active],0
    je paint_primary_normal
    test byte ptr [game_tick],1
    jz paint_primary_bullet
    mov si,offset smooth_enemy_bullet
    jmp paint_primary_bullet
paint_primary_normal:
    cmp byte ptr [homing_ticks],0
    je paint_primary_bullet
    test byte ptr [game_tick],4
    jz paint_primary_bullet
    mov si,offset smooth_enemy_bullet
paint_primary_bullet:
    call draw_smooth_sprite
paint_no_bullet:
    call pong23_paint
    xor bx,bx
paint_extra_loop:
    cmp byte ptr [extra_active+bx],0
    je paint_extra_next
    mov dl,[extra_px+bx]
    mov dh,[extra_py+bx]
    mov [paint_extra_x+bx],dl
    mov [paint_extra_y+bx],dh
    mov byte ptr [paint_extra_valid+bx],1
    mov si,offset smooth_bullet
    cmp byte ptr [extra_homing+bx],0
    je paint_extra_visible
    test byte ptr [game_tick],4
    jz paint_extra_visible
    mov si,offset smooth_enemy_bullet
paint_extra_visible:
    push bx
    call draw_smooth_sprite
    pop bx
paint_extra_next:
    inc bx
    cmp bx,3
    jb paint_extra_loop
    xor bx, bx
paint_shot_loop:
    cmp byte ptr [shot_active+bx], 0
    je paint_next_shot
    mov dl, [shot_px+bx]
    mov dh, [shot_py+bx]
    mov [paint_shot_x+bx], dl
    mov [paint_shot_y+bx], dh
    mov byte ptr [paint_shot_valid+bx], 1
    mov si, offset smooth_enemy_bullet
    cmp byte ptr [shot_super+bx],0
    je paint_enemy_projectile_ready
    test byte ptr [game_tick],1
    jz paint_enemy_projectile_ready
    mov si,offset smooth_bullet
paint_enemy_projectile_ready:
    call draw_smooth_sprite
paint_next_shot:
    inc bx
    cmp bx, 7
    jb paint_shot_loop
    /* One bounded four-phase explosion: debris expands without full-screen redraw. */
    cmp byte ptr [explosion_ticks], 0
    je paint_explosion_done
    mov dl, [explosion_x]
    mov dh, [explosion_y]
    mov [paint_explosion_x], dl
    mov [paint_explosion_y], dh
    mov byte ptr [paint_explosion_valid], 1
    xor ax, ax
    mov al, 8
    sub al, [explosion_ticks]
    shr al, 1
    cmp al, 3
    jbe paint_explosion_valid_frame
    mov al, 3
paint_explosion_valid_frame:
    shl ax, 1
    mov bx, ax
    mov si, [smooth_explosion_ptrs+bx]
    call draw_smooth_sprite
paint_explosion_done:
    call grenade17_fx_paint
    call bomber25_paint
    /* Finish the actor/background composition first. The beam is a
       transient VRAM-only overlay, NEVER written into the RAM shadow.
       Next frame's pending tile upload scrubs it even after expiry. */
    call commit_dirty_tiles
    call laser17_paint
    pop bp
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

/* Pointer tables keep all smooth-sprite variants in the generated assets. */
.section .data
.p2align 1
smooth_player_ptrs: .word smooth_player_up, smooth_player_right, smooth_player_down, smooth_player_left
smooth_enemy_ptrs: .word smooth_enemy_up, smooth_enemy_right, smooth_enemy, smooth_enemy_left
smooth_fast_ptrs: .word smooth_fast_up, smooth_fast_right, smooth_fast_down, smooth_fast_left
smooth_power_ptrs: .word smooth_power_up, smooth_power_right, smooth_power_down, smooth_power_left
smooth_armor_ptrs: .word smooth_armor_up, smooth_armor_right, smooth_armor_down, smooth_armor_left
smooth_bonus_ptrs: .word smooth_bonus_star, smooth_bonus_helmet, smooth_bonus_grenade, smooth_bonus_shovel, smooth_bonus_clock, smooth_bonus_life
    .word smooth_bonus_laser, smooth_bonus_ally, smooth_bonus_triple, smooth_bonus_homing, smooth_bonus_frenzy
    .word smooth_bonus_pong, smooth_bonus_quad, smooth_bonus_super
smooth_explosion_ptrs: .word smooth_explosion_0, smooth_explosion_1, smooth_explosion_2, smooth_explosion_3
.section .text

/* Return AL tile and SI writable address, DL/DH grid 0..15. */
get_tile:
    /* Row*16 via four shifts; avoid 8088 MUL for every tile lookup. */
    xor ax,ax
    mov al,dh
    shl ax,1
    shl ax,1
    shl ax,1
    shl ax,1
    add al,dl
    adc ah,0
    mov si,offset level_data
    add si,ax
    mov al,[si]
    ret

draw_map:
    xor dx, dx
map_row:
    xor dl, dl
map_col:
    push dx
    call draw_static_cell
    pop dx
    inc dl
    cmp dl, 16
    jb map_col
    inc dh
    cmp dh, 16
    jb map_row
    ret

/* Mark tile for redraw at the end of the simulation tick. */
draw_cell:
    push ax
    push si
    push dx
    call get_tile
    sub si, offset level_data
    mov byte ptr [dirty_tiles+si], 1
    mov byte ptr [upload_tiles+si], 1
    pop dx
    pop si
    pop ax
    ret

/* Actual tile bitmap is always background-only. Dynamic entities are drawn
 * separately with a masked pixel blitter to prevent ghosting/overwrites.
 */
draw_static_cell:
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    call get_tile
    mov bx, si
    sub bx, offset level_data  /* preserve true map-cell index */
    mov si, offset sprite_empty
    cmp al, '#'
    jne draw_not_brick
    xor ax, ax
    mov al, [brick_masks+bx]
    shl ax, 1
    mov bx, ax
    mov si, [brick_sprite_ptrs+bx]
    jmp draw_entities
draw_not_brick:
    cmp al, 'T'
    jne draw_not_steel
    mov si, offset sprite_steel
    jmp draw_entities
draw_not_steel:
    cmp al, '~'
    jne draw_not_water
    mov si, offset sprite_water
    jmp draw_entities
draw_not_water:
    cmp al, 'F'
    jne draw_not_forest
    mov si, offset sprite_forest
    jmp draw_entities
draw_not_forest:
    cmp al, 'I'
    jne draw_not_ice
    mov si, offset sprite_ice
    jmp draw_entities
draw_not_ice:
    cmp al, 'B'
    jne draw_entities
    mov si, offset sprite_base
draw_entities:
    call draw_sprite
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

/* CGA 2bpp 16x12 tile renderer: 6 * 8-byte scanline pairs. */
draw_sprite:
    push ax
    push bx
    push cx
    push di
    push si
    push es
    mov ax, [frame_seg]
    mov es, ax
    xor bx, bx
    mov bl, dh
    shl bx, 1
    mov di, [tile_row_offsets+bx]
    xor bx, bx
    mov bl, dl
    shl bx, 1
    shl bx, 1
    add di, bx
    mov cx, 6
sprite_row:
    mov ax, [si]
    mov es:[di], ax
    mov ax, [si+2]
    mov es:[di+2], ax
    mov ax, [si+4]
    mov es:[di+0x2000], ax
    mov ax, [si+6]
    mov es:[di+0x2002], ax
    add si, 8
    add di, 80
    loop sprite_row
    pop es
    pop si
    pop di
    pop cx
    pop bx
    pop ax
    ret

/* The original Battle City used a separate grey right HUD (enemy tank
 * badges, 1P lives, stage flag); score was shown on results after the stage.
 * CGA has no gray in this palette, so we use a white panel and black glyphs.
 * The 16x16 map is drawn at x0..255, compact HUD starts at x256.
 */
draw_sidebar_background:
    push ax
    push bx
    push cx
    push di
    push es
    mov ax, 0xb800
    mov es, ax
    mov ax, 0xffff
    mov di, 64               /* x256 / 4 */
    mov bx, 56               /* 112px high floating HUD at top right */
sidebar_row:
    push di
    mov cx, 8                /* 64px = 16 bytes = 8 words */
    rep stosw
    pop di
    push di
    add di, 0x2000
    mov cx, 8
    rep stosw
    pop di
    add di, 80
    dec bx
    jnz sidebar_row
    pop es
    pop di
    pop cx
    pop bx
    pop ax
    /* Copyright/branding lives on the BLACK lower-right field. */
    call draw_branding
    ret

/* Every 8x8 HUD glyph is 16 bytes packed CGA. DI points to its first
 * even scanline in B800:, 2 bytes wide; SI points to packed pixels.
 */
draw_hud_glyph:
    push ax
    push cx
    push di
    push si
    push es
    mov ax, 0xb800
    mov es, ax
    mov cx, 4
hud_glyph_row:
    mov ax, [si]
    mov es:[di], ax
    mov ax, [si+2]
    mov es:[di+0x2000], ax
    add si, 4
    add di, 80
    loop hud_glyph_row
    pop es
    pop si
    pop di
    pop cx
    pop ax
    ret

/* The 8x8 panel glyphs are normally black on white. Invert both CGA
 * 2-bit planes for WHITE-ON-BLACK brand lettering below the scoreboard. */
draw_hud_glyph_inverted:
    push ax
    push cx
    push di
    push si
    push es
    mov ax,0xb800
    mov es,ax
    mov cx,4
brand_glyph_scan:
    mov ax,[si]
    not ax
    mov es:[di],ax
    mov ax,[si+2]
    not ax
    mov es:[di+0x2000],ax
    add si,4
    add di,80
    loop brand_glyph_scan
    pop es
    pop si
    pop di
    pop cx
    pop ax
    ret

/* Release number is a single five-glyph table; update with each version.
 * x268: five 8px letters fit centrally in the 64px HUD strip. */
draw_branding:
    push bx
    push cx
    push di
    push si
    mov bx,offset brand_tanks_glyphs
    mov di,6147             /* x268,y152: blank 8px title separator */
    call draw_brand_row
    mov bx,offset brand_copyright_glyphs
    mov di,6787             /* x268, y168 */
    call draw_brand_row
    mov bx,offset brand_basic_glyphs
    mov di,7107             /* x268, y176 */
    call draw_brand_row
    mov bx,offset brand_version_glyphs
    mov di,7427             /* x268, y184 */
    call draw_brand_row
    pop si
    pop di
    pop cx
    pop bx
    ret

draw_brand_row:
    push cx
    mov cx,5
brand_row_next:
    mov si,[bx]
    call draw_hud_glyph_inverted
    add bx,2
    add di,2
    loop brand_row_next
    pop cx
    ret

/* AL = digit 0..9, DI = B800 even-bank offset (x multiple of 4px). */
draw_hud_digit:
    push bx
    push si
    xor bx, bx
    mov bl, al
    shl bx, 1
    mov si, [hud_digit_ptrs+bx]
    call draw_hud_glyph
    pop si
    pop bx
    ret

/* Refresh all 20 enemy badges (two columns of 10). The blank badge
 * is white, so the icons disappear as enemies are killed.
 */
draw_enemy_markers:
    push ax
    push bx
    push cx
    push dx
    push di
    push si
    mov al, 20
    sub al, [enemy_killed]
    mov [hud_remaining], al
    xor bx, bx
hud_enemy_next:
    mov ax, bx
    mov cl, 4
    div cl
    mov dl, ah               /* 0..3 mini columns */
    xor ah, ah
    shl ax, 1
    mov si, ax
    mov di, [hud_indicator_offsets+si]
    xor ax, ax
    mov al, dl
    mov cl, 3
    mul cl
    add di, ax               /* icons spaced by 12 pixels */
hud_enemy_first_column:
    mov si, offset hud_tank_icon
    cmp bl, [hud_remaining]
    jb hud_enemy_active
    mov si, offset hud_blank_icon
hud_enemy_active:
    call draw_hud_glyph
    inc bl
    cmp bl, 20
    jb hud_enemy_next
    pop si
    pop di
    pop dx
    pop cx
    pop bx
    pop ax
    ret

/* Lives and stage use direct CGA 8x8 glyphs to keep black-on-white legible
 * without BIOS teletype drawing black text with black backgrounds.
 */
draw_hud:
    push ax
    push bx
    push cx
    push dx
    push di
    push si
    call draw_enemy_markers
    cmp byte ptr [coop_mode],0
    je hud_solo_lives
    /* Exact eight 8px glyphs fit the 64px sidebar: 1Px1 2Px1. */
    mov di,2624
    mov al,1
    call draw_hud_digit
    mov di,2626
    mov si,offset hud_p_char
    call draw_hud_glyph
    mov di,2628
    mov si,offset hud_x_char
    call draw_hud_glyph
    mov di,2630
    mov al,[lives]
    call draw_hud_digit
    mov di,2632
    mov al,2
    call draw_hud_digit
    mov di,2634
    mov si,offset hud_p_char
    call draw_hud_glyph
    mov di,2636
    mov si,offset hud_x_char
    call draw_hud_glyph
    mov di,2638
    mov al,[coop_lives]
    call draw_hud_digit
    jmp hud_lives_finished
hud_solo_lives:
    mov di,2624
    mov si,offset hud_blank_icon
    call draw_hud_glyph
    mov di,2625             /* x260,y64: 1P */
    mov al, 1
    call draw_hud_digit
    mov di, 2627
    mov si, offset hud_p_char
    call draw_hud_glyph
    mov di, 2630             /* x280,y64: lives in reserve */
    mov si, offset hud_x_char
    call draw_hud_glyph
    mov al, [lives]
    or al, al
    jz hud_lives_zero
    dec al
hud_lives_zero:
    mov di, 2632
    call draw_hud_digit
    mov si,offset hud_blank_icon
    mov di,2634
    call draw_hud_glyph
    mov di,2636
    call draw_hud_glyph
    mov di,2638
    call draw_hud_glyph
hud_lives_finished:
    mov di, 2945             /* x260,y72: flag */
    mov si, offset hud_flag_icon
    call draw_hud_glyph
    mov al, [stage]
    xor ah, ah
    mov bl, 10
    div bl
    mov di, 2948             /* x272,y72 */
    call draw_hud_digit
    mov al, ah
    mov di, 2950             /* x280,y72 */
    call draw_hud_digit
    cmp byte ptr [player_upgrade], 0
    je hud_no_upgrade
    mov di, 2953             /* x292,y72 star */
    mov si, offset hud_star_icon
    call draw_hud_glyph
    mov al, [player_upgrade]
    mov di, 2955             /* x300,y72 */
    call draw_hud_digit
hud_no_upgrade:
    call format_score
    mov di, 3585             /* x260,y88: S + five digits */
    mov si, offset hud_s_char
    call draw_hud_glyph
    xor bx, bx
hud_score_loop:
    xor ax, ax
    mov al, [score_string+6+bx]
    sub al, '0'
    mov di, bx
    shl di, 1
    add di, 3587            /* x268 onwards */
    call draw_hud_digit
    inc bx
    cmp bx, 5
    jb hud_score_loop
    pop si
    pop di
    pop dx
    pop cx
    pop bx
    pop ax
    ret

/* Fixed 4x8px HUD glyphs: AUTO or MAN. Player input immediately takes
 * over without changing game balance; TAB returns to computer control. */
/* Flash the exact collected bonus icon, never a generic number/star. */
draw_bonus_indicator:
    push ax
    push bx
    push dx
    push si
    push di
    /* 64px right HUD row (y96):
       bonus at x256 | seconds x272-287 | reserve V x N at x296-319. */
    mov si,offset hud_blank_icon
    mov di,3906          /* separator x264 */
    call draw_hud_glyph
    mov di,3912          /* separator x288 */
    call draw_hud_glyph
    mov di,3904          /* icon starts at FAR LEFT edge */
    cmp byte ptr [coop_mode],0
    jne bonus25_flash_only
    cmp word ptr [ally_ticks],0
    jne bonus20_ally_icon
    cmp byte ptr [bonus_flash_ticks],0
    je bonus20_icon_draw
    test byte ptr [game_tick],8
    jnz bonus20_icon_draw
    xor bx,bx
    mov bl,[bonus_flash_type]
    shl bx,1
    mov si,[hud_bonus_ptrs+bx]
    jmp bonus20_icon_draw
bonus25_flash_only:
    cmp byte ptr [bonus_flash_ticks],0
    je bonus20_icon_draw
    test byte ptr [game_tick],8
    jnz bonus20_icon_draw
    xor bx,bx
    mov bl,[bonus_flash_type]
    shl bx,1
    mov si,[hud_bonus_ptrs+bx]
    jmp bonus20_icon_draw
bonus20_ally_icon:
    /* Active ally always overrides old pickup pictogram. */
    test byte ptr [game_tick],8
    jnz bonus20_icon_hidden
    mov si,offset hud_bonus_ally
    jmp bonus20_icon_draw
bonus20_icon_hidden:
    mov si,offset hud_blank_icon
bonus20_icon_draw:
    call draw_hud_glyph
    /* Always clear both digit glyphs so an expired timer leaves no 88. */
    mov si,offset hud_blank_icon
    mov di,3908
    call draw_hud_glyph
    mov di,3910
    call draw_hud_glyph
    cmp byte ptr [coop_mode],0
    jne bonus25_timer_flash
    cmp word ptr [ally_ticks],0
    jne bonus20_timer_ally
bonus25_timer_flash:
    cmp byte ptr [bonus_flash_ticks],0
    je bonus20_timer_done
    mov al,[bonus_flash_type]
    cmp al,0
    je bonus20_timer_done
    cmp al,2
    je bonus20_timer_done
    cmp al,5
    je bonus20_timer_done
    cmp al,7          /* unused stock bonus never has a countdown */
    je bonus20_timer_done
    xor ah,ah
    mov al,[bonus_flash_ticks]
    jmp bonus20_timer_convert
bonus20_timer_ally:
    mov ax,[ally_ticks]  /* 270 ticks = 15 seconds, cannot fit a byte */
bonus20_timer_convert:
    add ax,17
    mov bl,18
    div bl
    xor ah,ah
    mov bl,10
    div bl
    mov bh,ah
    mov di,3908         /* x272 tens */
    call draw_hud_digit
    mov al,bh
    mov di,3910         /* x280 ones */
    call draw_hud_digit
bonus20_timer_done:
    cmp byte ptr [coop_mode],0
    jne bonus24_coop_hud
    mov di,3914         /* x296 V */
    mov si,offset hud_v_char
    cmp byte ptr [ally_life_flash],0
    je bonus20_v_draw
    test byte ptr [game_tick],2
    jz bonus20_v_draw
    mov si,offset hud_blank_icon
bonus20_v_draw:
    call draw_hud_glyph
    mov di,3916         /* x304 x */
    mov si,offset hud_x_char
    call draw_hud_glyph
    mov di,3918         /* x312 available calls */
    mov al,[ally_stock]
    call draw_hud_digit
    jmp bonus24_hud_end
bonus24_coop_hud:
    /* COOP is displayed only on the mode row y104, not as V stock. */
    mov si,offset hud_blank_icon
    mov di,3912
    call draw_hud_glyph
    mov di,3914
    call draw_hud_glyph
    mov di,3916
    call draw_hud_glyph
    mov di,3918
    call draw_hud_glyph
bonus24_hud_end:
    pop di
    pop si
    pop dx
    pop bx
    pop ax
    ret

draw_mode_indicator:
    push ax
    push bx
    push cx
    push si
    push di
    mov bx,offset tactical_coop_glyphs
    cmp byte ptr [coop_mode],0
    jne mode_hud_selected
    mov bx, offset tactical_auto_glyphs
    cmp byte ptr [auto_mode], 0
    jne mode_hud_selected
    mov bx, offset tactical_manual_glyphs
mode_hud_selected:
    mov di, 4224             /* x256,y104: eight 8px glyphs = 64px sidebar */
    mov cx, 8
mode_hud_glyph:
    mov si,[bx]
    call draw_hud_glyph
    add bx,2
    add di,2
    loop mode_hud_glyph
    pop di
    pop si
    pop cx
    pop bx
    pop ax
    ret

cursor_at:
    mov ah, 2
    xor bh, bh
    int 0x10
    ret
bios_string:
    push ax
    push bx
    push si
put_char:
    lodsb
    test al, al
    jz printed
    mov ah, 0x0e
    xor bh, bh
    mov bl, 3
    int 0x10
    jmp put_char
printed:
    pop si
    pop bx
    pop ax
    ret

/* Repeatable built-in headless emulator logic regression. */
smoke_test:
    mov byte ptr [test_mode], 1
    mov byte ptr [auto_mode], 0
    /* Verify real B800: CGA sidebar data, not just generated source assets. */
    mov byte ptr [test_phase], 10
    push es
    mov ax, 0xb800
    mov es, ax
    cmp word ptr es:[64], 0xffff       /* white first panel scanline */
    je smoke_white_ok
    pop es
    jmp smoke_fail
smoke_white_ok:
    mov ax, [hud_tank_icon]            /* first active marker at x256,y16 */
    cmp word ptr es:[225], ax          /* (16/2)*80 + 256/4 */
    je smoke_mark_ok
    pop es
    jmp smoke_fail
smoke_mark_ok:
    pop es
    mov byte ptr [test_phase], 1
    /* All 3 starting enemy slots must be occupied. */
    cmp byte ptr [enemy_spawned], 3
    je test_spawned
    jmp smoke_fail
test_spawned:
    mov byte ptr [test_phase], 2
    mov dl, 7
    mov dh, 13
    call try_move
    cmp byte ptr [player_row], 13
    je test_move1
    jmp smoke_fail
test_move1:
    mov byte ptr [test_phase], 3
    mov dl, 7
    mov dh, 12
    call try_move
    cmp byte ptr [player_row], 12
    je test_move2
    jmp smoke_fail
test_move2:
    mov byte ptr [test_phase], 4
    mov dl, 7
    mov dh, 15
    call try_move
    cmp byte ptr [player_row], 12
    je test_blocked
    jmp smoke_fail
test_blocked:
    mov byte ptr [test_phase], 5
    /* Advance player bullet at row 9 col 6 through brick at col 9. */
    mov byte ptr [player_col], 7
    mov byte ptr [player_row], 9
    mov byte ptr [player_dir], 1
    call do_fire
    mov cx, 12
test_bullet_loop:
    push cx
    call advance_bullet
    pop cx
    loop test_bullet_loop
    /* One hit destroys only the entry-side half of the brick. */
    cmp byte ptr [level_data+154], '#'
    jne test_failed_jump_far
    cmp byte ptr [brick_masks+154], 10
    jne test_failed_jump_far
    /* A second shot removes the remaining half. */
    call do_fire
    mov cx, 12
test_bullet_again:
    push cx
    call advance_bullet
    pop cx
    loop test_bullet_again
    cmp byte ptr [level_data+154], '.'
    je test_brick
    jmp smoke_fail
test_failed_jump_far:
    jmp smoke_fail
test_brick:
    mov byte ptr [test_phase], 6
    mov byte ptr [player_row], 14
    mov byte ptr [player_col], 7
    mov byte ptr [player_shield], 0
    mov bx, 0
    mov byte ptr [shot_col+bx], 7
    mov byte ptr [shot_row+bx], 13
    mov byte ptr [shot_dir+bx], 2
    mov byte ptr [shot_active+bx], 1
    mov byte ptr [shot_delay+bx], 1
    call advance_enemy_shot
    cmp byte ptr [lives], 2
    je test_life
    jmp smoke_fail
test_life:
    mov byte ptr [test_phase], 7
    mov byte ptr [shot_col+bx], 7
    mov byte ptr [shot_row+bx], 14
    mov byte ptr [shot_dir+bx], 2
    mov byte ptr [shot_active+bx], 1
    mov byte ptr [shot_delay+bx], 1
    call advance_enemy_shot
    cmp byte ptr [game_state], 2
    je test_base
    jmp smoke_fail
test_base:
    mov byte ptr [test_phase], 8
    mov byte ptr [game_state], 0
    mov byte ptr [enemy_spawned], 20
    mov byte ptr [enemy_killed], 20
    call check_stage_complete
    cmp byte ptr [game_state], 1
    je test_wave_complete
    jmp smoke_fail
test_wave_complete:
    mov byte ptr [test_phase], 9
    call reset_campaign
    /* First spawned enemy at lane 0 should be basic, second fast, third power. */
    cmp byte ptr [enemy_type], 0
    je 1f
    jmp test_failed_jump
1:
    mov byte ptr [test_phase], 31
    cmp byte ptr [enemy_type+1], 1
    je 1f
    jmp test_failed_jump
1:
    mov byte ptr [test_phase], 32
    cmp byte ptr [enemy_type+2], 2
    je 1f
    jmp test_failed_jump
1:
    /* Force enemy 0 to armor, then hit once: it must survive with 3 HP. */
    mov byte ptr [enemy_type], 3
    mov byte ptr [enemy_hp], 4
    mov byte ptr [bullet_col], 1
    mov byte ptr [bullet_row], 1
    mov byte ptr [bullet_dir], 0
    mov byte ptr [bullet_delay], 1
    mov byte ptr [bullet_active], 1
    call advance_bullet
    mov byte ptr [test_phase], 33
    cmp byte ptr [enemy_hp], 3
    je 1f
    jmp test_failed_jump
1:
    mov byte ptr [test_phase], 34
    cmp byte ptr [enemy_active], 1
    je 1f
    jmp test_failed_jump
1:
    /* Score must be shown on stage-result overlay as five digits. */
    mov byte ptr [test_phase], 11
    mov word ptr [score], 1234
    call format_score
    cmp byte ptr [score_string+6], '0'
    je 1f
    jmp test_failed_jump
1:
    cmp byte ptr [score_string+7], '1'
    je 1f
    jmp test_failed_jump
1:
    cmp byte ptr [score_string+8], '2'
    je 1f
    jmp test_failed_jump
1:
    cmp byte ptr [score_string+9], '3'
    je 1f
    jmp test_failed_jump
1:
    cmp byte ptr [score_string+10], '4'
    je 1f
    jmp test_failed_jump
1:

    mov byte ptr [test_phase], 12
    call reset_campaign
    mov byte ptr [enemy_killed], 5
    xor bx,bx
    mov byte ptr [enemy_px],112
    mov byte ptr [enemy_py],120
    call maybe_drop_bonus
    cmp byte ptr [bonus_active], 1
    je 1f
    jmp test_failed_jump
1:
    cmp byte ptr [bonus_type], 0
    je 1f
    jmp test_failed_jump
1:
    mov al, [bonus_col]
    mov [player_col], al
    mov al, [bonus_row]
    mov [player_row], al
    /* Legacy smoke fixture must also move the actual pixel tank. */
    mov al,[bonus_col]
    shl al,1
    shl al,1
    shl al,1
    shl al,1
    mov [player_px],al
    mov al,[bonus_row]
    mov bl,12
    mul bl
    mov [player_py],al
    call check_bonus_pickup
    cmp byte ptr [player_upgrade], 1
    je 1f
    jmp test_failed_jump
1:
    cmp byte ptr [bonus_active], 0
    je 1f
    jmp test_failed_jump
1:

    mov byte ptr [test_phase], 13
    call protect_hq
    cmp byte ptr [level_data+230], 'T'
    je 1f
    jmp test_failed_jump
1:
    cmp byte ptr [level_data+232], 'T'
    je 1f
    jmp test_failed_jump
1:
    call restore_hq
    mov byte ptr [hq_shield], 0
    cmp byte ptr [level_data+230], '#'
    je 1f
    jmp test_failed_jump
1:
    cmp byte ptr [brick_masks+230], 15
    je 1f
    jmp test_failed_jump
1:

    mov byte ptr [test_phase], 14
    mov byte ptr [bullet_col], 3
    mov byte ptr [bullet_row], 10
    mov byte ptr [bullet_dir], 1
    mov byte ptr [bullet_active], 1
    mov byte ptr [bullet_delay], 1
    mov byte ptr [shot_col], 4
    mov byte ptr [shot_row], 10
    mov byte ptr [shot_active], 1
    call advance_bullet
    cmp byte ptr [bullet_active], 0
    je 1f
    jmp test_failed_jump
1:
    cmp byte ptr [shot_active], 0
    je 1f
    jmp test_failed_jump
1:

    mov byte ptr [test_phase], 15
    mov byte ptr [bonus_active], 1
    mov byte ptr [bonus_type], 1      /* helmet */
    mov al, [player_col]
    mov [bonus_col], al
    mov al, [player_row]
    mov [bonus_row], al
    call check_bonus_pickup
    cmp byte ptr [player_shield], 150
    je 1f
    jmp test_failed_jump
1:
    mov byte ptr [bonus_active], 1
    mov byte ptr [bonus_type], 4      /* clock */
    call check_bonus_pickup
    cmp byte ptr [freeze_ticks], 120
    je 1f
    jmp test_failed_jump
1:
    mov byte ptr [bonus_active], 1
    mov byte ptr [bonus_type], 5      /* extra tank */
    call check_bonus_pickup
    cmp byte ptr [lives], 4
    je 1f
    jmp test_failed_jump
1:

    mov byte ptr [test_phase], 16
    mov byte ptr [bonus_active], 1
    mov byte ptr [bonus_type], 2      /* grenade */
    call check_bonus_pickup
    cmp byte ptr [enemy_active], 0
    je 1f
    jmp test_failed_jump
1:
    cmp byte ptr [enemy_active+1], 0
    je 1f
    jmp test_failed_jump
1:
    cmp byte ptr [enemy_active+2], 0
    je 1f
    jmp test_failed_jump
1:
    mov byte ptr [test_phase], 17
    call reset_campaign
    mov byte ptr [player_col], 1
    mov byte ptr [player_row], 4
    mov dl, 2
    mov dh, 4
    call try_move
    cmp byte ptr [player_col], 2
    je 1f
    jmp test_failed_jump
1:
    mov byte ptr [player_col], 9
    mov byte ptr [player_row], 7
    mov dl, 10
    mov dh, 7
    call try_move
    cmp byte ptr [player_col], 10
    je 1f
    jmp test_failed_jump
1:
    cmp byte ptr [slide_ticks], 2
    je 1f
    jmp test_failed_jump
1:
    mov byte ptr [test_phase], 18
    mov byte ptr [stage], 9
    call load_stage
    cmp byte ptr [level_data+50], 'F' /* row3, col1 */
    je 1f
    jmp test_failed_jump
1:
    mov byte ptr [test_phase], 19
    call reset_campaign
    mov byte ptr [player_col], 7
    mov byte ptr [player_row], 9
    mov byte ptr [player_dir], 0
    mov byte ptr [player_upgrade], 3
    call do_fire
    cmp byte ptr [level_data+135], '.' /* max upgrade cuts steel */
    je 1f
    jmp test_failed_jump
1:
    mov byte ptr [test_phase], 20
    mov byte ptr [kills_by_type+2], 12
    call format_tally
    cmp byte ptr [tally3+11], '1'
    je 1f
    jmp test_failed_jump
1:
    cmp byte ptr [tally3+12], '2'
    je 1f
    jmp test_failed_jump
1:
    /* Smooth pixel and quadrant tests supplement legacy cell tests. */
    mov byte ptr [test_phase], 21
    call reset_campaign
    mov al, 0
    call player_move_pixel
    cmp byte ptr [player_py], 167
    je 1f
    jmp smoke_fail
1:
    cmp byte ptr [player_row], 13
    je 1f
    jmp smoke_fail
1:
    mov byte ptr [test_phase], 22
    mov byte ptr [player_px], 112
    mov byte ptr [player_py], 107
    xor al, al
    call player_move_pixel
    cmp byte ptr [player_py], 107
    je 1f
    jmp smoke_fail
1:
    mov byte ptr [test_phase], 23
    mov dl, 50
    mov dh, 25
    call projectile_probe
    cmp al, 1
    je 1f
    jmp smoke_fail
1:
    call chip_brick_pixel
    cmp byte ptr [brick_masks+35], 14   /* row2 col2: 2*13+2 */
    je 1f
    jmp smoke_fail
1:
    mov dl, 50
    mov dh, 25
    call projectile_probe
    cmp al, 0
    je 1f
    jmp smoke_fail
1:
    mov dl, 58
    mov dh, 25
    call projectile_probe
    cmp al, 1
    je 1f
    jmp smoke_fail
1:
    mov byte ptr [test_phase], 24
    call reset_campaign
    cmp byte ptr [enemy_px+1], 112
    je 1f
    jmp smoke_fail
1:
    mov byte ptr [bullet_px], 48
    mov byte ptr [bullet_py], 168
    mov byte ptr [bullet_dir], 1
    mov byte ptr [bullet_active], 1
    call advance_bullet_smooth
    cmp byte ptr [bullet_px], 51
    je 1f
    jmp smoke_fail
1:
    mov byte ptr [test_phase], 25
    /* Verify shifted 2-bit mask/colour atlas: 4 phases x 12 x 10 bytes. */
    mov al, byte ptr [smooth_player_up+1]
    or al, byte ptr [smooth_player_up+121]
    cmp al, 0
    jne 1f
    jmp smoke_fail
1:
    mov byte ptr [test_phase], 26
    call reset_campaign
    mov byte ptr [held_keys], 1
    call move_player_smooth
    cmp byte ptr [player_py], 166
    je 1f
    jmp smoke_fail
1:
    mov byte ptr [held_keys], 0
    mov byte ptr [test_phase], 27
    call refresh_screen
    mov cx, 8
smooth_regression_loop:
    push cx
    call game_tick_step
    call render_frame
    pop cx
    loop smooth_regression_loop
    cmp byte ptr [game_tick], 8
    je 1f
    jmp smoke_fail
1:
    jmp smoke_campaign_35
smoke_campaign_35:
    mov byte ptr [test_phase], 28
    mov byte ptr [stage], 35
    call load_stage
    cmp byte ptr [level_data+33], 'F'
    je 1f
    jmp smoke_fail
1:
    /* Last -> first via PgUp on pause. */
    mov byte ptr [game_state], 3
    mov byte ptr [pending_commands], 32
    call poll_controls
    cmp byte ptr [stage], 1
    je 1f
    jmp smoke_fail
1:
    /* First -> last via PgDn on pause. */
    mov byte ptr [game_state], 3
    mov byte ptr [pending_commands], 64
    call poll_controls
    cmp byte ptr [stage], 35
    je 1f
    jmp smoke_fail
1:
    /* Test phase 29: friendly rounds do damage when a moving ally crosses
       the lane despite the pre-fire safety check. */
    mov byte ptr [test_phase], 29
    call reset_campaign
    mov byte ptr [enemy_hp+1], 1
    mov byte ptr [shot_px], 94
    mov byte ptr [shot_py], 0
    mov byte ptr [enemy_px+1], 94
    mov byte ptr [enemy_py+1], 0
    xor bx, bx
    call shot_hits_other_enemy
    jc 1f
    jmp smoke_fail
1:
    cmp byte ptr [enemy_active+1], 0
    je 1f
    jmp smoke_fail
1:
    cmp byte ptr [enemy_hp+1], 1
    je 1f
    jmp smoke_fail
1:
    cmp byte ptr [enemy_killed], 1
    je 1f
    jmp smoke_fail
1:
    cmp word ptr [score], 0
    je 1f
    jmp smoke_fail
1:
    mov byte ptr [test_phase], 30
    mov byte ptr [palette_index], 0
    call cycle_cga_palette
    cmp byte ptr [palette_index], 1
    je 1f
    jmp smoke_fail
1:
    mov dl, 112
    mov dh, 40
    call spawn_explosion
    cmp byte ptr [explosion_ticks], 8
    je 1f
    jmp smoke_fail
1:
    call tick_explosion
    cmp byte ptr [explosion_ticks], 7
    je 1f
    jmp smoke_fail
1:
    /* Test phase 33: ensure the composed frame is committed to CGA, not
       just held in RAM, including background and moving player pixels. */
    mov byte ptr [test_phase], 33
    cmp word ptr [frame_seg], 0xb800
    jne 1f
    jmp smoke_fail
1:
    call reset_campaign
    call refresh_screen
    push es
    mov ax, [frame_seg]
    mov es, ax
    mov bx, es:[9162]       /* brick, y25 (odd bank), x40 */
    mov cx, es:[6748]       /* player's start x112,y168 (even bank) */
    mov ax, 0xb800
    mov es, ax
    cmp bx, es:[9162]
    jne smoke_buffer_bad
    cmp cx, es:[6748]
    jne smoke_buffer_bad
    pop es
    jmp smoke_tactics_v11
smoke_buffer_bad:
    pop es
    jmp smoke_fail
/* v0.11 tactical smoke: demo defaults, manual override, P1 threat reaction,
 * enemy roles, shared last known position and friendly fire suppression. */
smoke_tactics_v11:
    mov byte ptr [test_phase], 34
    mov byte ptr [auto_mode], 1
    mov byte ptr [game_state], 0
    mov byte ptr [held_keys], 0
    mov byte ptr [manual_keys], 0
    mov byte ptr [pending_commands], 0
    mov byte ptr [auto_toggle_pending], 1
    call poll_controls
    cmp byte ptr [auto_mode], 0
    je 1f
    jmp smoke_fail
1:
    mov byte ptr [test_phase], 35
    mov byte ptr [auto_toggle_pending], 1
    call poll_controls
    cmp byte ptr [auto_mode], 1
    je 1f
    jmp smoke_fail
1:
    mov byte ptr [test_phase], 36
    mov byte ptr [game_tick], 4
    mov byte ptr [player_px], 112
    mov byte ptr [player_py], 144
    mov byte ptr [shot_active], 1
    mov byte ptr [shot_dir], 2
    mov byte ptr [shot_px], 112
    mov byte ptr [shot_py], 120
    call tactical_find_threat
    jc 1f
    jmp smoke_fail
1:
    cmp al, 1
    je 1f
    jmp smoke_fail
1:
    mov byte ptr [test_phase], 37
    mov byte ptr [bullet_active], 0
    mov byte ptr [enemy_active], 1
    mov byte ptr [enemy_px], 80
    mov byte ptr [enemy_py], 80
    xor bx,bx
    call tactical_enemy_turn
    /* A locally planned detour may legitimately differ from the old
       hardcoded EAST heading if that route is obstructed. Verify the
       planner returns one of the four physical headings; phases 41-43
       separately verify exact open/blocked corridor choices. */
    cmp byte ptr [enemy_dir], 4
    jb 1f
    jmp smoke_fail
1:
    mov byte ptr [test_phase], 38
    call tactical_report_player
    cmp byte ptr [squad_target_x], 112
    je 1f
    jmp smoke_fail
1:
    cmp byte ptr [squad_alert], 96
    je 1f
    jmp smoke_fail
1:
    mov byte ptr [test_phase], 39
    mov byte ptr [enemy_active+1], 1
    mov byte ptr [enemy_px+1], 80
    mov byte ptr [enemy_py+1], 110
    mov byte ptr [enemy_dir], 2
    xor bx,bx
    call tactical_safe_fire
    jnc 1f
    jmp smoke_fail
1:
    /* Phase 40: autonomous 32-frame gameplay progression, actual smooth
       projectile path, background composition and enemy squad updates. */
    mov byte ptr [test_phase], 40
    mov byte ptr [test_mode],0
    call reset_campaign
    mov byte ptr [auto_mode],1
    mov cx,32
smoke_autoplay_tick:
    push cx
    call game_tick_step
    call render_frame
    pop cx
    loop smoke_autoplay_tick
    cmp byte ptr [game_tick],32
    je 1f
    jmp smoke_fail
1:
    cmp byte ptr [player_px],112
    jne smoke_tactical_path_tests
    cmp byte ptr [player_py],168
    jne smoke_tactical_path_tests
    jmp smoke_fail
smoke_tactical_path_tests:
    /* Isolate route geometry from the preceding live squad simulation.
       Dynamic actor occupancy is tested explicitly in phase 56. */
    mov byte ptr [enemy_active],1
    mov byte ptr [enemy_active+1],0
    mov byte ptr [enemy_active+2],0
    mov byte ptr [enemy_active+3],0
    mov byte ptr [player_px],200
    mov byte ptr [player_py],160
    /* Route probe: should pursue goal east along a clear corridor. */
    mov byte ptr [test_phase],41
    mov byte ptr [enemy_px],16
    mov byte ptr [enemy_py],12
    mov byte ptr [enemy_dir],1
    xor bx,bx
    mov dl,200
    mov dh,12
    call tactical_route_choose
    cmp al,1
    je 1f
    jmp smoke_fail
1:
    /* Steel placed just ahead: east must now be rejected. */
    mov byte ptr [test_phase],42
    mov byte ptr [level_data+18],'T'
    mov al,1
    call tactical_enemy_probe6
    jc 1f
    jmp smoke_fail
1:
    mov dl,200
    mov dh,12
    call tactical_route_choose
    cmp al,1
    jne 1f
    jmp smoke_fail
1:
    /* Restore map; clean corridor must again permit progress east. */
    mov byte ptr [test_phase],43
    mov byte ptr [level_data+18],'.'
    mov al,1
    call tactical_enemy_probe6
    jnc 1f
    jmp smoke_fail
1:
    cmp byte ptr [tactical_probe_x],22
    je 1f
    jmp smoke_fail
1:
    /* Phase 44: AUTO left -> human right must NOT inherit LEFT. */
    mov byte ptr [test_phase],44
    mov byte ptr [auto_mode],1
    mov byte ptr [held_keys],8
    mov byte ptr [manual_keys],0
    mov ah,2
    xor bl,bl
    call manual_key_event
    cmp byte ptr [auto_mode],0
    je 9f
    jmp smoke_extra_fail
9:
    cmp byte ptr [held_keys],2
    je 9f
    jmp smoke_extra_fail
9:
    mov bl,0x80
    call manual_key_event
    cmp byte ptr [held_keys],0
    je 9f
    jmp smoke_extra_fail
9:
    /* Phase 45: global flow fields lead from center spawn to HQ,
       and the left/right flank goals each have zero distance. */
    mov byte ptr [test_phase],45
    call reset_campaign
    cmp byte ptr [route_base+0xe7],0
    je 9f
    jmp smoke_extra_fail
9:
    cmp byte ptr [route_left+0xb3],0
    je 9f
    jmp smoke_extra_fail
9:
    cmp byte ptr [route_right+0xbc],0
    je 9f
    jmp smoke_extra_fail
9:
    cmp byte ptr [route_base+0x07],0xff
    jne 9f
    jmp smoke_extra_fail
9:
    /* Phase 46: a steel barrier has no passable cached cost. */
    mov byte ptr [test_phase],46
    mov byte ptr [level_data+0x77],'T'
    mov byte ptr [route_dirty],1
    call strategy_reset_routes
    cmp byte ptr [route_base+0x77],0xff
    je 9f
    jmp smoke_extra_fail
9:
    /* Phase 47: planned global HQ attack takes a valid heading. */
    mov byte ptr [test_phase],47
    call reset_campaign
    mov byte ptr [enemy_active],1
    mov byte ptr [enemy_px],112
    mov byte ptr [enemy_py],96
    mov byte ptr [enemy_dir],2
    mov word ptr [route_active_field],offset route_base
    xor bx,bx
    call strategy_route_heading
    cmp al,4
    jb 9f
    jmp smoke_extra_fail
9:
    /* Phase 48: synchronized attack starts after the staging deadline. */
    mov byte ptr [test_phase],48
    mov byte ptr [squad_doctrine],0  /* baseline timing, not patient pincer */
    mov byte ptr [squad_phase],0
    mov byte ptr [squad_clock],125
    call strategy_tick
    cmp byte ptr [squad_phase],1
    je 9f
    jmp smoke_extra_fail
9:
    /* Phase 49: HQ raider aims DOWN and holds a firing position. */
    mov byte ptr [test_phase],49
    mov byte ptr [bullet_active],0
    mov byte ptr [enemy_active],1
    mov byte ptr [enemy_px],112
    mov byte ptr [enemy_py],140
    mov byte ptr [enemy_dir],1
    xor bx,bx
    call tactical_enemy_turn
    cmp byte ptr [enemy_dir],2
    je 9f
    jmp smoke_extra_fail
9:
    cmp byte ptr [enemy_hold],24
    je 9f
    jmp smoke_extra_fail
9:
    /* Phase 50: teammate 120 pixels downrange blocks fire. */
    mov byte ptr [test_phase],50
    call reset_campaign
    mov byte ptr [enemy_active],1
    mov byte ptr [enemy_active+1],1
    mov byte ptr [enemy_px],64
    mov byte ptr [enemy_py],12
    mov byte ptr [enemy_px+1],64
    mov byte ptr [enemy_py+1],140
    mov byte ptr [enemy_dir],2
    xor bx,bx
    call tactical_safe_fire
    jnc 9f
    jmp smoke_extra_fail
9:
    /* Phase 51: teammate moves out of lane, same shot becomes safe. */
    mov byte ptr [test_phase],51
    mov byte ptr [enemy_px+1],144
    call tactical_safe_fire
    jc 9f
    jmp smoke_extra_fail
9:
    /* Phase 52: enemy projectile must DAMAGE an allied tank rather than
       only draw a harmless blast. This was accidentally disabled in v0.13. */
    mov byte ptr [test_phase],52
    call reset_campaign
    mov byte ptr [enemy_active],1
    mov byte ptr [enemy_active+1],1
    mov byte ptr [enemy_hp+1],1
    mov byte ptr [shot_px],100
    mov byte ptr [shot_py],88
    mov byte ptr [enemy_px+1],100
    mov byte ptr [enemy_py+1],88
    xor bx,bx
    call shot_hits_other_enemy
    jc 9f
    jmp smoke_extra_fail
9:
    cmp byte ptr [enemy_active+1],0
    je 9f
    jmp smoke_extra_fail
9:
    cmp byte ptr [enemy_killed],1
    je 9f
    jmp smoke_extra_fail
9:
    /* Phase 53: bonus flow must lead the AUTO defender toward an open
       reachable pickup instead of holding the HQ guard lane indefinitely. */
    mov byte ptr [test_phase],53
    call reset_campaign
    mov byte ptr [bonus_col],7
    mov byte ptr [bonus_row],10
    mov byte ptr [bonus_active],1
    call strategy_bonus_spawn
    cmp byte ptr [route_bonus+0xa7],0
    je 9f
    jmp smoke_extra_fail
9:
    mov byte ptr [game_tick],4
    mov byte ptr [auto_mode],1
    call tactical_player_tick
    cmp byte ptr [held_keys],1
    je 9f
    jmp smoke_extra_fail
9:
    /* Phase 54: an aligned opponent can trigger an actual AUTO shot, even
       before it enters the last two rows of the base defensive zone. */
    mov byte ptr [test_phase],54
    call reset_campaign
    mov byte ptr [enemy_active],1
    mov byte ptr [enemy_active+1],0
    mov byte ptr [enemy_active+2],0
    mov byte ptr [enemy_active+3],0
    /* x112/y96 lies inside the stage's steel tile: an impossible hit.
       Exercise a truly open, tread-aligned firing lane at x96 instead. */
    mov byte ptr [enemy_px],96
    mov byte ptr [enemy_py],104
    mov byte ptr [player_px],96
    mov byte ptr [player_py],136
    mov byte ptr [game_tick],4
    mov byte ptr [auto_mode],1
    call tactical_player_tick
    cmp byte ptr [bullet_active],1
    je 9f
    jmp smoke_extra_fail
9:
    cmp byte ptr [player_dir],0
    je 9f
    jmp smoke_extra_fail
9:
    /* Phase 55: the defender must actually collect a reachable pickup
       within a bounded autonomous gameplay replay, not just plan to. */
    mov byte ptr [test_phase],55
    call reset_campaign
    mov byte ptr [enemy_spawned],20
    mov byte ptr [freeze_ticks],120
    mov byte ptr [bonus_col],7
    mov byte ptr [bonus_row],10
    mov byte ptr [bonus_type],1
    mov byte ptr [bonus_active],1
    mov byte ptr [bonus_timer],180
    mov byte ptr [auto_mode],1
    call strategy_bonus_spawn
    mov cx,64
smoke_bonus_replay:
    push cx
    call game_tick_step
    pop cx
    loop smoke_bonus_replay
    cmp byte ptr [bonus_active],0
    je 9f
    jmp smoke_extra_fail
9:
    cmp byte ptr [player_shield],0
    jne 9f
    jmp smoke_extra_fail
9:
    /* Phase 56: six-pixel path probe rejects a teammate in the lane,
       but accepts reverse escape (row 10 is open in map 1). */
    mov byte ptr [test_phase],56
    call reset_campaign
    mov byte ptr [enemy_active],1
    mov byte ptr [enemy_active+1],1
    mov byte ptr [enemy_active+2],0
    mov byte ptr [enemy_active+3],0
    mov byte ptr [enemy_px],80
    mov byte ptr [enemy_py],120
    mov byte ptr [enemy_px+1],96
    mov byte ptr [enemy_py+1],120
    xor bx,bx
    mov al,1
    call tactical_enemy_probe6
    jc 9f
    jmp smoke_extra_fail
9:
    mov al,3
    call tactical_enemy_probe6
    jnc 9f
    jmp smoke_extra_fail
9:
    /* Phase 57: repeated physical blockage must force retreat,
       not another command into the neighboring tank's hull. */
    mov byte ptr [test_phase],57
    mov byte ptr [enemy_blocked],6
    mov byte ptr [enemy_dir],1
    call tactical_enemy_turn
    cmp byte ptr [enemy_dir],3
    je 9f
    jmp smoke_extra_fail
9:
    /* Phase 58: AUTO should establish a forward sentry line when
       an opponent is far away and the HQ corridor is still quiet. */
    mov byte ptr [test_phase],58
    call reset_campaign
    mov byte ptr [enemy_active],1
    mov byte ptr [enemy_active+1],0
    mov byte ptr [enemy_active+2],0
    mov byte ptr [enemy_active+3],0
    mov byte ptr [enemy_px],112
    mov byte ptr [enemy_py],16
    mov byte ptr [player_px],112
    mov byte ptr [player_py],136
    mov byte ptr [game_tick],4
    mov byte ptr [auto_mode],1
    call tactical_player_tick
    cmp byte ptr [held_keys],1
    je 9f
    jmp smoke_extra_fail
9:
    /* Phase 59: chasing a pickup must NOT suppress a clear shot. */
    mov byte ptr [test_phase],59
    call reset_campaign
    mov byte ptr [enemy_active],1
    mov byte ptr [enemy_active+1],0
    mov byte ptr [enemy_active+2],0
    mov byte ptr [enemy_active+3],0
    mov byte ptr [enemy_px],96
    mov byte ptr [enemy_py],88
    mov byte ptr [player_px],96
    mov byte ptr [player_py],136
    mov byte ptr [player_col],6
    mov byte ptr [player_row],11
    mov byte ptr [bullet_active],0
    mov byte ptr [bonus_col],7
    mov byte ptr [bonus_row],10
    mov byte ptr [bonus_active],1
    call strategy_bonus_spawn
    mov byte ptr [game_tick],4
    mov byte ptr [auto_mode],1
    call tactical_player_tick
    /* AUTO can either move toward the pickup or hold a real firing lane;
       independent AUTO fire must work in BOTH states. */
    cmp byte ptr [held_keys],0
    jne 9f
    cmp byte ptr [tactical_fire_request],1
    je 9f
    jmp smoke_extra_fail
9:
    call tactical_player_autofire
    cmp byte ptr [bullet_active],1
    je 9f
    jmp smoke_extra_fail
9:
    cmp byte ptr [bullet_dir],0
    je 9f
    jmp smoke_extra_fail
9:
    /* Phase 60: steel between aligned tanks must invalidate a fake shot. */
    mov byte ptr [test_phase],60
    call reset_campaign
    mov byte ptr [player_px],112
    mov byte ptr [player_py],136
    mov byte ptr [enemy_px],112
    mov byte ptr [enemy_py],80
    xor bx,bx
    call tactical_player_aim_if_aligned
    jnc 9f
    jmp smoke_extra_fail
9:
    /* Phase 61: the neighboring open x96 lane is actually fireable. */
    mov byte ptr [test_phase],61
    mov byte ptr [player_px],96
    mov byte ptr [enemy_px],96
    call tactical_player_aim_if_aligned
    jc 9f
    jmp smoke_extra_fail
9:
    /* Phase 62: collected helmet icon now starts at far-left x256. */
    mov byte ptr [test_phase],62
    mov byte ptr [bonus_flash_type],1
    mov byte ptr [bonus_flash_ticks],112
    mov byte ptr [game_tick],0
    call draw_bonus_indicator
    push es
    mov ax,0xb800
    mov es,ax
    mov ax,[hud_bonus_helmet]
    cmp word ptr es:[3904],ax
    je 9f
    pop es
    jmp smoke_extra_fail
9:
    pop es
    /* Phase 63: an enemy at HQ rows blocks the bonus excursion. */
    mov byte ptr [test_phase],63
    call reset_campaign
    mov byte ptr [enemy_active],1
    mov byte ptr [enemy_px],112
    mov byte ptr [enemy_py],144
    mov byte ptr [bonus_active],1
    mov byte ptr [bonus_col],2
    mov byte ptr [bonus_row],10
    call strategy_bonus_spawn
    call strategy_bonus_heading
    jnc 9f
    jmp smoke_extra_fail
9:
    /* Phase 64: an outer-wing decoy at y172 must NOT distract from
       a true HQ-corridor attacker at y120. */
    mov byte ptr [test_phase],64
    call reset_campaign
    mov byte ptr [enemy_active],1
    mov byte ptr [enemy_active+1],1
    mov byte ptr [enemy_active+2],0
    mov byte ptr [enemy_active+3],0
    mov byte ptr [enemy_px],128
    mov byte ptr [enemy_py],120
    mov byte ptr [enemy_px+1],208
    mov byte ptr [enemy_py+1],172
    call tactical_find_target
    jc 9f
    jmp smoke_extra_fail
9:
    cmp bx,0
    je 9f
    jmp smoke_extra_fail
9:
    /* Phase 65: at the edge of the defensive corridor choose a vertical
       interception instead of oscillating outside x144. */
    mov byte ptr [test_phase],65
    call reset_campaign
    mov byte ptr [enemy_active],1
    mov byte ptr [enemy_active+1],0
    mov byte ptr [enemy_active+2],0
    mov byte ptr [enemy_active+3],0
    mov byte ptr [enemy_px],208
    mov byte ptr [enemy_py],160
    mov byte ptr [player_px],144
    mov byte ptr [player_py],120
    mov byte ptr [game_tick],4
    mov byte ptr [auto_mode],1
    call tactical_player_tick
    cmp byte ptr [held_keys],4
    je 9f
    jmp smoke_extra_fail
9:
    /* Phase 66: a laser hits a live enemy in the same tick. */
    mov byte ptr [test_phase],66
    call reset_campaign
    mov byte ptr [enemy_active],1
    mov byte ptr [enemy_active+1],0
    mov byte ptr [enemy_active+2],0
    mov byte ptr [enemy_active+3],0
    mov byte ptr [enemy_hp],1
    mov byte ptr [enemy_px],96
    mov byte ptr [enemy_py],88
    mov byte ptr [player_px],96
    mov byte ptr [player_py],136
    mov byte ptr [bullet_px],96
    mov byte ptr [bullet_py],136
    mov byte ptr [bullet_dir],0
    mov byte ptr [bullet_active],1
    call laser17_fire
    cmp byte ptr [enemy_active],0
    je 9f
    jmp smoke_extra_fail
9:
    /* Phase 67: triple shots never allocate a fourth projectile. */
    mov byte ptr [test_phase],67
    call reset_campaign
    mov byte ptr [multi_ticks],180
    mov byte ptr [bullet_active],1
    mov byte ptr [player_dir],0
    call do_fire
    call do_fire
    cmp byte ptr [extra_active],1
    je 9f
    jmp smoke_extra_fail
9:
    cmp byte ptr [extra_active+1],1
    je 9f
    jmp smoke_extra_fail
9:
    /* Phase 68: homing chooses the closest enemy's direction. */
    mov byte ptr [test_phase],68
    call reset_campaign
    mov byte ptr [enemy_active],1
    mov byte ptr [enemy_active+1],0
    mov byte ptr [enemy_active+2],0
    mov byte ptr [enemy_active+3],0
    mov byte ptr [enemy_px],144
    mov byte ptr [enemy_py],120
    mov byte ptr [bullet_px],96
    mov byte ptr [bullet_py],120
    mov byte ptr [bullet_dir],0
    call extra17_home_direction
    cmp byte ptr [bullet_dir],1
    je 9f
    jmp smoke_extra_fail
9:
    /* Phase 69: an AI ally acquires an enemy and opens fire. */
    mov byte ptr [test_phase],69
    call reset_campaign
    mov byte ptr [enemy_active],1
    mov byte ptr [enemy_active+1],0
    mov byte ptr [enemy_active+2],0
    mov byte ptr [enemy_active+3],0
    mov byte ptr [enemy_px],96
    mov byte ptr [enemy_py],88
    mov byte ptr [player_px],96
    mov byte ptr [player_py],136
    call ally17_spawn
    jnc 9f
    jmp smoke_extra_fail
9:
    /* The new deploy point is by HQ, not magically at the player's feet. */
    mov al,[ally_px]
    mov [enemy_px],al
    mov al,[ally_py]
    sub al,40
    mov [enemy_py],al
    call ally17_tick
    cmp byte ptr [extra_active],1
    je 9f
    jmp smoke_extra_fail
9:
    /* Phase 70: enemy frenzy actively targets an allied enemy. */
    mov byte ptr [test_phase],70
    call reset_campaign
    mov byte ptr [enemy_active],1
    mov byte ptr [enemy_active+1],1
    mov byte ptr [enemy_active+2],0
    mov byte ptr [enemy_active+3],0
    mov byte ptr [enemy_px],64
    mov byte ptr [enemy_py],64
    mov byte ptr [enemy_px+1],64
    mov byte ptr [enemy_py+1],96
    xor bx,bx
    call frenzy17_target
    jc 9f
    jmp smoke_extra_fail
9:
    cmp byte ptr [enemy_dir],2
    je 9f
    jmp smoke_extra_fail
9:
    /* Phase 71: grenade leaves visible FX actors for every victim. */
    mov byte ptr [test_phase],71
    call reset_campaign
    call grenade_all_enemies
    cmp byte ptr [grenade_fx_ticks],12
    je 9f
    jmp smoke_extra_fail
9:
    cmp byte ptr [grenade_fx_ticks+1],12
    je 9f
    jmp smoke_extra_fail
9:
    cmp byte ptr [grenade_fx_ticks+2],12
    je 9f
    jmp smoke_extra_fail
9:
    /* Phase 72: the centered AUTO marker starts after TWO blank glyphs. */
    mov byte ptr [test_phase],72
    mov byte ptr [auto_mode],1
    call draw_mode_indicator
    push es
    mov ax,0xb800
    mov es,ax
    mov ax,[hud_a_char]
    cmp word ptr es:[4228],ax
    je 9f
    pop es
    jmp smoke_extra_fail
9:
    pop es
    /* Phase 73: title now has a blank glyph-height before ©1982; the
       release version is V0.19. */
    mov byte ptr [test_phase],73
    call draw_branding
    push es
    mov ax,0xb800
    mov es,ax
    mov ax,[hud_t_char]
    not ax
    cmp word ptr es:[6147],ax
    je 9f
    pop es
    jmp smoke_extra_fail
9:
    mov ax,[hud_v_char]
    not ax
    cmp word ptr es:[7427],ax
    je 9f
    pop es
    jmp smoke_extra_fail
9:
    pop es
    /* Phase 74: right edge moves from x13 to x12 and never covers x13. */
    mov byte ptr [test_phase],74
    cmp byte ptr [sprite_bonus_star+7],0xc0
    je 9f
    jmp smoke_extra_fail
9:
    /* Phase 75: retain live CGA palette after BIOS mode reset. The
       choice is IN RAM ONLY (compatible with cassette-tape booting). */
    mov byte ptr [test_phase],75
    mov byte ptr [palette_index],3
    call refresh_screen
    cmp byte ptr [palette_index],3
    je 9f
    jmp smoke_extra_fail
9:
    /* Phase 76: lookup matches 8088 DIV12 across tile boundaries. */
    mov byte ptr [test_phase],76
    cmp byte ptr [pixel_y_tile_lookup],0
    je 9f
    jmp smoke_extra_fail
9:
    cmp byte ptr [pixel_y_tile_lookup+11],0x0b
    je 9f
    jmp smoke_extra_fail
9:
    cmp byte ptr [pixel_y_tile_lookup+12],0x10
    je 9f
    jmp smoke_extra_fail
9:
    cmp byte ptr [pixel_y_tile_lookup+191],0xfb
    je 9f
    jmp smoke_extra_fail
9:
    /* Phase 77: a horizontal laser draws one continuous physical
       pixel line and marks its tiles for ghost-free next-frame restore. */
    mov byte ptr [test_phase],77
    mov byte ptr [laser_start_x],32
    mov byte ptr [laser_end_x],80
    mov byte ptr [laser_start_y],72
    mov byte ptr [laser_end_y],72
    mov byte ptr [laser_dir],1
    mov byte ptr [laser_flash_ticks],2
    mov byte ptr [game_tick],0
    call laser17_paint
    /* Post-commit laser overlay leaves the shadow pristine and queues
       uploads rather than polluting the dirty/static composition. */
    cmp byte ptr [upload_tiles+98],1
    je 9f
    jmp smoke_extra_fail
9:
    cmp byte ptr [upload_tiles+101],1
    je 9f
    jmp smoke_extra_fail
9:
    /* Phase 78: after laser expires, restore black background pixels
       without leaving a trail (old sprite-splat regression). */
    mov byte ptr [test_phase],78
    mov byte ptr [laser_flash_ticks],0
    mov byte ptr [bonus_active],0
    mov byte ptr [enemy_active],0
    mov byte ptr [enemy_active+1],0
    mov byte ptr [enemy_active+2],0
    mov byte ptr [enemy_active+3],0
    mov byte ptr [ally_ticks],0
    mov byte ptr [level_data+98],'.'
    mov byte ptr [brick_masks+98],0
    call render_frame
    push es
    mov ax,[frame_seg]
    mov es,ax
    mov al,es:[3130]     /* y78, x40: first pixel of horizontal beam */
    and al,0xc0
    cmp al,0
    je 9f
    pop es
    jmp smoke_extra_fail
9:
    pop es
    /* Phase 79: one free V summon, 15s and unchanged lives. */
    mov byte ptr [test_phase],79
    call reset_campaign
    mov byte ptr [auto_mode],0
    call ally20_try_call
    cmp byte ptr [ally_stock],0
    je 9f
    jmp smoke_extra_fail
9:
    cmp byte ptr [lives],3
    je 9f
    jmp smoke_extra_fail
9:
    cmp word ptr [ally_ticks],270
    je 9f
    jmp smoke_extra_fail
9:
    /* Phase 80: V with no stock spends life, never a final life. */
    mov byte ptr [test_phase],80
    mov word ptr [ally_ticks],0
    mov byte ptr [ally_stock],0
    call ally20_try_call
    cmp byte ptr [lives],2
    je 9f
    jmp smoke_extra_fail
9:
    cmp byte ptr [ally_life_flash],18
    je 9f
    jmp smoke_extra_fail
9:
    mov byte ptr [test_phase],81
    mov word ptr [ally_ticks],0
    mov byte ptr [lives],1
    call ally20_try_call
    cmp byte ptr [lives],1
    je 9f
    jmp smoke_extra_fail
9:
    cmp word ptr [ally_ticks],0
    je 9f
    jmp smoke_extra_fail
9:
    /* Phase 82: manual pickup adds a V stock without forced activation. */
    mov byte ptr [test_phase],82
    mov byte ptr [ally_stock],1
    mov byte ptr [auto_mode],0
    call ally20_collect
    cmp byte ptr [ally_stock],2
    je 9f
    jmp smoke_extra_fail
9:
    cmp word ptr [ally_ticks],0
    je 9f
    jmp smoke_extra_fail
9:
    /* Phase 83: AUTO pickup immediately dispatches one companion. */
    mov byte ptr [test_phase],83
    mov byte ptr [auto_mode],1
    call ally20_collect
    cmp word ptr [ally_ticks],270
    je 9f
    jmp smoke_extra_fail
9:
    cmp byte ptr [ally_stock],2
    je 9f
    jmp smoke_extra_fail
9:
    /* Phase 84: companion collects team powerups independently of P1. */
    mov byte ptr [test_phase],84
    mov byte ptr [auto_mode],0
    mov byte ptr [ally_px],80
    mov byte ptr [ally_py],120
    mov byte ptr [bonus_active],1
    mov byte ptr [bonus_col],5
    mov byte ptr [bonus_row],10
    mov byte ptr [bonus_type],5
    mov byte ptr [lives],3
    call ally20_pickup
    cmp byte ptr [lives],4
    je 9f
    jmp smoke_extra_fail
9:
    cmp byte ptr [bonus_active],0
    je 9f
    jmp smoke_extra_fail
9:
    /* Phase 85: Vx2 on right, companion's remaining 15s centered. */
    mov byte ptr [test_phase],85
    mov byte ptr [game_tick],0
    call draw_bonus_indicator
    push es
    mov ax,0xb800
    mov es,ax
    mov ax,[hud_digit_2]
    cmp word ptr es:[3918],ax
    je 9f
    pop es
    jmp smoke_extra_fail
9:
    mov ax,[hud_digit_1]
    cmp word ptr es:[3908],ax
    je 9f
    pop es
    jmp smoke_extra_fail
9:
    mov ax,[hud_digit_5]
    cmp word ptr es:[3910],ax
    je 9f
    pop es
    jmp smoke_extra_fail
9:
    pop es
    /* Phase 86: one physical CGA tile can be blanked for curtain wipes. */
    mov byte ptr [test_phase],86
    push es
    mov ax,0xb800
    mov es,ax
    mov word ptr es:[0],0xffff
    xor dx,dx
    call transition20_blank_tile
    cmp word ptr es:[0],0
    je 9f
    pop es
    jmp smoke_extra_fail
9:
    pop es
    /* Phase 87: execute the real 16-band introduction, including time
       pacing. The whole field is recovered from the shadow buffer. */
    mov byte ptr [test_phase],87
    mov byte ptr [stage],1
    mov byte ptr [transition_pending],1
    mov byte ptr [test_mode],0
    call transition20_open
    mov byte ptr [test_mode],1
    cmp byte ptr [transition_pending],0
    je 9f
    jmp smoke_extra_fail
9:
    /* Phase 88: the exit wipes the arena before results lettering. */
    mov byte ptr [test_phase],88
    mov byte ptr [test_mode],0
    call transition20_close
    mov byte ptr [test_mode],1
    push es
    mov ax,0xb800
    mov es,ax
    cmp word ptr es:[0],0
    je 9f
    pop es
    jmp smoke_extra_fail
9:
    pop es
    /* Phase 89: the heart is a REAL +1 life, not an armor/heal icon. */
    mov byte ptr [test_phase],89
    call reset_campaign
    mov byte ptr [lives],3
    mov byte ptr [bonus_active],1
    mov byte ptr [bonus_type],5
    mov al,[player_col]
    mov [bonus_col],al
    mov al,[player_row]
    mov [bonus_row],al
    call check_bonus_pickup
    cmp byte ptr [lives],4
    je 9f
    jmp smoke_extra_fail
9:
    /* Phase 90: enemies MUST leave hearts and V/ally calls for player. */
    mov byte ptr [test_phase],90
    mov byte ptr [enemy_active],1
    mov byte ptr [enemy_col],5
    mov byte ptr [enemy_row],10
    mov byte ptr [enemy_px],80
    mov byte ptr [enemy_py],120
    mov byte ptr [bonus_col],5
    mov byte ptr [bonus_row],10
    mov byte ptr [bonus_active],1
    mov byte ptr [bonus_type],5
    call enemy21_collect_bonus
    cmp byte ptr [bonus_active],1
    je 9f
    jmp smoke_extra_fail
9:
    mov byte ptr [bonus_type],7
    call enemy21_collect_bonus
    cmp byte ptr [bonus_active],1
    je 9f
    jmp smoke_extra_fail
9:
    /* Phase 91: enemy steals clock and releases frozen teammates. */
    mov byte ptr [test_phase],91
    mov byte ptr [bonus_type],4
    mov byte ptr [freeze_ticks],120
    call enemy21_collect_bonus
    cmp byte ptr [bonus_active],0
    je 9f
    jmp smoke_extra_fail
9:
    cmp byte ptr [freeze_ticks],0
    je 9f
    jmp smoke_extra_fail
9:
    /* Phase 92: bonus lands on the actual enemy wreck tile (5,10). */
    mov byte ptr [test_phase],92
    call reset_campaign
    mov byte ptr [enemy_killed],5
    mov byte ptr [enemy_px],80
    mov byte ptr [enemy_py],120
    xor bx,bx
    call maybe_drop_bonus
    cmp byte ptr [bonus_active],1
    je 9f
    jmp smoke_extra_fail
9:
    cmp byte ptr [bonus_col],5
    je 9f
    jmp smoke_extra_fail
9:
    cmp byte ptr [bonus_row],10
    je 9f
    jmp smoke_extra_fail
9:
    /* Phase 93: ally's actual spawn shield expires after 48 ticks. */
    mov byte ptr [test_phase],93
    call ally17_spawn
    jnc 9f
    jmp smoke_extra_fail
9:
    cmp byte ptr [ally_shield],48
    je 9f
    jmp smoke_extra_fail
9:
    mov byte ptr [ally_shield],1
    call bonus17_tick
    cmp byte ptr [ally_shield],0
    je 9f
    jmp smoke_extra_fail
9:
    /* Phase 94: actual chassis touches adjacent heart frame. */
    mov byte ptr [test_phase],94
    call reset_campaign
    mov byte ptr [bonus_active],1
    mov byte ptr [bonus_type],5
    mov byte ptr [bonus_col],8
    mov byte ptr [bonus_row],14
    mov byte ptr [player_px],118
    mov byte ptr [lives],3
    call check_bonus_pickup
    cmp byte ptr [lives],4
    je 9f
    jmp smoke_extra_fail
9:
    /* Phase 95: enemy collects an adjacent clock with real pixel coords. */
    mov byte ptr [test_phase],95
    call reset_campaign
    mov byte ptr [enemy_active],1
    mov byte ptr [enemy_px],102
    mov byte ptr [enemy_py],120
    mov byte ptr [bonus_col],7
    mov byte ptr [bonus_row],10
    mov byte ptr [bonus_type],4
    mov byte ptr [bonus_active],1
    mov byte ptr [freeze_ticks],120
    call enemy21_collect_bonus
    cmp byte ptr [bonus_active],0
    je 9f
    jmp smoke_extra_fail
9:
    cmp byte ptr [freeze_ticks],0
    je 9f
    jmp smoke_extra_fail
9:
    /* Phase 96: ping-pong launches exactly one dangerous independent ball. */
    mov byte ptr [test_phase],96
    call reset_campaign
    mov byte ptr [pong_ticks],180
    mov byte ptr [pong_active],0
    call do_fire
    cmp byte ptr [pong_active],1
    je 9f
    jmp smoke_extra_fail
9:
    /* A second fire request cannot create another moving ball. */
    mov byte ptr [pong_px],42
    call do_fire
    cmp byte ptr [pong_px],42
    je 9f
    jmp smoke_extra_fail
9:
    /* Phase 97: four-way shot creates primary and THREE independent slots. */
    mov byte ptr [test_phase],97
    call reset_campaign
    mov byte ptr [test_mode],0
    mov byte ptr [quad_ticks],180
    call do_fire
    mov byte ptr [test_mode],1
    cmp byte ptr [bullet_active],1
    je 9f
    jmp smoke_extra_fail
9:
    cmp byte ptr [extra_active],1
    je 9f
    jmp smoke_extra_fail
9:
    cmp byte ptr [extra_active+1],1
    je 9f
    jmp smoke_extra_fail
9:
    cmp byte ptr [extra_active+2],1
    je 9f
    jmp smoke_extra_fail
9:
    /* Phase 98: super-shell remains active and can pierce steel. */
    mov byte ptr [test_phase],98
    call reset_campaign
    mov byte ptr [test_mode],0
    mov byte ptr [super_ticks],180
    call do_fire
    mov byte ptr [test_mode],1
    cmp byte ptr [super_bullet_active],1
    je 9f
    jmp smoke_extra_fail
9:
    /* Phase 99: enemy really gains temporary guided weapon capability. */
    mov byte ptr [test_phase],99
    call reset_campaign
    mov byte ptr [enemy_active],1
    mov byte ptr [enemy_px],102
    mov byte ptr [enemy_py],120
    mov byte ptr [bonus_col],7
    mov byte ptr [bonus_row],10
    mov byte ptr [bonus_type],9
    mov byte ptr [bonus_active],1
    call enemy21_collect_bonus
    cmp byte ptr [enemy_weapon_kind],9
    je 9f
    jmp smoke_extra_fail
9:
    cmp byte ptr [enemy_weapon_ticks],180
    je 9f
    jmp smoke_extra_fail
9:
    /* Phase 100: P2 can join as an independent human ally. */
    mov byte ptr [test_phase],100
    call reset_campaign
    mov byte ptr [auto_mode],1
    call coop24_join
    cmp byte ptr [coop_mode],1
    je 9f
    jmp smoke_extra_fail
9:
    cmp byte ptr [coop_lives],3
    je 9f
    jmp smoke_extra_fail
9:
    cmp byte ptr [lives],3
    je 9f
    jmp smoke_extra_fail
9:
    cmp word ptr [ally_ticks],0x7fff
    je 9f
    jmp smoke_extra_fail
9:
    /* Phase 101: P2 WASD does not commandeer P1 MAN key state. */
    mov byte ptr [test_phase],101
    mov ah,1
    mov bl,0x11
    call coop24_key_event
    cmp byte ptr [coop_keys],1
    je 9f
    jmp smoke_extra_fail
9:
    cmp byte ptr [auto_mode],0
    je 9f
    jmp smoke_extra_fail
9:
    mov ah,1
    mov bl,0x91
    call coop24_key_event
    cmp byte ptr [coop_keys],0
    je 9f
    jmp smoke_extra_fail
9:
    /* Phase 102: Ctrl creates a real projectile owned by P2. */
    mov byte ptr [test_phase],102
    mov byte ptr [coop_keys],16
    mov byte ptr [ally_cooldown],0
    call coop24_tick
    mov byte ptr [coop_keys],0
    cmp byte ptr [extra_active],1
    je 9f
    jmp smoke_extra_fail
9:
    cmp byte ptr [bullet_active],0
    je 9f
    jmp smoke_extra_fail
9:
    /* Phase 103: disabled automatic companion never steals human P2. */
    mov byte ptr [test_phase],103
    call ally20_try_call
    call bonus17_tick
    cmp word ptr [ally_ticks],0x7fff
    je 9f
    jmp smoke_extra_fail
9:
    /* Phase 104: coop drops half as many power-up candidates. */
    mov byte ptr [test_phase],104
    mov byte ptr [bonus_active],0
    mov byte ptr [enemy_killed],2
    mov byte ptr [enemy_px],16
    mov byte ptr [enemy_py],0
    call maybe_drop_bonus
    cmp byte ptr [bonus_active],0
    je 9f
    jmp smoke_extra_fail
9:
    mov byte ptr [coop_mode],0
    call maybe_drop_bonus
    cmp byte ptr [bonus_active],1
    je 9f
    jmp smoke_extra_fail
9:
    /* Phase 105: enemy physically picks up and SHOOTS laser. */
    mov byte ptr [test_phase],105
    call reset_campaign
    mov byte ptr [enemy_active],1
    mov byte ptr [enemy_active+1],0
    mov byte ptr [enemy_active+2],0
    mov byte ptr [enemy_active+3],0
    mov byte ptr [enemy_px],96
    mov byte ptr [enemy_py],96
    mov byte ptr [enemy_dir],0
    mov byte ptr [bonus_col],6
    mov byte ptr [bonus_row],8
    mov byte ptr [bonus_active],1
    mov byte ptr [bonus_type],6
    call enemy21_collect_bonus
    cmp byte ptr [enemy_weapon_kind],6
    je 9f
    jmp smoke_extra_fail
9:
    mov byte ptr [enemy_hold],1
    mov byte ptr [shot_active],0
    mov byte ptr [laser_flash_ticks],0
    mov byte ptr [test_mode],0
    call enemy_fire_cycle
    mov byte ptr [test_mode],1
    cmp byte ptr [laser_flash_ticks],7
    je 9f
    jmp smoke_extra_fail
9:
    /* Phase 106: P2 is independently damaged; P1 stays alive. */
    mov byte ptr [test_phase],106
    call reset_campaign
    call coop24_join
    mov byte ptr [ally_shield],0
    mov byte ptr [shot_active],1
    mov al,[ally_px]
    mov [shot_px],al
    mov al,[ally_py]
    mov [shot_py],al
    mov byte ptr [shot_dir],0
    mov byte ptr [shot_super],0
    mov byte ptr [test_mode],0
    xor bx,bx
    call advance_enemy_shot_smooth
    mov byte ptr [test_mode],1
    cmp byte ptr [coop_lives],2
    je 9f
    jmp smoke_extra_fail
9:
    cmp byte ptr [game_state],0
    je 9f
    jmp smoke_extra_fail
9:
    cmp byte ptr [lives],3
    je 9f
    jmp smoke_extra_fail
9:
    /* Phase 107: alternating human AUTO orders are counted. */
    mov byte ptr [test_phase],107
    call reset_campaign
    mov byte ptr [p_loop_last],1
    mov byte ptr [p_loop_prev],3
    mov byte ptr [p_loop_count],0
    mov al,3
    call tactical24_player_unloop
    cmp byte ptr [p_loop_count],1
    je 9f
    jmp smoke_extra_fail
9:
    /* Phase 108: enemies have their own reversal counters. */
    mov byte ptr [test_phase],108
    mov byte ptr [enemy_loop_last],1
    mov byte ptr [enemy_loop_prev],3
    mov byte ptr [enemy_loop_count],0
    xor bx,bx
    mov al,3
    call tactical24_enemy_unloop
    cmp byte ptr [enemy_loop_count],1
    je 9f
    jmp smoke_extra_fail
9:
    /* Phase 109: both living human tank counts are shown in CGA HUD. */
    mov byte ptr [test_phase],109
    call reset_campaign
    call coop24_join
    call draw_hud
    push es
    mov ax,0xb800
    mov es,ax
    mov ax,[hud_digit_1]
    cmp word ptr es:[2624],ax
    je 9f
    pop es
    jmp smoke_extra_fail
9:
    mov ax,[hud_digit_2]
    cmp word ptr es:[2632],ax
    je 9f
    pop es
    jmp smoke_extra_fail
9:
    mov ax,[hud_digit_3]
    cmp word ptr es:[2638],ax
    je 9f
    pop es
    jmp smoke_extra_fail
9:
    pop es
    /* Phase 110: joining coop starts each human with THREE lives. */
    mov byte ptr [test_phase],110
    call reset_campaign
    call coop24_join
    cmp byte ptr [coop_lives],3
    je 9f
    jmp smoke_extra_fail
9:
    cmp byte ptr [lives],3
    je 9f
    jmp smoke_extra_fail
9:
    /* Phase 111: damaged P2 returns to an HQ exit, consumes one life. */
    mov byte ptr [test_phase],111
    mov byte ptr [ally_shield],0
    call coop25_hit_p2
    cmp byte ptr [coop_lives],2
    je 9f
    jmp smoke_extra_fail
9:
    cmp word ptr [ally_ticks],0
    jne 9f
    cmp byte ptr [coop25_respawn_pending],1
    je 9f
    jmp smoke_extra_fail
9:
    cmp byte ptr [game_state],0
    je 9f
    jmp smoke_extra_fail
9:
    /* Phase 112: COOP row stays, V×N row is physically blank. */
    mov byte ptr [test_phase],112
    call draw_bonus_indicator
    push es
    mov ax,0xb800
    mov es,ax
    mov ax,[hud_blank_icon]
    cmp word ptr es:[3914],ax
    je 9f
    pop es
    jmp smoke_extra_fail
9:
    cmp word ptr es:[3918],ax
    je 9f
    pop es
    jmp smoke_extra_fail
9:
    pop es
    /* Phase 113: randomized launch deadline and four flight directions. */
    mov byte ptr [test_phase],113
    call reset_campaign
    mov al,[bomber26_departure]
    mov [game_tick],al
    call bomber25_tick
    cmp byte ptr [bomber25_state],1
    je 9f
    jmp smoke_extra_fail
9:
    cmp byte ptr [bomber26_direction],4
    jb 9f
    jmp smoke_extra_fail
9:
    cmp byte ptr [bomber25_axis],0
    jne smoke26_first_vertical
    mov al,[bomber25_x]
    jmp smoke26_first_moved
smoke26_first_vertical:
    mov al,[bomber25_y]
smoke26_first_moved:
    cmp byte ptr [bomber26_reverse],0
    jne smoke26_first_reverse
    cmp al,2
    je 9f
    jmp smoke_extra_fail
smoke26_first_reverse:
    cmp al,238
    je smoke26_first_back_x
    cmp al,178
    je 9f
    jmp smoke_extra_fail
smoke26_first_back_x:
    cmp byte ptr [bomber25_axis],0
    je 9f
    jmp smoke_extra_fail
9:
    /* Phase 114: one pass ends and cannot restart. */
    mov byte ptr [test_phase],114
    mov byte ptr [player_shield],255
    mov cx,124
smoke25_flight_loop:
    call bomber25_tick
    loop smoke25_flight_loop
    cmp byte ptr [bomber25_state],2
    je 9f
    jmp smoke_extra_fail
9:
    cmp byte ptr [bomber25_step],12
    jae 9f
    jmp smoke_extra_fail
9:
    call bomber25_tick
    cmp byte ptr [bomber25_state],2
    je 9f
    jmp smoke_extra_fail
9:
    /* Phase 115: bomb detonates harmlessly above the headquarters B. */
    mov byte ptr [test_phase],115
    call reset_campaign
    mov dl,7
    mov dh,15
    xor bx,bx
    call bomber25_impact
    cmp byte ptr [level_data+247],'B'
    je 9f
    jmp smoke_extra_fail
9:
    cmp byte ptr [game_state],0
    je 9f
    jmp smoke_extra_fail
9:
    /* Phase 116: shots passing a bonus do not remove it. */
    mov byte ptr [test_phase],116
    call reset_campaign
    mov byte ptr [bonus_active],1
    mov byte ptr [bonus_timer],200
    mov byte ptr [bonus_col],7
    mov byte ptr [bonus_row],14
    mov byte ptr [bullet_active],1
    mov byte ptr [bullet_px],112
    mov byte ptr [bullet_py],156
    mov byte ptr [bullet_dir],0
    call advance_bullet_smooth
    cmp byte ptr [bonus_active],1
    je 9f
    jmp smoke_extra_fail
9:
    /* Phase 117: bomb damages a brick like an ordinary downward shot. */
    mov byte ptr [test_phase],117
    call reset_campaign
    mov byte ptr [level_data+34],'#'
    mov byte ptr [brick_masks+34],15
    mov dl,2
    mov dh,2
    xor bx,bx
    call bomber25_impact
    cmp byte ptr [brick_masks+34],12
    je 9f
    jmp smoke_extra_fail
9:
    /* Phase 118: bonus visibly flashes and a heart is collected. */
    mov byte ptr [test_phase],118
    call reset_campaign
    mov byte ptr [bonus_active],1
    mov byte ptr [bonus_col],7
    mov byte ptr [bonus_row],14
    mov byte ptr [bonus_type],5
    call check_bonus_pickup
    cmp byte ptr [bonus25_flash_ticks],14
    je 9f
    jmp smoke_extra_fail
9:
    cmp byte ptr [bonus_active],0
    je 9f
    jmp smoke_extra_fail
9:
    cmp byte ptr [lives],4
    je 9f
    jmp smoke_extra_fail
9:
    /* Phase 119: P1 reappears at base with remaining lives. */
    mov byte ptr [test_phase],119
    call reset_campaign
    mov byte ptr [player_shield],0
    mov dl,7
    mov dh,14
    xor bx,bx
    call bomber25_impact
    cmp byte ptr [lives],2
    je 9f
    jmp smoke_extra_fail
9:
    cmp byte ptr [player_shield],60
    je 9f
    jmp smoke_extra_fail
9:
    cmp byte ptr [game_state],0
    je 9f
    jmp smoke_extra_fail
9:
    /* Phase 120: bomber damage to P2 consumes own life, then respawns. */
    mov byte ptr [test_phase],120
    call reset_campaign
    call coop24_join
    mov byte ptr [ally_shield],0
    mov al,[ally_px]
    mov [bomber25_hit_x],al
    mov al,[ally_py]
    mov [bomber25_hit_y],al
    call bomber25_hit_players
    cmp byte ptr [coop_lives],2
    je 9f
    jmp smoke_extra_fail
9:
    cmp byte ptr [lives],3
    je 9f
    jmp smoke_extra_fail
9:
    cmp byte ptr [game_state],0
    je 9f
    jmp smoke_extra_fail
9:
    /* Phase 121: each new stage gets a fresh randomized flight plan. */
    mov byte ptr [test_phase],121
    mov byte ptr [stage],2
    call load_stage
    mov al,[bomber26_departure]
    mov [game_tick],al
    call bomber25_tick
    cmp byte ptr [bomber25_state],1
    je 9f
    jmp smoke_extra_fail
9:
    cmp byte ptr [bomber25_lane],4
    jae 9f
    jmp smoke_extra_fail
9:
    cmp byte ptr [bomber25_lane],11
    jbe 9f
    jmp smoke_extra_fail
9:
    /* Phase 122: 12-second bonus timeout, no projectile expiry. */
    mov byte ptr [test_phase],122
    call reset_campaign
    mov byte ptr [enemy_killed],5
    mov byte ptr [enemy_px],80
    mov byte ptr [enemy_py],120
    mov byte ptr [bonus_active],0
    call maybe_drop_bonus
    cmp byte ptr [bonus_timer],220
    je 9f
    jmp smoke_extra_fail
9:
    /* Phase 123: no pickup before actual chassis touches the frame. */
    mov byte ptr [test_phase],123
    call reset_campaign
    mov byte ptr [bonus_active],1
    mov byte ptr [bonus_type],5
    mov byte ptr [bonus_col],8
    mov byte ptr [bonus_row],14
    mov byte ptr [player_px],112
    call check_bonus_pickup
    cmp byte ptr [bonus_active],1
    je 9f
    jmp smoke_extra_fail
9:
    mov byte ptr [player_px],118
    call check_bonus_pickup
    cmp byte ptr [bonus_active],0
    je 9f
    jmp smoke_extra_fail
9:
    cmp byte ptr [bonus26_flash_owner],0
    je 9f
    jmp smoke_extra_fail
9:
    /* Phase 124: P2 also uses visible sprite bounds, flashes P2 only. */
    mov byte ptr [test_phase],124
    call reset_campaign
    call coop24_join
    mov byte ptr [bonus_active],1
    mov byte ptr [bonus_type],5
    mov byte ptr [bonus_col],8
    mov byte ptr [bonus_row],14
    mov byte ptr [ally_px],112
    mov byte ptr [ally_py],168
    call coop24_pickup
    cmp byte ptr [bonus_active],1
    je 9f
    jmp smoke_extra_fail
9:
    mov byte ptr [ally_px],118
    call coop24_pickup
    cmp byte ptr [bonus_active],0
    je 9f
    jmp smoke_extra_fail
9:
    cmp byte ptr [bonus26_flash_owner],1
    je 9f
    jmp smoke_extra_fail
9:
    /* Phase 125: enemy steals ONLY at actual chassis/frame contact. */
    mov byte ptr [test_phase],125
    call reset_campaign
    mov byte ptr [enemy_active],1
    mov byte ptr [enemy_px],96
    mov byte ptr [enemy_py],120
    mov byte ptr [bonus_active],1
    mov byte ptr [bonus_type],4
    mov byte ptr [bonus_col],7
    mov byte ptr [bonus_row],10
    call enemy21_collect_bonus
    cmp byte ptr [bonus_active],1
    je 9f
    jmp smoke_extra_fail
9:
    mov byte ptr [enemy_px],102
    call enemy21_collect_bonus
    cmp byte ptr [bonus_active],0
    je 9f
    jmp smoke_extra_fail
9:
    cmp byte ptr [bonus26_flash_owner],2
    je 9f
    jmp smoke_extra_fail
9:
    /* Phase 126: centered checkerboard = left lane then right lane,
       each along-track step leaves exactly ONE impact. */
    mov byte ptr [test_phase],126
    call reset_campaign
    mov byte ptr [bomber25_axis],0
    mov byte ptr [bomber25_step],0
    mov byte ptr [bomber25_base_col],5
    mov byte ptr [bomber25_base_row],7
    mov byte ptr [level_data+101],'.'
    mov byte ptr [level_data+133],'.'
    call bomber25_wave
    cmp byte ptr [bomber25_fx_x],80
    je 9f
    jmp smoke_extra_fail
9:
    cmp byte ptr [bomber25_fx_y],72
    je 9f
    jmp smoke_extra_fail
9:
    cmp byte ptr [bomber25_fx_ticks+1],0
    je 9f
    jmp smoke_extra_fail
9:
    call bomber25_wave
    cmp byte ptr [bomber25_fx_x+1],80
    je 9f
    jmp smoke_extra_fail
9:
    cmp byte ptr [bomber25_fx_y+1],96
    je 9f
    jmp smoke_extra_fail
9:
    cmp byte ptr [bomber25_step],2
    je 9f
    jmp smoke_extra_fail
9:
    /* Phase 127: vertical checkerboard is symmetric around column axis. */
    mov byte ptr [test_phase],127
    call reset_campaign
    mov byte ptr [bomber25_axis],1
    mov byte ptr [bomber25_step],0
    mov byte ptr [bomber25_base_col],7
    mov byte ptr [bomber25_base_row],5
    mov byte ptr [level_data+86],'.'
    mov byte ptr [level_data+88],'.'
    call bomber25_wave
    cmp byte ptr [bomber25_fx_x],96
    je 9f
    jmp smoke_extra_fail
9:
    cmp byte ptr [bomber25_fx_y],60
    je 9f
    jmp smoke_extra_fail
9:
    call bomber25_wave
    cmp byte ptr [bomber25_fx_x+1],128
    je 9f
    jmp smoke_extra_fail
9:
    cmp byte ptr [bomber25_fx_y+1],60
    je 9f
    jmp smoke_extra_fail
9:
    /* Phase 128: aircraft bomb is a normal single brick damaging shot. */
    mov byte ptr [test_phase],128
    call reset_campaign
    mov byte ptr [bomber25_axis],0
    mov byte ptr [bomber25_step],0
    mov byte ptr [bomber25_base_col],7
    mov byte ptr [bomber25_base_row],7
    mov byte ptr [level_data+103],'#'
    mov byte ptr [brick_masks+103],15
    call bomber25_wave
    cmp byte ptr [brick_masks+103],12
    je 9f
    jmp smoke_extra_fail
9:
    /* Phase 129: random flight plan contains one of four directions
       and time is 48..175 ticks, never stage-parity hardcoding. */
    mov byte ptr [test_phase],129
    mov word ptr [rng_state],0x4ab7
    call bomber26_roll
    cmp byte ptr [bomber26_direction],4
    jb 9f
    jmp smoke_extra_fail
9:
    cmp byte ptr [bomber26_departure],48
    jae 9f
    jmp smoke_extra_fail
9:
    cmp byte ptr [bomber26_departure],175
    jbe 9f
    jmp smoke_extra_fail
9:
    jmp smoke_pass
smoke_extra_fail:
    jmp smoke_fail
test_failed_jump:
    jmp smoke_fail
smoke_pass:
    mov ax, 0x0003
    int 0x10
    mov ax, 0x4c00
    int 0x21
smoke_fail:
    mov ax, 0x0003
    int 0x10
    mov al, [test_phase]
    mov ah, 0x4c
    int 0x21

.ifdef TRACE_BUILD
/* Deterministic real-mode trace, not an AI simulator or source-only test. */
trace_run:
    mov byte ptr [trace_count],0
.ifdef PERF_BUILD
    mov cx,384          /* exact 384 full visible frames, no real-time delay */
.else
    mov cx,2048
.endif
trace_tick:
    push cx
    call game_tick_step
.ifdef PERF_BUILD
    call render_frame     /* benchmark the real frame workload every tick */
.endif
    test byte ptr [game_tick],15
    jnz trace_no_sample
.ifndef PERF_BUILD
    /* Normal trace records 128 snapshots without painting every tick. */
    call render_frame
.endif
    call trace_record
trace_no_sample:
    pop cx
    loop trace_tick
    mov ax,0x0003
    int 0x10
    xor cx,cx
    mov dx,offset trace_filename
    mov ax,0x3c00
    int 0x21
    jc trace_failed
    mov bx,ax
    mov dx,offset trace_buffer
    xor cx,cx
    mov cl,[trace_count]
    shl cx,1
    shl cx,1
    shl cx,1
    shl cx,1
    mov ah,0x40
    int 0x21
    pushf
    push ax
    mov ah,0x3e
    int 0x21
    pop ax
    popf
    jc trace_failed
    cmp ax,cx
    jne trace_failed
    mov ax,0x4c00
    int 0x21
trace_failed:
    mov ax,0x4c01
    int 0x21

/* 16-byte record: tick, player XY, held keys, squad phase, enemies XY
   for four slots, total spawned, state, total destroyed. */
trace_record:
    push ax
    push bx
    push cx
    push si
    push di
    xor bx,bx
    mov bl,[trace_count]
    cmp bl,128
    jae trace_record_done
    shl bx,1
    shl bx,1
    shl bx,1
    shl bx,1
    mov di,offset trace_buffer
    add di,bx
    mov al,[game_tick]
    mov [di],al
    mov al,[player_px]
    mov [di+1],al
    mov al,[player_py]
    mov [di+2],al
    mov al,[held_keys]
    mov [di+3],al
    mov al,[squad_phase]
    mov [di+4],al
    xor bx,bx
trace_record_enemies:
    mov al,[enemy_px+bx]
    mov [di+bx+5],al
    inc bx
    cmp bx,4
    jb trace_record_enemies
    xor bx,bx
trace_record_enemy_y:
    mov al,[enemy_py+bx]
    mov [di+bx+9],al
    inc bx
    cmp bx,4
    jb trace_record_enemy_y
    mov al,[enemy_spawned]
    mov [di+13],al
    mov al,[game_state]
    mov [di+14],al
    mov al,[enemy_killed]
    mov [di+15],al
    inc byte ptr [trace_count]
trace_record_done:
    pop di
    pop si
    pop cx
    pop bx
    pop ax
    ret
.endif

.include "src/dos/tactics.inc"
.include "src/dos/strategy_v13.inc"
.include "src/dos/bonuses_v17.inc"
.include "src/dos/ally_v20.inc"
.include "src/dos/transitions_v20.inc"
.include "src/dos/enemy_pickups_v21.inc"
.include "src/dos/ally_marker_v21.inc"
.include "src/dos/bonus_v23.inc"
.include "src/dos/coop_v24.inc"
.include "src/dos/anti_loop_v24.inc"
.include "src/dos/bomber_v25.inc"
.include "src/dos/v027_render.inc"

.section .data
.ifdef TRACE_BUILD
trace_filename: .asciz "V16TRACE.BIN"
trace_count: .byte 0
trace_buffer: .space 2048
.endif
track23_mode: .byte 0
kills_by_type: .space 4
stage: .byte 1
/* Six original effects in a new arrangement; all durations are BIOS ticks. */
stage_tile_codes: .ascii ".#~TEPBFI"
bonus_active: .byte 0
bonus_col: .byte 0
bonus_row: .byte 0
bonus_type: .byte 0
bonus_timer: .byte 0
bonus_sequence: .byte 0
bonus_flash_type: .byte 0
bonus_flash_ticks: .byte 0
bonus_columns: .byte 2, 10, 4, 8, 1, 11, 6, 12, 5, 9, 3
bonus_drop_order: .byte 0, 6, 5, 8, 7, 9, 11, 12, 13, 1, 3, 4, 2, 10
/* Heart at second pickup, ally third; no more fixed center-row spawn. */
ally_stock: .byte 1        /* reserve V calls: max nine */
ally_call_pending: .byte 0 /* keyboard ISR, distinct from movement keys */
hq_wall_indices: .word 230, 232, 246, 248
hq_wall_columns: .byte 6, 8, 6, 8
hq_wall_rows: .byte 14, 14, 15, 15
player_upgrade: .byte 0
freeze_ticks: .byte 0
hq_shield: .byte 0
hq_originals: .space 4
hq_original_masks: .space 4
slide_ticks: .byte 0
slide_old_col: .byte 0
slide_old_row: .byte 0
sound_muted: .byte 0
adlib_present: .byte 0
palette_index: .byte 0
cga_palettes: .byte 0x20, 0x00, 0x30, 0x10
explosion_ticks: .byte 0
explosion_x: .byte 0
explosion_y: .byte 0
paint_explosion_valid: .byte 0
paint_explosion_x: .byte 0
paint_explosion_y: .byte 0
sound_ticks: .byte 0
sound_tone: .word 0
brick_masks: .space 256
test_phase: .byte 0
lives: .byte 3
score: .word 0
player_col: .byte 6
player_row: .byte 11
player_dir: .byte 0
player_shield: .byte 24
bullet_col: .byte 0
bullet_row: .byte 0
bullet_dir: .byte 0
bullet_active: .byte 0
bullet_delay: .byte 0
game_state: .byte 0
game_tick: .byte 0
enemy_ai_phase: .byte 0
only_fast: .byte 0
enemy_spawned: .byte 0
enemy_killed: .byte 0
rng_state: .word 0x51ab
last_tick: .word 0
temp_slot: .byte 0
old_col: .byte 0
old_row: .byte 0
next_col: .byte 0
next_row: .byte 0
spawn_columns: .byte 1, 7, 13
enemy_col: .space 4
enemy_row: .space 4
enemy_dir: .space 4
enemy_active: .space 4
enemy_type: .space 4
enemy_hp: .space 4
enemy_track_damage: .space 4
shot_col: .space 4
shot_row: .space 4
shot_dir: .space 7
shot_active: .space 7
shot_delay: .space 7
hud_remaining: .byte 20
/* Bonus HUD: star, helmet, grenade, shovel, clock, extra life. */
hud_bonus_ptrs: .word hud_star_icon, hud_bonus_helmet, hud_bonus_grenade, hud_bonus_shovel, hud_bonus_clock, hud_bonus_life
    .word hud_bonus_laser, hud_bonus_ally, hud_bonus_triple, hud_bonus_homing, hud_bonus_frenzy
    .word hud_bonus_pong, hud_bonus_quad, hud_bonus_super
hud_bonus_pong:
    .byte 0x3f,0xfc,0xc0,0x03,0x03,0xc0,0x0c,0x30,0x0c,0x30,0x03,0xc0,0xc0,0x03,0x3f,0xfc
hud_bonus_quad:
    .byte 0x0f,0xf0,0x0c,0x30,0xcc,0x33,0xff,0xff,0xff,0xff,0xcc,0x33,0x0c,0x30,0x0f,0xf0
hud_bonus_super:
    .byte 0x03,0xc0,0x0f,0xf0,0x3f,0xfc,0xff,0xff,0xff,0xff,0x3f,0xfc,0x0f,0xf0,0x03,0xc0
hud_bonus_laser:
    .byte 0xfc, 0x3f, 0xfc, 0x3f, 0xc0, 0x03, 0x00, 0x00, 0xfc, 0x3f, 0xc3, 0xc3, 0x0f, 0xf0, 0xff, 0xff
hud_bonus_ally:
    .byte 0x0f, 0xf0, 0x00, 0x00, 0xf0, 0x0f, 0x00, 0x00, 0x0c, 0x30, 0x0f, 0xf0, 0xc0, 0x03, 0xff, 0xff
hud_bonus_triple:
    .byte 0x0c, 0x30, 0x0c, 0x30, 0x0c, 0x30, 0x0c, 0x30, 0xcf, 0x3c, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff
hud_bonus_homing:
    .byte 0xc0, 0x03, 0x0f, 0xf0, 0x0c, 0x30, 0x0c, 0x30, 0x0c, 0x30, 0x0f, 0xf0, 0xc0, 0x03, 0xff, 0xff
hud_bonus_frenzy:
    .byte 0x0c, 0x30, 0xc0, 0x03, 0xf0, 0x0f, 0x00, 0x00, 0xc3, 0xc3, 0x0f, 0xf0, 0x3f, 0xfc, 0xff, 0xff
hud_bonus_helmet:
    .byte 0xf0, 0x0f, 0xc0, 0x03, 0x0f, 0xf0, 0x0f, 0xf0, 0x00, 0x00, 0xc0, 0x03, 0xf0, 0x0f, 0xff, 0xff
hud_bonus_grenade:
    .byte 0xfc, 0x3f, 0xc0, 0x0f, 0xf0, 0x3f, 0xc0, 0x03, 0x00, 0x00, 0x00, 0x00, 0xc0, 0x03, 0xf0, 0x0f
hud_bonus_shovel:
    .byte 0xff, 0xc3, 0xff, 0x03, 0xfc, 0x3f, 0xc0, 0xff, 0xf3, 0xff, 0xf3, 0xff, 0xc0, 0xff, 0xc0, 0xff
hud_bonus_clock:
    .byte 0xf0, 0x0f, 0xcf, 0xf3, 0x3f, 0x3c, 0x3f, 0x3c, 0x3f, 0x0c, 0x3f, 0xfc, 0xcf, 0xf3, 0xf0, 0x0f
hud_bonus_life:
    .byte 0xc3, 0xc3, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xc0, 0x03, 0xf0, 0x0f, 0xfc, 0x3f, 0xff, 0xff
tally_ptrs:
    .word tally1, tally2, tally3, tally4
tally1: .asciz "100 PTS   x00"
tally2: .asciz "200 PTS   x00"
tally3: .asciz "300 PTS   x00"
tally4: .asciz "400 PTS   x00"
pause_string: .asciz "PAUSED  P=PLAY"
score_string: .asciz "SCORE 00000"
victory_string: .asciz "STAGE CLEAR"
game_over_string: .asciz "GAME OVER"
next_string: .asciz "SPACE - NEXT"
restart_string: .asciz "R - RESTART"
tactical_auto_glyphs: .word hud_blank_icon, hud_blank_icon, hud_a_char, hud_u_char, hud_t_char, hud_o_char, hud_blank_icon, hud_blank_icon
tactical_coop_glyphs: .word hud_blank_icon,hud_blank_icon,hud_c_char,hud_o_char,hud_o_char,hud_p_char,hud_blank_icon,hud_blank_icon
brand_tanks_glyphs: .word hud_t_char, hud_a_char, hud_n_char, hud_k_char, hud_s_char
brand_copyright_glyphs: .word hud_copyright_icon, hud_digit_1, hud_digit_9, hud_digit_8, hud_digit_2
brand_basic_glyphs: .word hud_b_char, hud_u_char, hud_r_char, hud_i_char, hud_m_char
brand_version_glyphs: .word hud_v_char, hud_digit_0, hud_dot_char, hud_digit_2, hud_digit_7
tactical_manual_glyphs: .word hud_t_char, hud_a_char, hud_b_char, hud_dash_char, hud_a_char, hud_u_char, hud_t_char, hud_o_char
/* Pixel world coordinates, retained alongside coarse tile positions. */
bullet_substeps: .byte 0
shot_substeps: .byte 0
projectile_bit: .byte 0
keyboard_installed: .byte 0
old_int9_off: .word 0
old_int9_seg: .word 0
held_keys: .byte 0
manual_keys: .byte 0
pending_commands: .byte 0
test_mode: .byte 0
player_px: .byte 112
player_py: .byte 168
enemy_px: .space 4
enemy_py: .space 4
bullet_px: .byte 0
bullet_py: .byte 0
shot_px: .space 7
shot_py: .space 7
candidate_x: .byte 0
candidate_y: .byte 0
probe_x_original: .byte 0
probe_col: .byte 0
probe_row: .byte 0
probe_yrem: .byte 0
rect_x0: .byte 0
rect_x1: .byte 0
rect_y0: .byte 0
rect_y1: .byte 0
scan_x: .byte 0
scan_y: .byte 0
scan_bank: .word 0
/* y in 0..191; byte: high nibble tile row, low nibble y%12.
   Out-of-range y in 192..255 is clamped to row 15 for sprite restores. */
.p2align 1
pixel_y_tile_lookup:
.set y_lookup,0
.rept 256
    .if y_lookup < 192
        .byte (((y_lookup / 12) << 4) | (y_lookup % 12))
    .else
        .byte 0xf0
    .endif
    .set y_lookup,y_lookup+1
.endr
.p2align 1
cga_scanline_offsets:
.set scan_lookup,0
.rept 192
    .word ((scan_lookup / 2) * 80 + (scan_lookup & 1) * 8192)
    .set scan_lookup,scan_lookup+1
.endr
dirty_tiles: .space 256
upload_tiles: .space 256
frame_seg: .word 0xb800
paint_player_valid: .byte 0
paint_player_x: .byte 0
paint_player_y: .byte 0
paint_bullet_valid: .byte 0
paint_bullet_x: .byte 0
paint_bullet_y: .byte 0
paint_bonus_valid: .byte 0
paint_bonus_x: .byte 0
paint_bonus_y: .byte 0
paint_enemy_valid: .space 4
paint_enemy_x: .space 4
paint_enemy_y: .space 4
paint_shot_valid: .space 7
paint_shot_x: .space 7
paint_shot_y: .space 7
level_data: .space 256
.include "src/dos/cga_assets.inc"

/* First free byte of this .COM. DOS stack is positioned 4K above it. */
program_end:
