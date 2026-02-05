#include <stdint.h>
#include "stdio.h"

#define OK_FLAG  0xDEADBEEFu
#define ERR_FLAG 0xBAD00000u

#define DMEM_BASE 0x10000000u
#define RESULT    ((volatile uint32_t *)DMEM_BASE)

#define MMIO_GPIO_BASE  0x00000000u
#define MMIO_7SEG_BASE  0x00001000u
#define MMIO_UART_BASE  0x00002000u
#define MMIO_CLINT_BASE 0x00003000u

#define GPIO_DATA_OFFSET       0x00u
#define GPIO_DIR_OFFSET        0x04u
#define GPIO_IRQ_ENA_OFFSET    0x08u
#define GPIO_IRQ_STATUS_OFFSET 0x0Cu

#define SEG_DATA_OFFSET 0x00u
#define SEG_DP_OFFSET   0x04u

#define MSTATUS_MIE_MASK (1u << 3)
#define MIE_MEIE_MASK    (1u << 11)
#define MIE_MTIE_MASK    (1u << 7)
#define MCAUSE_MEI       0x8000000Bu
#define MCAUSE_MTI       0x80000007u

#define CSR_EXT_IRQ 0xF00

#define OUTPUT 1u
#define INPUT  0u

#define CLINT_MTIME_L     0x00u
#define CLINT_MTIME_H     0x04u
#define CLINT_MTIMECMP_L  0x08u
#define CLINT_MTIMECMP_H  0x0Cu

#define CPU_FREQ_HZ    100000000u
#define TIMER_TICKS    (CPU_FREQ_HZ)         // 1 second tick
#define DEBOUNCE_TICKS (CPU_FREQ_HZ / 10u)   // 100 ms debounce window

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

static inline uint32_t csr_read_ext_irq(void)
{
    uint32_t value;
    __asm__ volatile ("csrr %0, %1" : "=r"(value) : "i"(CSR_EXT_IRQ));
    return value;
}

static inline uint32_t mmio_read(uint32_t addr)
{
    return *(volatile uint32_t *)addr;
}

static inline void mmio_write(uint32_t addr, uint32_t value)
{
    *(volatile uint32_t *)addr = value;
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
    // Avoid spurious interrupts during update.
    mmio_write(MMIO_CLINT_BASE + CLINT_MTIMECMP_H, 0xFFFFFFFFu);
    mmio_write(MMIO_CLINT_BASE + CLINT_MTIMECMP_L, (uint32_t)value);
    mmio_write(MMIO_CLINT_BASE + CLINT_MTIMECMP_H, (uint32_t)(value >> 32));
}

static void enable_external_irq(void)
{
    uint32_t mie = csr_read_mie();
    mie |= MIE_MEIE_MASK;
    csr_write_mie(mie);

    uint32_t mstatus = csr_read_mstatus();
    mstatus |= MSTATUS_MIE_MASK;
    csr_write_mstatus(mstatus);
}

static void enable_timer_irq(void)
{
    uint32_t mie = csr_read_mie();
    mie |= MIE_MTIE_MASK;
    csr_write_mie(mie);

    uint32_t mstatus = csr_read_mstatus();
    mstatus |= MSTATUS_MIE_MASK;
    csr_write_mstatus(mstatus);
}

static void set_handler(uint32_t handler_addr)
{
    csr_write_mtvec(handler_addr);
}

static void gpio_set_direction(uint32_t direction)
{
    mmio_write(MMIO_GPIO_BASE + GPIO_DIR_OFFSET, direction);
}

static uint32_t gpio_read_status(){
    return mmio_read(MMIO_GPIO_BASE + GPIO_DATA_OFFSET);
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

static void seg7_write(uint32_t value, uint32_t dp_mask)
{
    mmio_write(MMIO_7SEG_BASE + SEG_DATA_OFFSET, value);
    mmio_write(MMIO_7SEG_BASE + SEG_DP_OFFSET, dp_mask);
}

static inline uint32_t irq_save_disable(void)
{
    uint32_t mstatus = csr_read_mstatus();
    csr_write_mstatus(mstatus & ~MSTATUS_MIE_MASK);
    return mstatus;
}

static inline void irq_restore(uint32_t mstatus)
{
    csr_write_mstatus(mstatus);
}

static volatile uint32_t g_irq_count_button;
static volatile uint32_t g_irq_count_timer;
static volatile uint32_t g_last_ext_irq;
static volatile uint32_t g_last_gpio_irq;
static volatile uint32_t g_button_pending;
static volatile uint32_t g_timer_pending;
static volatile uint32_t g_debounce_active;
static volatile uint64_t g_debounce_deadline;
static volatile uint64_t g_next_tick_deadline;

static void schedule_next_timer_from_isr(void)
{
    uint64_t next = g_next_tick_deadline;
    if (g_debounce_active && g_debounce_deadline < next) {
        next = g_debounce_deadline;
    }
    clint_write_mtimecmp(next);
}

/* ------------------------
 * Trap handler
 * ------------------------ */
void __attribute__((interrupt("machine"))) trap_handler(void)
{
    uint32_t mcause = csr_read_mcause();

    if (mcause == MCAUSE_MEI) {
        if (!g_debounce_active) {
            g_last_ext_irq = csr_read_ext_irq();
            g_last_gpio_irq = gpio_irq_status();
            if (g_last_gpio_irq != 0u) {
                gpio_clear_irq(g_last_gpio_irq);
            }
            gpio_enable_irq(0u);
            g_debounce_deadline = clint_read_mtime() + (uint64_t)DEBOUNCE_TICKS;
            g_debounce_active = 1u;
            schedule_next_timer_from_isr();
        } else {
            g_last_gpio_irq = gpio_irq_status();
            if (g_last_gpio_irq != 0u) {
                gpio_clear_irq(g_last_gpio_irq);
            }
        }

    } else if (mcause == MCAUSE_MTI) {
        uint64_t now = clint_read_mtime();

        if ((int64_t)(now - g_next_tick_deadline) >= 0) {
            do {
                g_next_tick_deadline += (uint64_t)TIMER_TICKS;
                g_timer_pending++;
            } while ((int64_t)(now - g_next_tick_deadline) >= 0);
        }

        if (g_debounce_active && (int64_t)(now - g_debounce_deadline) >= 0) {
            g_debounce_active = 0u;
            if (gpio_read_status() & 1u) {
                g_button_pending++;
            }
            gpio_clear_irq(0xFFFFFFFFu);
            gpio_enable_irq(1u << 0);
        }

        schedule_next_timer_from_isr();
    } else {
        RESULT[0] = ERR_FLAG | (mcause & 0xFFFFu);
    }
}

/* ------------------------
 * Main
 * ------------------------ */
int main(void)
{
    // Clear result word.
    RESULT[0] = 0u;

    // Set trap handler.
    set_handler((uint32_t)trap_handler);

    // Configure GPIO0 as input and enable its interrupt.
    gpio_set_direction(0x0u);
    gpio_clear_irq(0xFFFFFFFFu);
    gpio_enable_irq(1u << 0);
    seg7_write(0u, 0u);

    // Program and enable timer interrupts.
    g_next_tick_deadline = clint_read_mtime() + (uint64_t)TIMER_TICKS;
    g_debounce_active = 0u;
    clint_write_mtimecmp(g_next_tick_deadline);
    enable_timer_irq();

    // Enable CPU external interrupts.
    enable_external_irq();

    // Wait until 1000 button interrupts arrive.
    while (g_irq_count_button < 1000u) {
        uint32_t pending_button;
        uint32_t pending_timer;
        uint32_t mstatus = irq_save_disable();
        pending_button = g_button_pending;
        g_button_pending = 0u;
        pending_timer = g_timer_pending;
        g_timer_pending = 0u;
        irq_restore(mstatus);

        while (pending_button--) {
            g_irq_count_button++;
            printf_int((volatile uint32_t *)MMIO_UART_BASE, "BTN %d\n", (int)g_irq_count_button);
        }
        while (pending_timer--) {
            g_irq_count_timer++;
            printf_int((volatile uint32_t *)MMIO_UART_BASE, "TMR %d\n", (int)g_irq_count_timer);
        }

        if ((pending_button | pending_timer) != 0u) {
            seg7_write((g_irq_count_timer << 16) | (g_irq_count_button & 0xFFFFu), 0u);
        }

        if (g_button_pending == 0u && g_timer_pending == 0u) {
            __asm__ volatile ("wfi");
        }
    }

    // Stop external interrupts once the target count is reached.
    gpio_enable_irq(0u);
    csr_write_mie(csr_read_mie() & ~(MIE_MEIE_MASK | MIE_MTIE_MASK));
    clint_write_mtimecmp(~(uint64_t)0);

    // Record a simple success signature and latch the last IRQ sources.
    RESULT[0] = OK_FLAG;
    RESULT[1] = g_last_ext_irq;
    RESULT[2] = g_last_gpio_irq;

    for (;;) {
        __asm__ volatile ("wfi");
    }
}
