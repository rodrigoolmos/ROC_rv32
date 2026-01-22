// RV32I self-checking test for ROC_RV32.
// PASS  -> writes 0xDEADBEEF to dmem[0]
// FAIL  -> writes 0xBAD00000 | test_id to dmem[0]
//          writes actual to dmem[1], expected to dmem[2]

.section .text
.globl main

.macro FAIL test_id, actual_reg, expected_reg
  li   t0, 0x10000000
  li   t1, (0xBAD00000 | (\test_id & 0xFFFF))
  sw   t1, 0(t0)
  sw   \actual_reg, 4(t0)
  sw   \expected_reg, 8(t0)
.Lfail_halt\@:
  j .Lfail_halt\@
.endm

.macro ASSERT_EQ_REG test_id, reg_a, reg_b
  bne  \reg_a, \reg_b, .Lassert_fail\@
  j .Lassert_done\@
.Lassert_fail\@:
  FAIL \test_id, \reg_a, \reg_b
.Lassert_done\@:
.endm

.macro ASSERT_EQ_IMM test_id, reg_a, imm
  li   t6, \imm
  ASSERT_EQ_REG \test_id, \reg_a, t6
.endm

main:
  // Base pointer for dmem
  li   s2, 0x10000000

  // --- T0001: x0 is hardwired to zero ---
  li   t0, 0x12345678
  addi x0, t0, 0
  ASSERT_EQ_IMM 1, x0, 0

  // --- T0002: ADD/SUB ---
  li   t1, 5
  li   t2, 10
  add  t3, t1, t2
  ASSERT_EQ_IMM 2, t3, 15
  sub  t4, t2, t1
  ASSERT_EQ_IMM 3, t4, 5

  // --- T0004: ADDI with negative immediate ---
  li   t5, 100
  addi t5, t5, -7
  ASSERT_EQ_IMM 4, t5, 93

  // --- T0005: AND/OR/XOR ---
  li   t1, 0x0F0F0F0F
  li   t2, 0x00FF00FF
  and  t3, t1, t2
  ASSERT_EQ_IMM 5, t3, 0x000F000F
  or   t3, t1, t2
  ASSERT_EQ_IMM 6, t3, 0x0FFF0FFF
  xor  t3, t1, t2
  ASSERT_EQ_IMM 7, t3, 0x0FF00FF0

  // --- T0008: Shifts (imm + reg) ---
  li   t1, 1
  slli t2, t1, 31
  ASSERT_EQ_IMM 8, t2, 0x80000000
  srli t3, t2, 31
  ASSERT_EQ_IMM 9, t3, 1
  srai t4, t2, 31
  ASSERT_EQ_IMM 10, t4, 0xFFFFFFFF

  li   t1, 0x80000000
  li   t2, 4
  srl  t3, t1, t2
  ASSERT_EQ_IMM 11, t3, 0x08000000
  sra  t4, t1, t2
  ASSERT_EQ_IMM 12, t4, 0xF8000000
  li   t1, 0x00000011
  sll  t3, t1, t2
  ASSERT_EQ_IMM 13, t3, 0x00000110

  // --- T0014: SLT/SLTU and immediates ---
  li   t1, -1
  li   t2, 1
  slt  t3, t1, t2
  ASSERT_EQ_IMM 14, t3, 1
  sltu t4, t1, t2
  ASSERT_EQ_IMM 15, t4, 0
  slti t5, t2, 2
  ASSERT_EQ_IMM 16, t5, 1
  sltiu t5, t1, 1
  ASSERT_EQ_IMM 17, t5, 0

  // --- T0018: Branches ---
  li   t1, 0
  li   t2, 0
  beq  t1, t2, 1f
  FAIL 18, t1, t2
1:
  li   t1, 1
  li   t2, 2
  bne  t1, t2, 2f
  FAIL 19, t1, t2
2:
  li   t1, -5
  li   t2, 3
  blt  t1, t2, 3f
  FAIL 20, t1, t2
3:
  bge  t2, t1, 4f
  FAIL 21, t2, t1
4:
  li   t1, 0xFFFFFFFF
  li   t2, 1
  bltu t2, t1, 5f
  FAIL 22, t2, t1
5:
  bgeu t1, t2, 6f
  FAIL 23, t1, t2
6:

  // --- T0024: AUIPC sanity (delta = 4) ---
  auipc t0, 0
  auipc t1, 0
  sub   t2, t1, t0
  ASSERT_EQ_IMM 24, t2, 4

  // --- T0025: JAL sets RA correctly; return via JALR ---
  auipc t0, 0
  jal  ra, jal_target
jal_return:
  addi t3, t0, 8
  ASSERT_EQ_REG 25, s1, t3

  // --- T0026: JALR indirect jump (no relocations) ---
  // Build a target address inside this same code block.
  auipc t4, 0
  addi  t4, t4, 12
  jalr  t5, t4, 0
jalr_target:
  // After JALR, t5 (link) must equal the target address (t4).
  ASSERT_EQ_REG 26, t5, t4

  // --- T0027: Loads/stores (aligned) + sign/zero extend ---
  // Use scratch at byte address 0x40 (word 16) and beyond.
  li   t0, 0x11223344
  sw   t0, 0x40(s2)

  // Byte loads from 0x40 (little-endian => 0x44)
  lb   t1, 0x40(s2)
  lbu  t2, 0x40(s2)
  ASSERT_EQ_IMM 27, t2, 0x44

  // Halfword loads
  lh   t3, 0x40(s2)
  ASSERT_EQ_IMM 28, t3, 0x00003344
  lhu  t4, 0x42(s2)
  ASSERT_EQ_IMM 29, t4, 0x00001122

  // Store byte/half and read back as word
  li   t0, 0
  sw   t0, 0x44(s2)      // clear word at 0x44
  li   t1, 0xAA
  sb   t1, 0x44(s2)
  li   t1, 0xBEEF
  sh   t1, 0x46(s2)
  lw   t2, 0x44(s2)
  // Expect 0xBEEF00AA (bytes: AA 00 EF BE)
  ASSERT_EQ_IMM 30, t2, 0xBEEF00AA

  // Signed byte load from 0x44 should be 0xFFFFFFAA
  lb   t3, 0x44(s2)
  ASSERT_EQ_IMM 31, t3, 0xFFFFFFAA

  // --- PASS ---
  addi t0, s2, 0
	li   t1, 0xDEADBEEF
  sw   t1, 0(t0)
pass_halt:
  j pass_halt

jal_target:
  // Save return address from JAL and return via JALR.
  addi s1, ra, 0
  jalr x0, ra, 0
