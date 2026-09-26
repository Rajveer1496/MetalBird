.macro MPU6050_RECEIVE data_size:req mpu_reg_addr:req
    PUSH {R6-R8, LR}
    LDR R7, =(\data_size)
    LDR R8, =(\mpu_reg_addr)
    BL i2c_mpu6050_receive
    POP {R6-R8, LR}
.endm

.macro MPU6050_SEND data_input_reg:req data_size:req mpu_reg_addr:req
    PUSH {R6-R8, LR}
    MOV R6, \data_input_reg
    LDR R7, =(\data_size)
    LDR R8, =(\mpu_reg_addr)
    BL i2c_mpu6050_send
    POP {R6-R8, LR}
.endm
