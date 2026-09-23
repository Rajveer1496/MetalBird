.macro USART_SEND string:req
    .section .rodata, "a"
    msgx_usart\@:
        .string "\string"
        .balign 4
    .previous
    PUSH {R5, LR}
    LDR R5, =msgx_usart\@
    BL usart1_str_send
    POP {R5, LR}
.endm

.macro USART_SEND_NUM num_reg:req
    USART_SEND "0x"
    PUSH {R5, LR}
    MOV R5, \num_reg
    BL usart1_num_send
    POP {R5, LR}
.endm

.macro UDEBUG msg
    .ifb \msg
        USART_SEND "[DEBUG] \@ \r\n"
    .else 
        USART_SEND "[DEBUG] \msg \r\n"
    .endif
.endm

.macro REG_CHECK reg:req bits:req config:req debug_msg
    PUSH {R0,R4,R5,LR}
    LDR R0, =(\reg)
    LDR R4, =(\bits)
    LDR R5, =(\config)
    BL reg_val_check
    CMP R0, #(0x0)
    BEQ done_\@
    USART_SEND "REG CHECK does not match for \reg : Expected= "
    LDR R5, =(\config)
    USART_SEND_NUM R5
    USART_SEND " Actual= "
    USART_SEND_NUM R0
    done_\@:
    .ifnb debug_msg     @ if not blank
        USART_SEND " \debug_msg"
    .endif
    USART_SEND "\r\n"
    POP {R0,R4,R5,LR}
.endm





