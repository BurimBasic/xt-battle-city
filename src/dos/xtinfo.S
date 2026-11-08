/* XTINFO.COM -- tiny 8086-compatible DOS diagnostic (NOT the game).
 * GNU as .code16, tiny .COM binary with load/entry address 0100h.
 * DOS and BIOS calls are deliberately kept outside the future game core.
 */
.code16
.intel_syntax noprefix
.section .text
.global _start
_start:
    push cs
    pop ds
    mov dx, offset title
    call puts

    mov dx, offset mem_msg
    call puts
    int 0x12                /* AX = conventional KB reported by BIOS */
    call hex16
    mov dx, offset crlf
    call puts

    mov dx, offset mode_msg
    call puts
    mov ah, 0x0f
    int 0x10               /* AL = current video mode */
    call hex8
    mov dx, offset crlf
    call puts

    mov dx, offset done_msg
    call puts
    mov ax, 0x4c00
    int 0x21

puts:                       /* DS:DX -> DOS $-terminated string */
    mov ah, 0x09
    int 0x21
    ret

hex16:                      /* AX -> 4 hexadecimal chars */
    push ax
    mov al, ah
    call hex8
    pop ax
    call hex8
    ret

hex8:                       /* AL -> 2 hexadecimal chars */
    push ax
    push bx
    push cx
    mov bl, al
    mov cl, 4
    shr al, cl
    call hexdigit
    mov al, bl
    and al, 0x0f
    call hexdigit
    pop cx
    pop bx
    pop ax
    ret

hexdigit:
    and al, 0x0f
    cmp al, 9
    jbe decimal
    add al, 7
decimal:
    add al, '0'
    mov dl, al
    mov ah, 0x02
    int 0x21
    ret

title:    .ascii "XT Battle City / hardware probe (not game)\r\n$"
mem_msg:  .ascii "Conventional memory KB (hex): $"
mode_msg: .ascii "BIOS video mode (hex): $"
done_msg: .ascii "Diagnostic complete.\r\n$"
crlf:     .ascii "\r\n$"
