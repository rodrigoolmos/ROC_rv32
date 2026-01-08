#include <stdint.h>

#define OK_FLAG  0xDEADBEEFu
#define ERR_FLAG 0xBAD00000u

// DMEM base address (must match DMEM_BASE in the RTL)
#define DMEM_BASE 0x10000000u

__attribute__((noreturn)) static void fail(uint32_t code) {
    volatile uint32_t *addr = (volatile uint32_t *)DMEM_BASE;
    addr[0] = ERR_FLAG | (code & 0xFFFFu);
    while (1) {
    }
}

int main(void) {
    int i, j;
    volatile uint32_t *addr = (volatile uint32_t *)DMEM_BASE;

    // Avoid local array initializers: they often compile into calls to memcpy
    // (and with -nostdlib that breaks the link).
    // Instead generate the patterns directly.

    for (i = 0; i < 10; i++) {
        uint32_t input_i = (uint32_t)i;
        addr[i] = input_i;
    }

    for (j = 0; j < 10; j++) {
        addr[j + i] = addr[j] + addr[j];
    }

    for (j = 0; j < 10; j++) {
        if ((int)addr[j] != j) {
            fail((uint32_t)j);
        }
    }

    for (j = 0; j < 10; j++) {
        int expected = 2 * j;
        if ((int)addr[j + i] != expected) {
            fail((uint32_t)(j + i));
        }
    }

    addr[0] = OK_FLAG;
    while (1) {
    }
}