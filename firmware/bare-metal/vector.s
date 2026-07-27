.syntax unified     @ Thumb-2 syntax
.cpu cortex-m4      @ STM32F411 has corex M4 CPU
.thumb              @ tells assembler this is thumb code


.section .vector, "a"
    .word 0x20020000        @ SP value
    .word Reset_Handler+1   @ Reset handler address + 1(Thumb mode)

.section .text, "ax"
    .global Reset_Handler
        Reset_Handler:
            hang:
                B hang
