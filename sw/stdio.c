#include "stdio.h"
#include <stdarg.h>

static void putc_uart(volatile uint32_t *addr_uart, char c) {
    while (addr_uart[0] & (1u << 3)) {
        __asm__ volatile ("nop");
    }
    addr_uart[1] = (uint32_t)c;
}

static void put_int(volatile uint32_t *addr_uart, int v) {
    char buf[12];
    int i = 0;
    unsigned int x;

    if (v < 0) {
        putc_uart(addr_uart, '-');
        x = (unsigned int)(-v);
    } else {
        x = (unsigned int)v;
    }

    if (x == 0) {
        putc_uart(addr_uart, '0');
        return;
    }

    while (x > 0) {
        // Unsigned divide/mod by 10 without libgcc helpers.
        // q = x / 10 using shift/add approximation, then fix remainder.
        unsigned int q = (x >> 1) + (x >> 2);
        q = q + (q >> 4);
        q = q + (q >> 8);
        q = q + (q >> 16);
        q = q >> 3;
        unsigned int r = x - (q * 10);
        if (r >= 10) {
            r -= 10;
            q += 1;
        }
        buf[i++] = (char)('0' + r);
        x = q;
    }

    while (i--) {
        putc_uart(addr_uart, buf[i]);
    }
}

void print(volatile uint32_t *addr_uart, const char *s) {
    int i=0;
    while (s[i] != '\0') {
        // Wait if TX FIFO is full (status bit 3).
        putc_uart(addr_uart, s[i]);
        i++;
    }
}

void printf_int(volatile uint32_t *addr_uart, const char *fmt, ...) {
    va_list ap;
    va_start(ap, fmt);

    for (int i = 0; fmt[i] != '\0'; i++) {
        if (fmt[i] == '%' && fmt[i + 1] == 'd') {
            int v = va_arg(ap, int);
            put_int(addr_uart, v);
            i++;
        } else if (fmt[i] == '%' && fmt[i + 1] == '%') {
            putc_uart(addr_uart, '%');
            i++;
        } else {
            putc_uart(addr_uart, fmt[i]);
        }
    }

    va_end(ap);
}
