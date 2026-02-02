OUTPUT_ARCH(riscv)
ENTRY(_start)

MEMORY
{
  /* 4KB instruction memory (word-addressed imem behind the scenes) */
  IMEM (rx)  : ORIGIN = 0x00000000, LENGTH = 0x00001000
  /* IMEM read-only window for data loads (LSU alias) */
  IMEM_WIN (r) : ORIGIN = 0x20000000, LENGTH = 0x00001000
  /* 4KB data memory (word-addressed dmem behind the scenes) */
  DMEM (rwx) : ORIGIN = 0x10000000, LENGTH = 0x00001000
}

SECTIONS
{
  /* Code/const in IMEM */
  . = ORIGIN(IMEM);

  .text : ALIGN(4)
  {
    *(.text.start)
    *(.text*)
  } > IMEM

  /* Track end of IMEM load image after .text */
  _imem_lma_end = .;

  /* Initialized data/rodata live in DMEM, with their init image stored in IMEM */
  . = ORIGIN(DMEM);

  /* Reserve a small fixed area at the start of DMEM (dmem[0..3]).
     TB stop signatures live at DMEM_BASE+0.
     Keep this OUT of .bss so crt0 doesn't clobber it unintentionally. */
  .result (NOLOAD) : ALIGN(4)
  {
    _result_base = .;
    . = . + 0x10;
    _result_end = .;
  } > DMEM

  .data : ALIGN(4)
  {
    _sdata = .;
    *(.data*)
    _edata = .;
  } > DMEM AT > IMEM
  _sidata = LOADADDR(.data);

  /* Read-only data in IMEM, accessed via LSU window at IMEM_WIN.
     VMA = IMEM_WIN + (LMA - IMEM_BASE) so LSU window maps 1:1 to IMEM contents. */
  .rodata ORIGIN(IMEM_WIN) + (_imem_lma_end - ORIGIN(IMEM)) : ALIGN(4)
  {
    *(.rodata*)
  } > IMEM_WIN AT > IMEM

  /* Zero-initialized data in DMEM */
  .bss : ALIGN(4)
  {
    _sbss = .;
    *(.bss*)
    *(COMMON)
    _ebss = .;
  } > DMEM

  /* End of data image and stack top */
  _end = .;
  _stack_top = ORIGIN(DMEM) + LENGTH(DMEM);
}
