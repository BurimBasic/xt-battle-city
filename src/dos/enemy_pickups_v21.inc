/* v0.21 enemy pickup collector. A small shared bonus on the map can
 * be claimed by P1, companion or an enemy, but no enemy can steal
 * a heart/life (type 5) or V/ally reserve (type 7).
 * Collectors run once per BIOS tick, no new allocations/graphics.
 */
.section .text
enemy21_collect_bonus:
    cmp byte ptr [bonus_active],0
    jne enemy21_have_bonus
    ret
enemy21_have_bonus:
    cmp byte ptr [bonus_type],5
    jne enemy21_not_heart
    ret
enemy21_not_heart:
    cmp byte ptr [bonus_type],7
    jne enemy21_eligible
    ret
enemy21_eligible:
    push ax
    push bx
    push dx
    xor bx,bx
enemy21_scan:
    cmp byte ptr [enemy_active+bx],0
    jne enemy21_live
    jmp enemy21_next
enemy21_live:
    mov al,[enemy_col+bx]
    cmp al,[bonus_col]
    je enemy21_col_ok
    jmp enemy21_next
enemy21_col_ok:
    mov al,[enemy_row+bx]
    cmp al,[bonus_row]
    je enemy21_row_ok
    jmp enemy21_next
enemy21_row_ok:
    mov byte ptr [bonus_active],0
    mov byte ptr [bonus_timer],0
    mov dl,[bonus_col]
    mov dh,[bonus_row]
    call draw_cell
    /* Apply ONLY the specific effect of the stolen pickup. Giving
       generic armor for every type compounded 6+ stolen bonuses and
       made even stage 1 unwinnable for AUTO (17/20 before game-over). */
    mov al,[bonus_type]
    cmp al,0              /* star: extra armor */
    je enemy21_armor
    cmp al,1              /* helmet: extra armor */
    je enemy21_armor
    cmp al,2              /* grenade: destroy P1's companion */
    jne enemy21_shovel
    mov word ptr [ally_ticks],0
    jmp enemy21_picked
enemy21_shovel:
    cmp al,3              /* shovel: neutralize HQ fortification */
    jne enemy21_clock
    cmp byte ptr [hq_shield],0
    je enemy21_picked
    mov byte ptr [hq_shield],0
    call restore_hq
    jmp enemy21_picked
enemy21_clock:
    cmp al,4              /* clock: release frozen enemy troops */
    jne enemy21_laser
    mov byte ptr [freeze_ticks],0
    jmp enemy21_picked
enemy21_laser:
    cmp al,6              /* laser: stronger firing class */
    je enemy21_power
    cmp al,8              /* triple: stronger firing class */
    je enemy21_power
    cmp al,9              /* homing: fast tracking class */
    jne enemy21_frenzy
    mov byte ptr [enemy_type+bx],1
    jmp enemy21_picked
enemy21_power:
    mov byte ptr [enemy_type+bx],2
    jmp enemy21_picked
enemy21_frenzy:
    /* Cancel dangerous intra-enemy fighting. */
    mov byte ptr [frenzy_ticks],0
    jmp enemy21_picked
enemy21_armor:
    cmp byte ptr [enemy_hp+bx],9
    jae enemy21_picked
    inc byte ptr [enemy_hp+bx]
enemy21_picked:
    jmp enemy21_exit
enemy21_next:
    inc bx
    cmp bx,4
    jae enemy21_exit
    jmp enemy21_scan
enemy21_exit:
    pop dx
    pop bx
    pop ax
enemy21_done:
    ret
