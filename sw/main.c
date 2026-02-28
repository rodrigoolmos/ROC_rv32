#include <stdint.h>
#include "stdio.h"

#define OK_FLAG  0xDEADBEEFu
#define ERR_FLAG 0xBAD00000u

#define DMEM_BASE 0x10000000u
#define RESULT    ((volatile uint32_t *)DMEM_BASE)

#define MMIO_7SEG_BASE      0x00001000u
#define MMIO_uart_BASE      0x00002000u
#define MMIO_CLINT_BASE     0x00003000u
#define MMIO_SPI_BASE       0x00004000u
#define SEG_DATA_OFFSET     0x00u
#define SEG_DP_OFFSET       0x04u
#define ADDR_STATUS         0
#define ADDR_WRITE          4
#define ADDR_READ           8
#define ADDR_N_BYTE_W_R     12
#define ADDR_DELAYS         16
#define ADDR_CLK_DIV        20
#define ADDR_CFG            24

#define CLINT_MTIME_L       0x00u

#define CPU_FREQ_HZ         100000000u

struct spi_cfg_t{
    int msb_first;
    int delay_byte;
    int n_delay_byte;
    int cpol;
    int cpha;
    int clk_div;
};
static struct spi_cfg_t spi_cfg;

static inline void mmio_write(uint32_t addr, uint32_t data){
    *((volatile uint32_t *)(addr)) = data;
}

static inline void mmio_read(uint32_t addr, uint32_t *data){
    *data = *((volatile uint32_t *)(addr));
}

static void seg7_write(uint32_t digits, uint32_t dp_mask){
    mmio_write(MMIO_7SEG_BASE + SEG_DATA_OFFSET, digits);
    mmio_write(MMIO_7SEG_BASE + SEG_DP_OFFSET, dp_mask);
}

static uint32_t seg7_pack_x100(uint32_t value_x100){
    if (value_x100 > 9999u) {
        value_x100 = 9999u;
    }

    return (((value_x100 / 1000u) % 10u) << 12) |
           (((value_x100 /  100u) % 10u) << 8)  |
           (((value_x100 /   10u) % 10u) << 4)  |
           (((value_x100 /    1u) % 10u) << 0);
}

static inline void wait_for_spi_ready(void){
    uint32_t status;
    do {
        mmio_read(MMIO_SPI_BASE + ADDR_STATUS, &status);
    } while (status & (1u << 4)); // busy
}

static uint32_t clint_read_mtime_lo(void){
    uint32_t ticks;
    mmio_read(MMIO_CLINT_BASE + CLINT_MTIME_L, &ticks);
    return ticks;
}

static void delay_1s(void){
    uint32_t start = clint_read_mtime_lo();
    while ((uint32_t)(clint_read_mtime_lo() - start) < CPU_FREQ_HZ) {
        __asm__ volatile ("nop");
    }
}

static void configure_spi(const struct spi_cfg_t *cfg){
    wait_for_spi_ready();

    uint32_t cfgw = ((uint32_t)(cfg->msb_first & 1) << 0) |
                    ((uint32_t)(cfg->cpol      & 1) << 1) |
                    ((uint32_t)(cfg->cpha      & 1) << 2);

    uint32_t delays = ((uint32_t)(cfg->delay_byte   & 0xFFu) << 0) |
                      ((uint32_t)(cfg->n_delay_byte & 0xFFu) << 8);

    mmio_write(MMIO_SPI_BASE + ADDR_CFG, cfgw);
    mmio_write(MMIO_SPI_BASE + ADDR_DELAYS, delays);
    mmio_write(MMIO_SPI_BASE + ADDR_CLK_DIV, (uint32_t)cfg->clk_div);
}

/*
 * SPI transaction:
 *  - write tx_len bytes
 *  - then read rx_len bytes
 *
 * Orden robusto: cargar TX -> disparar -> esperar fin -> leer RX
 */
static void spi_xfer(const uint8_t *tx, uint32_t tx_len, uint8_t *rx, uint32_t rx_len){
    wait_for_spi_ready();

    for (uint32_t i = 0; i < tx_len; i++) {
        mmio_write(MMIO_SPI_BASE + ADDR_WRITE, tx[i]);
    }

    mmio_write(MMIO_SPI_BASE + ADDR_N_BYTE_W_R,
               ((rx_len & 0xFFFFu) << 0) | ((tx_len & 0xFFFFu) << 16));

    wait_for_spi_ready();

    for (uint32_t i = 0; i < rx_len; i++) {
        uint32_t d;
        mmio_read(MMIO_SPI_BASE + ADDR_READ, &d);
        rx[i] = (uint8_t)(d & 0xFFu);
    }
}

/* ------------------------
 * BME280 (SPI)
 * ------------------------ */
#define BME280_REG_ID        0xD0
#define BME280_REG_RESET     0xE0
#define BME280_REG_CTRL_HUM  0xF2
#define BME280_REG_STATUS    0xF3
#define BME280_REG_CTRL_MEAS 0xF4
#define BME280_REG_CONFIG    0xF5
#define BME280_REG_DATA      0xF7  // F7..FE (8 bytes)

static void bme280_write(uint8_t reg, const uint8_t *data, uint32_t len){
    uint8_t buf[1 + 32];
    if (len > 32) len = 32;

    buf[0] = (uint8_t)(reg & 0x7Fu); // write => bit7=0
    for (uint32_t i = 0; i < len; i++) buf[1 + i] = data[i];

    spi_xfer(buf, 1u + len, 0, 0);
}

static void bme280_read(uint8_t reg, uint8_t *data, uint32_t len){
    uint8_t cmd = (uint8_t)(reg | 0x80u); // read => bit7=1
    spi_xfer(&cmd, 1, data, len);
}

static uint8_t bme280_read_u8(uint8_t reg){
    uint8_t v = 0;
    bme280_read(reg, &v, 1);
    return v;
}

static void bme280_reset_and_wait(void){
    uint8_t rst = 0xB6;
    bme280_write(BME280_REG_RESET, &rst, 1);

    for (volatile uint32_t t = 0; t < 4000000u; t++) {
        uint8_t st = bme280_read_u8(BME280_REG_STATUS);
        if (((st & 0x01u) == 0) && ((st & 0x08u) == 0)) break;
    }
}

static void bme280_init_basic(void){
    bme280_reset_and_wait();

    // osrs_h = x1
    uint8_t ctrl_hum = 0x01;
    bme280_write(BME280_REG_CTRL_HUM, &ctrl_hum, 1);

    // t_sb=1000ms (101), filter=off (000), spi3w=0
    uint8_t config = (uint8_t)((0x05u << 5) | (0x00u << 2) | 0x00u);
    bme280_write(BME280_REG_CONFIG, &config, 1);

    // osrs_t=x1, osrs_p=x1, mode=normal
    uint8_t ctrl_meas = (uint8_t)((0x01u << 5) | (0x01u << 2) | 0x03u);
    bme280_write(BME280_REG_CTRL_MEAS, &ctrl_meas, 1);
}

/* -------- Calibración + compensación (Bosch, entero) -------- */
struct bme280_calib {
    uint16_t dig_T1; int16_t dig_T2; int16_t dig_T3;
    uint16_t dig_P1; int16_t dig_P2; int16_t dig_P3; int16_t dig_P4; int16_t dig_P5;
    int16_t  dig_P6; int16_t dig_P7; int16_t dig_P8; int16_t dig_P9;
    uint8_t  dig_H1; int16_t dig_H2; uint8_t dig_H3; int16_t dig_H4; int16_t dig_H5; int8_t dig_H6;
};

static struct bme280_calib calib;
static int32_t t_fine;

static void bme280_read_calibration(void){
    uint8_t b1[26];
    uint8_t b2[7];

    bme280_read(0x88, b1, 26);

    calib.dig_T1 = (uint16_t)(b1[1] << 8 | b1[0]);
    calib.dig_T2 = (int16_t)(b1[3] << 8 | b1[2]);
    calib.dig_T3 = (int16_t)(b1[5] << 8 | b1[4]);

    calib.dig_P1 = (uint16_t)(b1[7] << 8 | b1[6]);
    calib.dig_P2 = (int16_t)(b1[9] << 8 | b1[8]);
    calib.dig_P3 = (int16_t)(b1[11] << 8 | b1[10]);
    calib.dig_P4 = (int16_t)(b1[13] << 8 | b1[12]);
    calib.dig_P5 = (int16_t)(b1[15] << 8 | b1[14]);
    calib.dig_P6 = (int16_t)(b1[17] << 8 | b1[16]);
    calib.dig_P7 = (int16_t)(b1[19] << 8 | b1[18]);
    calib.dig_P8 = (int16_t)(b1[21] << 8 | b1[20]);
    calib.dig_P9 = (int16_t)(b1[23] << 8 | b1[22]);

    calib.dig_H1 = b1[25];

    bme280_read(0xE1, b2, 7);

    calib.dig_H2 = (int16_t)(b2[1] << 8 | b2[0]);
    calib.dig_H3 = b2[2];
    calib.dig_H4 = (int16_t)((b2[3] << 4) | (b2[4] & 0x0F));
    calib.dig_H5 = (int16_t)((b2[5] << 4) | (b2[4] >> 4));
    calib.dig_H6 = (int8_t)b2[6];
}

static int32_t bme280_comp_T_x100(int32_t adc_T){
    int32_t var1, var2;
    var1 = ((((adc_T >> 3) - ((int32_t)calib.dig_T1 << 1))) * ((int32_t)calib.dig_T2)) >> 11;
    var2 = (((((adc_T >> 4) - ((int32_t)calib.dig_T1)) * ((adc_T >> 4) - ((int32_t)calib.dig_T1))) >> 12) * ((int32_t)calib.dig_T3)) >> 14;
    t_fine = var1 + var2;
    return (t_fine * 5 + 128) >> 8; // °C * 100
}

static uint32_t bme280_comp_P_Pa(int32_t adc_P){
    int32_t var1, var2;
    uint32_t p;

    // Use Bosch's 32-bit integer path to avoid pulling in 64-bit libgcc helpers on RV32I.
    var1 = (t_fine >> 1) - 64000;
    var2 = (((var1 >> 2) * (var1 >> 2)) >> 11) * (int32_t)calib.dig_P6;
    var2 = var2 + ((var1 * (int32_t)calib.dig_P5) << 1);
    var2 = (var2 >> 2) + ((int32_t)calib.dig_P4 << 16);

    var1 = (((((var1 >> 2) * (var1 >> 2)) >> 13) * (int32_t)calib.dig_P3) >> 3) +
           (((int32_t)calib.dig_P2 * var1) >> 1);
    var1 = (var1 >> 18);
    var1 = (((32768 + var1) * (int32_t)calib.dig_P1) >> 15);

    if (var1 == 0) {
        return 0;
    }

    p = ((uint32_t)(1048576 - adc_P) - ((uint32_t)var2 >> 12)) * 3125u;
    if (p < 0x80000000u) {
        p = (p << 1) / (uint32_t)var1;
    } else {
        p = (p / (uint32_t)var1) << 1;
    }

    var1 = (((int32_t)calib.dig_P9) * (int32_t)(((p >> 3) * (p >> 3)) >> 13)) >> 12;
    var2 = (((int32_t)(p >> 2)) * (int32_t)calib.dig_P8) >> 13;

    p = p + (uint32_t)((var1 + var2 + (int32_t)calib.dig_P7) >> 4);
    return p; // Pa
}

static uint32_t bme280_comp_H_x1024(int32_t adc_H){
    int32_t v_x1;

    v_x1 = t_fine - 76800;
    v_x1 = (((((adc_H << 14) - ((int32_t)calib.dig_H4 << 20) - ((int32_t)calib.dig_H5 * v_x1)) + 16384) >> 15) *
            (((((((v_x1 * (int32_t)calib.dig_H6) >> 10) * (((v_x1 * (int32_t)calib.dig_H3) >> 11) + 32768)) >> 10) + 2097152) *
               (int32_t)calib.dig_H2 + 8192) >> 14));

    v_x1 = v_x1 - (((((v_x1 >> 15) * (v_x1 >> 15)) >> 7) * (int32_t)calib.dig_H1) >> 4);

    if (v_x1 < 0) v_x1 = 0;
    if (v_x1 > 419430400) v_x1 = 419430400;

    return (uint32_t)(v_x1 >> 12); // %RH * 1024
}

/* ------------------------
 * Main
 * ------------------------ */
int main(void)
{
    volatile uint32_t *addr_uart = (volatile uint32_t *)MMIO_uart_BASE;

    RESULT[0] = 0u;

    spi_cfg.msb_first   = 1;
    spi_cfg.delay_byte  = 0;
    spi_cfg.n_delay_byte= 0;
    spi_cfg.cpol        = 0; // SPI mode 0
    spi_cfg.cpha        = 0;
    spi_cfg.clk_div     = 100000;

    print(addr_uart, "Start program\n\0");

    configure_spi(&spi_cfg);

    // --- Detect ---
    uint8_t id = bme280_read_u8(BME280_REG_ID);
    RESULT[1] = id;

    if (id != 0x60) {
        print(addr_uart, "BME280 ID mismatch\n\0");
        printf_int(addr_uart, "ID=%d (expected 96)\n", (int)id, 0, 0);
        RESULT[0] = ERR_FLAG;
        for (;;) { __asm__ volatile ("wfi"); }
    }

    bme280_init_basic();
    bme280_read_calibration();

    RESULT[0] = OK_FLAG;
    RESULT[5] = 0u;

    for (;;) {
        // Leer raw
        uint8_t raw[8];
        bme280_read(BME280_REG_DATA, raw, 8);

        int32_t adc_P = (int32_t)(((uint32_t)raw[0] << 12) | ((uint32_t)raw[1] << 4) | ((uint32_t)raw[2] >> 4));
        int32_t adc_T = (int32_t)(((uint32_t)raw[3] << 12) | ((uint32_t)raw[4] << 4) | ((uint32_t)raw[5] >> 4));
        int32_t adc_H = (int32_t)(((uint32_t)raw[6] << 8)  | ((uint32_t)raw[7]));

        // Compensar
        int32_t  T_x100   = bme280_comp_T_x100(adc_T);   // °C * 100
        uint32_t P_Pa     = bme280_comp_P_Pa(adc_P);     // Pa
        uint32_t H_x1024  = bme280_comp_H_x1024(adc_H);  // % * 1024

        // Formatear para imprimir solo int:
        int32_t  T_int = T_x100 / 100;
        int32_t  T_dec = T_x100 % 100; if (T_dec < 0) T_dec = -T_dec;

        // Humedad: % *100 (desde %*1024)
        // H_x100 = round(H*100) = (H_x1024*100 + 512)/1024
        uint32_t H_x100 = (H_x1024 * 100u + 512u) >> 10;
        uint32_t H_int = H_x100 / 100u;
        uint32_t H_dec = H_x100 % 100u;

        // Presión: hPa con 2 decimales. 1 hPa = 100 Pa, así que Pa == hPa*100.
        uint32_t P_hPa_x100 = P_Pa;
        uint32_t P_int = P_hPa_x100 / 100u;
        uint32_t P_dec = P_hPa_x100 % 100u;

        printf_int(addr_uart, "T=%d.%dC H=%d.%d%% P=%d.%dhPa\n\r",
                   (int)T_int, (int)T_dec, (int)H_int, (int)H_dec, (int)P_int, (int)P_dec);

        // 8 displays: [Temp xx.xx][Hum xx.xx]
        // DPs on digit 6 and digit 2 place the decimal point in each 4-digit group.
        uint32_t T_disp = seg7_pack_x100((T_x100 < 0) ? (uint32_t)(-T_x100) : (uint32_t)T_x100);
        uint32_t H_disp = seg7_pack_x100(H_x100);
        seg7_write((T_disp << 16) | H_disp, (1u << 6) | (1u << 2));

        // Guardar también en RESULT por si quieres mirar DMEM
        RESULT[2] = (uint32_t)T_x100;
        RESULT[3] = (uint32_t)P_Pa;
        RESULT[4] = (uint32_t)H_x100;
        RESULT[5] = RESULT[5] + 1u;

        delay_1s();
    }
}
