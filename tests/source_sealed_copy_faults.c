/* Original test-only fault seams over actual synthetic host files and memfds. */
#define _GNU_SOURCE
#include <dlfcn.h>
#include <errno.h>
#include <stdarg.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/syscall.h>
static long (*actual)(long,...);
static int (*actual_close)(int);
static long source=-1,destination=-1;
static int reads=0,writes=0,digests=0,src_stats=0,dst_stats=0,gets=0;
static void record(const char *op,int attempt,long request,long offset) {
    const char *path=getenv("AESIR_SEAL_FAULT_LOG");
    if(!path)return;
    FILE *out=fopen(path,"a");
    if(!out)abort();
    fprintf(out,"{\"op\":\"%s\",\"attempt\":%d,\"request\":%ld,\"offset\":%ld}\n",op,attempt,request,offset);
    if(fclose(out))abort();
}
int close(int fd) {
    if(!actual_close)actual_close=dlsym(RTLD_NEXT,"close");
    int target=fd==destination&&destination>=0;
    if(target)destination=-1;
    int rc=actual_close(fd);
    const char *mode=getenv("AESIR_SEAL_FAULT_MODE");
    if(target&&mode&&!strcmp(mode,"close_after")){record("close_after",1,0,0);errno=EIO;return -1;}
    return rc;
}
long syscall(long nr,...) {
    va_list ap;va_start(ap,nr);
    long a=va_arg(ap,long),b=va_arg(ap,long),c=va_arg(ap,long);
    long d=va_arg(ap,long),e=va_arg(ap,long),f=va_arg(ap,long);va_end(ap);
    if(!actual)actual=dlsym(RTLD_NEXT,"syscall");
    const char *path=getenv("AESIR_SEAL_FAULT_PATH"),*mode=getenv("AESIR_SEAL_FAULT_MODE");
    if(!path||!mode)return actual(nr,a,b,c,d,e,f);
    if(nr==SYS_openat&&!strcmp((const char *)b,path)) {
        long fd=actual(nr,a,b,c,d,e,f);
        if(source<0){source=fd;reads=src_stats=0;}
        return fd;
    }
    if(nr==SYS_memfd_create) {
        record("create",1,b,0);
        if(!strcmp(mode,"create")){errno=ENOMEM;return -1;}
        if(!strcmp(mode,"alias"))return source;
        if(!strcmp(mode,"large_fd"))return 2147483648L;
        destination=actual(nr,a,b,c,d,e,f);writes=digests=dst_stats=gets=0;return destination;
    }
    if(nr==SYS_statx&&(a==source||a==destination)) {
        int is_source=a==source;int count=is_source?++src_stats:++dst_stats;
        record(is_source?"source_stat":"destination_stat",count,0,0);
        if((is_source&&count==1&&!strcmp(mode,"source_stat_before"))||(is_source&&count==2&&!strcmp(mode,"source_stat_after"))||(!is_source&&count==1&&!strcmp(mode,"destination_stat"))||(!is_source&&count==3&&!strcmp(mode,"digest_stat_before"))||(!is_source&&count==4&&!strcmp(mode,"digest_stat_after"))){errno=EIO;return -1;}
        long rc=actual(nr,a,b,c,d,e,f);
        if(!rc&&((is_source&&count==2&&!strcmp(mode,"source_extent"))||(!is_source&&count==1&&!strcmp(mode,"destination_extent")))){uint64_t size;memcpy(&size,(unsigned char *)e+40,8);size++;memcpy((unsigned char *)e+40,&size,8);}
        return rc;
    }
    if(nr==SYS_pread64&&(a==source||a==destination)) {
        int is_source=a==source;int count=is_source?++reads:++digests;
        record(is_source?"source_read":"digest_read",count,c,d);
        const char *short_mode=is_source?"read_short":"digest_short";
        const char *intr_mode=is_source?"read_eintr":"digest_eintr";
        const char *once_mode=is_source?"read_eintr_once":"digest_eintr_once";
        const char *error_mode=is_source?"read_error":"digest_error";
        const char *eof_mode=is_source?"read_eof":"digest_eof";
        const char *extra_mode=is_source?"read_extra":"digest_extra";
        if(!strcmp(mode,intr_mode)||(!strcmp(mode,once_mode)&&count==1)){errno=EINTR;return -1;}
        if(!strcmp(mode,error_mode)){errno=EIO;return -1;}
        if(!strcmp(mode,eof_mode))return 0;
        if(!strcmp(mode,extra_mode))return c+1;
        if(!strcmp(mode,short_mode)&&c>3)c=3;
    }
    if(nr==SYS_pwrite64&&a==destination) {
        writes++;record("copy_write",writes,c,d);
        if(!strcmp(mode,"write_eintr")||(!strcmp(mode,"write_eintr_once")&&writes==1)){errno=EINTR;return -1;}
        if(!strcmp(mode,"write_error")){errno=EIO;return -1;}
        if(!strcmp(mode,"write_zero"))return 0;
        if(!strcmp(mode,"write_extra"))return c+1;
        if(!strcmp(mode,"write_short")&&c>3)c=3;
    }
    if(nr==SYS_fcntl&&a==destination) {
        if(b==1033){record("add_seals",1,c,0);if(!strcmp(mode,"seal")){errno=EIO;return -1;}long rc=actual(nr,a,b,c,d,e,f);if(!strcmp(mode,"seal_after")){errno=EIO;return -1;}return rc;}
        if(b==1034){gets++;record("get_seals",gets,0,0);if(!strcmp(mode,"get_seals")){errno=EIO;return -1;}if(!strcmp(mode,"missing_seals"))return 0;long rc=actual(nr,a,b,c,d,e,f);if(!strcmp(mode,"extra_seals")&&rc>=0)rc|=16;return rc;}
    }
    return actual(nr,a,b,c,d,e,f);
}
