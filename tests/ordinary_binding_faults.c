/* Original test-only faults on retained synthetic source descriptors. */
#define _GNU_SOURCE
#include <dlfcn.h>
#include <errno.h>
#include <fcntl.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/syscall.h>
static long (*actual)(long,...);
static int (*real_close)(int);
static long original=-1,destination=-1;
static int phase=0;
static void record(const char *op,long size,long offset) {
    const char *p=getenv("AESIR_BINDING_LOG");if(!p)return;
    FILE *o=fopen(p,"a");if(!o)abort();
    fprintf(o,"{\"op\":\"%s\",\"phase\":%d,\"request\":%ld,\"offset\":%ld}\n",op,phase,size,offset);
    if(fclose(o))abort();
}
int close(int fd) {
    if(!real_close)real_close=dlsym(RTLD_NEXT,"close");
    int selected=fd==destination&&destination>=0;
    if(selected)destination=-1;
    int rc=real_close(fd);const char *m=getenv("AESIR_BINDING_FAULT");
    if(selected&&m&&!strcmp(m,"close_after")){record(m,0,0);errno=EIO;return -1;}
    return rc;
}
long syscall(long nr,...) {
    va_list ap;va_start(ap,nr);long a=va_arg(ap,long),b=va_arg(ap,long),c=va_arg(ap,long);
    long d=va_arg(ap,long),e=va_arg(ap,long),f=va_arg(ap,long);va_end(ap);
    if(!actual)actual=dlsym(RTLD_NEXT,"syscall");
    const char *label=getenv("AESIR_BINDING_LABEL"),*mode=getenv("AESIR_BINDING_FAULT");
    if(!label||!mode)return actual(nr,a,b,c,d,e,f);
    int target=atoi(getenv("AESIR_BINDING_PHASE")?getenv("AESIR_BINDING_PHASE"):"4");
    if(nr==SYS_openat2&&!strcmp((char *)b,label)){original=actual(nr,a,b,c,d,e,f);return original;}
    if(nr==SYS_memfd_create&&original>=0){destination=actual(nr,a,b,c,d,e,f);original=-1;phase=0;return destination;}
    if(nr==SYS_pread64&&a==destination){
        if(d==0)phase++;
        record("read",c,d);
        if(phase==target&&!strcmp(mode,"error")){record(mode,c,d);errno=EIO;return -1;}
        if(phase==target&&!strcmp(mode,"eof")){record(mode,c,d);return 0;}
        long rc=actual(nr,a,b,c,d,e,f);
        if(phase==target&&!strcmp(mode,"bad_json")&&d==0&&rc>0){record(mode,c,d);*(unsigned char *)b='!';}
        return rc;
    }
    return actual(nr,a,b,c,d,e,f);
}
