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
    char signature_roc[4] = {'R', 'O', 'C', 'V'};
    char signature_love[4] = {'L', 'O', 'V', 'E'};
    char signature_hada[4] = {'H', 'A', 'D', 'A'};

    // Avoid local array initializers: they often compile into calls to memcpy
    // (and with -nostdlib that breaks the link).
    // Instead generate the patterns directly.

    for (i = 0; i < 16; i++) {
        addr[i] = i;
    }

    for (j = 0; j < 16; j++) {
        addr[j + i] = addr[j] + addr[j];
    }

    // Fill a larger word pattern and compute a checksum.
    uint32_t checksum = 0;
    for (j = 0; j < 32; j++) {
        uint32_t v = (uint32_t)(j * 3 + 1) ^ 0xA5A5u;
        addr[32 + j] = v;
        checksum ^= v + (uint32_t)j;
    }

    for (j = 0; j < 16; j++) {
        if ((int)addr[j] != j) {
            fail(addr, (uint32_t)j);
        }
    }

    for (j = 0; j < 16; j++) {
        int expected = 2 * j;
        if ((int)addr[j + i] != expected) {
            fail(addr, (uint32_t)(j + i));
        }
    }

    // Verify word pattern and checksum.
    uint32_t chk2 = 0;
    for (j = 0; j < 32; j++) {
        uint32_t v = (uint32_t)(j * 3 + 1) ^ 0xA5A5u;
        if (addr[32 + j] != v) {
            fail(addr, (uint32_t)(32 + j));
        }
        chk2 ^= v + (uint32_t)j;
    }
    if (chk2 != checksum) {
        fail(addr, 0x1234u);
    }

    // Simple data-dependent loop to exercise ALU and branch paths.
    uint32_t acc = 0;
    for (j = 0; j < 64; j++) {
        acc += (j & 1) ? (j * 7u) : (j ^ 0x55u);
    }
    addr[1] = signature_roc[0] | ((uint32_t)signature_roc[1] << 8) |
               ((uint32_t)signature_roc[2] << 16) | ((uint32_t)signature_roc[3] << 24);
    addr[2] = signature_love[0] | ((uint32_t)signature_love[1] << 8) |
               ((uint32_t)signature_love[2] << 16) | ((uint32_t)signature_love[3] << 24);
    addr[3] = signature_hada[0] | ((uint32_t)signature_hada[1] << 8) |
               ((uint32_t)signature_hada[2] << 16) | ((uint32_t)signature_hada[3] << 24);
    addr[4] = acc;
    
    okay(addr);
    // infinite loop to prevent function return
    for (;;) {
        __asm__ volatile ("wfi");
    }

}
