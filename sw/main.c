#include <stdint.h>

#define OK_FLAG  0xDEADBEEFu
#define ERR_FLAG 0xBAD00000u

#define DMEM_BASE  0x10000000u
#define MMIO_REGS  0x00001000u
#define MMIO_CLINT 0x00003000u

#define CLINT_MTIME_L    (*(volatile uint32_t *)(MMIO_CLINT + 0x00u))
#define CLINT_MTIME_H    (*(volatile uint32_t *)(MMIO_CLINT + 0x04u))
#define CLINT_MTIMECMP_L (*(volatile uint32_t *)(MMIO_CLINT + 0x08u))
#define CLINT_MTIMECMP_H (*(volatile uint32_t *)(MMIO_CLINT + 0x0Cu))

#define MCAUSE_MTI       0x80000007u
#define MTIE_MASK        (1u << 7)
#define MSTATUS_MIE_MASK (1u << 3)
#define IMEM_SIZE_BYTES  0x00002000u

#define TIMER_PERIOD     3000u
#define IRQ_TIMEOUT      2500000u

#define CSR_CUSTOM0      0xF00

static volatile uint32_t irq_count;
static volatile uint32_t bad_mcause;
static volatile uint32_t nested_irq;
static volatile uint32_t bad_mie_in_handler;
static volatile uint32_t bad_mepc_align;
static volatile uint32_t bad_mepc_range;
static volatile uint32_t delta_samples;
static volatile uint32_t delta_min;
static volatile uint32_t delta_max;
static volatile uint32_t prev_mtime_lo;
static volatile uint32_t in_handler;
static volatile uint32_t last_mcause;
static volatile uint32_t last_mepc;

/* ------------------------
 * CSR custom0 basic read/write
 * ------------------------ */
static inline void csr_custom0_write(uint32_t v)
{
    asm volatile ("csrw 0xF00, %0" :: "r"(v));
}

static inline uint32_t csr_custom0_read(void)
{
    uint32_t v;
    asm volatile ("csrr %0, 0xF00" : "=r"(v));
    return v;
}

/* ------------------------
 * CSR instruction helpers for CSR_CUSTOM0
 * ------------------------ */
static inline uint32_t csrrw_custom0(uint32_t v)
{
    uint32_t old;
    asm volatile ("csrrw %0, %1, %2"
                  : "=r"(old)
                  : "i"(CSR_CUSTOM0), "r"(v));
    return old;
}

static inline uint32_t csrrs_custom0(uint32_t mask)
{
    uint32_t old;
    asm volatile ("csrrs %0, %1, %2"
                  : "=r"(old)
                  : "i"(CSR_CUSTOM0), "r"(mask));
    return old;
}

static inline uint32_t csrrc_custom0(uint32_t mask)
{
    uint32_t old;
    asm volatile ("csrrc %0, %1, %2"
                  : "=r"(old)
                  : "i"(CSR_CUSTOM0), "r"(mask));
    return old;
}

/* For *I forms, zimm is encoded in instruction => must be constant.
 * Use a switch to generate all 32 cases.
 */
static inline uint32_t csrrwi_custom0_zimm(uint32_t zimm5)
{
    uint32_t old = 0;
    switch (zimm5 & 31u) {
#define Z(n) case (n): asm volatile ("csrrwi %0, %1, " #n : "=r"(old) : "i"(CSR_CUSTOM0)); break
        Z(0);  Z(1);  Z(2);  Z(3);  Z(4);  Z(5);  Z(6);  Z(7);
        Z(8);  Z(9);  Z(10); Z(11); Z(12); Z(13); Z(14); Z(15);
        Z(16); Z(17); Z(18); Z(19); Z(20); Z(21); Z(22); Z(23);
        Z(24); Z(25); Z(26); Z(27); Z(28); Z(29); Z(30); Z(31);
#undef Z
        default: break;
    }
    return old;
}

static inline uint32_t csrrsi_custom0_zimm(uint32_t zimm5)
{
    uint32_t old = 0;
    switch (zimm5 & 31u) {
#define Z(n) case (n): asm volatile ("csrrsi %0, %1, " #n : "=r"(old) : "i"(CSR_CUSTOM0)); break
        Z(0);  Z(1);  Z(2);  Z(3);  Z(4);  Z(5);  Z(6);  Z(7);
        Z(8);  Z(9);  Z(10); Z(11); Z(12); Z(13); Z(14); Z(15);
        Z(16); Z(17); Z(18); Z(19); Z(20); Z(21); Z(22); Z(23);
        Z(24); Z(25); Z(26); Z(27); Z(28); Z(29); Z(30); Z(31);
#undef Z
        default: break;
    }
    return old;
}

static inline uint32_t csrrci_custom0_zimm(uint32_t zimm5)
{
    uint32_t old = 0;
    switch (zimm5 & 31u) {
#define Z(n) case (n): asm volatile ("csrrci %0, %1, " #n : "=r"(old) : "i"(CSR_CUSTOM0)); break
        Z(0);  Z(1);  Z(2);  Z(3);  Z(4);  Z(5);  Z(6);  Z(7);
        Z(8);  Z(9);  Z(10); Z(11); Z(12); Z(13); Z(14); Z(15);
        Z(16); Z(17); Z(18); Z(19); Z(20); Z(21); Z(22); Z(23);
        Z(24); Z(25); Z(26); Z(27); Z(28); Z(29); Z(30); Z(31);
#undef Z
        default: break;
    }
    return old;
}

/* ------------------------
 * Misc helpers
 * ------------------------ */
static void wait_cycles(uint32_t n)
{
    while (n--) {
        __asm__ volatile ("nop");
    }
}

/* ------------------------
 * Test all CSR ops on CSR_CUSTOM0.
 * Returns 0 on success, else an error code (0x03xx).
 * ------------------------ */
static uint32_t test_custom0_all_ops(void)
{
    uint32_t old;

    /* CSRRW: write and return old value */
    csr_custom0_write(0x11111111u);
    old = csrrw_custom0(0x22222222u);
    if (old != 0x11111111u) return 0x0301u;
    if (csr_custom0_read() != 0x22222222u) return 0x0302u;

    /* CSRRS: set bits */
    csr_custom0_write(0x0000000Fu);
    old = csrrs_custom0(0x000000F0u);
    if (old != 0x0000000Fu) return 0x0303u;
    if (csr_custom0_read() != 0x000000FFu) return 0x0304u;

    /* CSRRC: clear bits */
    csr_custom0_write(0x000000FFu);
    old = csrrc_custom0(0x0000000Fu);
    if (old != 0x000000FFu) return 0x0305u;
    if (csr_custom0_read() != 0x000000F0u) return 0x0306u;

    /* CSRRS with rs1=0 => read-only */
    csr_custom0_write(0xA5A5A5A5u);
    old = csrrs_custom0(0x00000000u);
    if (old != 0xA5A5A5A5u) return 0x0307u;
    if (csr_custom0_read() != 0xA5A5A5A5u) return 0x0308u;

    /* CSRRC with rs1=0 => read-only */
    csr_custom0_write(0x5A5A5A5Au);
    old = csrrc_custom0(0x00000000u);
    if (old != 0x5A5A5A5Au) return 0x0309u;
    if (csr_custom0_read() != 0x5A5A5A5Au) return 0x030Au;

    /* CSRRWI: write zimm (5 bits) */
    csr_custom0_write(0u);
    old = csrrwi_custom0_zimm(27u);
    if (old != 0u) return 0x030Bu;
    if (csr_custom0_read() != 27u) return 0x030Cu;

    /* CSRRSI: OR with zimm */
    csr_custom0_write(1u);
    old = csrrsi_custom0_zimm(30u);
    if (old != 1u) return 0x030Du;
    if (csr_custom0_read() != (1u | 30u)) return 0x030Eu;

    /* CSRRCI: AND with ~zimm */
    csr_custom0_write(31u);
    old = csrrci_custom0_zimm(3u);
    if (old != 31u) return 0x030Fu;
    if (csr_custom0_read() != (31u & ~3u)) return 0x0310u;

    /* CSRRSI zimm=0 => read-only */
    csr_custom0_write(0x12345678u);
    old = csrrsi_custom0_zimm(0u);
    if (old != 0x12345678u) return 0x0311u;
    if (csr_custom0_read() != 0x12345678u) return 0x0312u;

    /* CSRRCI zimm=0 => read-only */
    csr_custom0_write(0x87654321u);
    old = csrrci_custom0_zimm(0u);
    if (old != 0x87654321u) return 0x0313u;
    if (csr_custom0_read() != 0x87654321u) return 0x0314u;

    return 0u;
}

/* ------------------------
 * Trap handler (Machine timer)
 * ------------------------ */
void __attribute__((interrupt("machine"))) trap_handler(void)
{
    uint32_t mcause;
    uint32_t mstatus;
    uint32_t mepc;
    uint32_t now_lo;
    uint32_t now_hi;
    uint32_t next_lo;
    uint32_t next_hi;

    in_handler++;
    if (in_handler > 1u) {
        nested_irq++;
    }

    __asm__ volatile ("csrr %0, mcause" : "=r"(mcause));
    __asm__ volatile ("csrr %0, mstatus" : "=r"(mstatus));
    __asm__ volatile ("csrr %0, mepc" : "=r"(mepc));

    now_lo = CLINT_MTIME_L;
    now_hi = CLINT_MTIME_H;

    last_mcause = mcause;
    last_mepc   = mepc;

    if (mcause != MCAUSE_MTI) {
        bad_mcause++;
    }
    if (mstatus & MSTATUS_MIE_MASK) {
        bad_mie_in_handler++;
    }
    if (mepc & 1u) {
        bad_mepc_align++;
    }
    /* mepc must point inside IMEM (now 8KB). */
    if (mepc >= IMEM_SIZE_BYTES) {
        bad_mepc_range++;
    }

    if (irq_count != 0u) {
        uint32_t d = now_lo - prev_mtime_lo;
        if (d < delta_min) {
            delta_min = d;
        }
        if (d > delta_max) {
            delta_max = d;
        }
        delta_samples++;
    }
    prev_mtime_lo = now_lo;
    irq_count++;

    /* Re-arm timer (atomic-ish sequence for 64-bit compare) */
    next_lo = now_lo + TIMER_PERIOD;
    next_hi = now_hi + ((next_lo < now_lo) ? 1u : 0u);

    CLINT_MTIMECMP_H = 0xFFFFFFFFu;
    CLINT_MTIMECMP_L = next_lo;
    CLINT_MTIMECMP_H = next_hi;

    in_handler--;
}

/* ------------------------
 * Main
 * ------------------------ */
int main(void)
{
    uint32_t i;
    uint32_t phase_count;
    uint32_t timeout;
    uint32_t fail_code;
    uint32_t csr_fail;

    volatile uint32_t *dmem = (volatile uint32_t *)DMEM_BASE;
    volatile uint32_t *regs = (volatile uint32_t *)MMIO_REGS;

#define CHECK(cond, code) do { if (!(cond)) { fail_code = (code); goto fail; } } while (0)

    /* Basic CSR custom0 read/write */
    csr_custom0_write(0x12345678u);
    CHECK(csr_custom0_read() == 0x12345678u, 0x0100u);

    /* Full CSR instruction test suite on custom0 */
    csr_fail = test_custom0_all_ops();
    CHECK(csr_fail == 0u, csr_fail);

    /* Reset test variables */
    irq_count = 0;
    bad_mcause = 0;
    nested_irq = 0;
    bad_mie_in_handler = 0;
    bad_mepc_align = 0;
    bad_mepc_range = 0;
    delta_samples = 0;
    delta_min = 0xFFFFFFFFu;
    delta_max = 0u;
    prev_mtime_lo = 0u;
    in_handler = 0u;
    last_mcause = 0u;
    last_mepc = 0u;
    fail_code = 0u;

    for (i = 1; i < 16u; i++) {
        dmem[i] = 0u;
    }

    /* Set trap vector */
    __asm__ volatile ("csrw mtvec, %0" :: "r"((uint32_t)(uintptr_t)trap_handler));

    /* Disable global interrupts and MTIE initially */
    __asm__ volatile ("csrc mstatus, %0" :: "r"(MSTATUS_MIE_MASK));
    __asm__ volatile ("csrc mie, %0" :: "r"(MTIE_MASK));

    /* Phase 1: both disabled -> no interrupts */
    CLINT_MTIMECMP_H = 0xFFFFFFFFu;
    CLINT_MTIMECMP_L = CLINT_MTIME_L + 64u;
    CLINT_MTIMECMP_H = CLINT_MTIME_H;
    wait_cycles(TIMER_PERIOD * 4u);
    CHECK(irq_count == 0u, 0x0101u);

    /* Phase 2: MTIE on, global off -> no interrupts */
    __asm__ volatile ("csrs mie, %0" :: "r"(MTIE_MASK));
    CLINT_MTIMECMP_H = 0xFFFFFFFFu;
    CLINT_MTIMECMP_L = CLINT_MTIME_L + 64u;
    CLINT_MTIMECMP_H = CLINT_MTIME_H;
    wait_cycles(TIMER_PERIOD * 4u);
    CHECK(irq_count == 0u, 0x0102u);

    /* Phase 3: enable global MIE -> interrupts must arrive */
    __asm__ volatile ("csrs mstatus, %0" :: "r"(MSTATUS_MIE_MASK));
    CLINT_MTIMECMP_H = 0xFFFFFFFFu;
    CLINT_MTIMECMP_L = CLINT_MTIME_L + 64u;
    CLINT_MTIMECMP_H = CLINT_MTIME_H;

    timeout = IRQ_TIMEOUT;
    while ((timeout-- != 0u) && (irq_count < 8u)) {
        __asm__ volatile ("nop");
    }
    CHECK(irq_count >= 8u, 0x0103u);

    /* Small stress loop while IRQs are active */
    for (i = 0; i < 2000u; i++) {
        regs[i & 0xFu] = i ^ 0xA5A50000u;
        (void)regs[i & 0xFu];
    }

    /* Phase 4: global MIE off -> counter must stop */
    phase_count = irq_count;
    __asm__ volatile ("csrc mstatus, %0" :: "r"(MSTATUS_MIE_MASK));
    wait_cycles(TIMER_PERIOD * 6u);
    CHECK(irq_count == phase_count, 0x0104u);

    /* Phase 5: global MIE on -> counter must continue */
    __asm__ volatile ("csrs mstatus, %0" :: "r"(MSTATUS_MIE_MASK));
    CLINT_MTIMECMP_H = 0xFFFFFFFFu;
    CLINT_MTIMECMP_L = CLINT_MTIME_L + 64u;
    CLINT_MTIMECMP_H = CLINT_MTIME_H;

    timeout = IRQ_TIMEOUT;
    while ((timeout-- != 0u) && (irq_count < (phase_count + 6u))) {
        __asm__ volatile ("nop");
    }
    CHECK(irq_count >= (phase_count + 6u), 0x0105u);

    /* Phase 6: MTIE off with global on -> counter must stop */
    phase_count = irq_count;
    __asm__ volatile ("csrc mie, %0" :: "r"(MTIE_MASK));
    wait_cycles(TIMER_PERIOD * 6u);
    CHECK(irq_count == phase_count, 0x0106u);

    /* Phase 7: MTIE on again -> counter must continue */
    __asm__ volatile ("csrs mie, %0" :: "r"(MTIE_MASK));
    CLINT_MTIMECMP_H = 0xFFFFFFFFu;
    CLINT_MTIMECMP_L = CLINT_MTIME_L + 64u;
    CLINT_MTIMECMP_H = CLINT_MTIME_H;

    timeout = IRQ_TIMEOUT;
    while ((timeout-- != 0u) && (irq_count < (phase_count + 4u))) {
        __asm__ volatile ("nop");
    }
    CHECK(irq_count >= (phase_count + 4u), 0x0107u);

    /* Post-checks */
    CHECK(bad_mcause == 0u, 0x0201u);
    CHECK(nested_irq == 0u, 0x0202u);
    CHECK(bad_mie_in_handler == 0u, 0x0203u);
    CHECK(bad_mepc_align == 0u, 0x0204u);
    CHECK(bad_mepc_range == 0u, 0x0205u);
    CHECK(delta_samples >= 4u, 0x0206u);

fail:
    dmem[1] = irq_count;
    dmem[2] = (bad_mcause & 0xFFFFu) | ((nested_irq & 0xFFFFu) << 16);
    dmem[3] = (bad_mie_in_handler & 0xFFFFu) | ((bad_mepc_align & 0xFFFFu) << 16);
    dmem[4] = (bad_mepc_range & 0xFFFFu) | ((delta_samples & 0xFFFFu) << 16);
    dmem[5] = last_mcause;
    dmem[6] = last_mepc;
    dmem[7] = delta_min;
    dmem[8] = delta_max;

    if (fail_code != 0u) {
        dmem[0] = ERR_FLAG | (fail_code & 0xFFFFu);
    } else {
        dmem[0] = OK_FLAG;
    }

    for (;;) {
        __asm__ volatile ("wfi");
    }
}
