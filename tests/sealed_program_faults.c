/* Original isolated host-output fault seams. Never loaded by production. */
#define _GNU_SOURCE
#include <dlfcn.h>
#include <errno.h>
#include <stdarg.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/syscall.h>
#include <linux/stat.h>
static long (*actual)(long,...);
static int (*actual_close)(int);
static long destination=-1;
static int creations,active,reads,writes,stats,gets;
static void record(const char *op,long fd,long count,long offset) {
    const char *path=getenv("AESIR_PROGRAM_FAULT_LOG");
    if (!path) return;
    FILE *out=fopen(path,"a");
    if (!out) abort();
    fprintf(out,"{\"op\":\"%s\",\"fd\":%ld,\"count\":%ld,\"offset\":%ld,\"active\":%d}\n",op,fd,count,offset,active);
    if (fclose(out)) abort();
}
int close(int fd) {
    if (!actual_close) actual_close=dlsym(RTLD_NEXT,"close");
    int target=fd==destination&&destination>=0;
    if (target) record("close",fd,0,0);
    int rc=actual_close(fd);
    const char *mode=getenv("AESIR_PROGRAM_FAULT_MODE");
    if (target) destination=-1;
    if (target&&active&&mode&&!strcmp(mode,"close_after")) {errno=EIO;return -1;}
    return rc;
}
long syscall(long nr,...) {
    va_list ap;va_start(ap,nr);
    long a=va_arg(ap,long),b=va_arg(ap,long),c=va_arg(ap,long);
    long d=va_arg(ap,long),e=va_arg(ap,long),f=va_arg(ap,long);va_end(ap);
    if (!actual) actual=dlsym(RTLD_NEXT,"syscall");
    const char *mode=getenv("AESIR_PROGRAM_FAULT_MODE");
    if (!mode) return actual(nr,a,b,c,d,e,f);
    if (nr==SYS_memfd_create&&!strcmp((const char *)a,"aesir-program-payload")) {
        active=++creations==1;reads=writes=stats=gets=0;record("create",-1,b,0);
        if (active&&!strcmp(mode,"create")) {errno=ENOMEM;return -1;}
        if (active&&!strcmp(mode,"large_fd")) return 2147483648L;
        destination=actual(nr,a,b,c,d,e,f);record("created",destination,b,0);return destination;
    }
    if (a!=destination||destination<0) return actual(nr,a,b,c,d,e,f);
    if (nr==SYS_statx) {
        stats++;record("stat",a,stats,0);
        if (active&&!strcmp(mode,"stat_error")) {errno=EIO;return -1;}
        long rc=actual(nr,a,b,c,d,e,f);
        if (!rc&&active&&!strcmp(mode,"stat_extent")) ((struct statx *)e)->stx_size++;
        return rc;
    }
    if (nr==SYS_pwrite64||nr==SYS_pread64) {
        int writing=nr==SYS_pwrite64;int n=writing?++writes:++reads;
        record(writing?"write":"read",a,c,d);
        if (active) {
            const char *prefix=writing?"write":"read";char label[64];
#define MODE(suffix) (snprintf(label,sizeof(label),"%s_%s",prefix,suffix),!strcmp(mode,label))
            if (MODE("eintr")||(MODE("eintr_once")&&n==1)) {errno=EINTR;return -1;}
            if (MODE("error")) {errno=EIO;return -1;}
            if (MODE("zero")) return 0;
            if (MODE("extra")) return c+1;
            if (MODE("short")&&c>3) c=3;
#undef MODE
        }
        long rc=actual(nr,a,b,c,d,e,f);
        if (active&&!writing&&rc>0&&!strcmp(mode,"read_corrupt")) ((unsigned char *)b)[0]^=1;
        return rc;
    }
    if (nr==SYS_fcntl) {
        record("fcntl",a,b,c);
        if (b==1033&&active&&!strcmp(mode,"seal")) {errno=EIO;return -1;}
        if (b==1034) {
            gets++;
            if (active&&(!strcmp(mode,"get_seals")||(!strcmp(mode,"get_seals_late")&&gets>1))) {errno=EIO;return -1;}
            if (active&&!strcmp(mode,"missing_seals")) return 0;
        }
        if (b==1&&active&&!strcmp(mode,"get_flags")) {errno=EIO;return -1;}
        if (b==1&&active&&!strcmp(mode,"missing_flags")) return 0;
        long rc=actual(nr,a,b,c,d,e,f);
        if (b==1033&&active&&!strcmp(mode,"seal_after")) {errno=EIO;return -1;}
        return rc;
    }
    return actual(nr,a,b,c,d,e,f);
}
