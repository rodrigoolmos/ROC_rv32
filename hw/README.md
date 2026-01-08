# Hardware (hw)

This folder contains the SoC + RV32I core RTL and the main testbench used for simulation.

## Layout

- `RTL/`: synthesizable code (SystemVerilog)
  - `RTL/core/`: RV32I core
  - `RTL/imem.sv`: instruction memory
  - `RTL/dmem.sv`: data memory
  - `RTL/mem.sv`: common memory block (used by imem/dmem)
  - `RTL/soc.sv`: integration (core + imem + dmem)
- `TB/`: testbench(s)
  - `TB/tb_ROC_RV32_program.sv`: testbench that loads `sw/imem.dat` and runs the program

## Top-level RTL: `soc`

The `soc` module (see `RTL/soc.sv`) instantiates:

- `ROC_RV32` (core)
- `imem` (instruction memory)
- `dmem` (data memory)

### “Port B” interfaces (Debug/DMA)

Both `imem` and `dmem` expose an additional **Port B** interface (`*_b_*` signals) intended for debug/DMA access.
In the default testbench these ports are disabled (`*_b_en=0`).

## Core: `ROC_RV32`

The core lives in `RTL/core/ROC_RV32.sv` and implements RV32I without a pipeline.
At a high level it includes:

- `decoder`: extracts instruction fields (`opcode`, `funct3`, `funct7`, `rs1/rs2/rd`, immediates)
- `control_unit`: generates control signals and formats loads/stores (sign/zero extension, `store_strb`, etc.)
- `alu`: arithmetic/logic operations (type `alu_op_t` in `alu_ops_pkg.sv`)
- `pc`: PC / branch / jump logic
- `register_bank`: register file (x0…x31)

### Multi-cycle execution

The core uses an internal FSM (`cpu_state`).
For example, instruction + PC are latched during `S_DECODE`, and the ALU result is latched during `S_EXEC` (register `alu_out`).

### Memory map (Harvard)

The design uses separate instruction and data memories.
Internally both memories are **word-addressed**:

- IMEM address: `imem_addr = pc_output[ADDR_WIDTH_I+1:2]`
- DMEM address: the core works with byte addresses at the ISA level, and translates them to a word index using a **base address**:
  - Default `DMEM_BASE`: `0x1000_0000`
  - `dmem_byte_addr = alu_out - DMEM_BASE`
  - `dmem_addr = dmem_byte_addr[ADDR_WIDTH_D+1:2]`

Practical implication: if your program does `lw/sw` to `0x1000_0000`, that targets `dmem[word 0]`.

## Memories: `imem` / `dmem`

- `imem` is treated as ROM from the core perspective (Port A with `we_a=0`).
- `dmem` supports byte writes via `store_strb` (byte enable/write strobe).

## Testbench: `tb_ROC_RV32_program`

The main testbench is `TB/tb_ROC_RV32_program.sv` and it:

1. Generates clock (`always #5 clk = ~clk;`) and reset.
2. Initializes/clears part of DMEM.
3. Loads the program into IMEM via `$readmemh` from `sw/imem.dat`.
   - It tries `sw/imem.dat` and then `../sw/imem.dat` (useful because the simulation often runs under `questasim/`).
4. Runs until it detects a stop condition based on a store to DMEM.

### Stop condition (PASS/FAIL) and plusargs

By default, the simulation stops when the program performs a full-word store of `0xDEADBEEF` to `dmem[word 0]`.

You can override this via Questa plusargs:

- `+STOP_ADDR=<decimal>`: DMEM word index to watch (default `0`)
- `+STOP_WDATA=<hex>`: exact PASS value (default `DEADBEEF`)
- `+MAX_CYCLES=<decimal>`: timeout (default `5_000_000`)

Additionally, the TB treats a store matching `0xBAD0xxxx` as FAIL (error code in the low 16 bits).

At the end, it prints a small snapshot and dumps part of DMEM.

## Simulation file list

Simulation is compiled from `tb_ROC_RV32.flist` (in the repo root). If you add/remove RTL or testbenches, you will typically need to update that `.flist`.
