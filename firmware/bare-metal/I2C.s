/*
I2C2 Initialisation:

1. Pullup SDA (PB3) and SCL (PB10) with GPIOB_PUPDR
2. set speed with GPIOB_OSPEEDR
3. set AFxx with GPIOB_AFRL (AF09 for I2C_SDA, AF04 for I2C_SCL)
4. Enable I2C2 clock with RCC_APB1ENR


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


5. Set Moder to alternate function with GPIOB_MODER

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

.include "debug.i"
.include "time.i"
.include "reg.i"

.section .text, "ax"
    .global i2c_init
    .type i2c_init, %function
    .thumb_func
        i2c_init:

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

            @ 2. set speed with GPIOB_OSPEEDR
                @ Speed config bits (PB3) = 7:6 (00: Low speed / 01: Medium speed / 10: Fast speed / 11: High speed)
                @ Speed config bits (PB10) = 21:20
            LDR R0, =(GPIOB_BASE + GPIO_OSPEEDR)
            LDR R1, [R0]
            LDR R2, =(0x3 << 6 | 0x3 << 20)
            ORR R1, R2
            STR R1, [R0]

            @ 3. set AFxx with GPIOB_AFRL and GPIOB_AFRH
                @ AF09 for I2C_SDA (PB3), AF04 for I2C_SCL (PB10)
                @ Bits for PB3 = 15:12 in AFRL (AF09 = 1001)
                @ Bits for PB10 = 11:8 in AFRH (AF04 = 0100)
            LDR R0, =(GPIOB_BASE + GPIO_AFRL)
            LDR R1, [R0]
            BIC R1, R1, #(0xF << 12)
            ORR R1, R1, #(0x9 << 12)
            STR R1, [R0]

            LDR R0, =(GPIOB_BASE + GPIO_AFRH)
            LDR R1, [R0]
            BIC R1, R1, #(0xF << 8)
            ORR R1, R1, #(0X4 << 8)
            str R1, [R0]

            @ 4. Enable I2C2 clock with RCC_APB1ENR
                @ I2C2EN bit = 22
            LDR R0, =(RCC_BASE + RCC_APB1ENR)
            LDR R1, [R0]
            ORR R1, #(1 << 22)
            STR R1, [R0]

            @ Program the Peripheral clock frequency in I2C_CR2 register in order to generate correct timings.
                @ I2C2 uses -> APB1 uses -> PCLK1 (42 MHz in our case)
                @ Peripheral clock frequency bits = 5:0 (0b000010: 2 MHz ... 0b101000: 40 MHz ... 0b110010: 50 MHz)
            LDR R0, =(I2C2_BASE + I2C_CR2)
            LDR R1, [R0]
            BIC R1, R1, #(0x1F)
            ORR R1, R1, #(0x28)
            STR R1, [R0]

            @ Configure the clock control registers (I2C_CCR)
                /* TO DO--------------------------------------------------------------------------------- */



            