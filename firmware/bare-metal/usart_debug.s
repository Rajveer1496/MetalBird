@ Sequence to setup USART1

 @ USART DEBUG SETUP
    @ STM32F411CE - QFQFPN48
        @ pin 42 (PB6) = main: IO / Alternate: USART1_TX (AF07)
        @ pin 43 (PB7) = main: IO / Alternate: USART1_RX (AF07)

        @ Pull up RX with GPIOB_PUPDR,
        @ set speed with GPIOB_OSPEEDR,
        //---------------------------------------------what about GPIOB_OTYER?
        @ set AF7 with GPIOB_AFRL,
        @ enable USART1 clock with RCC_APB2ENR,
        @ Setup USART1
            /*
            Procedure:
            1. Enable the USART by writing the UE bit in USART_CR1 register to 1.
            2. Program the M bit in USART_CR1 to define the word length.
            3. Program the number of stop bits in USART_CR2.
            4. Select DMA enable (DMAT) in USART_CR3 if Multi buffer Communication is to take
            place. Configure the DMA register as explained in multibuffer communication.
            5. Select the desired baud rate using the USART_BRR register.
            6. Set the TE bit in USART_CR1 to send an idle frame as first transmission.
            7. Write the data to send in the USART_DR register (this clears the TXE bit). Repeat this
            for each data to be transmitted in case of single buffer.
            8. After writing the last data into the USART_DR register, wait until TC=1. This indicates
            that the transmission of the last frame is complete. This is required for instance when
            the USART is disabled or enters the Halt mode to avoid corrupting the last
            transmission.

            9. Set the RE bit USART_CR1. This enables the receiver which begins searching for a start bit.
            */
        @ Set Moder to alternate function with GPIOB_MODER
.syntax unified     @ Thumbed  syntax
.cpu cortex-m4      @ STM32F411 has corex M4 CPU
.thumb              @ tells assembler this is thumb code

.section .text, "ax"
    .global usart_debug_init
    .type usart_debug_init, %function
    .thumb_func
        usart_debug_init:                  
            
            @ Pull up Rx with GPIOB_PUPDR
                @ GPIOB base address = 0x4002 0400
                    @ GPIOB_PUPDR offset = 0x0C
                        @ Pull bits (PB7) = 15:14 (00: No pull-up, pull-down / 01: Pull-up / 10: Pull-down / 11: Reserved)
            LDR R0, =(0x40020400 + 0x0C)
            LDR R1, [R0]
            BIC R1, R1, #(0x3 << 14)    @ clear 15:14 bits
            ORR R1, R1, #(1 << 14)    @ set bit 14
            STR R1, [R0]

            @ Set Speed with GPIOB_OSPEEDR
                @ GPIOB base address = 0x4002 0400
                    @ GPIO_SPEEDR offset = 0x08
                        @ speed config bits (PB7) = 15:14 (00: Low speed / 01: Medium speed / 10: Fast speed / 11: High speed)
                        @ speed config bits (PB6) = 13:12
            LDR R0, =(0x40020400 + 0x08)
            LDR R1, [R0]
            BIC R1, R1, #(0x3 << 12 | 0x3 << 14) @ clear 15:12 bits
            ORR R1, R1, #(0x3 << 12 | 0x3 << 14) @ set 15:12 bits for High speed mode
            STR R1, [R0]

            @ set AF7 with GPIOB_AFRL
                @ GPIOB base address = 0x4002 0400
                    @ GPIPOB_AFRL offset = 0x20
                        @ Value for AF7 = 0111
                        @ PB6 bits = 27:24
                        @ PB7 bits = 31:28
            LDR R0, =(0x40020400 + 0x20)
            LDR R1, [R0]
            BIC R1, R1, #(0xFF << 24)
            ORR R1, R1, #(0x7 << 24 | 0x7 << 28)
            STR R1, [R0]

            @ enable USART1 clock with RCC_APB2ENR
                @ RCC base address = 0x4002 3800
                    @ RCC_APB2ENR offset = 0x44
                        @ USART1 clock enable bit = 4
            LDR R0, =(0x40023800)
            LDR R1, [R0]
            ORR R1, R1, #(1<<4)
            STR R1, [R0]

            @ setup USART1
                @ 1. Enable USART1 via USART_CR1
                    @ USART1 base address = 0x4001 1000
                        @ USART_CR1 offset = 0x0C
                            @ USART enable bit = 13
                LDR R0, =(0x40011000 + 0x0c)
                LDR R1, [R0]
                ORR R1, R1, #(1<<13)
                STR R1, [R0]

                @ 2. define the word length with M bit in USART_CR1
                    @ USART1 base address = 0x4001 1000
                        @ USART_CR1 offset = 0x0C
                            @ Word length bit = 12 (0: 8 Data bits / 1: 9 Data bits)
                LDR R0, =(0x40011000 + 0x0C)
                LDR R1, [R0]
                BIC R1, R1, #(1<<12) @ set word length to 8 bits
                STR R1,[R0]

                @ 3. Program the number of stop bits in USART_CR2.
                    @ USART1 base address = 0x4001 1000
                        @ USART_CR2 offset = 0x10
                            @ stop bits number bits = 13:12 (00: 1 Stop bit / 01: 0.5 Stop bit / 10: 2 Stop bits / 11: 1.5 Stop bit)
                LDR R0, =(0x40011000 + 0x10)
                LDR R1, [R0]
                BIC R1, R1, #(0x3 << 12)
                STR R1, [R0]

                @ 5. set Baud rate with USART_BRR register.
                    @ For 115200 baud rate at 84 Mhz : Mantissa = 45, fraction = 9
                    @ USART1 base address = 0x4001 1000
                        @ USART_BRR offset = 0x08
                            @ Mantissa bits = 15:4
                            @ Fraction bits = 3:0
                LDR R0, =(0x40011000 + 0x08)
                LDR R1, [R0]
                LDR R2, =(0xFFFF)
                BIC R1, R2
                LDR R2 , =((0x2E << 4) | 0x9)
                @ ORR R1, R1, #((0x2E << 4) | 0x9)
                ORR R1, R2
                STR R1, [R0]

                @ Set oversampling
                    @ USART1 base address = 0x4001 1000
                        @ USART_CR1 offset = 0x0C
                            @ OVER8 (oversampling) bit = 15 (0: oversampling by 16 / 1: oversampling by 8)
                LDR R0, =(0x40011000 + 0x0C)
                LDR R1, [R0]
                BIC R1, R1, #(1<<15)
                STR R1, [R0]

            @ Set Moder to alternate function with GPIOB_MODER
                @ GPIOB base address = 0x4002 0400
                    @ GPIOB_MODER offset = 0x00
                        @ MODER PINS PB6 = 13:12 (00: Input (reset state) / 01: General purpose output mode / 10: Alternate function mode / 11: Analog mode)
                        @ MODER PINS PB7 = 15:14
            LDR R0, =(0x40020400)
            LDR R1, [R0]
            BIC R1, R1, #(0xF << 12)
            ORR R1, R1, #(0x2 << 12 | 0x2 << 14)
            STR R1, [R0]

            @ 6. Set the TE bit in USART_CR1 to send an idle frame as first transmission.
                @ USART1 base address = 0x4001 1000
                        @ USART_CR1 offset = 0x0C
                            @ Transmitter enable bit = 3
            LDR R0, =(0x40011000 + 0x0C)
            LDR R1, [R0]
            ORR R1, R1, #(1<<3)
            STR R1, [R0]

            @ Set the RE bit USART_CR1
                @ USART1 base address = 0x4001 1000
                        @ USART_CR1 offset = 0x0C
                            @ Reciver enable bit = 2
            LDR R0, =(0x40011000 + 0x0C)
            LDR R1, [R0]
            ORR R1, R1, #(1<<2)
            STR R1, [R0]

            @ TO SEND DATA VIA USART : Write to USART_DR (TDR)
            /* NOTE: After writing the last data into the USART_DR register, wait until TC=1. This indicates
                that the transmission of the last frame is complete. This is required for instance when
                the USART is disabled or enters the Halt mode to avoid corrupting the last
                transmission. 
            */

            @ TO RECIVE DATA VIA USART : Read from USART_DR (RDR)
            /* NOTE: When a character is received :
                The RXNE bit is set. It indicates that the content of the shift register is transferred to the
                RDR. In other words, data has been received and can be read (as well as its
                associated error flags)
            */

            hang:
                B hang
