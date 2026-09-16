#define _GNU_SOURCE

#include <dlfcn.h>
#include <errno.h>
#include <fcntl.h>
#include <limits.h>
#include <signal.h>
#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/syscall.h>
#include <sys/types.h>
#include <unistd.h>

/*
 * Test-only LD_PRELOAD shim for the native catalog crash harness.
 *
 * The shim observes the exact libc calls used by storage.mojo and kills the
 * writer only after the selected successful durability boundary. Direct
 * syscalls write the marker so the probe cannot recursively trigger itself.
 */

static int (*next_fsync)(int);
static int (*next_rename)(const char *, const char *);

static const char *crash_stage;
static const char *crash_marker;
static char catalog_path[PATH_MAX];
static char staged_prefix[PATH_MAX];
static char root_path[PATH_MAX];
static size_t staged_prefix_length;

static void resolve_symbols(void) {
    next_fsync = dlsym(RTLD_NEXT, "fsync");
    next_rename = dlsym(RTLD_NEXT, "rename");

    crash_stage = getenv("AESIR_CRASH_STAGE");
    crash_marker = getenv("AESIR_CRASH_MARKER");
    const char *root = getenv("AESIR_CRASH_ROOT");
    if (root == NULL || crash_stage == NULL || crash_marker == NULL) {
        crash_stage = NULL;
        return;
    }

    int root_written = snprintf(root_path, sizeof(root_path), "%s", root);
    int catalog_written = snprintf(
        catalog_path, sizeof(catalog_path), "%s/catalog.v1", root
    );
    int prefix_written = snprintf(
        staged_prefix, sizeof(staged_prefix), "%s/.catalog.tmp.", root
    );
    if (root_written < 1 || catalog_written < 1 || prefix_written < 1 ||
        (size_t)root_written >= sizeof(root_path) ||
        (size_t)catalog_written >= sizeof(catalog_path) ||
        (size_t)prefix_written >= sizeof(staged_prefix)) {
        crash_stage = NULL;
        return;
    }
    staged_prefix_length = (size_t)prefix_written;
}

__attribute__((constructor)) static void initialize_shim(void) {
    resolve_symbols();
}

static int fd_path(int fd, char *destination, size_t capacity) {
    char proc_path[64];
    int written = snprintf(proc_path, sizeof(proc_path), "/proc/self/fd/%d", fd);
    if (written < 1 || (size_t)written >= sizeof(proc_path)) {
        return 0;
    }
    ssize_t length = readlink(proc_path, destination, capacity - 1);
    if (length < 0 || (size_t)length >= capacity) {
        return 0;
    }
    destination[length] = '\0';
    return 1;
}

static int fd_is_staged_catalog(int fd) {
    char path[PATH_MAX];
    return fd_path(fd, path, sizeof(path)) &&
        strncmp(path, staged_prefix, staged_prefix_length) == 0;
}

static int fd_is_store_root(int fd) {
    char path[PATH_MAX];
    return fd_path(fd, path, sizeof(path)) && strcmp(path, root_path) == 0;
}

static void crash_now(void) {
    int marker_fd = (int)syscall(
        SYS_openat,
        AT_FDCWD,
        crash_marker,
        O_WRONLY | O_CREAT | O_TRUNC | O_CLOEXEC,
        0600
    );
    if (marker_fd >= 0) {
        size_t length = strlen(crash_stage);
        (void)syscall(SYS_write, marker_fd, crash_stage, length);
        (void)syscall(SYS_fsync, marker_fd);
        (void)syscall(SYS_close, marker_fd);
    }
    (void)syscall(SYS_kill, syscall(SYS_getpid), SIGKILL);
    syscall(SYS_exit_group, 137);
}

int fsync(int fd) {
    if (next_fsync == NULL) {
        errno = ENOSYS;
        return -1;
    }
    /* Reaching the staged-file fsync proves the complete write loop returned. */
    if (crash_stage != NULL && strcmp(crash_stage, "staged_write") == 0 &&
        fd_is_staged_catalog(fd)) {
        crash_now();
    }
    int result = next_fsync(fd);
    if (result == 0 && crash_stage != NULL) {
        if (strcmp(crash_stage, "staged_fsync") == 0 &&
            fd_is_staged_catalog(fd)) {
            crash_now();
        }
        if (strcmp(crash_stage, "directory_fsync") == 0 &&
            fd_is_store_root(fd)) {
            crash_now();
        }
    }
    return result;
}

int rename(const char *old_path, const char *new_path) {
    if (next_rename == NULL) {
        errno = ENOSYS;
        return -1;
    }
    int result = next_rename(old_path, new_path);
    if (result == 0 && crash_stage != NULL &&
        strcmp(crash_stage, "rename") == 0 &&
        strstr(old_path, "/.catalog.tmp.") != NULL) {
        char resolved_new[PATH_MAX];
        if (realpath(new_path, resolved_new) != NULL &&
            strcmp(resolved_new, catalog_path) == 0) {
            crash_now();
        }
    }
    return result;
}
