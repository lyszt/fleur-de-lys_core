AS      := riscv64-unknown-elf-as
CC      := clang
LD      := riscv64-unknown-elf-ld

ARCH    := -march=rv64i -mabi=lp64

SRCDIR   := src
LDSCRIPT := $(SRCDIR)/linker.ld
BUILD    := build
TARGET   := $(BUILD)/os.elf

ASFLAGS  := $(ARCH)
CFLAGS   := --target=riscv64-unknown-elf $(ARCH) -mcmodel=medany -ffreestanding -fno-exceptions -fno-rtti -nostdlib -O0 -I$(SRCDIR)
LDFLAGS  := -T $(LDSCRIPT)

# 1. Dynamically find every .cpp and .s file in any subfolder of SRCDIR
CPP_SRCS := $(shell find $(SRCDIR) -name '*.cpp')
ASM_SRCS := $(shell find $(SRCDIR) -name '*.s')

CPP_OBJS := $(patsubst $(SRCDIR)/%.cpp, $(BUILD)/%.o, $(CPP_SRCS))
ASM_OBJS := $(patsubst $(SRCDIR)/%.s, $(BUILD)/%.o, $(ASM_SRCS))

OBJS := $(ASM_OBJS) $(CPP_OBJS)

.PHONY: all clean run

all: $(TARGET)

# Rule for Assembly files
$(BUILD)/%.o: $(SRCDIR)/%.s
	@mkdir -p $(dir $@)
	$(AS) $(ASFLAGS) $< -o $@

$(BUILD)/%.o: $(SRCDIR)/%.cpp
	@mkdir -p $(dir $@)
	$(CC) $(CFLAGS) -c $< -o $@

$(TARGET): $(OBJS)
	$(LD) $(LDFLAGS) $^ -o $@

run: $(TARGET)
	qemu-system-riscv64 -machine virt -bios none -kernel $(TARGET) -serial stdio -display gtk

clean:
	rm -rf $(BUILD)
