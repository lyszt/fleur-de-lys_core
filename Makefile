AS      := riscv64-unknown-elf-as
CC      := clang
LD      := riscv64-unknown-elf-ld

ARCH    := -march=rv64i -mabi=lp64

SRCDIR   := src/src
LDSCRIPT := src/linker.ld
BUILD    := build
TARGET   := $(BUILD)/os.elf

ASFLAGS  := $(ARCH)
CFLAGS   := --target=riscv64-unknown-elf $(ARCH) -mcmodel=medany -ffreestanding -fno-exceptions -fno-rtti -nostdlib -O0
LDFLAGS  := -T $(LDSCRIPT)

OBJS := $(BUILD)/boot.o $(BUILD)/kernel.o

.PHONY: all clean run

all: $(TARGET)

$(BUILD):
	mkdir -p $@

$(BUILD)/boot.o: $(SRCDIR)/boot.s | $(BUILD)
	$(AS) $(ASFLAGS) $< -o $@

$(BUILD)/kernel.o: $(SRCDIR)/kernel.cpp | $(BUILD)
	$(CC) $(CFLAGS) -c $< -o $@

$(TARGET): $(OBJS)
	$(LD) $(LDFLAGS) $^ -o $@

run: $(TARGET)
	qemu-system-riscv64 -machine virt -bios none -kernel $(TARGET) -serial stdio

clean:
	rm -rf $(BUILD)
