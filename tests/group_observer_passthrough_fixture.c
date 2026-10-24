/* Independent test-only six-argument gateway/errno fixture. /dev/null only. */
#define _GNU_SOURCE
#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#include <unistd.h>
#include <sys/syscall.h>

int main(void) {
    errno = E2BIG;
    long fd = syscall(SYS_openat, (long)AT_FDCWD, "/dev/null", (long)(O_RDWR | O_CLOEXEC), 0L, 0L, 0L);
    int open_errno = errno;
    if (fd < 0) return 2;
    errno = EDOM;
    long bad = syscall(SYS_ioctl, fd, 0L, 0L, 0L, 0L, 0L);
    int bad_errno = errno;
    errno = ERANGE;
    long close_result = syscall(SYS_close, fd, 0L, 0L, 0L, 0L, 0L);
    int close_errno = errno;
    errno = EBUSY;
    long missing = syscall(SYS_close, -1L, 0L, 0L, 0L, 0L, 0L);
    int missing_errno = errno;
    printf("%ld %d %ld %d %ld %d %ld %d\n", fd, open_errno, bad, bad_errno,
           close_result, close_errno, missing, missing_errno);
    return !(open_errno == E2BIG && bad == -1 && bad_errno == ENOTTY &&
             close_result == 0 && close_errno == ERANGE && missing == -1 && missing_errno == EBADF);
}
