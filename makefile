# RISC-V GCC toolchain prefix.
# Common options:
# - riscv32-unknown-elf-
# - riscv64-unknown-elf-
#
# Example:
#   make RISCV_PREFIX=riscv64-unknown-elf-
RISCV_PREFIX ?= riscv32-unknown-elf-
CC      := $(RISCV_PREFIX)gcc
OBJDUMP := $(RISCV_PREFIX)objdump
OBJCOPY := $(RISCV_PREFIX)objcopy
HOST_CC ?= gcc

BUILD_DIR := build

ELF := $(BUILD_DIR)/main.elf
BIN := $(BUILD_DIR)/main.bin
ASM := $(BUILD_DIR)/main.asm

IMEM_DAT := sw/imem.dat
BOOTLOADER_BIN := tools/bootloader

SW_DIR := sw

# Select which software entry file to build (relative to sw/).
# Example:
#   make RISCV_PREFIX=riscv64-unknown-elf- riscv-test-sim
SW_APP ?= main.c
SW_APP_PATH := $(SW_DIR)/$(SW_APP)

CFLAGS  := -march=rv32i -mabi=ilp32 -O0 -g3 \
	-ffreestanding -fno-builtin \
	-fno-builtin-memcpy -fno-builtin-memset -fno-builtin-memmove -fno-builtin-memcmp \
	-fno-tree-loop-distribute-patterns \
	-fno-jump-tables -fno-tree-switch-conversion -Wall -Wextra
LDFLAGS := -nostdlib -Wl,-T,$(SW_DIR)/link.ld -Wl,--gc-sections

.PHONY: all clean toolchain-check sim sim-gui sim-batch riscv-test riscv-test-sim vivado-syn bootloader

all: $(IMEM_DAT) $(ASM) bootloader

toolchain-check:
	@command -v $(CC) >/dev/null 2>&1 || (echo "ERROR: $(CC) not found. Install a RISC-V GCC toolchain, or override RISCV_PREFIX (e.g. make RISCV_PREFIX=riscv64-unknown-elf-)." && exit 1)

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

SW_COMMON_SRCS := $(SW_DIR)/stdio.c

$(ELF): toolchain-check $(BUILD_DIR) $(SW_DIR)/crt0.S $(SW_APP_PATH) $(SW_COMMON_SRCS) $(SW_DIR)/link.ld
	$(CC) $(CFLAGS) $(LDFLAGS) -o $@ $(SW_DIR)/crt0.S $(SW_APP_PATH) $(SW_COMMON_SRCS)

$(BIN): $(ELF)
	$(OBJCOPY) -O binary $< $@

$(ASM): $(ELF)
	$(OBJDUMP) -d -S $< > $@

$(IMEM_DAT): $(BIN) tools/bin2imem.py
	python3 tools/bin2imem.py $(BIN) $(IMEM_DAT) --words 1024

clean:
	rm -rf $(BUILD_DIR) $(IMEM_DAT)
	rm -f $(BOOTLOADER_BIN)

# Simulation configuration
TOP_MODULE ?= tb_ROC_RV32_program
SIM_MODE ?= gui

# `make sim SW_APP=foo.c` builds, generates sw/imem.dat and runs the simulator.
# Choose GUI vs batch with SIM_MODE=gui|batch, or use the convenience targets
# `make sim-gui ...` / `make sim-batch ...`.
sim: $(IMEM_DAT)
	@if [ "$(SIM_MODE)" = "batch" ]; then \
		./run_batch.sh $(TOP_MODULE); \
	else \
		./run.sh $(TOP_MODULE); \
	fi

sim-gui: SIM_MODE=gui
sim-gui: sim

sim-batch: SIM_MODE=batch
sim-batch: sim

# Build and run the RV32I self-checking test.
riscv-test:
	$(MAKE) SW_APP=tests/rv32i_full.S all

riscv-test-sim:
	$(MAKE) SW_APP=tests/rv32i_full.S sim

vivado-syn:
	vivado -mode batch -source vivado/run.tcl

bootloader: $(BOOTLOADER_BIN)

$(BOOTLOADER_BIN): tools/bootloader.c
	$(HOST_CC) -O2 -Wall -Wextra -o $@ $<
