/* Original test-only same-extent fixture write after sealed copy, before parse. */
#define _GNU_SOURCE
#include <dlfcn.h>
#include <fcntl.h>
#include <stdarg.h>
#include <stdlib.h>
#include <stdio.h>
#include <sys/syscall.h>
static long (*actual)(long,...);
static long destination=-1;
static int gets=0;
long syscall(long nr,...) {
    va_list ap;va_start(ap,nr);
    long a=va_arg(ap,long),b=va_arg(ap,long),c=va_arg(ap,long);
    long d=va_arg(ap,long),e=va_arg(ap,long),f=va_arg(ap,long);va_end(ap);
    if(!actual)actual=dlsym(RTLD_NEXT,"syscall");
    const char *path=getenv("AESIR_SAFETENSORS_MUTATION_PATH");
    if(path&&nr==SYS_memfd_create){destination=actual(nr,a,b,c,d,e,f);gets=0;return destination;}
    if(path&&nr==SYS_fcntl&&a==destination&&b==1034&&++gets==2){
        long original=actual(SYS_openat,AT_FDCWD,path,O_RDWR|O_CLOEXEC|O_NONBLOCK,0,0,0);
        if(original<0)abort();
        long size=actual(SYS_lseek,original,0,SEEK_END,0,0,0);
        unsigned char byte=0;
        if(size<=0||actual(SYS_pread64,original,&byte,1,size-1,0,0)!=1)abort();
        byte^=0x40;
        if(actual(SYS_pwrite64,original,&byte,1,size-1,0,0)!=1)abort();
        if(actual(SYS_close,original,0,0,0,0,0)!=0)abort();
    }
    return actual(nr,a,b,c,d,e,f);
}
