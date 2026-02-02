#include <stdint.h>
#include "stdio.h"

#define OK_FLAG  0xDEADBEEFu
#define ERR_FLAG 0xBAD00000u

// DMEM base address (must match DMEM_BASE in the RTL)
#define DMEM_BASE 0x10000000u

// MMIO base address (must match MMIO in the RTL)
#define MMIO_GPIO 0x00000000u
#define MMIO_REGS 0x00001000u
#define MMIO_UART 0x00002000u

// Number of regs in the MMIO_REGS block
#define MMIO_REGS_NUM 16

static void okay(volatile uint32_t *addr_dmem) {
    addr_dmem[0] = OK_FLAG;
}

static void fail(volatile uint32_t *addr_dmem, uint32_t code) {
    addr_dmem[0] = ERR_FLAG | (code & 0xFFFFu);
}

void set_dir_gpios_output(volatile uint32_t *addr_mmio, uint32_t pin_mask) {
    addr_mmio[1] = pin_mask;
}

void set_gpios_value(volatile uint32_t *addr_mmio, uint32_t value) {
    addr_mmio[0] = value;
}

void read_gpios_value(volatile uint32_t *addr_mmio, volatile uint32_t *addr_out) {
    *addr_out = addr_mmio[0];
}

void wait_cycles(volatile uint32_t count) {
    while (count--) {
        __asm__ volatile ("nop");
    }
}

int main(void) {
    int i, j;
    uint32_t regs_val = 0;
    volatile uint32_t *addr_dmem = (volatile uint32_t *)DMEM_BASE;
    volatile uint32_t *addr_gpio = (volatile uint32_t *)MMIO_GPIO;
    volatile uint32_t *addr_regs = (volatile uint32_t *)MMIO_REGS;
    volatile uint32_t *addr_uart = (volatile uint32_t *)MMIO_UART;
    char signature_roc[4] = {'R', 'O', 'C', 'V'};
    char signature_love[4] = {'L', 'O', 'V', 'E'};
    char signature_hada[4] = {'H', 'A', 'D', 'A'};

    print(addr_uart, "Start program\n\0");
    printf_int(addr_uart, "Test print_int %d, %d\n\0", 6, 7);


    // Avoid local array initializers: they often compile into calls to memcpy
    // (and with -nostdlib that breaks the link).
    // Instead generate the patterns directly.

    for (i = 0; i < 16; i++) {
        addr_dmem[i] = i;
    }

    for (j = 0; j < 16; j++) {
        addr_dmem[j + i] = addr_dmem[j] + addr_dmem[j];
    }

    // Fill a larger word pattern and compute a checksum.
    uint32_t checksum = 0;
    for (j = 0; j < 32; j++) {
        uint32_t v = (uint32_t)(j * 3 + 1) ^ 0xA5A5u;
        addr_dmem[32 + j] = v;
        checksum ^= v + (uint32_t)j;
    }

    for (j = 0; j < 16; j++) {
        if ((int)addr_dmem[j] != j) {
            fail(addr_dmem, (uint32_t)j);
        }
    }

    for (j = 0; j < 16; j++) {
        int expected = 2 * j;
        if ((int)addr_dmem[j + i] != expected) {
            fail(addr_dmem, (uint32_t)(j + i));
        }
    }

    // Verify word pattern and checksum.
    uint32_t chk2 = 0;
    for (j = 0; j < 32; j++) {
        uint32_t v = (uint32_t)(j * 3 + 1) ^ 0xA5A5u;
        if (addr_dmem[32 + j] != v) {
            fail(addr_dmem, (uint32_t)(32 + j));
        }
        chk2 ^= v + (uint32_t)j;
    }
    if (chk2 != checksum) {
        fail(addr_dmem, 0x1234u);
    }

    // Simple data-dependent loop to exercise ALU and branch paths.
    uint32_t acc = 0;
    for (j = 0; j < 64; j++) {
        acc += (j & 1) ? (j * 7u) : (j ^ 0x55u);
    }
    addr_dmem[1] = signature_roc[0] | ((uint32_t)signature_roc[1] << 8) |
               ((uint32_t)signature_roc[2] << 16) | ((uint32_t)signature_roc[3] << 24);
    addr_dmem[2] = signature_love[0] | ((uint32_t)signature_love[1] << 8) |
               ((uint32_t)signature_love[2] << 16) | ((uint32_t)signature_love[3] << 24);
    addr_dmem[3] = signature_hada[0] | ((uint32_t)signature_hada[1] << 8) |
               ((uint32_t)signature_hada[2] << 16) | ((uint32_t)signature_hada[3] << 24);
    addr_dmem[4] = acc;
    addr_dmem[5] = 0xCAFEBABEu;
    
    //MMIO test: write and read back regs
    for (i = 0; i < MMIO_REGS_NUM; i++){
        addr_regs[i] = i;
        regs_val = addr_regs[i];
        if (regs_val != (uint32_t)i) {
            fail(addr_dmem, (uint32_t)(i + 0xA10));
        }
    }
    for (i = 0; i < MMIO_REGS_NUM; i++){
        regs_val = addr_regs[i];
        addr_regs[i] = regs_val+10;
        regs_val = addr_regs[i];
        if (regs_val != (uint32_t)(i + 10)) {
            fail(addr_dmem, (uint32_t)(i + 0xA10));
        }
    }

    set_dir_gpios_output(addr_gpio, 0xFFFF0000u);

    uint32_t pattern = 0x0000fu;
    
    for (int i=0; i<100; i++){

        set_gpios_value(addr_gpio, (pattern << 16));
        pattern = (pattern << 1);
        if (pattern == 0xf00000u){
            pattern = 0x0000fu;
        }
        // print(addr_uart, "GPIO pattern updated\n\0");
        wait_cycles(100u);
    }
    
    print(addr_uart, "End program\n\0");
    printf_int(addr_uart, "Test print_int \n\0%d, %d, %d, %d", 1, 2, 6, 7);


    okay(addr_dmem);
    // infinite loop to prevent function return
    for (;;) {
        __asm__ volatile ("wfi");
    }

}
