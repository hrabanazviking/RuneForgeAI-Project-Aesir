/* Isolated test syscall faults over real regular files; no production linkage. */
#define _GNU_SOURCE
#include <dlfcn.h>
#include <errno.h>
#include <stdarg.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <sys/syscall.h>
static long (*actual)(long, ...);
static long selected = -1;
static int stats = 0;
static int reads = 0;
long syscall(long nr, ...) {
    va_list ap;
    va_start(ap, nr);
    long a = va_arg(ap, long), b = va_arg(ap, long), c = va_arg(ap, long);
    long d = va_arg(ap, long), e = va_arg(ap, long), f = va_arg(ap, long);
    va_end(ap);
    if (!actual) actual = dlsym(RTLD_NEXT, "syscall");
    const char *target = getenv("AESIR_INDEX_FAULT_PATH");
    const char *mode = getenv("AESIR_INDEX_FAULT_MODE");
    if (!target || !mode) return actual(nr, a, b, c, d, e, f);
    if (nr == SYS_openat && strcmp((const char *)b, target) == 0) {
        if (!strcmp(mode, "open")) { errno = EACCES; return -1; }
        selected = actual(nr, a, b, c, d, e, f);
        stats = reads = 0;
        return selected;
    }
    if (a != selected || selected < 0) return actual(nr, a, b, c, d, e, f);
    if (nr == SYS_statx) {
        stats++;
        if (!strcmp(mode, "statx")) { errno = EIO; return -1; }
        long rc = actual(nr, a, b, c, d, e, f);
        if (rc == 0) {
            unsigned char *p = (unsigned char *)e;
            if (!strcmp(mode, "mask")) p[1] &= ~2;
            if (!strcmp(mode, "type")) { p[28] = 0; p[29] = 0x20; }
            if ((!strcmp(mode, "changed") && stats == 2) || !strcmp(mode, "early_size")) {
                uint64_t size;
                memcpy(&size, p + 40, 8); size++;
                memcpy(p + 40, &size, 8);
            }
        }
        return rc;
    }
    if (nr == SYS_read) {
        reads++;
        if (!strcmp(mode, "read")) { errno = EIO; return -1; }
        if (!strcmp(mode, "eintr")) { errno = EINTR; return -1; }
        if (!strcmp(mode, "eof")) return 0;
        if (!strcmp(mode, "short") && c > 3) c = 3;
        long rc = actual(nr, a, b, c, d, e, f);
        if (!strcmp(mode, "extra") && rc == 0 && c > 0) {
            ((unsigned char *)b)[0] = 32; return 1;
        }
        return rc;
    }
    if (nr == SYS_close) {
        selected = -1;
        long rc = actual(nr, a, b, c, d, e, f);
        if (!strcmp(mode, "close")) { errno = EIO; return -1; }
        return rc;
    }
    return actual(nr, a, b, c, d, e, f);
}
