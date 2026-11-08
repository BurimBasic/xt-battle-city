/* XT Battle City v0.2: original CGA tile arcade for DOS, 8086/8088.
 * Gameplay: waves of 20, 3 active enemies, movement/AI, enemy shots,
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
    call load_stage
    ret
load_stage:
    push es
    push ds
    pop es
    mov si, offset level_template
    cmp byte ptr [stage], 2
    jne load_not2
    mov si, offset level2_template
load_not2:
    cmp byte ptr [stage], 3
    jne load_selected
    mov si, offset level3_template
load_selected:
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
    mov di, offset enemy_active
    mov cx, 3
    xor al, al
    rep stosb
    mov di, offset shot_active
    mov cx, 3
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
    cmp byte ptr [game_state], 1
    jne kb_not_won
    cmp al, ' '
    jne kb_return
    inc byte ptr [stage]
    cmp byte ptr [stage], 3
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
    call draw_hud
    ret
exit_game:
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
    jne blocked_move
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

/* 18.2 Hz game tick, no busy-wait dependent on CPU MHz. */
game_tick_step:
    inc byte ptr [game_tick]
    cmp byte ptr [player_shield], 0
    je tick_no_shield
    dec byte ptr [player_shield]
tick_no_shield:
    call advance_bullet
    call update_enemy_bullets
    test byte ptr [game_tick], 3
    jnz tick_no_ai
    call move_enemies
    call enemy_fire_cycle
tick_no_ai:
    test byte ptr [game_tick], 7
    jnz tick_no_spawn
    call spawn_enemy
tick_no_spawn:
    call check_stage_complete
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
    cmp bx, 3
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
    cmp bx, 3
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
    call random_byte
    and al, 7
    cmp al, 5
    jae enemy_random_dir
    mov al, 2
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
    jne enemy_move_next
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
    cmp bx, 3
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
    call random_byte
    test al, 3
    jnz enemy_fire_next
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
    cmp bx, 3
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
    call advance_bullet
fire_done:
    ret
advance_bullet:
    cmp byte ptr [bullet_active], 0
    jne bullet_ready
    ret
bullet_ready:
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
    jc bullet_out
    mov [next_col], dl
    mov [next_row], dh
    call get_tile
    cmp al, '#'
    je bullet_break_brick
    cmp al, 'T'
    je bullet_out
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
    mov byte ptr [si], '.'
    jmp bullet_impact
bullet_break_base:
    mov byte ptr [game_state], 2
    jmp bullet_impact
bullet_kill_enemy:
    xor bx, bx
    mov bl, al
    mov byte ptr [enemy_active+bx], 0
    mov byte ptr [shot_active+bx], 0
    inc byte ptr [enemy_killed]
    add word ptr [score], 100
    call draw_hud
    jmp bullet_impact
bullet_out:
    mov byte ptr [bullet_active], 0
    mov dl, [old_col]
    mov dh, [old_row]
    call draw_cell
    ret
bullet_impact:
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
    cmp bx, 3
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
    mov byte ptr [si], '.'
    jmp shot_impact
shot_base_hit:
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
stage_clear_hud:
    mov dh, 22
    xor dl, dl
    call cursor_at
    mov si, offset victory_string
    call bios_string
    ret
game_over_hud:
    mov dh, 22
    xor dl, dl
    call cursor_at
    mov si, offset game_over_string
    call bios_string
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
    mov si, offset sprite_brick
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
    mov si, [enemy_sprite_ptrs+si]
draw_no_enemy:
    mov [draw_sprite_ptr], si
    pop si
    cmp dl, [player_col]
    jne draw_not_player
    cmp dh, [player_row]
    jne draw_not_player
    xor bx, bx
    mov bl, [player_dir]
    shl bx, 1
    mov si, [player_sprite_ptrs+bx]
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
    cmp bx, 3
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

/* HUD drawn only on state change, not on every tick. */
draw_hud:
    push ax
    push bx
    push cx
    push dx
    push si
    mov dh, 0
    xor dl, dl
    call cursor_at
    mov si, offset title_string
    call bios_string
    mov dh, 23
    xor dl, dl
    call cursor_at
    mov si, offset help_string
    call bios_string
    mov al, [stage]
    add al, '0'
    mov byte ptr [status_string+3], al
    mov al, 20
    sub al, [enemy_killed]
    xor ah, ah
    mov bl, 10
    div bl
    add al, '0'
    add ah, '0'
    mov byte ptr [status_string+14], al
    mov byte ptr [status_string+15], ah
    mov al, [lives]
    add al, '0'
    mov byte ptr [status_string+24], al
    mov ax, [score]
    mov di, offset status_string+37
    mov cx, 5
    mov bx, 10
score_digit_loop:
    xor dx, dx
    div bx
    add dl, '0'
    mov [di], dl
    dec di
    loop score_digit_loop
    mov dh, 21
    xor dl, dl
    call cursor_at
    mov si, offset status_string
    call bios_string
    pop si
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
    /* All 3 starting enemy slots must be occupied. */
    cmp byte ptr [enemy_spawned], 3
    je test_spawned
    jmp smoke_fail
test_spawned:
    mov dl, 6
    mov dh, 10
    call try_move
    cmp byte ptr [player_row], 10
    je test_move1
    jmp smoke_fail
test_move1:
    mov dl, 6
    mov dh, 9
    call try_move
    cmp byte ptr [player_row], 9
    je test_move2
    jmp smoke_fail
test_move2:
    mov dl, 6
    mov dh, 8
    call try_move
    cmp byte ptr [player_row], 9
    je test_blocked
    jmp smoke_fail
test_blocked:
    /* Advance player bullet at row 9 col 6 through brick at col 9. */
    mov byte ptr [player_dir], 1
    call do_fire
    mov cx, 12
test_bullet_loop:
    push cx
    call advance_bullet
    pop cx
    loop test_bullet_loop
    cmp byte ptr [level_data+126], '.'
    je test_brick
    jmp smoke_fail
test_brick:
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
    mov byte ptr [game_state], 0
    mov byte ptr [enemy_spawned], 20
    mov byte ptr [enemy_killed], 20
    call check_stage_complete
    cmp byte ptr [game_state], 1
    je smoke_pass
    jmp smoke_fail
smoke_pass:
    mov ax, 0x0003
    int 0x10
    mov ax, 0x4c00
    int 0x21
smoke_fail:
    mov ax, 0x0003
    int 0x10
    mov ax, 0x4c01
    int 0x21

.section .data
stage: .byte 1
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
enemy_col: .space 3
enemy_row: .space 3
enemy_dir: .space 3
enemy_active: .space 3
shot_col: .space 3
shot_row: .space 3
shot_dir: .space 3
shot_active: .space 3
shot_delay: .space 3
draw_sprite_ptr: .word 0
player_sprite_ptrs:
    .word sprite_player_up, sprite_player_right, sprite_player_down, sprite_player_left
enemy_sprite_ptrs:
    .word sprite_enemy_up, sprite_enemy_right, sprite_enemy, sprite_enemy_left
title_string: .asciz " XT BATTLE CITY 2 / CGA / XT 8088 "
help_string: .asciz "ARROWS/WASD MOVE SPACE FIRE R RESET ESC"
/* Update digit offsets in draw_hud whenever editing this template! */
status_string: .asciz "ST 1  ENEMIES 20  LIVES 3  SCORE 00000"
victory_string: .asciz "STAGE CLEAR! SPACE=NEXT  R=RESTART    "
game_over_string: .asciz "GAME OVER! R=RESTART                 "
level_data: .space 169
.include "src/dos/cga_assets.inc"
