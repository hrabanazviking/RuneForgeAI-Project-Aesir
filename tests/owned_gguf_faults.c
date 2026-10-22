/* Original test-only compiler boundary faults, after sealed mmap succeeds. */
#define _GNU_SOURCE
#include <dlfcn.h>
#include <errno.h>
#include <stdarg.h>
#include <stdlib.h>
#include <string.h>
#include <sys/syscall.h>
static long (*actual)(long,...);
static long destination=-1;
static int mapped=0, fired=0;
long syscall(long nr,...) {
    va_list ap;va_start(ap,nr);
    long a=va_arg(ap,long),b=va_arg(ap,long),c=va_arg(ap,long);
    long d=va_arg(ap,long),e=va_arg(ap,long),f=va_arg(ap,long);va_end(ap);
    if(!actual)actual=dlsym(RTLD_NEXT,"syscall");
    const char *mode=getenv("AESIR_OWNED_COMPILER_FAULT");
    if(!mode)return actual(nr,a,b,c,d,e,f);
    if(nr==SYS_memfd_create){destination=actual(nr,a,b,c,d,e,f);mapped=0;return destination;}
    if(nr==SYS_mmap&&e==destination){long result=actual(nr,a,b,c,d,e,f);if(result!=-1)mapped=1;return result;}
    if(mapped&&!fired&&a==destination&&((nr==SYS_pread64&&!strcmp(mode,"compiler_digest"))||(nr==SYS_fcntl&&b==1034&&!strcmp(mode,"compiler_seals")))){fired=1;errno=EIO;return -1;}
    return actual(nr,a,b,c,d,e,f);
}
