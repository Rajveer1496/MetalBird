.macro USART_SEND string:req
    .section .rodata, "a"
    msgx_usart\@:
        .string "\string"
        .balign 4
    .previous
    PUSH {R0, R5}
    LDR R5, =msgx_usart\@
    BL usart1_str_send
    POP {R0, R5}
.endm
