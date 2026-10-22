/* Original test-only seams at the actual sealed descriptor's parser admission. */
#define _GNU_SOURCE
#include <dlfcn.h>
#include <errno.h>
#include <stdarg.h>
#include <stdlib.h>
#include <string.h>
#include <sys/syscall.h>
static long (*actual)(long,...);
static long destination=-1;
static int gets=0;
long syscall(long nr,...) {
    va_list ap;va_start(ap,nr);
    long a=va_arg(ap,long),b=va_arg(ap,long),c=va_arg(ap,long);
    long d=va_arg(ap,long),e=va_arg(ap,long),f=va_arg(ap,long);va_end(ap);
    if(!actual)actual=dlsym(RTLD_NEXT,"syscall");
    const char *mode=getenv("AESIR_SEALED_GGUF_FAULT");
    if(!mode)return actual(nr,a,b,c,d,e,f);
    if(nr==SYS_memfd_create){destination=actual(nr,a,b,c,d,e,f);gets=0;return destination;}
    if(nr==SYS_fcntl&&a==destination&&b==1034){
        gets++;
        if((gets==2&&!strcmp(mode,"parser_digest"))||(gets==3&&!strcmp(mode,"transfer"))||(gets==4&&!strcmp(mode,"admit"))){errno=EIO;return -1;}
    }
    if(nr==SYS_mmap&&e==destination&&!strcmp(mode,"mmap")){errno=ENOMEM;return -1;}
    return actual(nr,a,b,c,d,e,f);
}
