/*
I2C2 Initialisation:

1. Pullup SDA (PB3) and SCL (PB10) with GPIOB_PUPDR
2. set speed with GPIOB_OSPEEDR
3. Set output opendrain in GPIO_OTYPER
4. Set Moder to alternate function with GPIOB_MODER
5. set AFxx with GPIOB_AFRL (AF09 for I2C_SDA, AF04 for I2C_SCL)
6. Enable I2C2 clock with RCC_APB1ENR


The following is the required sequence in controller mode.
• Program the peripheral input clock in I2C_CR2 register in order to generate correct
timings
• Configure the clock control registers (I2C_CCR)
• Configure the rise time register (I2C_TRISE)
• Program the I2C_CR1 register to enable the peripheral
• Set the START bit in the I2C_CR1 register to generate a Start condition
The peripheral input clock frequency must be at least:
• 2 MHz in Sm mode
• 4 MHz in Fm mode
*/

/* --------------------------------------------------------------------------------------------------------------------
TO SEND / RECEIVE DATA:

• Set the START bit in the I2C_CR1 register to generate a Start condition
• In 7-bit addressing mode, one address byte is sent.
  As soon as the address byte is sent, the ADDR bit is set by hardware and an interrupt
  is generated if the ITEVFEN bit is set. Then the controller waits for a read of the SR1
  register followed by a read of the SR2 register.

The controller can decide to enter Transmitter or Receiver mode depending on the LSB of
the target address sent.

• In 7-bit addressing mode
    – To enter Transmitter mode, a controller sends the target address with LSB reset.
    – To enter Receiver mode, a controller sends the target address with LSB set.

The TRA bit indicates whether the controller is in Receiver or Transmitter mode.

----------------------------------------------------------------------------------------------------------------------
Controller transmitter:
    Following the address transmission and after clearing ADDR, the controller sends bytes
    from the DR register to the SDA line via the internal shift register.

    The controller waits until the first data byte is written into I2C_DR

    When the acknowledge pulse is received, the TxE bit is set by hardware and an interrupt is
    generated if the ITEVFEN and ITBUFEN bits are set.

    If TxE is set and a data byte was not written in the DR register before the end of the last data
    transmission, BTF is set and the interface waits until BTF is cleared by a write to I2C_DR,
    stretching SCL low.

    Closing the communication:
        After the last byte is written to the DR register, the STOP bit is set by software to generate a
        stop condition. The interface automatically goes back to target mode (MSL bit cleared)
    Note: Stop condition should be programmed during EV8_2 event, when either TxE or BTF is set.

-----------------------------------------------------------------------------------------------------------------------
Controller receiver:
    Following the address transmission and after clearing ADDR, the I2C interface enters
    controller receiver mode. In this mode the interface receives bytes from the SDA line into
    the DR register via the internal shift register. After each byte the interface generates in
    sequence:
        1. An acknowledge pulse if the ACK bit is set
        2. The RxNE bit is set and an interrupt is generated if the ITEVFEN and ITBUFEN bits are set.

    If the RxNE bit is set and the data in the DR register is not read before the end of the last
    data reception, the BTF bit is set by hardware and the interface waits until BTF is cleared by
    a read in the DR register, stretching SCL low.

    Closing the communication:
        The controller sends a NACK for the last byte received from the target. After receiving this
        NACK, the target releases the control of the SCL and SDA lines. Then the controller can
        send a Stop/Restart condition.
            1. To generate the nonacknowledge pulse after the last received data byte, the ACK bit
            must be cleared just after reading the second last data byte (after second last RxNE event).
            2. In order to generate the Stop/Restart condition, software must set the STOP/START bit
            after reading the second last data byte (after the second last RxNE event).
            3. In case a single byte has to be received, the Acknowledge disable is made during EV6
            (before ADDR flag is cleared) and the STOP condition generation is made after EV6.
    
        After the Stop condition generation, the interface goes automatically back to target mode
        (MSL bit cleared).

*/

.syntax unified     @ Thumbed  syntax
.cpu cortex-m4      @ STM32F411 has corex M4 CPU
.thumb              @ tells assembler this is thumb code

.include "reg.i"
.include "debug.i"
.include "time.i"

.section .text, "ax"
    .global i2c_init
    .type i2c_init, %function
    .thumb_func
        i2c_init:
            USART_SEND "I2C_INIT Start\r\n"

            @ 1. Pullup SDA (PB3) and SCL (PB10) with GPIOB_PUPDR
                @ GPIOB base address = 0x4002 0400
                    @ GPIOB_PUPDR offset = 0x0C
                        @ Pull bits (PB3) = 7:6 (00: No pull-up, pull-down / 01: Pull-up / 10: Pull-down / 11: Reserved)
                        @ Pull bits (PB10) = 21:20
            LDR R0, =(GPIOB_BASE + GPIO_PUPDR)
            LDR R1, [R0]
            LDR R2, =(0x3 << 6 | 0x3 << 20)
            BIC R1, R2
            LDR R2, =(0x1 << 6 | 0x1 << 20)
            ORR R1, R2
            STR R1, [R0]

            REG_CHECK "GPIOB_BASE + GPIO_PUPDR" "0x3 << 6 | 0x3 << 20" "0x1 << 6 | 0x1 << 20"

            @ 2. set speed with GPIOB_OSPEEDR
                @ Speed config bits (PB3) = 7:6 (00: Low speed / 01: Medium speed / 10: Fast speed / 11: High speed)
                @ Speed config bits (PB10) = 21:20
            LDR R0, =(GPIOB_BASE + GPIO_OSPEEDR)
            LDR R1, [R0]
            LDR R2, =(0x3 << 6 | 0x3 << 20)
            ORR R1, R2
            STR R1, [R0]

            REG_CHECK "GPIOB_BASE + GPIO_OSPEEDR" "0x3 << 6 | 0x3 << 20" "0x3 << 6 | 0x3 << 20"

            @ 3. Set output opendrain in GPIO_OTYPER
                @ PB3 bit = 3 (0: Output push-pull (reset state) / 1: Output open-drain)
                @ PB10 bit = 10
            LDR R0, =(GPIOB_BASE + GPIO_OTYPER)
            LDR R1, [R0]
            LDR R2, =(1<<3 | 1<<10)
            ORR R1, R2
            STR R1, [R0]

            REG_CHECK "GPIOB_BASE + GPIO_OTYPER" "1<<3 | 1<<10" "1<<3 | 1<<10"

            @ Check the bits in register

            @ 4. Set Moder to alternate function with GPIOB_MODER
                @ PB3 bits = 7:6 (00: Input (reset state) , 01: General purpose output mode , 10: Alternate function mode, 11: Analog mode)
                @ PB10 bits = 21:20
            LDR R0, =(GPIOB_BASE + GPIO_MODER)
            LDR R1, [R0]
            LDR R2, =(0x3<< 6 | 0x3 << 20)
            BIC R1, R2
            LDR R2, =(0x2 << 6 | 0x2 << 20)
            ORR R1, R2
            STR R1, [R0]

            REG_CHECK "GPIOB_BASE + GPIO_MODER" "0x3<< 6 | 0x3 << 20" "0x2 << 6 | 0x2 << 20"


            @ 5. set AFxx with GPIOB_AFRL and GPIOB_AFRH
                @ AF09 for I2C_SDA (PB3), AF04 for I2C_SCL (PB10)
                @ Bits for PB3 = 15:12 in AFRL (AF09 = 1001)
                @ Bits for PB10 = 11:8 in AFRH (AF04 = 0100)
            LDR R0, =(GPIOB_BASE + GPIO_AFRL)
            LDR R1, [R0]
            BIC R1, R1, #(0xF << 12)
            ORR R1, R1, #(0x9 << 12)
            STR R1, [R0]

            REG_CHECK "GPIOB_BASE + GPIO_AFRL" "0xF << 12" "0x09 << 12" 

            LDR R0, =(GPIOB_BASE + GPIO_AFRH)
            LDR R1, [R0]
            BIC R1, R1, #(0xF << 8)
            ORR R1, R1, #(0X4 << 8)
            str R1, [R0]

            REG_CHECK "GPIOB_BASE + GPIO_AFRH" "0xF << 8" "0X4 << 8"

            @ Enable I2C2 clock with RCC_APB1ENR
                @ I2C2EN bit = 22
            LDR R0, =(RCC_BASE + RCC_APB1ENR)
            LDR R1, [R0]
            ORR R1, #(1 << 22)
            STR R1, [R0]

            REG_CHECK "RCC_BASE + RCC_APB1ENR" "1 << 22" "1 << 22"

            @ Program the Peripheral clock frequency in I2C_CR2 register in order to generate correct timings.
            @ NOTE: It is to tell peripheral what our APB1 frequency is
                @ I2C2 uses -> APB1 uses -> PCLK1 (42 MHz in our case)
                @ Peripheral clock frequency bits = 5:0 (0b000010: 2 MHz ... 0b110010: 50 MHz)
            LDR R0, =(I2C2_BASE + I2C_CR2)
            LDR R1, [R0]
            BIC R1, R1, #(0x3F)
            ORR R1, R1, #(0x2A)
            STR R1, [R0]

            REG_CHECK "I2C2_BASE + I2C_CR2" "0x3F" "0x2A"

            @ Configure the clock control registers (I2C_CCR)
                @ FM / SM mode bit = 15 (0: Sm mode, 1: Fm mode)
                @ Duty bit = 14 (0: Fm mode tlow/thigh = 2 / 1: Fm mode tlow/thigh = 16/9)
                @ CCR bits = 11:0
                @ For 400 KHz FM mode : Duty=0 , CCR=0x23
            LDR R0, =(I2C2_BASE + I2C_CCR)
            LDR R1, [R0]
            LDR R2, =(1<<14 | 0xFFF)
            BIC R1, R2
            LDR R2, =(1<<15 | 0x23)
            ORR R1, R2
            STR R1, [R0]

            REG_CHECK "I2C2_BASE + I2C_CCR" "0x1<<15 | 0x1<<14 | 0xFFF" "1<<15 | 0x23"

            @ Configure the rise time register (I2C_TRISE)
                @ TRISE = (max rise time / T_PCLK1) + 1 , Take integr part to respect t_HIGH
                    @ Fm max SCL rise time (I²C spec) = 300 ns
                @ TRISE bits= 5:0 (at Pclk1=42 MHz and I2C speed at 400 KHz FM, TRISE=0xD)
            LDR R0, =(I2C2_BASE + I2C_TRISE)
            LDR R1, [R0]
            BIC R1, #(0x3F)
            ORR R1, #(0xD)
            STR R1, [R0]

            REG_CHECK "I2C2_BASE + I2C_TRISE" "0x3F" "0xD"

            @ Enable Acknowledge
                @ Acknowledge bit = 10 (0: No acknowledge returned / 1: Acknowledge returned after a byte is received (matched address or data))
            LDR R0, =(I2C2_BASE + I2C_CR1)
            LDR R1, [R0]
            ORR R1, R1, #(0x1 << 10)
            STR R1, [R0]

            REG_CHECK "I2C2_BASE + I2C_CR1" "0x1 << 10" "0x1 << 10" "ENABLE ACK"

            @ Program the I2C_CR1 register to enable the peripheral
                @ Peripheral enable bit = 0 (0: Peripheral disable, 1: Peripheral enable)
            LDR R0, =(I2C2_BASE + I2C_CR1)
            LDR R1, [R0]
            ORR R1, #(0x1)
            STR R1, [R0]

            REG_CHECK "I2C2_BASE + I2C_CR1" "0x1" "0x1"

            @ SELF TEST
                @ Set the START bit in the I2C_CR1 register to generate a Start condition
                @ START bit = 8 (In Controller mode: 0: No Start generation / 1: Repeated start generation)
                    LDR R0, =(I2C2_BASE + I2C_CR1)
                    LDR R1, [R0]
                    ORR R1, R1, #(1<<8)
                    STR R1, [R0]

                    UDEBUG

                    @ Wait untill Start condition is generated by reading SB bit in I2C_SR1
                        @ SB bit = 0
                    LDR R0, =(I2C2_BASE + I2C_SR1)
                    I2C_SB_WAIT_init:
                        LDR R1, [R0]
                        ANDS R1, R1, #(0x1)
                        BEQ I2C_SB_WAIT_init

                @ Send stop condition


            USART_SEND "I2C_INIT Complete\r\n"

            BX LR


@ Function to send data to I2C device with given address
    .global i2c_send
    .type i2c_send, %function
    .thumb_func
        i2c_send:
            @ R5 = 7 bit address
            @ R6 = Data Address
            @ R7 = Data Size (in Bytes)

            PUSH {R0-R5}

            @ Set the START bit in the I2C_CR1 register to generate a Start condition
                @ START bit = 8 (In Controller mode: 0: No Start generation / 1: Repeated start generation)
            LDR R0, =(I2C2_BASE + I2C_CR1)
            LDR R1, [R0]
            ORR R1, R1, #(1<<8)
            STR R1, [R0]

            @ Wait untill Start condition is generated by reading SB bit in I2C_SR1
                @ SB bit = 0
            LDR R0, =(I2C2_BASE + I2C_SR1)
            I2C_SB_WAIT:
                LDR R1, [R0]
                ANDS R1, R1, #(0x1)
                BEQ I2C_SB_WAIT
            
            /*  
                The target address is sent to the SDA line via the internal shift register.

                In 7-bit addressing mode, one address byte is sent.
                As soon as the address byte is sent, the ADDR bit is set by hardware

                In 7-bit addressing mode
                    – To enter Transmitter mode, a controller sends the target address with LSB reset.
                    – To enter Receiver mode, a controller sends the target address with LSB set.

                The TRA bit indicates whether the controller is in Receiver or Transmitter mode.
            */

            @ Send address byte in I2C_DR Register
                @ Data bits = 7:0
            LDR R0, =(I2C2_BASE + I2C_DR)
            LDR R1, [R0]
            BIC R1, R1, #(0xFF)
            LDR R2, =(0xFFFFFF << 9 | 0x1) @ To clear unwanted bits and reset LSB for address byte
            LSL R5, R5, #(0x1)
            BIC R5, R2
            ORR R1, R5
            STR R1, [R0]

            @ Read I2C_SR1 to clear ADDR
                @ ADDR bit = 1
            LDR R0, =(I2C2_BASE + I2C_SR1)
            I2C_ADDR_WAIT:
                LDR R1, [R0]
                ANDS R1, R1, #(0x2)
                BEQ I2C_ADDR_WAIT

            @ Send Data Bytes in I2C_DR
                @ Data bits = 7:0
            I2C_DATA_SEND_MAIN_LOOP:
                LDR R0, =(I2C2_BASE + I2C_DR)
                LDRB R2, [R6], #1           @ The data byte

                SUBS R7, R7, #1                  @ Check for End of data
                CMP R7, #0
                BLT I2C_DATA_COMPLETE

                LDR R3, =(0xFFFFFF << 9)
                BIC R2, R3

                LDR R1, [R0]                @ I2C_DR content
                ORR R1, R2
                STR R1, [R0]                @ Write to I2C_DR

                @ Wait untill I2C_DR is empty by checking TxE bit in I2C_SR1
                    @ TxE bit = 7 (0: Data register not empty / 1: Data register empty)
                LDR R0, =(I2C2_BASE + I2C_SR1)
                I2C_TxE_Wait:
                    LDR R1, [R0]
                    ANDS R1, R1, #(1<<7)
                    BEQ I2C_TxE_Wait

            B I2C_DATA_SEND_MAIN_LOOP

            I2C_DATA_COMPLETE:
            @ Send Closing bit
                @ Check if TxE bit is set
                LDR R0, =(I2C2_BASE + I2C_SR1)
                I2C_TxE_Wait_2:
                    LDR R1, [R0]
                    ANDS R1, R1, #(1<<7)
                    BEQ I2C_TxE_Wait_2
            
            @ Send Stop condition in I2C_CR1
                @ Stop bit = 9
            LDR R0, =(I2C2_BASE + I2C_CR1)
            LDR R1, [R0]
            ORR R1, #(1 << 9)
            STR R1, [R0]

            POP {R0-R5}
            BX LR

@ Function to receive data to I2C device with given address
    .global i2c_receive
    .type i2c_receive, %function
    .thumb_func
        i2c_receive:
            @ R5 = 7 bit address
            @ R6 = Data Address
            @ R7 = Data Size (in Bytes)

            PUSH {R0-R5}

            @ Enable Acknowledge
                @ Acknowledge bit = 10 (0: No acknowledge returned / 1: Acknowledge returned after a byte is received (matched address or data))
            LDR R0, =(I2C2_BASE + I2C_CR1)
            LDR R1, [R0]
            ORR R1, R1, #(0x1 << 10)
            STR R1, [R0]

            @ Set the START bit in the I2C_CR1 register to generate a Start condition
                @ START bit = 8 (In Controller mode: 0: No Start generation / 1: Repeated start generation)
            LDR R0, =(I2C2_BASE + I2C_CR1)
            LDR R1, [R0]
            ORR R1, R1, #(1<<8)
            STR R1, [R0]

            @ Wait untill Start condition is generated by reading SB bit in I2C_SR1
                @ SB bit = 0
            LDR R0, =(I2C2_BASE + I2C_SR1)
            I2C_SB_WAIT_2:
                LDR R1, [R0]
                ANDS R1, R1, #(0x1)
                BEQ I2C_SB_WAIT_2

            /*  
                The target address is sent to the SDA line via the internal shift register.

                In 7-bit addressing mode, one address byte is sent.
                As soon as the address byte is sent, the ADDR bit is set by hardware

                In 7-bit addressing mode
                    – To enter Transmitter mode, a controller sends the target address with LSB reset.
                    – To enter Receiver mode, a controller sends the target address with LSB set.

                The TRA bit indicates whether the controller is in Receiver or Transmitter mode.
            */

            @ Send address byte in I2C_DR Register
                @ Data bits = 7:0
            LDR R0, =(I2C2_BASE + I2C_DR)
            LDR R1, [R0]
            BIC R1, R1, #(0xFF)
            LDR R2, =(0xFFFFFF << 9) @ To clear unwanted
            LSL R5, R5, #(0x1)
            ORR R5, R5, #(0x1)
            BIC R5, R2
            ORR R1, R5
            STR R1, [R0]

            @ Read I2C_SR1 to clear ADDR
                @ ADDR bit = 1
            LDR R0, =(I2C2_BASE + I2C_SR1)
            I2C_ADDR_WAIT_2:
                LDR R1, [R0]
                ANDS R1, R1, #(0x2)
                BEQ I2C_ADDR_WAIT_2
            
            @ Check BTF bit if byte transfer is finished or not
                @ BTF bit = 2
            I2C_RECEIVE_BTF_WAIT:
                LDR R0, =(I2C2_BASE + I2C_SR1)
                LDR R1, [R0]
                ANDS R1, R1, #(1<<2)
                BEQ I2C_RECEIVE_BTF_WAIT

            @ Read data from DR register
                @ Data bits = 7:0
            LDR R0, =(I2C2_BASE + I2C_DR)
            LDR R1,[R0]
            STRB R1, [R6], #1

            SUBS R7, R7, #1                  @ Check for End of data
                CMP R7, #0
                BLT I2C_RECEIVE_DATA_COMPLETE

            B I2C_RECEIVE_BTF_WAIT

            I2C_RECEIVE_DATA_COMPLETE:

            @ send Stop condition
                @ Stop bit = 9
            LDR R0, =(I2C2_BASE + I2C_CR1)
            LDR R1, [R0]
            ORR R1, #(1<<9)
            STR R1, [R0]  

            POP {R0-R5}
            BX LR

    .global i2c_mpu6050_receive
    .type i2c_mpu6050_receive, %function
    .thumb_func
        i2c_mpu6050_receive:
            USART_SEND "MPU_RECIVE START\r\n"
            @ R6 = Data Address
            @ R7 = Data Size (in Bytes)
            @ R8 = MPU6050 register address

            PUSH {R0-R5}

            LDR R5, =(0x69) @ MPU6050 slave address when ADO=1
            
            @ Enable Acknowledge
            @ Acknowledge bit = 10 (0: No acknowledge returned / 1: Acknowledge returned after a byte is received (matched address or data))
            LDR R0, =(I2C2_BASE + I2C_CR1)
            LDR R1, [R0]
            ORR R1, R1, #(0x1 << 10)
            STR R1, [R0]

        @ Send MPU6050 Register address

                @ Set the START bit in the I2C_CR1 register to generate a Start condition
                @ START bit = 8 (In Controller mode: 0: No Start generation / 1: Repeated start generation)
            LDR R0, =(I2C2_BASE + I2C_CR1)
            LDR R1, [R0]
            ORR R1, R1, #(1<<8)
            STR R1, [R0]

            UDEBUG

            @ Wait untill Start condition is generated by reading SB bit in I2C_SR1
                @ SB bit = 0
            LDR R0, =(I2C2_BASE + I2C_SR1)
            I2C_SB_WAIT_mpu6050:
                LDR R1, [R0]
                ANDS R1, R1, #(0x1)
                BEQ I2C_SB_WAIT_mpu6050

            UDEBUG

            /*  
                The target address is sent to the SDA line via the internal shift register.

                In 7-bit addressing mode, one address byte is sent.
                As soon as the address byte is sent, the ADDR bit is set by hardware

                In 7-bit addressing mode
                    – To enter Transmitter mode, a controller sends the target address with LSB reset.
                    – To enter Receiver mode, a controller sends the target address with LSB set.

                The TRA bit indicates whether the controller is in Receiver or Transmitter mode.
            */

            @ Send address byte in I2C_DR Register
                @ Data bits = 7:0
            LDR R0, =(I2C2_BASE + I2C_DR)
            LDR R1, [R0]
            BIC R1, R1, #(0xFF)
            LDR R2, =(0xFFFFFF << 9 | 0x1) @ To clear unwanted bits and reset LSB for address byte
            LSL R5, R5, #(0x1)
            BIC R5, R2
            ORR R1, R5
            STR R1, [R0]

            @ Read I2C_SR1 to clear ADDR
                @ ADDR bit = 1
            LDR R0, =(I2C2_BASE + I2C_SR1)
            I2C_ADDR_WAIT_mpu6050:
                LDR R1, [R0]
                ANDS R1, R1, #(0x2)
                BEQ I2C_ADDR_WAIT_mpu6050

            @ Send MPU6050 register in I2C_DR
                @ Data bits = 7:0
                LDR R0, =(I2C2_BASE + I2C_DR)

                LDR R3, =(0xFFFFFF << 9)
                BIC R8, R3

                LDR R1, [R0]                @ I2C_DR content
                ORR R1, R8
                STR R1, [R0]                @ Write to I2C_DR

                @ wait for acknowledgment from mpu6050------------------- THE TxE bit
                @ TxE bit = 7 (0: Data register not empty / 1: Data register empty)
                LDR R0, =(I2C2_BASE + I2C_SR1)
                I2C_TxE_Wait_mpu6050:
                    LDR R1, [R0]
                    ANDS R1, R1, #(1<<7)
                    BEQ I2C_TxE_Wait_mpu6050

        @ Reading from MPU6050

            @ Set the START bit in the I2C_CR1 register to generate a Start condition
                @ START bit = 8 (In Controller mode: 0: No Start generation / 1: Repeated start generation)
            LDR R0, =(I2C2_BASE + I2C_CR1)
            LDR R1, [R0]
            ORR R1, R1, #(1<<8)
            STR R1, [R0]

            @ Wait untill Start condition is generated by reading SB bit in I2C_SR1
                @ SB bit = 0
            LDR R0, =(I2C2_BASE + I2C_SR1)
            I2C_SB_WAIT__mpu6050:
                LDR R1, [R0]
                ANDS R1, R1, #(0x1)
                BEQ I2C_SB_WAIT__mpu6050

            /*  
                The target address is sent to the SDA line via the internal shift register.

                In 7-bit addressing mode, one address byte is sent.
                As soon as the address byte is sent, the ADDR bit is set by hardware

                In 7-bit addressing mode
                    – To enter Transmitter mode, a controller sends the target address with LSB reset.
                    – To enter Receiver mode, a controller sends the target address with LSB set.

                The TRA bit indicates whether the controller is in Receiver or Transmitter mode.
            */

            @ Send address byte in I2C_DR Register
                @ Data bits = 7:0
            LDR R0, =(I2C2_BASE + I2C_DR)
            LDR R1, [R0]
            BIC R1, R1, #(0xFF)
            LDR R2, =(0xFFFFFF << 9) @ To clear unwanted
            LSL R5, R5, #(0x1)
            ORR R5, R5, #(0x1)
            BIC R5, R2
            ORR R1, R5
            STR R1, [R0]

                @ If it is single byte transfer ACK must be disabled before Clearing ADDR
                CMP R7, #1  @ if only 1 data byte is to be transfered
                BNE I2C_RECEIVE_MORE_BYTES_mpu6050
                    @ Disable ACK
                    LDR R0, =(I2C2_BASE + I2C_CR1)
                    LDR R1, [R0]
                    BIC R1, R1, #(0x1 << 10)
                    STR R1, [R0]

            I2C_RECEIVE_MORE_BYTES_mpu6050:

            @ Read I2C_SR1 to clear ADDR
                @ ADDR bit = 1
            LDR R0, =(I2C2_BASE + I2C_SR1)
            I2C_ADDR_WAIT_mpu6050_2:
                LDR R1, [R0]
                ANDS R1, R1, #(0x2)
                BEQ I2C_ADDR_WAIT_mpu6050
            
            @ Check BTF bit if byte transfer is finished or not
                @ BTF bit = 2
            I2C_RECEIVE_BTF_WAIT_mpu6050:
                LDR R0, =(I2C2_BASE + I2C_SR1)
                LDR R1, [R0]
                ANDS R1, R1, #(1<<2)
                BEQ I2C_RECEIVE_BTF_WAIT_mpu6050

            @ Read data from DR register
                @ Data bits = 7:0
            LDR R0, =(I2C2_BASE + I2C_DR)
            LDR R1,[R0]
            STRB R1, [R6], #1

            SUBS R7, R7, #1              @ Check for End of data
                CMP R7, #0
                BLE I2C_RECEIVE_DATA_COMPLETE_mpu6050

            B I2C_RECEIVE_BTF_WAIT_mpu6050

            I2C_RECEIVE_DATA_COMPLETE_mpu6050:

            @ send Stop condition
                @ Stop bit = 9 (In Controller mode: 0: No Stop generation. 1: Stop generation after the current byte transfer or after the current Start condition is sent.)
            LDR R0, =(I2C2_BASE + I2C_CR1)
            LDR R1, [R0]
            ORR R1, #(1<<9)
            STR R1, [R0]
            
            POP {R0-R5}

            USART_SEND "MPU_RECIVE END\r\n"
            BX LR

@ ---------------------------------------------------------------- BTF bit might-------------------------



/*
    MPU6050:

    The slave address of the MPU-60X0 is b110100X which is 7 bits long. The LSB bit of the 7 bit address is
    determined by the logic level on pin AD0. This allows two MPU-60X0s to be connected to the same I2C bus.
    When used in this configuration, the address of the one of the devices should be b1101000 (pin AD0 is logic
    low) and the address of the other should be b1101001 (pin AD0 is logic high).

    After beginning communications with the START condition (S), the master sends a 7-bit slave address
    followed by an 8th bit, the read/write bit. The read/write bit indicates whether the master is receiving data from
    or is writing to the slave device. Then, the master releases the SDA line and waits for the acknowledge
    signal (ACK) from the slave device. Each byte transferred must be followed by an acknowledge bit. To
    acknowledge, the slave device pulls the SDA line LOW and keeps it LOW for the high period of the SCL line.
    Data transmission is always terminated by the master with a STOP condition (P), thus freeing the
    communications line. However, the master can generate a repeated START condition (Sr), and address
    another slave without first generating a STOP condition (P). A LOW to HIGH transition on the SDA line while
    SCL is HIGH defines the stop condition. All SDA changes should take place when SCL is low, with the
    exception of start and stop conditions

    Write to MPU6050:
        To write the internal MPU-60X0 registers, the master transmits the start condition (S), followed by the I2C
        address and the write bit (0). At the 9th clock cycle (when the clock is high), the MPU-60X0 acknowledges the
        transfer. Then the master puts the register address (RA) on the bus. After the MPU-60X0 acknowledges the
        reception of the register address, the master puts the register data onto the bus. This is followed by the ACK
        signal, and data transfer may be concluded by the stop condition (P). To write multiple bytes after the last
        ACK signal, the master can continue outputting data rather than transmitting a stop signal. In this case, the
        MPU-60X0 automatically increments the register address and loads the data to the appropriate register.

    Read from MPU6050:
        To read the internal MPU-60X0 registers, the master sends a start condition, followed by the I2C address and
        a write bit, and then the register address that is going to be read. Upon receiving the ACK signal from the
        MPU-60X0, the master transmits a start signal followed by the slave address and read bit. As a result, the
        MPU-60X0 sends an ACK signal and the data. The communication ends with a not acknowledge (NACK)
        signal and a stop bit from master. The NACK condition is defined such that the SDA line remains high at the
        9th clock cycle.

*/