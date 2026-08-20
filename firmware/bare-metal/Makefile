PROGRAM_BIN = program.bin
BAUD_RATE = 115200

all : $(PROGRAM_BIN)

$(PROGRAM_BIN) : program.elf
	arm-none-eabi-objcopy -O binary $< $@

program.elf : vector.o usart_debug.o I2C.o
	arm-none-eabi-ld -T linker.ld vector.o usart_debug.o -o $@

I2C.o : I2C.s
	arm-none-eabi-as -mcpu=cortex-m4 -mthumb $< -o $@

usart_debug.o : usart_debug.s
	arm-none-eabi-as -mcpu=cortex-m4 -mthumb $< -o $@

vector.o : vector.s
	arm-none-eabi-as -mcpu=cortex-m4 -mthumb $< -o $@

run: $(PROGRAM_BIN)
	st-flash write $(PROGRAM_BIN) 0x08000000
	rm -rf *.bin *.elf *.o

info:
	st-info --probe

clean:
	rm -rf *.bin *.elf *.o

debug:
	stty -F /dev/ttyUSB0 115200 raw -echo clocal -crtscts
	picocom --noinit /dev/ttyUSB0
