/* Isolated installed public syscall/type facts only. */
#define _GNU_SOURCE
#include <stdio.h>
#include <sys/syscall.h>
#include <unistd.h>
int main(void) {
    printf("{\"pread64_syscall\":%d,\"off_t_bytes\":%zu,\"int_bytes\":%zu}\n",SYS_pread64,sizeof(off_t),sizeof(int));
    return 0;
}
