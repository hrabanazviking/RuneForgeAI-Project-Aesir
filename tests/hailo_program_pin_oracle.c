/* Original installed-header/kernel permission oracle; no device or DMA. */
#define _GNU_SOURCE
#include <fcntl.h>
#include <linux/memfd.h>
#include <sys/mman.h>
#include <sys/resource.h>
#include <sys/wait.h>
#include <unistd.h>
#include <signal.h>
#include <errno.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
int main(int argc,char **argv) {
    if (argc!=3) return 2;
    size_t n=(size_t)strtoul(argv[2],NULL,10);
    int writable=!strcmp(argv[1],"sealed-cow");
    if ((!writable&&strcmp(argv[1],"sealed-ro"))||(n!=70&&n!=4097&&n!=16385)) return 2;
    long page=sysconf(_SC_PAGESIZE);
    if (page<=0||page>1048576||(page&(page-1))) return 3;
    size_t extent=(n+(size_t)page-1)/(size_t)page*(size_t)page;
    unsigned char *data=malloc(n),*copy=malloc(n);
    if (!data||!copy) return 3;
    for (size_t i=0;i<n;i++) data[i]=(unsigned char)(i*37+11);
    int fd=memfd_create("aesir-pin-oracle",MFD_CLOEXEC|MFD_ALLOW_SEALING);
    if (fd<0||pwrite(fd,data,n,0)!=(ssize_t)n||fcntl(fd,F_ADD_SEALS,15)) return 4;
    void *view=mmap(NULL,extent,PROT_READ|(writable?PROT_WRITE:0),MAP_PRIVATE,fd,0);
    if (view==MAP_FAILED||(uintptr_t)view%(uintptr_t)page||memcmp(view,data,n)) return 5;
    if (writable) {
        ((unsigned char *)view)[0]^=1;
        if (pread(fd,copy,n,0)!=(ssize_t)n||memcmp(copy,data,n)) return 6;
        ((unsigned char *)view)[0]^=1;
    } else {
        struct rlimit limit={0,0};
        if (setrlimit(RLIMIT_CORE,&limit)) return 7;
        pid_t pid=fork();
        if (pid<0) return 7;
        if (!pid) {((volatile unsigned char *)view)[0]^=1;_exit(99);}
        int status=0;
        if (waitpid(pid,&status,0)!=pid||!WIFSIGNALED(status)||WTERMSIG(status)!=SIGSEGV) return 8;
    }
    if (memcmp(view,data,n)) return 9;
    if (pwrite(fd,data,1,0)!=-1||errno!=EPERM) return 10;
    if (ftruncate(fd,(off_t)n+1)!=-1||errno!=EPERM) return 11;
    if (ftruncate(fd,(off_t)n-1)!=-1||errno!=EPERM) return 12;
    if (mmap(NULL,extent,PROT_READ|PROT_WRITE,MAP_SHARED,fd,0)!=MAP_FAILED||errno!=EPERM) return 13;
    if (munmap(view,extent)||pread(fd,copy,n,0)!=(ssize_t)n||memcmp(copy,data,n)) return 14;
    if (fcntl(fd,F_GET_SEALS)!=15||fcntl(fd,F_GETFD)!=1||close(fd)) return 15;
    printf("{\"profile\":\"%s\",\"logical_bytes\":%zu,\"page_size\":%ld,\"mapping_bytes\":%zu,\"permission_verified\":true,\"backing_unchanged\":true,\"kernel_refusals\":4,\"hex\":\"",argv[1],n,page,extent);
    for (size_t i=0;i<n;i++) printf("%02x",copy[i]);
    puts("\"}");free(data);free(copy);return 0;
}
