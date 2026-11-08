/* TANKS.COM v0.1 - original tile-step tank arcade for IBM PC/XT + CGA.
 * Requires DOS, IBM CGA mode 04h palette 1. NOT a native Poisk-1 binary.
 * CPU: 8086/8088 only. No 286+ instructions, no DOS memory allocation.
 * Code is GNU as (GAS) .code16 / Intel syntax; linked to .COM at 0100h.
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
    call reset_game
    mov ah, 0x00
    mov al, 0x04             /* IBM CGA 320 x 200 x 4 */
    int 0x10
    mov ax, 0x0b00
    mov bx, 0x0101          /* BH=01 palette select, BL=01 cyan/magenta/white */
    int 0x10
    call draw_map
    call draw_hud
    /* Optional automated DOSBox-X smoke test: TANKS.COM /TEST */
    cmp byte ptr [0x80], 6
    jne normal_start
    cmp byte ptr [0x82], '/'
    jne normal_start
    cmp byte ptr [0x83], 'T'
    jne normal_start
    jmp smoke_test
normal_start:
    mov ah, 0
    int 0x1a               /* BIOS timer: CX:DX, 18.2065 ticks/sec */
    mov word ptr [last_tick], dx

main_loop:
    mov ah, 0
    int 0x1a
    cmp dx, word ptr [last_tick]
    je main_loop
    mov word ptr [last_tick], dx
    cmp byte ptr [game_state], 0
    jne poll_only
    call advance_bullet
poll_only:
    call poll_keyboard
    jmp main_loop

reset_game:
    mov si, offset level_template
    mov di, offset level_data
    mov cx, 169
    rep movsb
    mov byte ptr [level_data + 149], '.'     /* P start at row 11 col 6 */
    mov byte ptr [player_row], 11
    mov byte ptr [player_col], 6
    mov byte ptr [player_dir], 0
    mov byte ptr [bullet_active], 0
    mov byte ptr [bullet_delay], 0
    mov byte ptr [enemy_count], 3
    mov byte ptr [game_state], 0
    ret

poll_keyboard:
    mov ah, 0x01
    int 0x16
    jnz keyboard_ready
    ret
keyboard_ready:
    xor ah, ah
    int 0x16
    cmp al, 27
    jne not_escape
    jmp exit_game
not_escape:
    cmp al, 'r'
    jne not_restart_lower
    jmp do_restart
not_restart_lower:
    cmp al, 'R'
    jne not_restart_upper
    jmp do_restart
not_restart_upper:
    cmp byte ptr [game_state], 0
    je game_active
    ret
game_active:
    cmp al, ' '
    jne not_fire
    jmp do_fire
not_fire:
    cmp ah, 0x48
    jne not_up_scan
    jmp up_key
not_up_scan:
    cmp ah, 0x50
    jne not_down_scan
    jmp down_key
not_down_scan:
    cmp ah, 0x4b
    jne not_left_scan
    jmp left_key
not_left_scan:
    cmp ah, 0x4d
    jne check_letters
    jmp right_key
check_letters:
    and al, 0xdf           /* lowercase ASCII -> uppercase */
    cmp al, 'W'
    jne not_w
    jmp up_key
not_w:
    cmp al, 'S'
    jne not_s
    jmp down_key
not_s:
    cmp al, 'A'
    jne not_a
    jmp left_key
not_a:
    cmp al, 'D'
    jne no_key
    jmp right_key
no_key:
    ret

up_key:
    mov byte ptr [player_dir], 0
    mov dl, byte ptr [player_col]
    mov dh, byte ptr [player_row]
    test dh, dh
    jz no_key
    dec dh
    call try_move
    ret
right_key:
    mov byte ptr [player_dir], 1
    mov dl, byte ptr [player_col]
    mov dh, byte ptr [player_row]
    cmp dl, 12
    je no_key
    inc dl
    call try_move
    ret
down_key:
    mov byte ptr [player_dir], 2
    mov dl, byte ptr [player_col]
    mov dh, byte ptr [player_row]
    cmp dh, 12
    je no_key
    inc dh
    call try_move
    ret
left_key:
    mov byte ptr [player_dir], 3
    mov dl, byte ptr [player_col]
    mov dh, byte ptr [player_row]
    test dl, dl
    jz no_key
    dec dl
    call try_move
    ret

do_restart:
    push ds
    pop es
    call reset_game
    mov ax, 0x0004
    int 0x10
    mov ax, 0x0b00
    mov bx, 0x0101
    int 0x10
    call draw_map
    call draw_hud
    ret

do_fire:
    cmp byte ptr [bullet_active], 0
    jne no_key
    mov al, byte ptr [player_col]
    mov byte ptr [bullet_col], al
    mov al, byte ptr [player_row]
    mov byte ptr [bullet_row], al
    mov al, byte ptr [player_dir]
    mov byte ptr [bullet_dir], al
    mov byte ptr [bullet_active], 1
    mov byte ptr [bullet_delay], 1
    call advance_bullet     /* immediately travel one tile */
    ret

exit_game:
    mov ax, 0x0003
    int 0x10
    mov ax, 0x4c00
    int 0x21

/* Built-in fast game-logic test for CI/emulator: movement, collision and
 * destruction. It really uses the CGA renderers and BIOS, then restores text.
 */
smoke_test:
    mov dl, 6
    mov dh, 10
    call try_move
    cmp byte ptr [player_row], 10
    je smoke_move1_ok
    jmp smoke_fail
smoke_move1_ok:
    mov dl, 6
    mov dh, 9
    call try_move
    cmp byte ptr [player_row], 9
    je smoke_move2_ok
    jmp smoke_fail
smoke_move2_ok:
    mov dl, 6
    mov dh, 8
    call try_move               /* steel tile must block */
    cmp byte ptr [player_row], 9
    je smoke_block_ok
    jmp smoke_fail
smoke_block_ok:
    mov byte ptr [player_dir], 1
    call do_fire                /* fires one cell right immediately */
    mov cx, 4
smoke_bullet_loop:
    push cx
    call advance_bullet
    pop cx
    loop smoke_bullet_loop
    cmp byte ptr [level_data + 126], '.'  /* brick at (col9,row9) */
    je smoke_brick_ok
    jmp smoke_fail
smoke_brick_ok:
    cmp byte ptr [bullet_active], 0
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

try_move:                   /* DL=new col, DH=new row */
    push dx
    call get_tile
    cmp al, '.'
    jne blocked_move
    pop dx
    mov byte ptr [next_col], dl
    mov byte ptr [next_row], dh
    mov dl, byte ptr [player_col]
    mov dh, byte ptr [player_row]
    mov al, byte ptr [next_col]
    mov byte ptr [player_col], al
    mov al, byte ptr [next_row]
    mov byte ptr [player_row], al
    call draw_cell           /* old player square */
    mov dl, byte ptr [player_col]
    mov dh, byte ptr [player_row]
    call draw_cell
    ret
blocked_move:
    pop dx
    mov dl, byte ptr [player_col]
    mov dh, byte ptr [player_row]
    call draw_cell           /* update barrel direction even when blocked */
    ret

advance_bullet:
    cmp byte ptr [bullet_active], 0
    je bullet_done
    xor byte ptr [bullet_delay], 1
    jz bullet_step
bullet_done:
    ret
bullet_step:
    mov dl, byte ptr [bullet_col]
    mov dh, byte ptr [bullet_row]
    mov byte ptr [bullet_old_col], dl
    mov byte ptr [bullet_old_row], dh
    mov al, byte ptr [bullet_dir]
    cmp al, 0
    je bullet_up
    cmp al, 1
    je bullet_right
    cmp al, 2
    je bullet_down
    /* left */
    test dl, dl
    jz bullet_out
    dec dl
    jmp bullet_check
bullet_up:
    test dh, dh
    jz bullet_out
    dec dh
    jmp bullet_check
bullet_right:
    cmp dl, 12
    je bullet_out
    inc dl
    jmp bullet_check
bullet_down:
    cmp dh, 12
    je bullet_out
    inc dh
bullet_check:
    mov byte ptr [next_col], dl
    mov byte ptr [next_row], dh
    call get_tile          /* AL tile, SI mutable tile */
    cmp al, '#'
    je bullet_hit_brick
    cmp al, 'E'
    je bullet_hit_enemy
    cmp al, 'T'
    je bullet_out
    cmp al, 'B'
    je bullet_out
    /* Move over floor or water; redraw both dirty cells. */
    mov byte ptr [bullet_col], dl
    mov byte ptr [bullet_row], dh
    mov dl, byte ptr [bullet_old_col]
    mov dh, byte ptr [bullet_old_row]
    call draw_cell
    mov dl, byte ptr [bullet_col]
    mov dh, byte ptr [bullet_row]
    call draw_cell
    ret
bullet_hit_brick:
    mov byte ptr [si], '.'
    jmp bullet_impact
bullet_hit_enemy:
    mov byte ptr [si], '.'
    dec byte ptr [enemy_count]
    jmp bullet_impact
bullet_out:
    mov byte ptr [bullet_active], 0
    mov dl, byte ptr [bullet_old_col]
    mov dh, byte ptr [bullet_old_row]
    call draw_cell
    ret
bullet_impact:
    mov byte ptr [bullet_active], 0
    mov dl, byte ptr [bullet_old_col]
    mov dh, byte ptr [bullet_old_row]
    call draw_cell
    mov dl, byte ptr [next_col]
    mov dh, byte ptr [next_row]
    call draw_cell
    cmp byte ptr [enemy_count], 0
    jne impact_done
    mov byte ptr [game_state], 1
    call victory_hud
impact_done:
    ret

victory_hud:
    mov dh, 22
    xor dl, dl
    call cursor_at
    mov si, offset victory_string
    call bios_string
    ret

/* Return AL=tile, SI=address of tile. DL col/DH row (0..12).
 * Row-major index = row*13+col (fits in byte).
 */
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
    mov al, byte ptr [si]
    pop bx
    ret

draw_map:
    xor dx, dx
map_row:
    mov dl, 0
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

/* DL/DH grid coordinate. Uses mutable map, overlays player / bullet. */
draw_cell:
    push ax
    push si
    push dx
    call get_tile
    mov si, offset sprite_empty
    cmp al, '#'
    jne not_brick
    mov si, offset sprite_brick
    jmp check_overlays
not_brick:
    cmp al, 'T'
    jne not_steel
    mov si, offset sprite_steel
    jmp check_overlays
not_steel:
    cmp al, '~'
    jne not_water
    mov si, offset sprite_water
    jmp check_overlays
not_water:
    cmp al, 'B'
    jne not_base
    mov si, offset sprite_base
    jmp check_overlays
not_base:
    cmp al, 'E'
    jne check_overlays
    mov si, offset sprite_enemy
check_overlays:
    cmp dl, byte ptr [player_col]
    jne bullet_overlay
    cmp dh, byte ptr [player_row]
    jne bullet_overlay
    xor bx, bx
    mov bl, byte ptr [player_dir]
    shl bx, 1
    mov si, word ptr [player_sprite_ptrs+bx]
    jmp draw_selected
bullet_overlay:
    cmp byte ptr [bullet_active], 0
    je draw_selected
    cmp dl, byte ptr [bullet_col]
    jne draw_selected
    cmp dh, byte ptr [bullet_row]
    jne draw_selected
    mov si, offset sprite_bullet
draw_selected:
    call draw_sprite
    pop dx
    pop si
    pop ax
    ret

/* Draw one 16x12 2bpp CGA sprite. Input SI pointer, DL column, DH row.
 * CGA address: even scanlines B800:(row/2)*80; odd scanlines +2000h.
 * Tiles start at (56,16), each row advances 480 bytes per bank.
 * 6 pairs * 8 bytes per sprite = exactly 48 bytes of sprite data.
 */
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
    mov di, word ptr [tile_row_offsets+bx]
    xor bx, bx
    mov bl, dl
    shl bx, 1
    shl bx, 1
    add di, bx
    mov cx, 6
sprite_row:
    mov ax, word ptr [si]
    mov word ptr es:[di], ax
    mov ax, word ptr [si+2]
    mov word ptr es:[di+2], ax
    mov ax, word ptr [si+4]
    mov word ptr es:[di+0x2000], ax
    mov ax, word ptr [si+6]
    mov word ptr es:[di+0x2002], ax
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

/* BIOS teletype only for static HUD text, not in game frame loop. */
draw_hud:
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
    cld
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

.section .data
player_col:    .byte 6
player_row:    .byte 11
player_dir:    .byte 0
bullet_col:    .byte 0
bullet_row:    .byte 0
bullet_dir:    .byte 0
bullet_active: .byte 0
bullet_delay:  .byte 0
bullet_old_col: .byte 0
bullet_old_row: .byte 0
next_col:      .byte 0
next_row:      .byte 0
enemy_count:   .byte 3
game_state:    .byte 0
last_tick:     .word 0
player_sprite_ptrs:
    .word sprite_player_up, sprite_player_right, sprite_player_down, sprite_player_left
victory_string:
    .asciz "ALL TANKS DOWN! R=RESTART"
title_string:
    .asciz "XT BATTLE CITY / CGA TECH DEMO"
help_string:
    .asciz "ARROWS/WASD MOVE SPACE FIRE R RESET ESC"
level_data:
    .space 169
.include "src/dos/cga_assets.inc"
