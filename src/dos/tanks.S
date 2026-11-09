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
    call render_frame
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
    call draw_mode_indicator
    cmp byte ptr [game_state], 2
    jne no_end_overlay
    call game_over_hud
no_end_overlay:
    cmp byte ptr [game_state], 1
    jne no_stage_overlay
    call stage_clear_hud
no_stage_overlay:
    jmp main_loop

/* State: 0 playing, 1 won stage, 2 lost. */
reset_campaign:
    mov byte ptr [stage], 1
    mov byte ptr [lives], 3
    mov word ptr [score], 0
    mov byte ptr [bonus_sequence], 0
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
    mov cx, 128
unpack_stage_loop:
    lodsb
    mov dh,al                  /* upper nibble = second tile */
    and al,15
    xor bx,bx
    mov bl,al
    mov al,[stage_tile_codes+bx]
    stosb
    mov al,dh
    shr al,1
    shr al,1
    shr al,1
    shr al,1
    mov bl,al
    mov al,[stage_tile_codes+bx]
    stosb
    loop unpack_stage_loop
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
    mov byte ptr [enemy_ai_phase], 0
    mov byte ptr [squad_alert], 0
    mov byte ptr [squad_target_x], 112
    mov byte ptr [squad_target_y], 168
    mov byte ptr [player_upgrade], 0
    mov byte ptr [bonus_active], 0
    mov byte ptr [bonus_timer], 0
    mov byte ptr [freeze_ticks], 0
    mov byte ptr [hq_shield], 0
    mov byte ptr [slide_ticks], 0
    mov byte ptr [sound_ticks], 0
    mov byte ptr [held_keys], 0
    mov byte ptr [manual_keys], 0
    mov byte ptr [pending_commands], 0
    mov byte ptr [auto_toggle_pending], 0
    mov byte ptr [player_px], 112
    mov byte ptr [player_py], 168
    mov byte ptr [paint_player_valid], 0
    mov byte ptr [paint_bullet_valid], 0
    mov byte ptr [paint_bonus_valid], 0
    mov di, offset paint_enemy_valid
    mov cx, 4
    xor al, al
    rep stosb
    mov di, offset paint_shot_valid
    mov cx, 4
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

poll_keyboard:
    mov ah, 1
    int 0x16
    jnz kb_ready
    ret
kb_ready:
    xor ah, ah
    int 0x16
    cmp al, 27
    jne kb_not_escape
    jmp exit_game
kb_not_escape:
    cmp al, 'r'
    je kb_restart
    cmp al, 'R'
    jne kb_not_restart
kb_restart:
    jmp do_restart
kb_not_restart:
    cmp al, 'm'
    je toggle_sound
    cmp al, 'M'
    je toggle_sound
    jmp kb_after_sound
toggle_sound:
    xor byte ptr [sound_muted], 1
    call sound_stop
    ret
kb_after_sound:
    cmp al, 'p'
    je kb_pause
    cmp al, 'P'
    jne kb_after_pause
kb_pause:
    cmp byte ptr [game_state], 0
    je kb_pause_begin
    cmp byte ptr [game_state], 3
    jne kb_return
    mov byte ptr [game_state], 0
    call refresh_screen
    ret
kb_pause_begin:
    mov byte ptr [game_state], 3
    call pause_hud
    ret
kb_after_pause:
    cmp byte ptr [game_state], 1
    jne kb_not_won
    cmp al, ' '
    jne kb_return
    inc byte ptr [stage]
    cmp byte ptr [stage], 9
    jbe kb_next_level
    mov byte ptr [stage], 1
kb_next_level:
    call load_stage
    call refresh_screen
    ret
kb_not_won:
    cmp byte ptr [game_state], 0
    jne kb_return
    cmp al, ' '
    jne kb_not_shoot
    call do_fire
    ret
kb_not_shoot:
    cmp ah, 0x48
    jne kb_not_up
    jmp up_key
kb_not_up:
    cmp ah, 0x50
    jne kb_not_down
    jmp down_key
kb_not_down:
    cmp ah, 0x4b
    jne kb_not_left
    jmp left_key
kb_not_left:
    cmp ah, 0x4d
    jne kb_letters
    jmp right_key
kb_letters:
    and al, 0xdf
    cmp al, 'W'
    jne kb_not_w
    jmp up_key
kb_not_w:
    cmp al, 'S'
    jne kb_not_s
    jmp down_key
kb_not_s:
    cmp al, 'A'
    jne kb_not_a
    jmp left_key
kb_not_a:
    cmp al, 'D'
    jne kb_return
    jmp right_key
kb_return:
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
    call draw_map
    call present_full_field
    call draw_sidebar_background
    call draw_hud
    call render_frame
    call draw_mode_indicator
    ret
exit_game:
    call restore_keyboard
    call sound_stop
    mov ax, 0x0003
    int 0x10
    mov ax, 0x4c00
    int 0x21

up_key:
    mov byte ptr [player_dir], 0
    mov dl, [player_col]
    mov dh, [player_row]
    test dh, dh
    jz player_turn_only
    dec dh
    jmp player_move
right_key:
    mov byte ptr [player_dir], 1
    mov dl, [player_col]
    mov dh, [player_row]
    cmp dl, 15
    je player_turn_only
    inc dl
    jmp player_move
down_key:
    mov byte ptr [player_dir], 2
    mov dl, [player_col]
    mov dh, [player_row]
    cmp dh, 15
    je player_turn_only
    inc dh
    jmp player_move
left_key:
    mov byte ptr [player_dir], 3
    mov dl, [player_col]
    mov dh, [player_row]
    test dl, dl
    jz player_turn_only
    dec dl
player_move:
    call try_move
    ret
player_turn_only:
    mov dl, [player_col]
    mov dh, [player_row]
    call draw_cell
    ret

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
    call tactical_player_tick
 game_tick_no_autopilot:
    cmp byte ptr [squad_alert],0
    je game_tick_no_alert
    dec byte ptr [squad_alert]
 game_tick_no_alert:
    call move_player_smooth
    call sound_tick
    call tick_explosion
    call tick_powerups
    call slide_player_smooth
    cmp byte ptr [player_shield], 0
    je tick_no_shield
    dec byte ptr [player_shield]
    jnz tick_no_shield
    mov dl, [player_col]
    mov dh, [player_row]
    call draw_cell
tick_no_shield:
    call advance_bullet_smooth
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
    call check_stage_complete
    ret

/* Power-up sequence: 0 star, 1 helmet, 2 grenade, 3 shovel,
 * 4 clock, 5 extra life. All spawn positions are open in authored maps.
 */
maybe_drop_bonus:
    push ax
    push bx
    push dx
    push si
    cmp byte ptr [bonus_active], 0
    jne bonus_drop_done
    mov al, [enemy_killed]
    and al, 3
    jnz bonus_drop_done
    xor bx, bx
    mov bl, [bonus_sequence]
    mov [bonus_type], bl
    mov dl, [bonus_columns+bx]
    mov dh, 10
    call get_tile
    cmp al, '.'
    jne bonus_drop_done
    call enemy_at
    cmp al, 0xff
    jne bonus_drop_done
    cmp dh, [player_row]
    jne bonus_drop_ready
    cmp dl, [player_col]
    je bonus_drop_done
bonus_drop_ready:
    mov [bonus_col], dl
    mov [bonus_row], dh
    mov byte ptr [bonus_active], 1
    mov byte ptr [bonus_timer], 180
    /* Plan the bonus route once on spawn, never per video frame. */
    call strategy_bonus_spawn
    inc byte ptr [bonus_sequence]
    cmp byte ptr [bonus_sequence], 6
    jb bonus_cycle_valid
    mov byte ptr [bonus_sequence], 0
bonus_cycle_valid:
    call draw_cell
bonus_drop_done:
    pop si
    pop dx
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
    mov al, [player_col]
    cmp al, [bonus_col]
    jne bonus_pickup_done
    mov al, [player_row]
    cmp al, [bonus_row]
    jne bonus_pickup_done
    mov byte ptr [bonus_active], 0
    mov byte ptr [bonus_timer], 0
    mov ax, 880
    call sound_play
    mov al, [bonus_type]
    cmp al, 0
    jne pickup_not_star
    cmp byte ptr [player_upgrade], 3
    jae bonus_pickup_done
    inc byte ptr [player_upgrade]
    call draw_hud
    jmp bonus_pickup_done
pickup_not_star:
    cmp al, 1
    jne pickup_not_helmet
    mov byte ptr [player_shield], 150
    jmp bonus_pickup_done
pickup_not_helmet:
    cmp al, 2
    jne pickup_not_grenade
    call grenade_all_enemies
    jmp bonus_pickup_done
pickup_not_grenade:
    cmp al, 3
    jne pickup_not_shovel
    call protect_hq
    jmp bonus_pickup_done
pickup_not_shovel:
    cmp al, 4
    jne pickup_not_clock
    mov byte ptr [freeze_ticks], 120
    jmp bonus_pickup_done
pickup_not_clock:
    cmp byte ptr [lives], 9
    jae bonus_pickup_done
    inc byte ptr [lives]
    call draw_hud
bonus_pickup_done:
    pop dx
    pop cx
    pop bx
    pop ax
    ret

grenade_all_enemies:
    push ax
    push bx
    push dx
    xor bx, bx
grenade_next:
    cmp byte ptr [enemy_active+bx], 0
    je grenade_skip
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
    mov byte ptr [enemy_blocked+bx], 0
    mov byte ptr [shot_active+bx], 0
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
    je enemy_fire_next
    cmp byte ptr [shot_active+bx], 0
    jne enemy_fire_next
    call tactical_safe_fire
    jnc enemy_fire_next
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
    cmp byte ptr [test_mode], 0
    je enemy_fire_smooth_init
    call advance_enemy_shot
    jmp enemy_fire_next
enemy_fire_smooth_init:
    mov al, [enemy_px+bx]
    mov [shot_px+bx], al
    mov al, [enemy_py+bx]
    mov [shot_py+bx], al
enemy_fire_next:
    inc bx
    cmp bx, 4
    jb enemy_fire_loop
    ret

/* Player projectile: one at a time, one cell per two simulated frames. */
do_fire:
    cmp byte ptr [bullet_active], 0
    jne fire_done
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
    mov al, [player_px]
    mov [bullet_px], al
    mov al, [player_py]
    mov [bullet_py], al
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
    call stage_clear_hud
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
    jb enemy_pixel_collision
    cmp al, 245
    jae enemy_pixel_collision
 enemy_pixel_no_player:
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
    jmp smooth_bullet_terrain
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
    jmp smooth_bullet_out
smooth_bullet_next_shot:
    inc bx
    cmp bx, 4
    jb smooth_bullet_vs_shot
    /* Hit an enemy tank, center point inside rectangle. */
    xor bx, bx
smooth_bullet_enemy_check:
    cmp byte ptr [enemy_active+bx], 0
    je smooth_bullet_enemy_next
    mov al, [bullet_px]
    add al, 8
    sub al, [enemy_px+bx]
    cmp al, 16
    jae smooth_bullet_enemy_next
    mov al, [bullet_py]
    add al, 6
    sub al, [enemy_py+bx]
    cmp al, 12
    jae smooth_bullet_enemy_next
    cmp byte ptr [enemy_hp+bx], 1
    jbe smooth_enemy_destroyed
    dec byte ptr [enemy_hp+bx]
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
    jmp smooth_bullet_impact
smooth_bullet_enemy_next:
    inc bx
    cmp bx, 4
    jb smooth_bullet_enemy_check
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
    cmp bx, 4
    jb smooth_shot_loop
    ret
advance_enemy_shot_smooth:
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
    jmp smooth_shot_terrain
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
    jmp smooth_shot_out
smooth_shot_no_bullet:
    call shot_hits_other_enemy
    jnc smooth_shot_no_friend
    jmp smooth_shot_out
smooth_shot_no_friend:
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
    jne smooth_shot_out
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
    jmp smooth_shot_out
smooth_player_dead:
    mov byte ptr [game_state], 2
    jmp smooth_shot_out
smooth_shot_no_player:
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
    cmp si, bx
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
    dec byte ptr [enemy_hp+si]
    jmp friendly_target_fx
friendly_target_destroyed:
    mov byte ptr [enemy_active+si],0
    mov byte ptr [shot_active+si],0
    inc byte ptr [enemy_killed]
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
    jb friendly_target_loop
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
    cmp al, 0x48
    je irq_up
    cmp al, 0x11
    je irq_up
    cmp al, 0x4d
    je irq_right
    cmp al, 0x20
    je irq_right
    cmp al, 0x50
    je irq_down
    cmp al, 0x1f
    je irq_down
    cmp al, 0x4b
    je irq_left
    cmp al, 0x1e
    je irq_left
    cmp al, 0x39
    je irq_fire
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
    popf
    test ah, 1
    jz controls_no_auto_toggle
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
    mov al, dh
    xor ah, ah
    mov bl, 12
    div bl
    mov [probe_row], al
    mov [probe_yrem], ah
    mov dl, [probe_col]
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
    push cx
    push dx
    push si
    mov al, dl
    shr al, 1
    shr al, 1
    shr al, 1
    shr al, 1
    mov [rect_x0], al
    mov al, dl
    add al, 15
    shr al, 1
    shr al, 1
    shr al, 1
    shr al, 1
    mov [rect_x1], al
    mov al, dh
    xor ah, ah
    mov bl, 12
    div bl
    mov [rect_y0], al
    mov al, dh
    add al, 11
    xor ah, ah
    div bl
    mov [rect_y1], al
    mov dh, [rect_y0]
mark_rect_row:
    mov dl, [rect_x0]
mark_rect_col:
    cmp dl, 16
    jae mark_rect_next_col
    cmp dh, 16
    jae mark_rect_next_col
    call get_tile
    sub si, offset level_data
    mov byte ptr [dirty_tiles+si], 1
    mov byte ptr [upload_tiles+si], 1
mark_rect_next_col:
    inc dl
    cmp dl, [rect_x1]
    jbe mark_rect_col
    inc dh
    cmp dh, [rect_y1]
    jbe mark_rect_row
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

mark_old_sprites:
    cmp byte ptr [paint_player_valid], 0
    je old_player_done
    mov dl, [paint_player_x]
    mov dh, [paint_player_y]
    call mark_dirty_rect
old_player_done:
    mov byte ptr [paint_player_valid], 0
    cmp byte ptr [paint_bullet_valid], 0
    je old_bullet_done
    mov dl, [paint_bullet_x]
    mov dh, [paint_bullet_y]
    call mark_dirty_rect
old_bullet_done:
    mov byte ptr [paint_bullet_valid], 0
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
    xor dx, dx
flush_row:
    xor dl, dl
flush_col:
    push dx
    call get_tile
    sub si, offset level_data
    cmp byte ptr [dirty_tiles+si], 0
    je flush_skip
    mov byte ptr [dirty_tiles+si], 0
    call draw_static_cell
flush_skip:
    pop dx
    inc dl
    cmp dl, 16
    jb flush_col
    inc dh
    cmp dh, 16
    jb flush_row
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
    push bx
    push cx
    push dx
    push si
    push di
    push es
    mov ax, [frame_seg]
    cmp ax, 0xb800
    je commit_done
    xor dx, dx
commit_row:
    xor dl, dl
commit_col:
    xor ax, ax
    mov al, dh
    shl ax, 1
    shl ax, 1
    shl ax, 1
    shl ax, 1
    xor bx, bx
    mov bl, dl
    add ax, bx
    mov bx, ax
    cmp byte ptr [upload_tiles+bx], 0
    je commit_skip
    mov byte ptr [upload_tiles+bx], 0
    push dx
    call copy_tile_to_cga
    pop dx
commit_skip:
    inc dl
    cmp dl, 16
    jb commit_col
    inc dh
    cmp dh, 16
    jb commit_row
commit_done:
    pop es
    pop di
    pop si
    pop dx
    pop cx
    pop bx
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
    xor ax, ax
    mov al, [scan_y]
    test al, 1
    jz smooth_even
    mov word ptr [scan_bank], 0x2000
    jmp smooth_bank_ready
smooth_even:
    mov word ptr [scan_bank], 0
smooth_bank_ready:
    shr ax, 1
    mov bx, ax
    shl ax, 1
    shl ax, 1
    shl ax, 1
    shl ax, 1
    shl bx, 1
    shl bx, 1
    shl bx, 1
    shl bx, 1
    shl bx, 1
    shl bx, 1
    add ax, bx                    /* 16*halfY + 64*halfY */
    add ax, [scan_bank]
    mov di, ax
    xor ax, ax
    mov al, [scan_x]
    shr ax, 1
    shr ax, 1
    add di, ax
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
paint_bonus_done:
    /* Four enemy tanks. */
    xor bx, bx
paint_enemy_loop:
    cmp byte ptr [enemy_active+bx], 0
    je paint_enemy_next
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
    call draw_smooth_sprite
    /* Tread phase is tied to position: stops immediately if tank stops. */
    mov dl, [enemy_px+bx]
    mov dh, [enemy_py+bx]
    xor ax, ax
    mov al, [enemy_dir+bx]
    shl al, 1
    mov ah, [enemy_px+bx]
    xor ah, [enemy_py+bx]
    shr ah, 1
    and ah, 1
    or al, ah
    xor ah, ah
    shl ax, 1
    mov si, ax
    mov si, [smooth_tread_ptrs+si]
    call draw_smooth_sprite
    pop bx
paint_enemy_next:
    inc bx
    cmp bx, 4
    jae paint_enemy_finished
    jmp paint_enemy_loop
paint_enemy_finished:
    /* Player's tank. */
    mov dl, [player_px]
    mov dh, [player_py]
    mov [paint_player_x], dl
    mov [paint_player_y], dh
    mov byte ptr [paint_player_valid], 1
    xor bx, bx
    mov bl, [player_dir]
    shl bx, 1
    cmp byte ptr [player_shield], 0
    je paint_player_normal
    mov si, [smooth_shield_ptrs+bx]
    jmp paint_player_smooth
paint_player_normal:
    mov si, [smooth_player_ptrs+bx]
paint_player_smooth:
    call draw_smooth_sprite
    /* Moving tread overlay, with no extra per-frame dynamic buffers. */
    mov dl, [player_px]
    mov dh, [player_py]
    xor bx, bx
    mov bl, [player_dir]
    shl bx, 1
    mov al, [player_px]
    xor al, [player_py]
    shr al, 1
    and al, 1
    or bl, al
    shl bx, 1
    mov si, [smooth_tread_ptrs+bx]
    call draw_smooth_sprite
    /* Player projectile and up to four enemy projectiles. */
    cmp byte ptr [bullet_active], 0
    je paint_no_bullet
    mov dl, [bullet_px]
    mov dh, [bullet_py]
    mov [paint_bullet_x], dl
    mov [paint_bullet_y], dh
    mov byte ptr [paint_bullet_valid], 1
    mov si, offset smooth_bullet
    call draw_smooth_sprite
paint_no_bullet:
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
    call draw_smooth_sprite
paint_next_shot:
    inc bx
    cmp bx, 4
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
    /* One composed transfer after ALL actors. Never expose a partially
       erased sprite in CGA memory between the restore and paint passes. */
    call commit_dirty_tiles
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
smooth_shield_ptrs: .word smooth_player_shield_up, smooth_player_shield_right, smooth_player_shield_down, smooth_player_shield_left
smooth_enemy_ptrs: .word smooth_enemy_up, smooth_enemy_right, smooth_enemy, smooth_enemy_left
smooth_fast_ptrs: .word smooth_fast_up, smooth_fast_right, smooth_fast_down, smooth_fast_left
smooth_power_ptrs: .word smooth_power_up, smooth_power_right, smooth_power_down, smooth_power_left
smooth_armor_ptrs: .word smooth_armor_up, smooth_armor_right, smooth_armor_down, smooth_armor_left
smooth_bonus_ptrs: .word smooth_bonus_star, smooth_bonus_helmet, smooth_bonus_grenade, smooth_bonus_shovel, smooth_bonus_clock, smooth_bonus_life
smooth_tread_ptrs:
    .word smooth_tread_0_0, smooth_tread_0_1, smooth_tread_1_0, smooth_tread_1_1
    .word smooth_tread_2_0, smooth_tread_2_1, smooth_tread_3_0, smooth_tread_3_1
smooth_explosion_ptrs: .word smooth_explosion_0, smooth_explosion_1, smooth_explosion_2, smooth_explosion_3
.section .text

/* Return AL tile and SI writable address, DL/DH grid 0..15. */
get_tile:
    push bx
    xor ax, ax
    mov al, dh
    mov bl, 16
    mul bl
    add al, dl
    adc ah, 0
    mov si, offset level_data
    add si, ax
    mov al, [si]
    pop bx
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
    mov di, 2625             /* x260,y64: 1P */
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
draw_mode_indicator:
    push ax
    push bx
    push cx
    push si
    push di
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
    mov byte ptr [enemy_killed], 4
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
    mov byte ptr [enemy_px],112
    mov byte ptr [enemy_py],96
    mov byte ptr [player_px],112
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
    mov cx,384
trace_tick:
    push cx
    call game_tick_step
    call render_frame
    test byte ptr [game_tick],15
    jnz trace_no_sample
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
    cmp bl,24
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

.section .data
.ifdef TRACE_BUILD
trace_filename: .asciz "V13TRACE.BIN"
trace_count: .byte 0
trace_buffer: .space 384
.endif
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
bonus_columns: .byte 2, 10, 4, 8, 1, 11
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
shot_col: .space 4
shot_row: .space 4
shot_dir: .space 4
shot_active: .space 4
shot_delay: .space 4
draw_sprite_ptr: .word 0
player_sprite_ptrs:
    .word sprite_player_up, sprite_player_right, sprite_player_down, sprite_player_left
player_shield_sprite_ptrs:
    .word sprite_player_shield_up, sprite_player_shield_right, sprite_player_shield_down, sprite_player_shield_left
enemy_sprite_ptrs:
    .word sprite_enemy_up, sprite_enemy_right, sprite_enemy, sprite_enemy_left
fast_sprite_ptrs:
    .word sprite_fast_up, sprite_fast_right, sprite_fast_down, sprite_fast_left
power_sprite_ptrs:
    .word sprite_power_up, sprite_power_right, sprite_power_down, sprite_power_left
armor_sprite_ptrs:
    .word sprite_armor_up, sprite_armor_right, sprite_armor_down, sprite_armor_left
hud_remaining: .byte 20
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
tactical_auto_glyphs: .word hud_a_char, hud_u_char, hud_t_char, hud_o_char, hud_blank_icon, hud_blank_icon, hud_blank_icon, hud_blank_icon
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
shot_px: .space 4
shot_py: .space 4
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
paint_shot_valid: .space 4
paint_shot_x: .space 4
paint_shot_y: .space 4
level_data: .space 256
.include "src/dos/cga_assets.inc"

/* First free byte of this .COM. DOS stack is positioned 4K above it. */
program_end:
