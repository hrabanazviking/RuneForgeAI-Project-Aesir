/* Isolated public UAPI layout oracle, never a production dependency. */
#define _GNU_SOURCE
#include <fcntl.h>
#include <linux/openat2.h>
#include <stddef.h>
#include <stdio.h>
#include <sys/syscall.h>
int main(void) {
    struct open_how how = { .flags = O_RDONLY | O_CLOEXEC | O_NONBLOCK,
                            .mode = 0,
                            .resolve = RESOLVE_BENEATH | RESOLVE_NO_MAGICLINKS };
    printf("{\"size\":%zu,\"alignment\":%zu,\"flags_offset\":%zu,\"mode_offset\":%zu,\"resolve_offset\":%zu,\"openat2\":%d,\"directory\":%d,\"cloexec\":%d,\"nonblock\":%d,\"resolve\":%llu,\"bytes_hex\":\"",
      sizeof(how),_Alignof(struct open_how),offsetof(struct open_how,flags),
      offsetof(struct open_how,mode),offsetof(struct open_how,resolve),
      SYS_openat2,O_DIRECTORY,O_CLOEXEC,O_NONBLOCK,(unsigned long long)how.resolve);
    for (size_t i=0;i<sizeof(how);i++) printf("%02x",((unsigned char *)&how)[i]);
    puts("\"}");
    return 0;
}
