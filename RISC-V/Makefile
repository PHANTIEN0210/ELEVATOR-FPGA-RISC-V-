PREFIX       ?= riscv-none-elf-
CC            = $(PREFIX)gcc
OBJCOPY       = $(PREFIX)objcopy
OBJDUMP       = $(PREFIX)objdump
SIZE          = $(PREFIX)size

ARCH          ?= rv32im
ABI           ?= ilp32

CFLAGS        = -march=$(ARCH) -mabi=$(ABI) -O2 -Wall -Wextra \
                -ffunction-sections -fdata-sections \
                -nostdlib -nostartfiles -fno-builtin -pipe

LDFLAGS       = -Wl,-T,link.ld -Wl,--gc-sections -lgcc

TARGET        = firmware
C_SRCS        = elevator.c
ASM_SRCS      = crt0.S
OBJS          = $(ASM_SRCS:.S=.o) $(C_SRCS:.c=.o)

# Gowin project references the firmware images from src/.
DEST_DIR      = ../src
PYTHON        ?= python

.PHONY: all hex disasm clean

all: hex

%.o: %.c
	$(CC) $(CFLAGS) -c $< -o $@

%.o: %.S
	$(CC) $(CFLAGS) -c $< -o $@

$(TARGET).elf: $(OBJS)
	$(CC) $(CFLAGS) $(OBJS) $(LDFLAGS) -o $@
	@echo ""
	$(SIZE) $@

$(TARGET).bin: $(TARGET).elf
	$(OBJCOPY) -O binary $< $@

hex: $(TARGET).bin
	$(PYTHON) make_hex.py $(TARGET).bin $(DEST_DIR) 0x80

disasm: $(TARGET).elf
	$(OBJDUMP) -d $< > $(TARGET).dis

clean:
	rm -f *.o *.elf *.bin *.dis
	rm -f $(DEST_DIR)/firmware_bank*.hex
