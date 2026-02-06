#include <stdint.h>

#define OK_FLAG  0xDEADBEEFu
#define ERR_FLAG 0xBAD00000u

#define DMEM_BASE 0x10000000u
#define RESULT    ((volatile uint32_t *)DMEM_BASE)

#define MMIO_GPIO_BASE  0x00000000u
#define MMIO_CLINT_BASE 0x00003000u

#define GPIO_DATA_OFFSET       0x00u
#define GPIO_DIR_OFFSET        0x04u
#define GPIO_IRQ_ENA_OFFSET    0x08u
#define GPIO_IRQ_STATUS_OFFSET 0x0Cu

#define CLINT_MTIME_L     0x00u
#define CLINT_MTIME_H     0x04u
#define CLINT_MTIMECMP_L  0x08u
#define CLINT_MTIMECMP_H  0x0Cu

#define MSTATUS_MIE_MASK (1u << 3)
#define MIE_MEIE_MASK    (1u << 11)
#define MIE_MTIE_MASK    (1u << 7)

#define MCAUSE_MEI 0x8000000Bu
#define MCAUSE_MTI 0x80000007u

#define FAIL_EXT_WAKE        0x0001u
#define FAIL_EXT_PENDING     0x0002u
#define FAIL_TIMER_IRQ       0x0003u
#define FAIL_PRIORITY_EXT    0x0004u
#define FAIL_PRIORITY_TIMER  0x0005u
#define FAIL_GPIO_TIMEOUT    0x0006u
#define FAIL_TIMER_TIMEOUT   0x0007u
#define FAIL_PRIORITY_TIMEOUT 0x0008u

static inline uint32_t csr_read_mstatus(void)
{
    uint32_t value;
    __asm__ volatile ("csrr %0, mstatus" : "=r"(value));
    return value;
}

static inline void csr_write_mstatus(uint32_t value)
{
    __asm__ volatile ("csrw mstatus, %0" : : "r"(value));
}

static inline uint32_t csr_read_mie(void)
{
    uint32_t value;
    __asm__ volatile ("csrr %0, mie" : "=r"(value));
    return value;
}

static inline void csr_write_mie(uint32_t value)
{
    __asm__ volatile ("csrw mie, %0" : : "r"(value));
}

static inline void csr_write_mtvec(uint32_t value)
{
    __asm__ volatile ("csrw mtvec, %0" : : "r"(value));
}

static inline uint32_t csr_read_mcause(void)
{
    uint32_t value;
    __asm__ volatile ("csrr %0, mcause" : "=r"(value));
    return value;
}

static inline void wfi(void)
{
    __asm__ volatile ("wfi");
}

static inline void nop(void)
{
    __asm__ volatile ("addi x0, x0, 0");
}

static inline uint32_t mmio_read(uint32_t addr)
{
    return *(volatile uint32_t *)addr;
}

static inline void mmio_write(uint32_t addr, uint32_t value)
{
    *(volatile uint32_t *)addr = value;
}

static void gpio_set_direction(uint32_t direction)
{
    mmio_write(MMIO_GPIO_BASE + GPIO_DIR_OFFSET, direction);
}

static void gpio_enable_irq(uint32_t irq_mask)
{
    mmio_write(MMIO_GPIO_BASE + GPIO_IRQ_ENA_OFFSET, irq_mask);
}

static uint32_t gpio_irq_status(void)
{
    return mmio_read(MMIO_GPIO_BASE + GPIO_IRQ_STATUS_OFFSET);
}

static void gpio_clear_irq(uint32_t irq_mask)
{
    mmio_write(MMIO_GPIO_BASE + GPIO_IRQ_STATUS_OFFSET, irq_mask);
}

static uint64_t clint_read_mtime(void)
{
    uint32_t hi1;
    uint32_t lo;
    uint32_t hi2;

    do {
        hi1 = mmio_read(MMIO_CLINT_BASE + CLINT_MTIME_H);
        lo  = mmio_read(MMIO_CLINT_BASE + CLINT_MTIME_L);
        hi2 = mmio_read(MMIO_CLINT_BASE + CLINT_MTIME_H);
    } while (hi1 != hi2);

    return ((uint64_t)hi2 << 32) | lo;
}

static void clint_write_mtimecmp(uint64_t value)
{
    mmio_write(MMIO_CLINT_BASE + CLINT_MTIMECMP_H, 0xFFFFFFFFu);
    mmio_write(MMIO_CLINT_BASE + CLINT_MTIMECMP_L, (uint32_t)value);
    mmio_write(MMIO_CLINT_BASE + CLINT_MTIMECMP_H, (uint32_t)(value >> 32));
}

static void clint_disable_timer(void)
{
    clint_write_mtimecmp(~(uint64_t)0);
}

static void clint_arm_timer(uint32_t delta_cycles)
{
    uint64_t now = clint_read_mtime();
    clint_write_mtimecmp(now + (uint64_t)delta_cycles);
}

static void enable_global_irq(void)
{
    csr_write_mstatus(csr_read_mstatus() | MSTATUS_MIE_MASK);
}

static void disable_global_irq(void)
{
    csr_write_mstatus(csr_read_mstatus() & ~MSTATUS_MIE_MASK);
}

static void fail(uint32_t code)
{
    RESULT[0] = ERR_FLAG | code;
    for (;;) {
        wfi();
    }
}

static volatile uint32_t g_ext_irq_count;
static volatile uint32_t g_timer_irq_count;
static volatile uint32_t g_last_gpio_irq;
static volatile uint32_t g_last_mcause;
static volatile uint32_t g_first_mcause;
static volatile uint32_t g_capture_first;

void __attribute__((interrupt("machine"))) trap_handler(void)
{
    uint32_t mcause = csr_read_mcause();
    g_last_mcause = mcause;

    if (g_capture_first && g_first_mcause == 0u) {
        g_first_mcause = mcause;
    }

    if (mcause == MCAUSE_MEI) {
        g_ext_irq_count++;
        g_last_gpio_irq = gpio_irq_status();
        if (g_last_gpio_irq != 0u) {
            gpio_clear_irq(g_last_gpio_irq);
        }
    } else if (mcause == MCAUSE_MTI) {
        g_timer_irq_count++;
        clint_disable_timer();
    } else {
        RESULT[0] = ERR_FLAG | (mcause & 0xFFFFu);
    }
}

static void wait_gpio_pending(uint32_t timeout_loops)
{
    while (gpio_irq_status() == 0u) {
        if (timeout_loops-- == 0u) {
            fail(FAIL_GPIO_TIMEOUT);
        }
        nop();
    }
}

static void wait_timer_irq(uint32_t timeout_loops)
{
    while (g_timer_irq_count == 0u) {
        if (timeout_loops-- == 0u) {
            fail(FAIL_TIMER_TIMEOUT);
        }
        nop();
    }
}

static void wait_first_mcause(uint32_t timeout_loops)
{
    while (g_first_mcause == 0u) {
        if (timeout_loops-- == 0u) {
            fail(FAIL_PRIORITY_TIMEOUT);
        }
        nop();
    }
}

int main(void)
{
    const uint32_t timer_delta = 2000u;
    const uint32_t watchdog_ext = 300000u;
    const uint32_t watchdog_pending = 200000u;
    const uint32_t timeout_spin = 500000u;

    RESULT[0] = 0u;
    g_ext_irq_count = 0u;
    g_timer_irq_count = 0u;
    g_last_gpio_irq = 0u;
    g_last_mcause = 0u;
    g_first_mcause = 0u;
    g_capture_first = 0u;

    csr_write_mtvec((uint32_t)trap_handler);

    gpio_set_direction(0x0u);
    gpio_clear_irq(0xFFFFFFFFu);
    gpio_enable_irq(0u);

    csr_write_mie(0u);
    disable_global_irq();
    clint_disable_timer();

    /* Phase 1: WFI wakes on external IRQ (watchdog timer prevents hang). */
    g_ext_irq_count = 0u;
    g_timer_irq_count = 0u;
    gpio_clear_irq(0xFFFFFFFFu);
    gpio_enable_irq(1u << 0);

    csr_write_mie(MIE_MEIE_MASK | MIE_MTIE_MASK);
    enable_global_irq();

    clint_arm_timer(watchdog_ext);
    while (g_ext_irq_count == 0u && g_timer_irq_count == 0u) {
        wfi();
    }
    if (g_ext_irq_count == 0u) {
        fail(FAIL_EXT_WAKE);
    }
    clint_disable_timer();
    g_timer_irq_count = 0u;

    /* Phase 2: external IRQ pending before WFI (should wake immediately). */
    disable_global_irq();
    gpio_clear_irq(0xFFFFFFFFu);
    gpio_enable_irq(1u << 0);
    wait_gpio_pending(timeout_spin);
    g_ext_irq_count = 0u;

    enable_global_irq();
    clint_arm_timer(watchdog_pending);
    wfi();
    nop();
    if (g_ext_irq_count == 0u) {
        fail(FAIL_EXT_PENDING);
    }
    clint_disable_timer();
    g_timer_irq_count = 0u;

    /* Phase 3: timer IRQ works (no WFI, to avoid raw-IRQ wake issues). */
    gpio_enable_irq(0u);
    g_timer_irq_count = 0u;
    csr_write_mie(MIE_MTIE_MASK);
    enable_global_irq();
    clint_arm_timer(timer_delta);
    wait_timer_irq(timeout_spin);
    if (g_timer_irq_count == 0u) {
        fail(FAIL_TIMER_IRQ);
    }

    /* Phase 4: priority when both pending (external must win). */
    disable_global_irq();
    g_ext_irq_count = 0u;
    g_timer_irq_count = 0u;
    g_first_mcause = 0u;
    g_capture_first = 1u;
    gpio_clear_irq(0xFFFFFFFFu);
    gpio_enable_irq(1u << 0);
    csr_write_mie(MIE_MEIE_MASK | MIE_MTIE_MASK);
    clint_arm_timer(0u);
    wait_gpio_pending(timeout_spin);

    enable_global_irq();
    wait_first_mcause(timeout_spin);
    g_capture_first = 0u;

    if (g_first_mcause != MCAUSE_MEI) {
        fail(FAIL_PRIORITY_EXT);
    }

    gpio_enable_irq(0u);
    wait_timer_irq(timeout_spin);
    if (g_last_mcause != MCAUSE_MTI) {
        fail(FAIL_PRIORITY_TIMER);
    }

    clint_disable_timer();

    RESULT[0] = OK_FLAG;
    RESULT[1] = g_ext_irq_count;
    RESULT[2] = g_timer_irq_count;
    RESULT[3] = g_last_gpio_irq;
    RESULT[4] = g_last_mcause;

    for (;;) {
        wfi();
    }
}
