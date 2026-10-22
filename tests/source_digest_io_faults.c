/* Test-only faults for the exact synthetic source descriptor. */
#define _GNU_SOURCE
#include <dlfcn.h>
#include <errno.h>
#include <stdarg.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <sys/syscall.h>
static long (*actual)(long,...);
static long selected=-1;
static int reads=0,stats=0;
long syscall(long nr,...) {
    va_list ap;va_start(ap,nr);
    long a=va_arg(ap,long),b=va_arg(ap,long),c=va_arg(ap,long);
    long d=va_arg(ap,long),e=va_arg(ap,long),f=va_arg(ap,long);
    va_end(ap);
    if (!actual) actual=dlsym(RTLD_NEXT,"syscall");
    const char *path=getenv("AESIR_DIGEST_FAULT_PATH");
    const char *mode=getenv("AESIR_DIGEST_FAULT_MODE");
    if (!path || !mode) return actual(nr,a,b,c,d,e,f);
    if (nr==SYS_openat && !strcmp((const char *)b,path)) {
        selected=actual(nr,a,b,c,d,e,f);reads=0;stats=0;return selected;
    }
    if (a!=selected || selected<0) return actual(nr,a,b,c,d,e,f);
    if (nr==SYS_statx) {
        stats++;
        if ((!strcmp(mode,"stat_before") && stats==1) || (!strcmp(mode,"stat_after") && stats==2)) {errno=EIO;return -1;}
        long rc=actual(nr,a,b,c,d,e,f);
        if (!rc && stats==2 && !strcmp(mode,"changed_size")) {
            uint64_t size;memcpy(&size,(unsigned char *)e+40,8);size++;memcpy((unsigned char *)e+40,&size,8);
        }
        return rc;
    }
    if (nr==SYS_pread64) {
        reads++;
        if (!strcmp(mode,"eintr") || (!strcmp(mode,"eintr_once") && reads==1)) {errno=EINTR;return -1;}
        if (!strcmp(mode,"eio")) {errno=EIO;return -1;}
        if (!strcmp(mode,"eof")) return 0;
        if (!strcmp(mode,"extra_count")) return c+1;
        if (!strcmp(mode,"short") && c>3) c=3;
    }
    return actual(nr,a,b,c,d,e,f);
}
