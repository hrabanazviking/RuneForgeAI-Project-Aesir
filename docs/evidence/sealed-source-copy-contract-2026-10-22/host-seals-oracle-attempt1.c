/* Original test of installed Linux userspace fields; no kernel code copied. */
#define _GNU_SOURCE
#include <errno.h>
#include <linux/fcntl.h>
#include <linux/memfd.h>
#include <linux/stat.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
#include <sys/syscall.h>
#include <unistd.h>
#define CHECK(x) do { if (!(x)) { fprintf(stderr,"line%d errno%d\n",__LINE__,errno);exit(1); } } while(0)
int main(void) {
    const int mask=F_SEAL_SEAL|F_SEAL_SHRINK|F_SEAL_GROW|F_SEAL_WRITE;
    printf("{\"abi\":[%ld,%ld,%u,%u,%d,%d,%d],\"cases\":[",(long)SYS_memfd_create,(long)SYS_fcntl,MFD_CLOEXEC,MFD_ALLOW_SEALING,F_ADD_SEALS,F_GET_SEALS,mask);
    const size_t sizes[]={0,17,8193};
    for (size_t test=0;test<3;test++) {
        size_t n=sizes[test];unsigned char *raw=malloc(n?n:1),*out=malloc(n?n:1);CHECK(raw&&out);
        for(size_t i=0;i<n;i++)raw[i]=(unsigned char)(i*37+11);
        long fd=syscall(SYS_memfd_create,"aesir-seal-qualification",MFD_CLOEXEC|MFD_ALLOW_SEALING);CHECK(fd>=0);
        CHECK(syscall(SYS_fcntl,fd,F_GETFD,0)&FD_CLOEXEC);
        CHECK(syscall(SYS_fcntl,fd,F_GET_SEALS,0)==0);
        CHECK(pwrite((int)fd,raw,n,0)==(ssize_t)n);
        if(n) {
            void *write_map=mmap(NULL,n,PROT_READ|PROT_WRITE,MAP_SHARED,(int)fd,0);CHECK(write_map!=MAP_FAILED);
            errno=0;CHECK(syscall(SYS_fcntl,fd,F_ADD_SEALS,mask)==-1&&errno==EBUSY);
            CHECK(munmap(write_map,n)==0);
        }
        CHECK(syscall(SYS_fcntl,fd,F_ADD_SEALS,mask)==0);
        CHECK(syscall(SYS_fcntl,fd,F_GET_SEALS,0)==mask);
        struct statx st;memset(&st,0,sizeof(st));
        CHECK(syscall(SYS_statx,fd,"",AT_EMPTY_PATH,STATX_TYPE|STATX_SIZE,&st)==0);
        CHECK((st.stx_mask&(STATX_TYPE|STATX_SIZE))==(STATX_TYPE|STATX_SIZE));
        CHECK((st.stx_mode&0170000)==0100000&&st.stx_size==n);
        CHECK(pread((int)fd,out,n,0)==(ssize_t)n&&!memcmp(raw,out,n));
        errno=0;CHECK(pwrite((int)fd,"X",1,0)==-1&&errno==EPERM);
        errno=0;CHECK(ftruncate((int)fd,(off_t)n+1)==-1&&errno==EPERM);
        if(n) {errno=0;CHECK(ftruncate((int)fd,(off_t)n-1)==-1&&errno==EPERM);}
        errno=0;CHECK(syscall(SYS_fcntl,fd,F_ADD_SEALS,F_SEAL_WRITE)==-1&&errno==EPERM);
        if(n) {
            errno=0;void *map=mmap(NULL,n,PROT_READ|PROT_WRITE,MAP_SHARED,(int)fd,0);CHECK(map==MAP_FAILED&&errno==EPERM);
            map=mmap(NULL,n,PROT_READ,MAP_SHARED,(int)fd,0);CHECK(map!=MAP_FAILED&&!memcmp(map,raw,n));CHECK(munmap(map,n)==0);
        }
        CHECK(pread((int)fd,out,n,0)==(ssize_t)n&&!memcmp(raw,out,n));
        printf("%s{\"bytes\":%zu,\"hex\":\"",test?",":"",n);
        for(size_t i=0;i<n;i++)printf("%02x",out[i]);printf("\",\"seals\":%d}",mask);
        CHECK(close((int)fd)==0);free(raw);free(out);
    }
    puts("]}");return 0;
}
