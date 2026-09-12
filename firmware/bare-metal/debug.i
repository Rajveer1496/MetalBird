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

.macro UDEBUG
    USART_SEND "DEBUG \@ \r\n"
.endm

.macro REG_CHECK reg:req bits:req config:req debug_msg
    SYSTICK_SLEEP 0x64   @ 100 ms delay to let hardware settle

    PUSH {R0-R5,LR}
    LDR R0, =(\reg)
    LDR R1, [R0]

    LDR R2, =(0xFFFFFFFF)
    LDR R3, =(\bits)
    BIC R2, R3
    BIC R1, R2  @ Keep only bits that matters
    MOV R4, R1 @ save actual value

    LDR R3, =(\config)
    EOR R1, R3 @ XOR -> this should set R1=0 if it was configured correctly with config

    CMP R1, #(0x0)
    BEQ reg_check_matched\@

    USART_SEND "REG CHECK does not match for \reg : Expected= "
    LDR R5, =(\config)
    USART_SEND_NUM R5
    USART_SEND " Actual= "
    USART_SEND_NUM R4
    USART_SEND "\r\n"
    B done\@

    @ Actual Value

    reg_check_matched\@:
    USART_SEND "REG CHECK Matched for \reg"

    done\@:

    .ifnb debug_msg     @ if not blank
        USART_SEND " \debug_msg"
    .endif

    USART_SEND "\r\n"

    POP {R0-R5,LR}
.endm






