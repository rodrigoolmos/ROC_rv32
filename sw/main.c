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

#define TIMER_PERIOD     3000u
#define IRQ_TIMEOUT      2500000u

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

static void wait_cycles(uint32_t n) {
    while (n--) {
        __asm__ volatile ("nop");
    }
}

void __attribute__((interrupt("machine"))) trap_handler(void) {
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
    last_mepc = mepc;

    if (mcause != MCAUSE_MTI) {
        bad_mcause++;
    }
    if (mstatus & MSTATUS_MIE_MASK) {
        bad_mie_in_handler++;
    }
    if (mepc & 1u) {
        bad_mepc_align++;
    }
    if ((mepc & 0xFFFFF000u) != 0u) {
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

    next_lo = now_lo + TIMER_PERIOD;
    next_hi = now_hi + ((next_lo < now_lo) ? 1u : 0u);

    CLINT_MTIMECMP_H = 0xFFFFffffu;
    CLINT_MTIMECMP_L = next_lo;
    CLINT_MTIMECMP_H = next_hi;

    in_handler--;
}

int main(void) {
    uint32_t i;
    uint32_t phase_count;
    uint32_t timeout;
    uint32_t fail_code;
    volatile uint32_t *dmem = (volatile uint32_t *)DMEM_BASE;
    volatile uint32_t *regs = (volatile uint32_t *)MMIO_REGS;

#define CHECK(cond, code) do { if (!(cond)) { fail_code = (code); goto fail; } } while (0)

    irq_count = 0;
    bad_mcause = 0;
    nested_irq = 0;
    bad_mie_in_handler = 0;
    bad_mepc_align = 0;
    bad_mepc_range = 0;
    delta_samples = 0;
    delta_min = 0xFFFFffffu;
    delta_max = 0u;
    prev_mtime_lo = 0u;
    in_handler = 0u;
    last_mcause = 0u;
    last_mepc = 0u;
    fail_code = 0u;

    for (i = 1; i < 16u; i++) {
        dmem[i] = 0u;
    }

    __asm__ volatile ("csrw mtvec, %0" :: "r"((uint32_t)(uintptr_t)trap_handler));

    __asm__ volatile ("csrc mstatus, %0" :: "r"(MSTATUS_MIE_MASK));
    __asm__ volatile ("csrc mie, %0" :: "r"(MTIE_MASK));

    // Phase 1: both disabled -> no interrupts.
    CLINT_MTIMECMP_H = 0xFFFFffffu;
    CLINT_MTIMECMP_L = CLINT_MTIME_L + 64u;
    CLINT_MTIMECMP_H = CLINT_MTIME_H;
    wait_cycles(TIMER_PERIOD * 4u);
    CHECK(irq_count == 0u, 0x0101u);

    // Phase 2: MTIE on, global off -> no interrupts.
    __asm__ volatile ("csrs mie, %0" :: "r"(MTIE_MASK));
    CLINT_MTIMECMP_H = 0xFFFFffffu;
    CLINT_MTIMECMP_L = CLINT_MTIME_L + 64u;
    CLINT_MTIMECMP_H = CLINT_MTIME_H;
    wait_cycles(TIMER_PERIOD * 4u);
    CHECK(irq_count == 0u, 0x0102u);

    // Phase 3: enable global MIE -> interrupts must arrive.
    __asm__ volatile ("csrs mstatus, %0" :: "r"(MSTATUS_MIE_MASK));
    CLINT_MTIMECMP_H = 0xFFFFffffu;
    CLINT_MTIMECMP_L = CLINT_MTIME_L + 64u;
    CLINT_MTIMECMP_H = CLINT_MTIME_H;
    timeout = IRQ_TIMEOUT;
    while ((timeout-- != 0u) && (irq_count < 8u)) {
        __asm__ volatile ("nop");
    }
    CHECK(irq_count >= 8u, 0x0103u);

    // Small stress loop while IRQs are active.
    for (i = 0; i < 2000u; i++) {
        regs[i & 0xFu] = i ^ 0xA5A50000u;
        (void)regs[i & 0xFu];
    }

    // Phase 4: global MIE off -> counter must stop.
    phase_count = irq_count;
    __asm__ volatile ("csrc mstatus, %0" :: "r"(MSTATUS_MIE_MASK));
    wait_cycles(TIMER_PERIOD * 6u);
    CHECK(irq_count == phase_count, 0x0104u);

    // Phase 5: global MIE on -> counter must continue.
    __asm__ volatile ("csrs mstatus, %0" :: "r"(MSTATUS_MIE_MASK));
    CLINT_MTIMECMP_H = 0xFFFFffffu;
    CLINT_MTIMECMP_L = CLINT_MTIME_L + 64u;
    CLINT_MTIMECMP_H = CLINT_MTIME_H;
    timeout = IRQ_TIMEOUT;
    while ((timeout-- != 0u) && (irq_count < (phase_count + 6u))) {
        __asm__ volatile ("nop");
    }
    CHECK(irq_count >= (phase_count + 6u), 0x0105u);

    // Phase 6: MTIE off with global on -> counter must stop.
    phase_count = irq_count;
    __asm__ volatile ("csrc mie, %0" :: "r"(MTIE_MASK));
    wait_cycles(TIMER_PERIOD * 6u);
    CHECK(irq_count == phase_count, 0x0106u);

    // Phase 7: MTIE on again -> counter must continue.
    __asm__ volatile ("csrs mie, %0" :: "r"(MTIE_MASK));
    CLINT_MTIMECMP_H = 0xFFFFffffu;
    CLINT_MTIMECMP_L = CLINT_MTIME_L + 64u;
    CLINT_MTIMECMP_H = CLINT_MTIME_H;
    timeout = IRQ_TIMEOUT;
    while ((timeout-- != 0u) && (irq_count < (phase_count + 4u))) {
        __asm__ volatile ("nop");
    }
    CHECK(irq_count >= (phase_count + 4u), 0x0107u);

    CHECK(bad_mcause == 0u, 0x0201u);
    CHECK(nested_irq == 0u, 0x0202u);
    CHECK(bad_mie_in_handler == 0u, 0x0203u);
    CHECK(bad_mepc_align == 0u, 0x0204u);
    CHECK(bad_mepc_range == 0u, 0x0205u);
    CHECK(delta_samples >= 4u, 0x0206u);

fail:
    dmem[1]  = irq_count;
    dmem[2]  = (bad_mcause & 0xFFFFu) | ((nested_irq & 0xFFFFu) << 16);
    dmem[3]  = (bad_mie_in_handler & 0xFFFFu) | ((bad_mepc_align & 0xFFFFu) << 16);
    dmem[4]  = (bad_mepc_range & 0xFFFFu) | ((delta_samples & 0xFFFFu) << 16);
    dmem[5]  = last_mcause;
    dmem[6]  = last_mepc;
    dmem[7]  = delta_min;
    dmem[8]  = delta_max;

    if (fail_code != 0u) {
        dmem[0] = ERR_FLAG | (fail_code & 0xFFFFu);
    } else {
        dmem[0] = OK_FLAG;
    }

    for (;;) {
        __asm__ volatile ("wfi");
    }
}
