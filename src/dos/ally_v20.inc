/* v0.20: human/AI reserve companion system. 8086, RAM-only.
 * Lives are never reduced to zero to call a companion.
 * Reserve tokens belong to the campaign, not a new stage. */
.section .text

ally20_try_call:
    push ax
    cmp byte ptr [game_state],0
    jne ally20_done
    cmp word ptr [ally_ticks],0
    jne ally20_done       /* cannot stack allies */
    cmp byte ptr [ally_stock],0
    jne ally20_spawn
    cmp byte ptr [lives],1
    jbe ally20_done      /* NEVER spend the final life */
ally20_spawn:
    call ally17_spawn
    jc ally20_done        /* blocked exit: do not charge a token/life */
    cmp byte ptr [ally_stock],0
    je ally20_from_life
    dec byte ptr [ally_stock]
    jmp ally20_charged
ally20_from_life:
    dec byte ptr [lives]
    mov byte ptr [ally_life_flash],18
    call draw_hud        /* refresh the 1P spare-lives marker */
ally20_charged:
    mov ax,1320
    call sound_play
ally20_done:
    pop ax
    ret

/* Reserve bonus increases V stock (max 9). In AUTO immediately
 * dispatch a companion, or refresh the already active ally for 15s. */
ally20_collect:
    cmp byte ptr [ally_stock],9
    jae ally20_collect_ready
    inc byte ptr [ally_stock]
ally20_collect_ready:
    cmp byte ptr [auto_mode],0
    je ally20_collect_done
    cmp word ptr [ally_ticks],0
    je ally20_auto_spawn
    cmp byte ptr [ally_stock],0
    je ally20_collect_done
    dec byte ptr [ally_stock]
    mov word ptr [ally_ticks],270
    jmp ally20_collect_done
ally20_auto_spawn:
    call ally20_try_call
ally20_collect_done:
    ret

/* Ally automatically collects any bonus it reaches.  The existing
 * bonus20_apply shares team effects, including V tokens and timed buffs.
 * No spoofing or mutation of the player's actual coordinates. */
ally20_pickup:
    push ax
    push bx
    cmp word ptr [ally_ticks],0
    je ally20_pickup_done
    cmp byte ptr [bonus_active],0
    je ally20_pickup_done
    mov al,[ally_px]
    shr al,1
    shr al,1
    shr al,1
    shr al,1
    cmp al,[bonus_col]
    jne ally20_pickup_done
    xor bx,bx
    mov bl,[ally_py]
    mov al,[pixel_y_tile_lookup+bx]
    shr al,1
    shr al,1
    shr al,1
    shr al,1
    cmp al,[bonus_row]
    jne ally20_pickup_done
    call bonus20_apply
ally20_pickup_done:
    pop bx
    pop ax
    ret

.section .data
ally_life_flash: .byte 0

.section .text
