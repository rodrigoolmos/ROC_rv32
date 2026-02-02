#include <stdint.h>

void print(volatile uint32_t *addr_uart, const char *s);
void printf_int(volatile uint32_t *addr_uart, const char *fmt, ...);
