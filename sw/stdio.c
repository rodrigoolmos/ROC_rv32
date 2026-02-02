#include "stdio.h"

void print(volatile uint32_t *addr_uart, const char *s) {
    int i=0;
    while (s[i] != '\0') {
        // Wait if TX FIFO is full (status bit 3).
        while (addr_uart[0] & (1u << 3)) {
            __asm__ volatile ("nop");
        }
        // TX write register is at offset 0x4 (index 1).
        addr_uart[1] = (uint32_t)(s[i]);
        i++;
    }
}
