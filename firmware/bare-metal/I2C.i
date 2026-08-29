.macro MPU6050_RECEIVE data_addr:req data_size:req mpu_reg_addr:req
    PUSH {R6-R8, LR}
    LDR R6, =(\data_addr)
    LDR R7, =(\data_size)
    LDR R8, =(\mpu_reg_addr)
    BL i2c_mpu6050_receive
    POP {R6-R8, LR}
.endm

@ R6 = Data Address
@ R7 = Data Size (in Bytes)
@ R8 = MPU6050 register address