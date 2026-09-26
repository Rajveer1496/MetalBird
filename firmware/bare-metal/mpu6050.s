/*
Selection of the source for generating the internal synchronous clock depends on the availability of external
sources and the requirements for power consumption and clock accuracy. These requirements will most
likely vary by mode of operation. For example, in one mode, where the biggest concern is power
consumption, the user may wish to operate the Digital Motion Processor of the MPU-60X0 to process
accelerometer data, while keeping the gyros off. In this case, the internal relaxation oscillator is a good clock
choice. However, in another mode, where the gyros are active, selecting the gyros as the clock source
provides for a more accurate clock source
 */
.syntax unified     @ Thumb-2 syntax
.cpu cortex-m4      @ STM32F411 has corex M4 CPU
.thumb              @ tells assembler this is thumb code

.include "time.i"
.include "reg.i"
.include "debug.i"
.include "I2C.i"

.equiv MPU6050_POWER_UP_TIME, 100
.equiv MPU6050_REG_UP_TIME_MAX, 10000

.section .text, "ax"
    .global mpu6050_init
    .type mpu6050_init, %function
    .thumb_func
        mpu6050_init:
            PUSH {R0-R5}
            MPU6050_RECEIVE 1 0x75
            CMP R0, #(0x68)
            BNE mpu6050_init_fail

            MOV R0, #(0x80) @ 7th bit set -> reset
            MPU6050_SEND R0 1 0x6B
            SYSTICK_SLEEP MPU6050_POWER_UP_TIME

            MOV R0, #(0x1)  @ Select X axis gyro as clock source
            MPU6050_SEND R0 1 0x6B
            SYSTICK_SLEEP MPU6050_REG_UP_TIME_MAX

        B mpu6050_init_done
        mpu6050_init_fail:
            USART_SEND "[ERROR]: MPU6050 WHO AM I FAIL\r\n"
        mpu6050_init_done:
        USART_SEND "MPU6050 Init Complete\r\n"

        POP {R0-R5}
        BX LR
