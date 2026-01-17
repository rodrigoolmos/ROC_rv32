#include <stdint.h>

#define OK_FLAG  0xDEADBEEFu
#define ERR_FLAG 0xBAD00000u

// DMEM base address (must match DMEM_BASE in the RTL)
#define DMEM_BASE 0x10000000u

static void okay(volatile uint32_t *addr) {
    addr[0] = OK_FLAG;
}

static void fail(volatile uint32_t *addr, uint32_t code) {
    addr[0] = ERR_FLAG | (code & 0xFFFFu);
}

int main(void) {
    int i, j;
    volatile uint32_t *addr = (volatile uint32_t *)DMEM_BASE;

    // Avoid local array initializers: they often compile into calls to memcpy
    // (and with -nostdlib that breaks the link).
    // Instead generate the patterns directly.

    for (i = 0; i < 10; i++) {
        ((uint8_t *)addr)[i] = (uint8_t)i;
    }

    for (j = 0; j < 10; j++) {
        addr[j + i] = ((uint8_t *)addr)[j] + ((uint8_t *)addr)[j];
    }

    for (j = 0; j < 10; j++) {
        if (((uint8_t *)addr)[j] != j) {
            fail(addr, (uint32_t)j);
        }
    }

    for (j = 0; j < 10; j++) {
        int expected = 2 * j;
        if ((int)addr[j + i] != expected) {
            fail(addr, (uint32_t)(j + i));
        }
    }
    
    okay(addr);
    // infinite loop to prevent function return
    for (;;) {
        __asm__ volatile ("wfi");
    }

}