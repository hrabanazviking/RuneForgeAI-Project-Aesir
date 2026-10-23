/* Original test seam for bounded reads of synthetic sealed JSON bytes only. */
#define _GNU_SOURCE
#include <dlfcn.h>
#include <errno.h>
#include <stdarg.h>
#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include <sys/stat.h>
#include <sys/syscall.h>
static long (*actual)(long,...);
static long destination=-1, extent=-1;
static int phase=0, gets=0;
static void record(const char *op,long request,long offset) {
    const char *path=getenv("AESIR_METADATA_LOG");
    if(!path)return;
    FILE *out=fopen(path,"a");if(!out)abort();
    fprintf(out,"{\"op\":\"%s\",\"phase\":%d,\"request\":%ld,\"offset\":%ld}\n",op,phase,request,offset);
    if(fclose(out))abort();
}
long syscall(long nr,...) {
    va_list ap;va_start(ap,nr);
    long a=va_arg(ap,long),b=va_arg(ap,long),c=va_arg(ap,long);
    long d=va_arg(ap,long),e=va_arg(ap,long),f=va_arg(ap,long);va_end(ap);
    if(!actual)actual=dlsym(RTLD_NEXT,"syscall");
    const char *mode=getenv("AESIR_METADATA_FAULT");
    if(!mode)return actual(nr,a,b,c,d,e,f);
    if(nr==SYS_memfd_create){destination=actual(nr,a,b,c,d,e,f);phase=gets=0;extent=-1;return destination;}
    if(nr==SYS_statx&&a==destination){
        long rc=actual(nr,a,b,c,d,e,f);
        if(!rc)extent=(long)((struct statx *)e)->stx_size;
        return rc;
    }
    if(nr==SYS_fcntl&&a==destination&&b==1034){
        gets++;record("get_seals",gets,0);
        if(gets==5&&!strcmp(mode,"after_metadata")){errno=EIO;return -1;}
    }
    if(nr==SYS_pread64&&a==destination){
        if(d==0)phase++;
        record("read",c,d);
        if(phase==2&&!strcmp(mode,"parser_digest")){errno=EIO;return -1;}
        if(phase>=3){
            if(!strcmp(mode,"metadata_error")){errno=EIO;return -1;}
            if(!strcmp(mode,"metadata_eintr")){errno=EINTR;return -1;}
            if(!strcmp(mode,"metadata_eof"))return 0;
            if(!strcmp(mode,"metadata_extra"))return c+1;
            if(!strcmp(mode,"metadata_lookahead")&&d==extent){*(unsigned char *)b=0;return 1;}
            if(!strcmp(mode,"metadata_short")&&c>3)c=3;
        }
    }
    return actual(nr,a,b,c,d,e,f);
}
