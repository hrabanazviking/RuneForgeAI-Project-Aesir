/* Isolated positional-I/O faults over actual synthetic files. */
#define _GNU_SOURCE
#include <dlfcn.h>
#include <errno.h>
#include <stdarg.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <sys/syscall.h>
static long (*actual)(long,...);
static int (*actual_close)(int);
static long selected=-1;
static int stats=0;
static long close_selected(int fd) {
    if (!actual_close) actual_close=dlsym(RTLD_NEXT,"close");
    const char *mode=getenv("AESIR_FD_FAULT_MODE");
    int target=fd==selected && selected>=0;
    if (target) selected=-1;
    int rc=actual_close(fd);
    if (target && mode && !strcmp(mode,"close")) { errno=EIO; return -1; }
    return rc;
}
int close(int fd) { return (int)close_selected(fd); }
long syscall(long nr,...) {
    va_list ap;va_start(ap,nr);
    long a=va_arg(ap,long),b=va_arg(ap,long),c=va_arg(ap,long);
    long d=va_arg(ap,long),e=va_arg(ap,long),f=va_arg(ap,long);
    va_end(ap);
    if (!actual) actual=dlsym(RTLD_NEXT,"syscall");
    const char *label=getenv("AESIR_FD_FAULT_LABEL");
    const char *mode=getenv("AESIR_FD_FAULT_MODE");
    if (!label || !mode) return actual(nr,a,b,c,d,e,f);
    if (nr==SYS_openat2 && !strcmp((const char *)b,label)) {
        selected=actual(nr,a,b,c,d,e,f);stats=0;return selected;
    }
    if (a!=selected || selected<0) return actual(nr,a,b,c,d,e,f);
    if (nr==SYS_close) return close_selected((int)a);
    if (nr==SYS_statx) {
        stats++;
        if (stats==2 && !strcmp(mode,"statx")) { errno=EIO; return -1; }
        long rc=actual(nr,a,b,c,d,e,f);
        if (!rc && stats==2 && !strcmp(mode,"mask")) ((unsigned char *)e)[1]&=~2;
        if (!rc && stats==2 && !strcmp(mode,"type")) { ((unsigned char *)e)[28]=0;((unsigned char *)e)[29]=0x20; }
        if (!rc && ((stats==3 && !strcmp(mode,"changed")) || (stats==2 && !strcmp(mode,"size")))) {
            uint64_t n;memcpy(&n,(unsigned char *)e+40,8);n++;memcpy((unsigned char *)e+40,&n,8);
        }
        return rc;
    }
    if (nr==SYS_pread64) {
        if (!strcmp(mode,"read")) { errno=EIO;return -1; }
        if (!strcmp(mode,"eintr")) { errno=EINTR;return -1; }
        if (!strcmp(mode,"eof") || (!strcmp(mode,"header_eof") && d>=8)) return 0;
        if (!strcmp(mode,"body") && d>=8) { errno=EIO;return -1; }
        if (!strcmp(mode,"extra_count")) return c+1;
        if (!strcmp(mode,"short") && c>3) c=3;
    }
    long rc=actual(nr,a,b,c,d,e,f);
    if (nr==SYS_pread64 && !strcmp(mode,"extra") && rc==0 && c>0) {
        ((unsigned char *)b)[0]=32;return 1;
    }
    return rc;
}
