#include <errno.h>
#include <fcntl.h>
#include <poll.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <termios.h>
#include <unistd.h>

#define DEFAULT_PORT "/dev/ttyUSB0"
#define DEFAULT_IMEM "sw/imem.dat"
#define BAUD_RATE B115200
#define MAX_WORDS 1024
#define CHUNK_WORDS 128

static void usage(const char *prog) {
    fprintf(stderr,
            "Usage:\n"
            "  %s -addr <word> -load [-file <imem.dat>] [-port <dev>]\n"
            "  %s -addr <word> -ndata <n> -read [-port <dev>]\n"
            "\n"
            "Notes:\n"
            "  -addr is a word address (0..1023). Baudrate is fixed at 115200.\n",
            prog, prog);
}

static int open_serial(const char *port) {
    int fd = open(port, O_RDWR | O_NOCTTY | O_SYNC);
    if (fd < 0) {
        perror("open");
        return -1;
    }

    struct termios tio;
    if (tcgetattr(fd, &tio) != 0) {
        perror("tcgetattr");
        close(fd);
        return -1;
    }

    cfmakeraw(&tio);
    tio.c_cflag |= (CLOCAL | CREAD);
    tio.c_cflag &= ~CRTSCTS;
    tio.c_cflag &= ~PARENB;
    tio.c_cflag &= ~CSTOPB;
    tio.c_cflag &= ~CSIZE;
    tio.c_cflag |= CS8;
    tio.c_iflag &= ~(IXON | IXOFF | IXANY);

    if (cfsetispeed(&tio, BAUD_RATE) != 0 || cfsetospeed(&tio, BAUD_RATE) != 0) {
        perror("cfsetispeed/cfsetospeed");
        close(fd);
        return -1;
    }

    tio.c_cc[VMIN] = 0;
    tio.c_cc[VTIME] = 10;

    if (tcsetattr(fd, TCSANOW, &tio) != 0) {
        perror("tcsetattr");
        close(fd);
        return -1;
    }

    tcflush(fd, TCIOFLUSH);
    return fd;
}

static int write_all(int fd, const uint8_t *buf, size_t len) {
    size_t off = 0;
    while (off < len) {
        ssize_t n = write(fd, buf + off, len - off);
        if (n < 0) {
            if (errno == EINTR) {
                continue;
            }
            return -1;
        }
        off += (size_t)n;
    }
    return 0;
}

static int read_exact(int fd, uint8_t *buf, size_t len, int timeout_ms) {
    size_t off = 0;
    while (off < len) {
        struct pollfd pfd = { .fd = fd, .events = POLLIN };
        int pr = poll(&pfd, 1, timeout_ms);
        if (pr < 0) {
            if (errno == EINTR) {
                continue;
            }
            return -1;
        }
        if (pr == 0) {
            return -2;
        }
        ssize_t n = read(fd, buf + off, len - off);
        if (n < 0) {
            if (errno == EINTR) {
                continue;
            }
            return -1;
        }
        if (n == 0) {
            continue;
        }
        off += (size_t)n;
    }
    return 0;
}

static int send_word_le(int fd, uint32_t word) {
    uint8_t b[4];
    b[0] = (uint8_t)(word & 0xFF);
    b[1] = (uint8_t)((word >> 8) & 0xFF);
    b[2] = (uint8_t)((word >> 16) & 0xFF);
    b[3] = (uint8_t)((word >> 24) & 0xFF);
    return write_all(fd, b, sizeof(b));
}

static int recv_word_le(int fd, uint32_t *out) {
    uint8_t b[4];
    int rc = read_exact(fd, b, sizeof(b), 1000);
    if (rc != 0) {
        return rc;
    }
    *out = (uint32_t)b[0]
         | ((uint32_t)b[1] << 8)
         | ((uint32_t)b[2] << 16)
         | ((uint32_t)b[3] << 24);
    return 0;
}

static int load_imem_file(const char *path, uint32_t **out_words, size_t *out_count) {
    FILE *f = fopen(path, "r");
    if (!f) {
        perror("fopen");
        return -1;
    }

    size_t cap = 256;
    size_t count = 0;
    uint32_t *words = (uint32_t *)malloc(cap * sizeof(uint32_t));
    if (!words) {
        fclose(f);
        return -1;
    }

    char line[256];
    while (fgets(line, sizeof(line), f)) {
        char *s = line;
        for (;;) {
            while (*s == ' ' || *s == '\t' || *s == '\r' || *s == '\n') {
                s++;
            }
            if (*s == '\0' || *s == '#') {
                break;
            }
            if (*s == '/' && s[1] == '/') {
                break;
            }
            char *end = NULL;
            unsigned long val = strtoul(s, &end, 16);
            if (end == s) {
                break;
            }
            if (count == cap) {
                cap *= 2;
                uint32_t *tmp = (uint32_t *)realloc(words, cap * sizeof(uint32_t));
                if (!tmp) {
                    free(words);
                    fclose(f);
                    return -1;
                }
                words = tmp;
            }
            words[count++] = (uint32_t)val;
            s = end;
        }
    }
    fclose(f);

    if (count == 0) {
        free(words);
        fprintf(stderr, "imem file is empty: %s\n", path);
        return -1;
    }

    *out_words = words;
    *out_count = count;
    return 0;
}

static int send_load(int fd, uint32_t addr, const uint32_t *words, size_t count) {
    size_t sent = 0;
    while (sent < count) {
        size_t chunk = count - sent;
        if (chunk > CHUNK_WORDS) {
            chunk = CHUNK_WORDS;
        }
        uint32_t header = (1u << 31) | ((addr & 0x7FFFu) << 16) | (uint32_t)chunk;
        if (send_word_le(fd, header) != 0) {
            return -1;
        }
        for (size_t i = 0; i < chunk; i++) {
            if (send_word_le(fd, words[sent + i]) != 0) {
                return -1;
            }
        }
        addr += (uint32_t)chunk;
        sent += chunk;
    }
    return 0;
}

static int send_read(int fd, uint32_t addr, uint32_t ndata) {
    uint32_t header = (0u << 31) | ((addr & 0x7FFFu) << 16) | (ndata & 0xFFFFu);
    if (send_word_le(fd, header) != 0) {
        return -1;
    }
    for (uint32_t i = 0; i < ndata; i++) {
        uint32_t word = 0;
        int rc = recv_word_le(fd, &word);
        if (rc != 0) {
            fprintf(stderr, "timeout reading word %u\n", i);
            return -1;
        }
        printf("dmem[0x%04x]=0x%08x, %c%c%c%c\n", addr + i, word, 
               (char)(word & 0xFF),
               (char)((word >> 8) & 0xFF),
               (char)((word >> 16) & 0xFF),
               (char)((word >> 24) & 0xFF) );
    }
    return 0;
}

int main(int argc, char **argv) {
    const char *port = DEFAULT_PORT;
    const char *imem_path = DEFAULT_IMEM;
    uint32_t addr = 0;
    uint32_t ndata = 0;
    int do_load = 0;
    int do_read = 0;
    int have_addr = 0;

    for (int i = 1; i < argc; i++) {
        if (strcmp(argv[i], "-port") == 0 && i + 1 < argc) {
            port = argv[++i];
        } else if (strcmp(argv[i], "-file") == 0 && i + 1 < argc) {
            imem_path = argv[++i];
        } else if (strcmp(argv[i], "-addr") == 0 && i + 1 < argc) {
            addr = (uint32_t)strtoul(argv[++i], NULL, 0);
            have_addr = 1;
        } else if (strcmp(argv[i], "-ndata") == 0 && i + 1 < argc) {
            ndata = (uint32_t)strtoul(argv[++i], NULL, 0);
        } else if (strcmp(argv[i], "-load") == 0) {
            do_load = 1;
        } else if (strcmp(argv[i], "-read") == 0) {
            do_read = 1;
        } else if (strcmp(argv[i], "-h") == 0 || strcmp(argv[i], "--help") == 0) {
            usage(argv[0]);
            return 0;
        } else {
            fprintf(stderr, "unknown argument: %s\n", argv[i]);
            usage(argv[0]);
            return 1;
        }
    }

    if (!have_addr || (do_load == do_read)) {
        usage(argv[0]);
        return 1;
    }

    if (do_read && ndata == 0) {
        fprintf(stderr, "error: -read requires -ndata <n>\n");
        return 1;
    }

    int fd = open_serial(port);
    if (fd < 0) {
        return 1;
    }

    int rc = 0;
    if (do_load) {
        uint32_t *words = NULL;
        size_t count = 0;
        if (load_imem_file(imem_path, &words, &count) != 0) {
            close(fd);
            return 1;
        }
        if (addr + count > MAX_WORDS) {
            fprintf(stderr, "error: addr+words out of range (max %u words)\n", MAX_WORDS);
            free(words);
            close(fd);
            return 1;
        }
        printf("Loading %zu words to IMEM at word address 0x%04x\n", count, addr);
        rc = send_load(fd, addr, words, count);
        free(words);
    } else {
        if (addr + ndata > MAX_WORDS) {
            fprintf(stderr, "error: addr+ndata out of range (max %u words)\n", MAX_WORDS);
            close(fd);
            return 1;
        }
        printf("Reading %u words from DMEM at word address 0x%04x\n", ndata, addr);
        rc = send_read(fd, addr, ndata);
    }

    close(fd);
    return (rc == 0) ? 0 : 1;
}
