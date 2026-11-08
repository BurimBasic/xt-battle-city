/* XT Battle City v0.4: original CGA tile arcade for DOS, 8086/8088.
 * Gameplay: 20-enemy waves, 4 tank classes, segmented bricks, 6 pickups,
 * destructible bricks, lives, headquarters, score and stage transitions.
 * 16x12 CGA cells, 13x13 battlefield. Original artwork and stage layouts.
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
    call reset_campaign
    mov ax, 0x0004
    int 0x10
    mov ax, 0x0b00
    mov bx, 0x0101
    int 0x10
    call draw_map
    call draw_sidebar_background
    call draw_hud
    /* Invocation: TANKS.COM /TEST (six command-line chars). */
    cmp byte ptr [0x80], 6
    jne normal_start
    cmp byte ptr [0x82], '/'
    jne normal_start
    cmp byte ptr [0x83], 'T'
    jne normal_start
    jmp smoke_test
normal_start:
    mov ah, 0
    int 0x1a
    mov word ptr [last_tick], dx
main_loop:
    call poll_keyboard
    mov ah, 0
    int 0x1a
    cmp dx, [last_tick]
    je main_loop
    mov [last_tick], dx
    cmp byte ptr [game_state], 0
    jne main_loop
    call game_tick_step
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
    mov cx, 169
    rep movsb
    pop es
    /* Strip static E/P markers, replace with dynamic entities. */
    mov di, offset level_data
    mov cx, 169
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
    mov byte ptr [player_col], 6
    mov byte ptr [player_row], 11
    mov byte ptr [player_dir], 0
    mov byte ptr [player_shield], 24
    mov byte ptr [bullet_active], 0
    mov byte ptr [bullet_delay], 0
    mov byte ptr [enemy_spawned], 0
    mov byte ptr [enemy_killed], 0
    mov byte ptr [game_state], 0
    mov byte ptr [game_tick], 0
    mov byte ptr [enemy_ai_phase], 0
    mov byte ptr [player_upgrade], 0
    mov byte ptr [bonus_active], 0
    mov byte ptr [bonus_timer], 0
    mov byte ptr [freeze_ticks], 0
    mov byte ptr [hq_shield], 0
    mov byte ptr [slide_ticks], 0
    mov byte ptr [sound_ticks], 0
    mov si, offset level_data
    mov di, offset brick_masks
    mov cx, 169
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
    mov di, offset enemy_active
    mov cx, 4
    xor al, al
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
    call draw_sidebar_background
    call draw_hud
    ret
exit_game:
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
    cmp dl, 12
    je player_turn_only
    inc dl
    jmp player_move
down_key:
    mov byte ptr [player_dir], 2
    mov dl, [player_col]
    mov dh, [player_row]
    cmp dh, 12
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
    call sound_tick
    call tick_powerups
    call slide_player
    cmp byte ptr [player_shield], 0
    je tick_no_shield
    dec byte ptr [player_shield]
    jnz tick_no_shield
    mov dl, [player_col]
    mov dh, [player_row]
    call draw_cell
tick_no_shield:
    call advance_bullet
    cmp byte ptr [freeze_ticks], 0
    jne tick_frozen
    call update_enemy_bullets
    test byte ptr [game_tick], 3
    jnz tick_no_ai
    mov byte ptr [only_fast], 0
    call move_enemies
    call enemy_fire_cycle
tick_no_ai:
    mov al, [game_tick]
    and al, 3
    cmp al, 2
    jne tick_no_fast
    mov byte ptr [only_fast], 1
    call move_enemies
tick_no_fast:
    test byte ptr [game_tick], 7
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
sound_play:
    push ax
    push bx
    push dx
    cmp byte ptr [sound_muted], 0
    jne sound_play_done
    mov bx, ax
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
    jne spawn_abort
    call enemy_at
    cmp al, 0xff
    jne spawn_abort
    cmp dl, [player_col]
    jne spawn_ready
    cmp dh, [player_row]
    je spawn_abort
spawn_ready:
    xor bx, bx
    mov bl, [temp_slot]
    mov [enemy_col+bx], dl
    mov [enemy_row+bx], dh
    mov byte ptr [enemy_dir+bx], 2
    mov al, [enemy_spawned]
    and al, 3
    mov [enemy_type+bx], al
    mov byte ptr [enemy_hp+bx], 1
    cmp al, 3
    jne spawn_basic_health
    mov byte ptr [enemy_hp+bx], 4
spawn_basic_health:
    mov byte ptr [enemy_active+bx], 1
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
    cmp al, 13
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
    cmp dl, 12
    je enemy_move_next
    inc dl
    jmp enemy_target
enemy_not_right:
    cmp al, 2
    jne enemy_not_down
    cmp dh, 12
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
    call advance_enemy_shot
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
    mov ax, 1250
    call sound_play
    call advance_bullet
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
    cmp dl, 12
    je pos_off
    inc dl
    clc
    ret
pos_not_right:
    cmp al, 2
    jne pos_not_down
    cmp dh, 12
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
    mov byte ptr [player_col], 6
    mov byte ptr [player_row], 11
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
    mov di, 1128             /* y28 /2 *80 + x32/4 */
    mov bx, 64               /* 128 physical scan lines */
stage_box_row:
    push di
    mov cx, 26
    rep stosw
    pop di
    push di
    add di, 0x2000
    mov cx, 26
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
    mov dl, 12
    mov dh, 10
    call cursor_at
    mov si, offset game_over_string
    call bios_string
    mov dl, 11
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
    mov di, 2888             /* (72/2)*80 + 32/4 */
    mov bx, 32               /* 64 physical scan lines */
result_box_row:
    push di
    mov cx, 26               /* 208 pixels = 52 bytes */
    rep stosw
    pop di
    push di
    add di, 0x2000
    mov cx, 26
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

/* Return AL tile and SI writable address, DL/DH grid 0..12. */
get_tile:
    push bx
    xor ax, ax
    mov al, dh
    mov bl, 13
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
    call draw_cell
    pop dx
    inc dl
    cmp dl, 13
    jb map_col
    inc dh
    cmp dh, 13
    jb map_row
    ret

/* DL/DH cell; preserve all regs used by callers. */
draw_cell:
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    call get_tile
    mov si, offset sprite_empty
    cmp al, '#'
    jne draw_not_brick
    push bx
    mov bx, si
    sub bx, offset level_data
    xor ax, ax
    mov al, [brick_masks+bx]
    shl ax, 1
    mov bx, ax
    mov si, [brick_sprite_ptrs+bx]
    pop bx
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
    push si
    call enemy_at
    cmp al, 0xff
    je draw_no_enemy
    xor bx, bx
    mov bl, al
    xor cx, cx
    mov cl, [enemy_dir+bx]
    shl cx, 1
    mov si, cx
    cmp byte ptr [enemy_type+bx], 1
    jne draw_enemy_not_fast
    mov si, [fast_sprite_ptrs+si]
    jmp draw_enemy_selected
draw_enemy_not_fast:
    cmp byte ptr [enemy_type+bx], 2
    jne draw_enemy_not_power
    mov si, [power_sprite_ptrs+si]
    jmp draw_enemy_selected
draw_enemy_not_power:
    cmp byte ptr [enemy_type+bx], 3
    jne draw_enemy_normal
    mov si, [armor_sprite_ptrs+si]
    jmp draw_enemy_selected
draw_enemy_normal:
    mov si, [enemy_sprite_ptrs+si]
draw_enemy_selected:
draw_no_enemy:
    mov [draw_sprite_ptr], si
    pop si
    cmp byte ptr [bonus_active], 0
    je draw_no_bonus
    cmp dl, [bonus_col]
    jne draw_no_bonus
    cmp dh, [bonus_row]
    jne draw_no_bonus
    push bx
    xor bx, bx
    mov bl, [bonus_type]
    shl bx, 1
    mov si, [bonus_sprite_ptrs+bx]
    mov [draw_sprite_ptr], si
    pop bx
draw_no_bonus:
    cmp dl, [player_col]
    jne draw_not_player
    cmp dh, [player_row]
    jne draw_not_player
    xor bx, bx
    mov bl, [player_dir]
    shl bx, 1
    cmp byte ptr [player_shield], 0
    jne draw_player_shielded
    mov si, [player_sprite_ptrs+bx]
    jmp draw_player_sprite
draw_player_shielded:
    mov si, [player_shield_sprite_ptrs+bx]
draw_player_sprite:
    mov [draw_sprite_ptr], si
draw_not_player:
    cmp byte ptr [bullet_active], 0
    je draw_no_player_bullet
    cmp dl, [bullet_col]
    jne draw_no_player_bullet
    cmp dh, [bullet_row]
    jne draw_no_player_bullet
    mov word ptr [draw_sprite_ptr], offset sprite_bullet
draw_no_player_bullet:
    xor bx, bx
draw_enemy_bullet_loop:
    cmp byte ptr [shot_active+bx], 0
    je draw_enemy_bullet_next
    cmp dl, [shot_col+bx]
    jne draw_enemy_bullet_next
    cmp dh, [shot_row+bx]
    jne draw_enemy_bullet_next
    mov word ptr [draw_sprite_ptr], offset sprite_enemy_bullet
    jmp draw_final
draw_enemy_bullet_next:
    inc bx
    cmp bx, 4
    jb draw_enemy_bullet_loop
draw_final:
    mov si, [draw_sprite_ptr]
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
    mov ax, 0xb800
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
 * The 13x13 map is drawn at x32..239, sidebar starts at x248.
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
    mov di, 62               /* x248 / 4 pixels per byte */
    mov bx, 100              /* 100 even/odd pairs = 200 scanlines */
sidebar_row:
    push di
    mov cx, 9                /* 72px = 18 bytes = 9 words */
    rep stosw
    pop di
    push di
    add di, 0x2000
    mov cx, 9
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
    mov cl, 2
    div cl
    mov dl, ah               /* odd index -> second icon column */
    xor ah, ah
    shl ax, 1
    mov si, ax
    mov di, [hud_indicator_offsets+si]
    test dl, dl
    jz hud_enemy_first_column
    add di, 6                /* x280 (24 px to right) */
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
    mov di, 4864             /* x256, y120  (1P) */
    mov al, 1
    call draw_hud_digit
    mov di, 4866             /* x264, y120 */
    mov si, offset hud_p_char
    call draw_hud_glyph
    mov di, 5504             /* x256, y136  (x2) */
    mov si, offset hud_x_char
    call draw_hud_glyph
    mov al, [lives]
    test al, al
    jz hud_lives_zero
    dec al                    /* NES HUD shows lives in reserve */
hud_lives_zero:
    mov di, 5506
    call draw_hud_digit
    cmp byte ptr [player_upgrade], 0
    je hud_no_upgrade
    mov di, 5510             /* x280, y136: star power indicator */
    mov si, offset hud_star_icon
    call draw_hud_glyph
    mov al, [player_upgrade]
    mov di, 5512             /* x288, y136: upgrade level */
    call draw_hud_digit
hud_no_upgrade:
    mov di, 6464             /* x256, y160: stage flag */
    mov si, offset hud_flag_icon
    call draw_hud_glyph
    mov al, [stage]
    xor ah, ah
    mov bl, 10
    div bl
    mov di, 7104             /* x256, y176: two stage digits */
    call draw_hud_digit
    mov al, ah
    mov di, 7106
    call draw_hud_digit
    pop si
    pop di
    pop dx
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
    /* Verify real B800: CGA sidebar data, not just generated source assets. */
    mov byte ptr [test_phase], 10
    push es
    mov ax, 0xb800
    mov es, ax
    cmp word ptr es:[62], 0xffff       /* white first panel scanline */
    je smoke_white_ok
    pop es
    jmp smoke_fail
smoke_white_ok:
    mov ax, [hud_tank_icon]            /* first active marker at x256,y16 */
    cmp word ptr es:[704], ax          /* (16/2)*80 + 256/4 */
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
    mov dl, 6
    mov dh, 10
    call try_move
    cmp byte ptr [player_row], 10
    je test_move1
    jmp smoke_fail
test_move1:
    mov byte ptr [test_phase], 3
    mov dl, 6
    mov dh, 9
    call try_move
    cmp byte ptr [player_row], 9
    je test_move2
    jmp smoke_fail
test_move2:
    mov byte ptr [test_phase], 4
    mov dl, 6
    mov dh, 8
    call try_move
    cmp byte ptr [player_row], 9
    je test_blocked
    jmp smoke_fail
test_blocked:
    mov byte ptr [test_phase], 5
    /* Advance player bullet at row 9 col 6 through brick at col 9. */
    mov byte ptr [player_dir], 1
    call do_fire
    mov cx, 12
test_bullet_loop:
    push cx
    call advance_bullet
    pop cx
    loop test_bullet_loop
    /* One hit destroys only the entry-side half of the brick. */
    cmp byte ptr [level_data+126], '#'
    jne test_failed_jump_far
    cmp byte ptr [brick_masks+126], 10
    jne test_failed_jump_far
    /* A second shot removes the remaining half. */
    call do_fire
    mov cx, 12
test_bullet_again:
    push cx
    call advance_bullet
    pop cx
    loop test_bullet_again
    cmp byte ptr [level_data+126], '.'
    je test_brick
    jmp smoke_fail
test_failed_jump_far:
    jmp smoke_fail
test_brick:
    mov byte ptr [test_phase], 6
    mov byte ptr [player_row], 11
    mov byte ptr [player_col], 6
    mov byte ptr [player_shield], 0
    mov bx, 0
    mov byte ptr [shot_col+bx], 6
    mov byte ptr [shot_row+bx], 10
    mov byte ptr [shot_dir+bx], 2
    mov byte ptr [shot_active+bx], 1
    mov byte ptr [shot_delay+bx], 1
    call advance_enemy_shot
    cmp byte ptr [lives], 2
    je test_life
    jmp smoke_fail
test_life:
    mov byte ptr [test_phase], 7
    mov byte ptr [shot_col+bx], 6
    mov byte ptr [shot_row+bx], 11
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
    cmp byte ptr [enemy_type+1], 1
    je 1f
    jmp test_failed_jump
1:
    cmp byte ptr [enemy_type+2], 2
    je 1f
    jmp test_failed_jump
1:
    /* Force enemy 0 to armor, then hit once: it must survive with 3 HP. */
    mov byte ptr [enemy_type], 3
    mov byte ptr [enemy_hp], 4
    mov byte ptr [bullet_col], 0
    mov byte ptr [bullet_row], 1
    mov byte ptr [bullet_dir], 0
    mov byte ptr [bullet_delay], 1
    mov byte ptr [bullet_active], 1
    call advance_bullet
    cmp byte ptr [enemy_hp], 3
    je 1f
    jmp test_failed_jump
1:
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
    cmp byte ptr [level_data+148], 'T'
    je 1f
    jmp test_failed_jump
1:
    cmp byte ptr [level_data+150], 'T'
    je 1f
    jmp test_failed_jump
1:
    call restore_hq
    mov byte ptr [hq_shield], 0
    cmp byte ptr [level_data+148], '#'
    je 1f
    jmp test_failed_jump
1:
    cmp byte ptr [brick_masks+148], 15
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
    mov byte ptr [player_col], 0
    mov byte ptr [player_row], 4
    mov dl, 1
    mov dh, 4
    call try_move
    cmp byte ptr [player_col], 1
    je 1f
    jmp test_failed_jump
1:
    mov byte ptr [player_col], 8
    mov byte ptr [player_row], 7
    mov dl, 9
    mov dh, 7
    call try_move
    cmp byte ptr [player_col], 9
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
    cmp byte ptr [level_data+40], 'F' /* row3, col1 */
    je 1f
    jmp test_failed_jump
1:
    mov byte ptr [test_phase], 19
    call reset_campaign
    mov byte ptr [player_col], 6
    mov byte ptr [player_row], 9
    mov byte ptr [player_dir], 0
    mov byte ptr [player_upgrade], 3
    call do_fire
    cmp byte ptr [level_data+110], '.' /* max upgrade cuts steel */
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
    jmp smoke_pass
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

.section .data
kills_by_type: .space 4
stage: .byte 1
/* Six original effects in a new arrangement; all durations are BIOS ticks. */
bonus_active: .byte 0
bonus_col: .byte 0
bonus_row: .byte 0
bonus_type: .byte 0
bonus_timer: .byte 0
bonus_sequence: .byte 0
bonus_columns: .byte 2, 10, 4, 8, 1, 11
hq_wall_indices: .word 148, 150, 161, 163
hq_wall_columns: .byte 5, 7, 5, 7
hq_wall_rows: .byte 11, 11, 12, 12
player_upgrade: .byte 0
freeze_ticks: .byte 0
hq_shield: .byte 0
hq_originals: .space 4
hq_original_masks: .space 4
slide_ticks: .byte 0
slide_old_col: .byte 0
slide_old_row: .byte 0
sound_muted: .byte 0
sound_ticks: .byte 0
sound_tone: .word 0
brick_masks: .space 169
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
spawn_columns: .byte 0, 6, 12
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
level_data: .space 169
.include "src/dos/cga_assets.inc"
