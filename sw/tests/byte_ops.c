#include <stdint.h>

#define RESULT ((volatile uint32_t *)0x10000000u) // dmem[0]

__attribute__((noreturn)) static void fail(uint16_t code) {
    RESULT[0] = 0xBAD00000u | (uint32_t)code;
    while (1) {
    }
}

int main(void) {
    volatile uint32_t *const w = (volatile uint32_t *)0x10000040u;
    volatile uint8_t *const b  = (volatile uint8_t *)0x10000040u;

    // Baseline word store/load
    w[0] = 0x11223344u;
    if (w[0] != 0x11223344u) fail(0x0001);

    // Byte stores + byte loads
    b[0] = 0xAAu;
    if (b[0] != 0xAAu) fail(0x0010);
    b[1] = 0xBBu;
    if (b[1] != 0xBBu) fail(0x0011);
    b[2] = 0xCCu;
    if (b[2] != 0xCCu) fail(0x0012);
    b[3] = 0xDDu;
    if (b[3] != 0xDDu) fail(0x0013);

    // Word view should reflect little-endian byte lanes
    if (w[0] != 0xDDCCBBAAu) fail(0x0020);

    // Signed byte load (LB) sign-extension check
    b[0] = 0x80u;
    if ((int8_t)b[0] != (int8_t)0x80) fail(0x0030);

    RESULT[0] = 0xDEADBEEFu;
    while (1) {
    }
}
