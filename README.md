# ROC_rv32

Simple **RV32I** core (single-cycle / no pipeline) plus a minimal SoC + testbench and scripts to **compile a bare‑metal program**, load it into **instruction memory**, and **simulate** with QuestaSim/ModelSim. Includes a **UART bootloader** for IMEM load and DMEM read, plus a **Vivado** bitstream flow.

## Quick start

### 1) Prerequisites

- **QuestaSim/ModelSim** available in PATH (`vsim`, `vlog`).
- **RISC-V GCC toolchain** (one of these is common):
	- `riscv32-unknown-elf-` (default)
	- `riscv64-unknown-elf-`
- **Python 3**.

### 2) Build SW + run simulation (GUI)

```bash
make sim-gui SW_APP=main.c RISCV_PREFIX=riscv64-unknown-elf-
```

### 3) Build SW + run simulation (batch/CLI)

```bash
make sim-batch SW_APP=main.c RISCV_PREFIX=riscv64-unknown-elf-
```

Notes:
- `SW_APP` is **relative to** `sw/`.
- The build produces `sw/imem.dat` from the compiled binary, then the testbench loads it.

## Common targets

### Build only (no simulation)

```bash
make all SW_APP=main.c RISCV_PREFIX=riscv64-unknown-elf-
```

Artifacts:
- `build/main.elf`: linked ELF
- `build/main.bin`: raw binary
- `build/main.asm`: disassembly
- `sw/imem.dat`: program image used by the testbench
- `tools/bootloader`: host UART tool (built by `make all`)

### Run the included RV32I test

Build only:

```bash
make riscv-test RISCV_PREFIX=riscv64-unknown-elf-
```

Build + simulate:

```bash
make riscv-test-sim RISCV_PREFIX=riscv64-unknown-elf-
```

### Choose a different top testbench module

By default the simulator runs:
- `TOP_MODULE=tb_ROC_RV32_program`

Override it like this:

```bash
make sim-gui TOP_MODULE=tb_ROC_RV32_program SW_APP=main.c
```

## Bootloader (UART) usage

Build the host tool:

```bash
make bootloader
```

Load IMEM from `sw/imem.dat` (default) starting at word address 0:

```bash
tools/bootloader -addr 0 -load -port /dev/ttyUSB0
```

Read DMEM words (example: 16 words at address 0):

```bash
tools/bootloader -addr 0 -ndata 16 -read -port /dev/ttyUSB0
```

Notes:
- `-addr` is a **word** address (0..1023).
- `-file` overrides the IMEM file path.
- Baud rate is fixed at 115200.

## Vivado bitstream (Nexys A7)

Run the batch flow:

```bash
make vivado-syn
```

Output bitstream:
- `vivado/vivado_proj/roc_rv32.runs/impl_1/soc.bit`

## Repository layout

- `hw/RTL/`: synthesizable RTL
	- `hw/RTL/core/`: RV32 core (ALU, decoder, control, register bank, etc.)
	- `hw/RTL/imem.sv`, `hw/RTL/dmem.sv`: instruction/data memories
	- `hw/RTL/soc.sv`: top SoC wrapper
- `hw/TB/`: testbenches
- `sw/`: bare-metal software
	- `crt0.S`: startup code
	- `link.ld`: linker script
	- `main.c`: example program
	- `tests/`: additional C/ASM tests
- `tools/`:
	- `bin2imem.py`: converts `build/main.bin` → `sw/imem.dat`
	- `bootloader.c`: UART host tool (IMEM load, DMEM read)
	- `run_sim.tcl`, `run_sim_batch.tcl`: QuestaSim scripts (GUI / batch)
- `tb_ROC_RV32.flist`: filelist used by Questa compilation

## Troubleshooting

- **“`riscv*-unknown-elf-gcc not found`”**
	- Install a RISC-V toolchain or set `RISCV_PREFIX`, e.g.:
		- `make RISCV_PREFIX=riscv64-unknown-elf- sim-gui SW_APP=main.c`

- **“`vsim: command not found`”**
	- Ensure QuestaSim/ModelSim is installed and sourced so `vsim` and `vlog` are in PATH.

- **Simulation rebuilds from scratch**
	- This is expected: `run.sh` / `run_batch.sh` remove and recreate `questasim/` each run.
