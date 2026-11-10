/* v0.17 compact tactical bonuses, all 8086 code, no FPU or allocation.
 * Tick clock is 18.2Hz. Extra bullets temporarily reuse the vetted P1
 * collision engine so that armor, destructible walls and scoring stay real.
 */
.section .text

bonus17_tick:
    cmp byte ptr [laser_ticks],0
    je b17_no_laser
    dec byte ptr [laser_ticks]
b17_no_laser:
    cmp byte ptr [multi_ticks],0
    je b17_no_multi
    dec byte ptr [multi_ticks]
b17_no_multi:
    cmp byte ptr [homing_ticks],0
    je b17_no_homing
    dec byte ptr [homing_ticks]
b17_no_homing:
    cmp byte ptr [frenzy_ticks],0
    je b17_no_frenzy
    dec byte ptr [frenzy_ticks]
b17_no_frenzy:
    cmp byte ptr [laser_flash_ticks],0
    je b17_no_flash
    dec byte ptr [laser_flash_ticks]
b17_no_flash:
    cmp byte ptr [ally_life_flash],0
    je b20_flash_done
    dec byte ptr [ally_life_flash]
b20_flash_done:
    cmp word ptr [ally_ticks],0
    je b17_done
    dec word ptr [ally_ticks]
    jz b17_done
    call ally17_tick
b17_done:
    ret

/* Reserve an extra shot only while the three-shot power-up is live. */
extra17_player_fire:
    cmp byte ptr [multi_ticks],0
    je extra17_fail
    xor bx,bx
extra17_slot:
    cmp byte ptr [extra_active+bx],0
    je extra17_create
    inc bx
    cmp bx,2
    jb extra17_slot
extra17_fail:
    ret
extra17_create:
    mov al,[player_px]
    mov [extra_px+bx],al
    mov al,[player_py]
    mov [extra_py+bx],al
    mov al,[player_dir]
    mov [extra_dir+bx],al
    mov byte ptr [extra_active+bx],1
    mov al,0
    cmp byte ptr [homing_ticks],0
    je extra17_create_normal
    inc al
extra17_create_normal:
    mov [extra_homing+bx],al
    call tactical_report_player
    mov ax,1250
    call sound_play
    ret

/* Fire ally-owned shot into one of the two extra projectile slots.
 * Never overwrite an active P1 shot. */
extra17_ally_fire:
    xor bx,bx
extra17_ally_find:
    cmp byte ptr [extra_active+bx],0
    je extra17_ally_spawn
    inc bx
    cmp bx,2
    jb extra17_ally_find
    ret
extra17_ally_spawn:
    mov al,[ally_px]
    mov [extra_px+bx],al
    mov al,[ally_py]
    mov [extra_py+bx],al
    mov al,[ally_dir]
    mov [extra_dir+bx],al
    mov byte ptr [extra_active+bx],1
    mov byte ptr [extra_homing+bx],0
    mov byte ptr [ally_cooldown],12
    ret

/* Called after advance_bullet_smooth() on the primary player projectile.
 * A low-cost one-slot swap calls that SAME terrain/enemy collision code
 * for each extra projectile. SI and the original player shot are restored.
 */
extra17_advance:
    push ax
    push bx
    push si
    xor si,si
extra17_step_loop:
    cmp byte ptr [extra_active+si],0
    je extra17_next
    mov al,[bullet_active]
    mov [saved_bullet_active],al
    mov al,[bullet_px]
    mov [saved_bullet_x],al
    mov al,[bullet_py]
    mov [saved_bullet_y],al
    mov al,[bullet_dir]
    mov [saved_bullet_dir],al
    mov al,[extra_active+si]
    mov [bullet_active],al
    mov al,[extra_px+si]
    mov [bullet_px],al
    mov al,[extra_py+si]
    mov [bullet_py],al
    mov al,[extra_dir+si]
    mov [bullet_dir],al
    cmp byte ptr [extra_homing+si],0
    je extra17_no_home
    call extra17_home_direction
extra17_no_home:
    push si
    call advance_bullet_smooth
    pop si
    mov al,[bullet_active]
    mov [extra_active+si],al
    mov al,[bullet_px]
    mov [extra_px+si],al
    mov al,[bullet_py]
    mov [extra_py+si],al
    mov al,[bullet_dir]
    mov [extra_dir+si],al
    mov al,[saved_bullet_active]
    mov [bullet_active],al
    mov al,[saved_bullet_x]
    mov [bullet_px],al
    mov al,[saved_bullet_y]
    mov [bullet_py],al
    mov al,[saved_bullet_dir]
    mov [bullet_dir],al
extra17_next:
    inc si
    cmp si,2
    jae 1f
    jmp extra17_step_loop
1:
    pop si
    pop bx
    pop ax
    ret

/* Select the nearest living enemy to the bullet by Manhattan distance.
 * Steering is per tick; the bright round flashes every four ticks. */
extra17_home_direction:
    push ax
    push bx
    push cx
    push dx
    mov word ptr [home_best],0xffff
    mov byte ptr [home_target],0xff
    xor bx,bx
extra17_home_scan:
    cmp byte ptr [enemy_active+bx],0
    je extra17_home_next
    mov al,[enemy_px+bx]
    sub al,[bullet_px]
    jnc extra17_x_abs
    neg al
extra17_x_abs:
    xor ah,ah
    mov dx,ax
    mov al,[enemy_py+bx]
    sub al,[bullet_py]
    jnc extra17_y_abs
    neg al
extra17_y_abs:
    xor ah,ah
    add ax,dx
    cmp ax,[home_best]
    jae extra17_home_next
    mov [home_best],ax
    mov [home_target],bl
extra17_home_next:
    inc bx
    cmp bx,4
    jb extra17_home_scan
    xor bx,bx
    mov bl,[home_target]
    cmp bl,4
    jae extra17_home_done
    mov al,[enemy_px+bx]
    sub al,[bullet_px]
    jnc extra17_home_dx
    neg al
extra17_home_dx:
    mov cl,al
    mov al,[enemy_py+bx]
    sub al,[bullet_py]
    jnc extra17_home_dy
    neg al
extra17_home_dy:
    cmp cl,10
    jb extra17_home_vertical
    cmp al,7
    jb extra17_home_horizontal
    cmp cl,al
    jb extra17_home_vertical
extra17_home_horizontal:
    mov al,1
    mov dl,[enemy_px+bx]
    cmp dl,[bullet_px]
    ja extra17_home_assign
    mov al,3
    jmp extra17_home_assign
extra17_home_vertical:
    xor al,al
    mov dl,[enemy_py+bx]
    cmp dl,[bullet_py]
    jb extra17_home_assign
    mov al,2
extra17_home_assign:
    mov [bullet_dir],al
extra17_home_done:
    pop dx
    pop cx
    pop bx
    pop ax
    ret

/* Laser does a real 3px swept shell trace, all in the firing tick.
 * Thus it cannot tunnel through steel or brick, and damage is immediate.
 * A three-tick bright trail is rendered from muzzle to impact location. */
laser17_fire:
    push ax
    push cx
    mov al,[bullet_dir]
    mov [laser_dir],al
    mov al,[player_px]
    mov [laser_start_x],al
    mov al,[player_py]
    mov [laser_start_y],al
    mov byte ptr [laser_flash_ticks],3
    mov cx,88
laser17_step:
    cmp byte ptr [bullet_active],0
    je laser17_done
    push cx
    call advance_bullet_smooth
    pop cx
    loop laser17_step
laser17_done:
    mov al,[bullet_px]
    mov [laser_end_x],al
    mov al,[bullet_py]
    mov [laser_end_y],al
    pop cx
    pop ax
    ret

/* Spawn from the HQ area; do not teleport beside the player.
 * Try a few authored open exits and reject overlapping the main tank.
 * Carry means the exits are blocked; the V token/life is NOT consumed. */
ally17_spawn:
    push ax
    push bx
    push dx
    xor bx,bx
ally20_base_candidate:
    mov dl,[ally20_spawn_x+bx]
    mov dh,[ally20_spawn_y+bx]
    mov [ally_px],dl
    mov [ally_py],dh
    call rect_passable
    jc ally20_base_next
    mov al,dl
    sub al,[player_px]
    add al,15
    cmp al,30
    ja ally20_spawn_clear
    mov al,dh
    sub al,[player_py]
    add al,11
    cmp al,22
    jbe ally20_base_next
ally20_spawn_clear:
    mov byte ptr [ally_dir],0
    mov word ptr [ally_ticks],270     /* 15 seconds * 18 BIOS ticks */
    mov byte ptr [ally_cooldown],0
    clc
    jmp ally20_base_done
ally20_base_next:
    inc bx
    cmp bx,4
    jb ally20_base_candidate
    stc
ally20_base_done:
    pop dx
    pop bx
    pop ax
    ret

ally17_tick:
    push ax
    push bx
    push cx
    push dx
    push si
    cmp byte ptr [ally_cooldown],0
    je ally17_cool_ready
    dec byte ptr [ally_cooldown]
ally17_cool_ready:
    xor bx,bx
    mov word ptr [ally_best],0xffff
    mov byte ptr [ally_target],0xff
ally17_seek:
    cmp byte ptr [enemy_active+bx],0
    je ally17_seek_next
    mov al,[enemy_px+bx]
    sub al,[ally_px]
    jnc ally17_x_positive
    neg al
ally17_x_positive:
    xor ah,ah
    mov dx,ax
    mov al,[enemy_py+bx]
    sub al,[ally_py]
    jnc ally17_y_positive
    neg al
ally17_y_positive:
    xor ah,ah
    add ax,dx
    cmp ax,[ally_best]
    jae ally17_seek_next
    mov [ally_best],ax
    mov [ally_target],bl
ally17_seek_next:
    inc bx
    cmp bx,4
    jb ally17_seek
    xor bx,bx
    mov bl,[ally_target]
    cmp bl,4
    jb 1f
    jmp ally17_finished
1:
    mov al,[enemy_px+bx]
    sub al,[ally_px]
    add al,9
    cmp al,19
    ja ally17_check_horizontal
    mov byte ptr [ally_dir],0
    mov dl,[enemy_py+bx]
    cmp dl,[ally_py]
    jb ally17_try_fire
    mov byte ptr [ally_dir],2
    jmp ally17_try_fire
ally17_check_horizontal:
    mov al,[enemy_py+bx]
    sub al,[ally_py]
    add al,7
    cmp al,15
    ja ally17_move
    mov byte ptr [ally_dir],3
    mov dl,[enemy_px+bx]
    cmp dl,[ally_px]
    jb ally17_try_fire
    mov byte ptr [ally_dir],1
ally17_try_fire:
    cmp byte ptr [ally_cooldown],0
    je 1f
    jmp ally17_finished
1:
    call extra17_ally_fire
    jmp ally17_finished
ally17_move:
    test byte ptr [game_tick],1
    jnz ally17_finished
    mov al,[enemy_px+bx]
    sub al,[ally_px]
    jnc ally17_move_x_abs
    neg al
ally17_move_x_abs:
    mov cl,al
    mov al,[enemy_py+bx]
    sub al,[ally_py]
    jnc ally17_move_y_abs
    neg al
ally17_move_y_abs:
    cmp al,cl
    ja ally17_vertical
    mov al,1
    mov dl,[enemy_px+bx]
    cmp dl,[ally_px]
    ja ally17_step
    mov al,3
    jmp ally17_step
ally17_vertical:
    xor al,al
    mov dl,[enemy_py+bx]
    cmp dl,[ally_py]
    jb ally17_step
    mov al,2
ally17_step:
    mov [ally_dir],al
    mov dl,[ally_px]
    mov dh,[ally_py]
    call step_pixel
    jc ally17_finished
    mov [ally_candidate_x],dl
    mov [ally_candidate_y],dh
    call rect_passable
    jc ally17_finished
    /* Do not overlap the human player's tank. */
    mov al,dl
    sub al,[player_px]
    add al,15
    cmp al,30
    ja ally17_position
    mov al,dh
    sub al,[player_py]
    add al,11
    cmp al,22
    jbe ally17_finished
ally17_position:
    mov al,[ally_candidate_x]
    mov [ally_px],al
    mov al,[ally_candidate_y]
    mov [ally_py],al
ally17_finished:
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

/* Frenzy bonus overrides safe-fire suppression; enemies pick a teammate
 * to aim at. Existing shot_hits_other_enemy() scores physical damage. */
frenzy17_target:
    push ax
    push cx
    push dx
    push si
    mov byte ptr [frenzy_target],0xff
    mov word ptr [frenzy_best],0xffff
    xor si,si
frenzy17_scan:
    cmp si,bx
    je frenzy17_next
    cmp byte ptr [enemy_active+si],0
    je frenzy17_next
    mov al,[enemy_px+si]
    sub al,[enemy_px+bx]
    jnc frenzy17_xabs
    neg al
frenzy17_xabs:
    xor ah,ah
    mov dx,ax
    mov al,[enemy_py+si]
    sub al,[enemy_py+bx]
    jnc frenzy17_yabs
    neg al
frenzy17_yabs:
    xor ah,ah
    add ax,dx
    cmp ax,[frenzy_best]
    jae frenzy17_next
    mov [frenzy_best],ax
    mov [frenzy_target],si
frenzy17_next:
    inc si
    cmp si,4
    jb frenzy17_scan
    xor si,si
    mov si,[frenzy_target]
    cmp si,4
    jae frenzy17_failure
    mov al,[enemy_px+si]
    sub al,[enemy_px+bx]
    add al,9
    cmp al,19
    ja frenzy17_horizontal
    mov al,0
    mov dl,[enemy_py+si]
    cmp dl,[enemy_py+bx]
    jb frenzy17_direction
    mov al,2
    jmp frenzy17_direction
frenzy17_horizontal:
    mov al,[enemy_py+si]
    sub al,[enemy_py+bx]
    add al,7
    cmp al,15
    ja frenzy17_failure
    mov al,3
    mov dl,[enemy_px+si]
    cmp dl,[enemy_px+bx]
    jb frenzy17_direction
    mov al,1
frenzy17_direction:
    mov [enemy_dir+bx],al
    stc
    jmp frenzy17_done
frenzy17_failure:
    clc
frenzy17_done:
    pop si
    pop dx
    pop cx
    pop ax
    ret

/* Four independent expanding grenade explosions, not instantaneous vanish. */
grenade17_fx_tick:
    push bx
    xor bx,bx
grenade17_fx_loop:
    cmp byte ptr [grenade_fx_ticks+bx],0
    je grenade17_fx_next
    dec byte ptr [grenade_fx_ticks+bx]
grenade17_fx_next:
    inc bx
    cmp bx,4
    jb grenade17_fx_loop
    pop bx
    ret

grenade17_fx_paint:
    xor bx,bx
grenade17_fx_paint_loop:
    cmp byte ptr [grenade_fx_ticks+bx],0
    je grenade17_fx_paint_next
    mov dl,[grenade_fx_x+bx]
    mov dh,[grenade_fx_y+bx]
    mov [paint_grenade_x+bx],dl
    mov [paint_grenade_y+bx],dh
    mov byte ptr [paint_grenade_valid+bx],1
    push bx
    mov al,12
    sub al,[grenade_fx_ticks+bx]
    shr al,1
    shr al,1
    cmp al,3
    jbe grenade17_frame_ok
    mov al,3
grenade17_frame_ok:
    xor ah,ah
    shl ax,1
    mov bx,ax
    mov si,[smooth_explosion_ptrs+bx]
    call draw_smooth_sprite
    pop bx
grenade17_fx_paint_next:
    inc bx
    cmp bx,4
    jb grenade17_fx_paint_loop
    ret

/* v0.19: continuous 1-pixel laser line, rather than 16x12 projectile
 * sprites every eight pixels. The shell trace above determines the REAL
 * obstruction point, so this never crosses steel or an enemy. Alternate
 * CGA color 1 / 3 each BIOS tick. Dirty tiles are restored the next frame
 * so there are no ghost trails. One line = one bounded scan, no sprite
 * blitter calls or per-pixel division/multiplication. */
laser17_paint:
    cmp byte ptr [laser_flash_ticks],0
    jne laser19_paint_active
    ret
laser19_paint_active:
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    push es
    mov ax,[frame_seg]
    mov es,ax
    mov dl,[laser_start_x]
    add dl,8
    mov dh,[laser_start_y]
    add dh,6
    mov al,[laser_end_x]
    cmp al,247
    jbe laser19_end_x_clamped
    mov al,247
laser19_end_x_clamped:
    add al,8
    mov [laser_paint_end_x],al
    mov al,[laser_end_y]
    cmp al,185
    jbe laser19_end_y_clamped
    mov al,185
laser19_end_y_clamped:
    add al,6
    mov [laser_paint_end_y],al
    mov cx,240
laser19_pixel:
    cmp dh,192
    jb laser19_pixel_in_world
    jmp laser19_finished
laser19_pixel_in_world:
    /* (y/12)*16 + (x/16) indexes a 16x16 static map. */
    xor bx,bx
    mov bl,dh
    mov al,[pixel_y_tile_lookup+bx]
    and al,0xf0
    xor ah,ah
    mov bx,ax
    mov al,dl
    shr al,1
    shr al,1
    shr al,1
    shr al,1
    xor ah,ah
    add bx,ax
    mov byte ptr [dirty_tiles+bx],1
    mov byte ptr [upload_tiles+bx],1
    /* Convert x/y to mode-4 CGA interleaved address. */
    xor bx,bx
    mov bl,dh
    shl bx,1
    mov di,[cga_scanline_offsets+bx]
    xor bx,bx
    mov bl,dl
    shr bx,1
    shr bx,1
    add di,bx
    mov al,dl
    and al,3
    xor bx,bx
    mov bl,al
    mov al,[laser19_masks+bx]
    not al
    and al,es:[di]
    test byte ptr [game_tick],1
    jnz laser19_white
    or al,[laser19_color1+bx]
    jmp laser19_pixel_store
laser19_white:
    or al,[laser19_color3+bx]
laser19_pixel_store:
    mov es:[di],al
    /* Stop at the captured shell impact, never continue past the wall. */
    mov al,[laser_dir]
    cmp al,0
    jne laser19_right
    cmp dh,[laser_paint_end_y]
    jbe laser19_finished
    dec dh
    jmp laser19_next
laser19_right:
    cmp al,1
    jne laser19_down
    cmp dl,[laser_paint_end_x]
    jae laser19_finished
    inc dl
    jmp laser19_next
laser19_down:
    cmp al,2
    jne laser19_left
    cmp dh,[laser_paint_end_y]
    jae laser19_finished
    inc dh
    jmp laser19_next
laser19_left:
    cmp dl,[laser_paint_end_x]
    jbe laser19_finished
    dec dl
laser19_next:
    dec cx
    jz laser19_finished
    jmp laser19_pixel
laser19_finished:
    pop es
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

.section .data
laser_ticks: .byte 0
multi_ticks: .byte 0
homing_ticks: .byte 0
frenzy_ticks: .byte 0
laser_flash_ticks: .byte 0
laser19_masks: .byte 0xc0,0x30,0x0c,0x03
laser19_color1: .byte 0x40,0x10,0x04,0x01
laser19_color3: .byte 0xc0,0x30,0x0c,0x03
laser_paint_end_x: .byte 0
laser_paint_end_y: .byte 0
laser_dir: .byte 0
laser_start_x: .byte 0
laser_start_y: .byte 0
laser_end_x: .byte 0
laser_end_y: .byte 0
extra_active: .space 2
extra_px: .space 2
extra_py: .space 2
extra_dir: .space 2
extra_homing: .space 2
saved_bullet_active: .byte 0
saved_bullet_x: .byte 0
saved_bullet_y: .byte 0
saved_bullet_dir: .byte 0
home_best: .word 0xffff
home_target: .byte 0xff
ally_ticks: .word 0
/* HQ-side deployment positions, tried in order for blocked base exits. */
ally20_spawn_x: .byte 112,96,128,112
ally20_spawn_y: .byte 144,144,144,132
ally_px: .byte 0
ally_py: .byte 0
ally_dir: .byte 0
ally_cooldown: .byte 0
ally_candidate_x: .byte 0
ally_candidate_y: .byte 0
ally_best: .word 0xffff
ally_target: .byte 0xff
frenzy_best: .word 0xffff
frenzy_target: .word 0x00ff
grenade_fx_ticks: .space 4
grenade_fx_x: .space 4
grenade_fx_y: .space 4
paint_extra_valid: .space 2
paint_extra_x: .space 2
paint_extra_y: .space 2
paint_ally_valid: .byte 0
paint_ally_x: .byte 0
paint_ally_y: .byte 0
paint_grenade_valid: .space 4
paint_grenade_x: .space 4
paint_grenade_y: .space 4
.section .text
