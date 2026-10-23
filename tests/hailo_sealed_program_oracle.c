/* Original test-only installed-header/kernel oracle. No target device. */
#define _GNU_SOURCE
#include <fcntl.h>
#include <linux/memfd.h>
#include <sys/mman.h>
#include <unistd.h>
#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
_Static_assert(MFD_CLOEXEC==1&&MFD_ALLOW_SEALING==2,"create flags");
_Static_assert(F_ADD_SEALS==1033&&F_GET_SEALS==1034,"seal controls");
_Static_assert((F_SEAL_SEAL|F_SEAL_SHRINK|F_SEAL_GROW|F_SEAL_WRITE)==15,"required seals");
int main(int argc,char **argv) {
    if (argc!=2) return 2;
    size_t n=strlen(argv[1])/2;
    if (strlen(argv[1])%2||n>65536) return 2;
    unsigned char *data=malloc(n?n:1),*copy=malloc(n?n:1);
    if (!data||!copy) return 3;
    for (size_t i=0;i<n;i++) {unsigned x;if (sscanf(argv[1]+i*2,"%2x",&x)!=1) return 2;data[i]=(unsigned char)x;}
    int fd=memfd_create("aesir-program-oracle",MFD_CLOEXEC|MFD_ALLOW_SEALING);
    if (fd<0||pwrite(fd,data,n,0)!=(ssize_t)n||fcntl(fd,F_ADD_SEALS,15)) return 4;
    int seals=fcntl(fd,F_GET_SEALS),flags=fcntl(fd,F_GETFD);
    if (pread(fd,copy,n,0)!=(ssize_t)n||memcmp(data,copy,n)) return 5;
    unsigned char byte=0;
    if (pwrite(fd,&byte,1,0)!=-1||errno!=EPERM) return 6;
    if (ftruncate(fd,(off_t)n+1)!=-1||errno!=EPERM) return 7;
    if (n&& (ftruncate(fd,(off_t)n-1)!=-1||errno!=EPERM)) return 8;
    if (n) {void *p=mmap(NULL,n,PROT_READ|PROT_WRITE,MAP_SHARED,fd,0);if (p!=MAP_FAILED||errno!=EPERM) return 9;}
    printf("{\"seals\":%d,\"fd_flags\":%d,\"hex\":\"",seals,flags);
    for (size_t i=0;i<n;i++) printf("%02x",copy[i]);
    puts("\",\"kernel_refusals\":true}");
    if (close(fd)) return 10;
    free(data);free(copy);return 0;
}
