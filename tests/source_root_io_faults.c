/* Isolated pre-effect faults over real root/shard files; no production link. */
#define _GNU_SOURCE
#include <dlfcn.h>
#include <errno.h>
#include <stdarg.h>
#include <stdlib.h>
#include <string.h>
#include <sys/syscall.h>
static long (*actual)(long, ...);
static long root_fd = -1, file_fd = -1;
static int stats = 0;
long syscall(long nr, ...) {
    va_list ap;
    va_start(ap, nr);
    long a=va_arg(ap,long), b=va_arg(ap,long), c=va_arg(ap,long);
    long d=va_arg(ap,long), e=va_arg(ap,long), f=va_arg(ap,long);
    va_end(ap);
    if (!actual) actual = dlsym(RTLD_NEXT, "syscall");
    const char *root = getenv("AESIR_ROOT_FAULT_PATH");
    const char *label = getenv("AESIR_ROOT_FAULT_LABEL");
    const char *mode = getenv("AESIR_ROOT_FAULT_MODE");
    if (!root || !label || !mode) return actual(nr,a,b,c,d,e,f);
    if (nr==SYS_openat && !strcmp((const char *)b,root)) {
        if (!strcmp(mode,"root")) { errno=EACCES; return -1; }
        root_fd=actual(nr,a,b,c,d,e,f); return root_fd;
    }
    if (nr==SYS_openat2 && a==root_fd && !strcmp((const char *)b,label)) {
        if (!strcmp(mode,"open")) { errno=EACCES; return -1; }
        if (!strcmp(mode,"enosys")) { errno=ENOSYS; return -1; }
        file_fd=actual(nr,a,b,c,d,e,f); stats=0; return file_fd;
    }
    if (nr==SYS_statx && a==file_fd && file_fd>=0) {
        stats++;
        if (!strcmp(mode,"statx") || (!strcmp(mode,"transfer_statx") && stats==2)) { errno=EIO; return -1; }
        long rc=actual(nr,a,b,c,d,e,f);
        if (!rc && !strcmp(mode,"mask")) ((unsigned char *)e)[1]&=~2;
        if (!rc && !strcmp(mode,"type")) { ((unsigned char *)e)[28]=0; ((unsigned char *)e)[29]=0x20; }
        return rc;
    }
    if (nr==SYS_close && (a==root_fd || a==file_fd)) {
        int failure = (a==root_fd && !strcmp(mode,"root_close")) || (a==file_fd && !strcmp(mode,"file_close"));
        if (a==root_fd) root_fd=-1;
        if (a==file_fd) file_fd=-1;
        long rc=actual(nr,a,b,c,d,e,f);
        if (failure) { errno=EIO; return -1; }
        return rc;
    }
    return actual(nr,a,b,c,d,e,f);
}
