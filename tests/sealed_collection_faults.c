/* Original isolated seams over tiny source-root fixtures and sealed host fds. */
#define _GNU_SOURCE
#include <dlfcn.h>
#include <errno.h>
#include <fcntl.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/syscall.h>
#include <unistd.h>
static long (*actual)(long,...);
static int (*actual_close)(int);
static long original=-1,destination=-1;
static int phase=0;
static void record(const char *op,long request,long offset) {
    const char *path=getenv("AESIR_COLLECTION_LOG");if(!path)return;
    FILE *out=fopen(path,"a");if(!out)abort();
    fprintf(out,"{\"op\":\"%s\",\"phase\":%d,\"request\":%ld,\"offset\":%ld}\n",op,phase,request,offset);
    if(fclose(out))abort();
}
int close(int fd) {
    if(!actual_close)actual_close=dlsym(RTLD_NEXT,"close");
    int selected=fd==destination&&destination>=0;
    if(selected)destination=-1;
    int rc=actual_close(fd);
    const char *mode=getenv("AESIR_COLLECTION_FAULT");
    if(selected&&mode&&!strcmp(mode,"close_after")){record("close_after",0,0);errno=EIO;return -1;}
    return rc;
}
static void mutate(const char *mode) {
    const char *path=getenv("AESIR_COLLECTION_PATH");if(!path)abort();
    long fd;
    if(!strcmp(mode,"before_replace")){
        if(actual(SYS_unlinkat,AT_FDCWD,path,0,0,0,0))abort();
        fd=actual(SYS_openat,AT_FDCWD,path,O_RDWR|O_CLOEXEC|O_CREAT,0600,0,0);
    } else fd=actual(SYS_openat,AT_FDCWD,path,O_RDWR|O_CLOEXEC,0,0,0);
    if(fd<0)abort();
    if(!strcmp(mode,"before_same_size")){
        long size=actual(SYS_lseek,fd,0,SEEK_END,0,0,0);unsigned char b=0;
        if(size<=0||actual(SYS_pread64,fd,&b,1,size-1,0,0)!=1)abort();
        b^=64;if(actual(SYS_pwrite64,fd,&b,1,size-1,0,0)!=1)abort();
    } else if(actual(SYS_ftruncate,fd,0,0,0,0,0))abort();
    if(actual(SYS_close,fd,0,0,0,0,0))abort();
    record(mode,0,0);
}
long syscall(long nr,...) {
    va_list ap;va_start(ap,nr);
    long a=va_arg(ap,long),b=va_arg(ap,long),c=va_arg(ap,long);
    long d=va_arg(ap,long),e=va_arg(ap,long),f=va_arg(ap,long);va_end(ap);
    if(!actual)actual=dlsym(RTLD_NEXT,"syscall");
    const char *label=getenv("AESIR_COLLECTION_LABEL"),*mode=getenv("AESIR_COLLECTION_FAULT");
    if(!label||!mode)return actual(nr,a,b,c,d,e,f);
    if(nr==SYS_openat2&&!strcmp((const char *)b,label)){
        record("open_beneath",0,0);
        if(!strcmp(mode,"open")){errno=EACCES;return -1;}
        original=actual(nr,a,b,c,d,e,f);return original;
    }
    if(nr==SYS_memfd_create&&original>=0){
        record("create",0,0);
        if(!strcmp(mode,"create")){errno=ENOMEM;return -1;}
        destination=actual(nr,a,b,c,d,e,f);phase=0;return destination;
    }
    if(nr==SYS_pread64&&(a==original||a==destination)){
        if(a==destination&&d==0)phase++;
        record(a==original?"source_read":"sealed_read",c,d);
        if(a==original&&!strcmp(mode,"read_error")){errno=EIO;return -1;}
        if(a==original&&!strcmp(mode,"read_eof"))return 0;
        if(a==destination&&phase==1&&!strcmp(mode,"copy_digest")){errno=EIO;return -1;}
        if(a==destination&&phase==2&&!strcmp(mode,"parser_digest")){errno=EIO;return -1;}
        if(a==destination&&phase>=3&&!strcmp(mode,"metadata_error")){errno=EIO;return -1;}
        if(!strcmp(mode,"short")&&c>3)c=3;
    }
    if(nr==SYS_pwrite64&&a==destination){
        record("copy_write",c,d);
        if(!strcmp(mode,"write_error")){errno=EIO;return -1;}
        if(!strcmp(mode,"write_zero"))return 0;
    }
    if(nr==SYS_fcntl&&a==destination){
        if(b==F_ADD_SEALS&&!strcmp(mode,"seal")){record("seal",0,0);errno=EIO;return -1;}
        if(b==F_GET_SEALS&&!strcmp(mode,"missing_seals")){record("missing_seals",0,0);return 0;}
    }
    if(nr==SYS_mmap&&e==destination&&!strcmp(mode,"map")){record("map",b,0);errno=ENOMEM;return -1;}
    if(nr==SYS_close&&a==original){
        long rc=actual(nr,a,b,c,d,e,f);original=-1;record("original_close",0,0);
        if(!strncmp(mode,"before_",7))mutate(mode);
        if(!strcmp(mode,"source_close")){errno=EIO;return -1;}
        return rc;
    }
    return actual(nr,a,b,c,d,e,f);
}
