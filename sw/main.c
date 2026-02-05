#include <stdint.h>
#include "stdio.h"

#define OK_FLAG  0xDEADBEEFu
#define ERR_FLAG 0xBAD00000u

#define DMEM_BASE 0x10000000u
#define RESULT    ((volatile uint32_t *)DMEM_BASE)

#define MMIO_GPIO_BASE  0x00000000u
#define MMIO_UART_BASE  0x00002000u
#define MMIO_CLINT_BASE 0x00003000u

#define GPIO_DATA_OFFSET       0x00u
#define GPIO_DIR_OFFSET        0x04u
#define GPIO_IRQ_ENA_OFFSET    0x08u
#define GPIO_IRQ_STATUS_OFFSET 0x0Cu

#define MSTATUS_MIE_MASK (1u << 3)
#define MIE_MEIE_MASK    (1u << 11)
#define MCAUSE_MEI       0x8000000Bu

#define CSR_EXT_IRQ 0xF00

#define OUTPUT 1u
#define INPUT  0u

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

static void enable_external_irq(void)
{
    uint32_t mie = csr_read_mie();
    mie |= MIE_MEIE_MASK;
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

static volatile uint32_t g_irq_count;
static volatile uint32_t g_last_ext_irq;
static volatile uint32_t g_last_gpio_irq;

/* ------------------------
 * Trap handler
 * ------------------------ */
void __attribute__((interrupt("machine"))) trap_handler(void)
{
    uint32_t mcause = csr_read_mcause();

    if (mcause == MCAUSE_MEI) {
        g_last_ext_irq = csr_read_ext_irq();
        g_last_gpio_irq = gpio_irq_status();
        if (g_last_gpio_irq != 0u) {
            gpio_clear_irq(g_last_gpio_irq);
        }
        g_irq_count++;
        printf_int((volatile uint32_t *)MMIO_UART_BASE, "IRQ %d\n", (int)g_irq_count);

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

    // Enable CPU external interrupts.
    enable_external_irq();

    // Wait until 10 external interrupts arrive.
    while (g_irq_count < 10u) {
        __asm__ volatile ("wfi");
    }

    // Stop external interrupts once the target count is reached.
    gpio_enable_irq(0u);
    csr_write_mie(csr_read_mie() & ~MIE_MEIE_MASK);

    // Record a simple success signature and latch the last IRQ sources.
    RESULT[0] = OK_FLAG;
    RESULT[1] = g_last_ext_irq;
    RESULT[2] = g_last_gpio_irq;

    for (;;) {
        __asm__ volatile ("wfi");
    }
}
