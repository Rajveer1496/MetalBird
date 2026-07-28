.syntax unified     @ Thumb-2 syntax
.cpu cortex-m4      @ STM32F411 has corex M4 CPU
.thumb              @ tells assembler this is thumb code


.section .vector, "a"
    .word 0x20020000        @ SP value
    .word Reset_Handler+1   @ Reset handler address + 1(Thumb mode)

.section .text, "ax"
    .global Reset_Handler
        Reset_Handler:
            @ GPIOB CLOCK ENABLE
                @ RCC Base address = 0x4002 3800
                @ RCC_AHB1ENR offset = 0x30
                @ GPIOBEN bit = 1
            LDR R0, =0x40023830     @LOAD this 32 bit address into R0 (RCC Base address + RCC_AHB1ENR offset)
            LDR R1, [R0]            @LOAD 32 bit value at this addreess into R1
            ORR R1, R1, #0x2         @(set bit 1)
            STR R1, [R0]            @STORE Updated value to RCC_AHB1ENR register

            @ PIN OUT
                @ GPIOB Base address = 0x4002 0400
                @ MODER Offset = 0x0
                @ PB 13 bits = 27 26
                @ PB 14 bits = 29 28
                @ Bits config to set pin as output = 0 1
            LDR R0, =0x40020400
            LDR R1, [R0]
            BIC R1, R1, #(0xF << 26)                     @ Clear all 4 bits (26-29)
            ORR R1, R1, #((0x1 << 26) | (0x1 << 28))     @ Set bit 26 and 28 (Output mode)
            STR R1, [R0]

            @ SET PIN HIGH
                @ GPIO Base address = 0x4002 0400
                @ BSRR offset = 0x18
                @ 0-15 bits = Set Pin high
                @ 16-31 bits = Set Pin low (reset)
            LDR R0, =0x40020418
            loop:
                LDR R1, =((0x1<<13)|(0x1<<14))  @ set 13th and 14th bit
                STR R1, [R0]
                BL Delay

                LDR R1, =((0x1<<(13+16)) | (0x1<<(14+16)))
                STR R1,[R0]
                BL Delay
                B loop

            hang:
                B hang
            
        Delay:
            LDR R2, =0x000FFFFF
            wait:
            SUBS R2, R2, #0x1
            BNE wait
            BX LR

