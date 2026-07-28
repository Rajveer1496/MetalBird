PROGRAM_BIN = program.bin

all : $(PROGRAM_BIN)

$(PROGRAM_BIN) : program.elf
	arm-none-eabi-objcopy -O binary $< $@

program.elf : vector.o linker.ld
	arm-none-eabi-ld -T linker.ld $< -o $@

vector.o : vector.s
	arm-none-eabi-as -mcpu=cortex-m4 -mthumb $< -o $@

run: $(PROGRAM_BIN)
	st-flash write $(PROGRAM_BIN) 0x08000000
	rm -rf $(PROGRAM_BIN) program.elf vector.o

info:
	st-info --probe

clean:
	rm -rf $(PROGRAM_BIN) program.elf vector.o

