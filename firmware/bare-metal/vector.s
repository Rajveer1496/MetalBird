.syntax unified     @ Thumb-2 syntax
.cpu cortex-m4      @ STM32F411 has corex M4 CPU
.thumb              @ tells assembler this is thumb code


.section .vector, "a"
    .word 0x20020000        @ SP value
    .word Reset_Handler+1   @ Reset handler address + 1(Thumb mode)

.section .text, "ax"
    .global Reset_Handler
        Reset_Handler:
            @ Setting up Clock tree
            
            @ Wait state & Cache Enable
                @ Flash intefrace register base address = 0x4002 3C00
                @ FLASH_ACR (flash access control register) offset = 0x0
                @ LATENCY (wait state) bits = 3:0
                @ PREFETCH ENABLE bit = 8
                @ INSTRUCTION CACHE enable bit = 9
                @ DATA CACHE enable bit = 10
            LDR R0, =(0x40023C00)
            LDR R1, [R0]
            BIC R1, R1, #(0xF) @ Clear bits 3:0
            LDR R2, =((1<<8) | (1<<9) | (1<<10) | 0x2)  @ Enable all cache and Set Wait_state=2
            ORR R1, R2
            STR R1,[R0]

            @ HSE oscillator enable
                @ RCC Base address = 0x4002 3800
                @ RCC_CR offset = 0x0
                @ HSEON bit = 16
                @ HSERDY flag bit = 17
            LDR R0, =(0x40023800)
            LDR R1, [R0]
            LDR R2, =(1<<16) @ Enable HSE Oscillator
            ORR R1,R2
            STR R1,[R0]
            HSE_WAIT: @ wait untill HSE stabalises
                LDR R1,[R0]
                LDR R2, =(1<<17)
                ANDS R1, R2
            BEQ HSE_WAIT @ Loop if result of AND is Zero (HSERDY flag is not set)
            
            @ Configure PLL Dividers ! NOTE: while PLL is disabled
                @ RCC Base address = 0x4002 3800
                @ RCC_PLLCFGR offset = 0x04
                @ PLLSRC bit = 22
                @ PLLM bits = 5:0
                @ PLLN bits = 14:6
                @ PLLP bits = 17:16
                @ PLLQ bits = 27:24

                @ for our config we want 
                    @ PLLSRC = 1
                    @ PLLM = 4
                    @ PLLN = 168
                    @ PLLP = 4 (bits 01 maps to divider 4)
                    @ PLLQ = 7
            LDR R0, =(0x40023800 + 0x04)
            LDR R1, [R0]
            LDR R2, =((0x7FFF) | (0x3 << 16) | (1 << 22) | (0xF << 24)) @ Clear all required bits
            BIC R1, R2
            LDR R2, =((1<<22) | (0x4) | (0xA8 << 6) | (0x1 << 16) | (0x7 << 24)) @ set all required values
            ORR R1, R2
            STR R1, [R0]

            @ PLL Enable
                @ RCC Base address = 0x4002 3800
                @ RCC_CR offset = 0x0
                @ PLLON bit = 24
                @ PLLRDY bit = 25
            LDR R0, =(0x40023800)
            LDR R1, [R0]
            ORR R1, #(1<<24)
            STR R1, [R0]
            PLL_WAIT:
                LDR R1,[R0]
                LDR R2, =(1<<25)
                ANDS R1,R2
            BEQ PLL_WAIT
            
            @ FEED PLL to SYSCLK
                @ RCC Base address = 0x4002 3800
                @ RCC_CFGR offset = 0x08
                @ SW bits = 1:0 (10 = PLL selected as system clock) -> switch bits
                @ SWS bits = 3:2 (10 = PLL, 00 = HSI, 01 = HSE used as system clock) -> status bits
            LDR R0, =(0x40023800 + 0x08)
            LDR R1, [R0]
            BIC R1, R1, #(0x3) @ Clear Switch bits
            ORR R1, R1, #(0x2)
            STR R1, [R0]
            
            FEED_PLL_WAIT:
            @ Check if Switch is correct
            LDR R1,[R0]
            LDR R2, =(~(0x3<<2))
            BIC R1, R2
            EORS R1, R1, #(0x2<<2)
            BNE FEED_PLL_WAIT

            @ SysTick setup
                @ STCSR (SysTick control and status register) address = 0xE000E010
                    @ COUNTFLAG bit = 16 (Returns 1 if timer counted to 0 since last time this was read.)
                    @ CLKSOURCE bit = 2 (0 = external clock, 1 = processor clock)
                    @ TICKINT bit = 1 (Enables SysTick exception request)
                    @ ENABLE bit = 0

                @ STRVR (SysTick reload value register) address = 0xE000E014
                    @ NOTE: RVR is 24 bit so max_val = 16777216 -> at 84 MHz biggest SysTick period we can get is ~199.72 ms

                @ STCVR (SysTick current value register) address = 0xE000E018
            LDR R0, =(0xE000E014)
            @ LDR R1, =(0x1481F) @ set reload value to 83999 (Reload value = Cycles - 1)
            LDR R1, =(0x00FFFFF)
            STR R1, [R0]

            @ write to CVR as init setp
            LDR R0, =(0xE000E018)
            LDR R1, =(0x1)
            STR R1, [R0]
            
            LDR R0, =(0xE000E010)
            LDR R1, [R0]
            ORR R1, R1, #(0x5) @ Enable Systick and set clock source to internal
            STR R1, [R0]


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
                LDR R1, =((0x1<<13)|(0x1<<14))  @ set 13th and 14th bit (TO SET PIN HIGH)
                STR R1, [R0]
                BL Delay

                LDR R1, =((0x1<<(13+16)) | (0x1<<(14+16))) @ set 13+16th and 14+16th bit (TO SET PIN LOW)
                STR R1,[R0]
                BL Delay
                B loop

            hang:
                B hang
            
        @ Delay:
        @     LDR R2, =0x000FFFFF
        @     wait:
        @     SUBS R2, R2, #0x1
        @     BNE wait
        @     BX LR

        Delay:
            LDR R3, =(0xE000E010)
            wait:
            LDR R4, [R3]
            ANDS R4, R4, #(1<<16)
            BEQ wait
            BX LR


