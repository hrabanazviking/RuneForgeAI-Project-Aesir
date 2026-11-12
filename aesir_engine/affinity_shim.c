/* affinity_shim.c — Aesir thread-placement FFI shim (slice A-024).
 *
 * The Mojo stdlib in this toolchain exposes no sched_setaffinity,
 * so core/thread_placement.mojo applies its placement maps through
 * this shim, exactly as core/parallel.mojo rides thread_par.c.
 *
 * Contract:
 *   long aesir_aff_apply(const long *cpus, long n)
 *     Sets the calling thread's affinity to exactly the n CPUs
 *     listed. Returns 0 on success, -1 for invalid arguments
 *     (NULL, n outside [1, 1024], a CPU outside [0, CPU_SETSIZE)),
 *     -2 when sched_setaffinity itself fails. On any failure the
 *     caller's affinity is left as the kernel leaves it after a
 *     failed call (unchanged); the Mojo side raises, never assumes.
 *   long aesir_aff_read(long *out, long cap)
 *     Writes the calling thread's current affinity CPU ids into
 *     out in ascending order and returns how many there are.
 *     Returns -1 for invalid arguments, -2 when sched_getaffinity
 *     fails, -3 when the mask holds more CPUs than cap.
 *
 * Build (mirroring the thread_par staging in the run scripts):
 *   cc -std=c11 -O2 -fPIC -shared affinity_shim.c -o libaesir_aff.so
 */
#define _GNU_SOURCE
#include <sched.h>
#include <stddef.h>

long aesir_aff_apply(const long *cpus, long n) {
    if (!cpus || n < 1 || n > 1024) return -1;
    cpu_set_t set;
    CPU_ZERO(&set);
    for (long i = 0; i < n; i++) {
        if (cpus[i] < 0 || cpus[i] >= CPU_SETSIZE) return -1;
        CPU_SET((int)cpus[i], &set);
    }
    if (sched_setaffinity(0, sizeof(set), &set) != 0) return -2;
    return 0;
}

long aesir_aff_read(long *out, long cap) {
    if (!out || cap < 1) return -1;
    cpu_set_t set;
    CPU_ZERO(&set);
    if (sched_getaffinity(0, sizeof(set), &set) != 0) return -2;
    long count = 0;
    for (int cpu = 0; cpu < CPU_SETSIZE; cpu++) {
        if (CPU_ISSET(cpu, &set)) {
            if (count >= cap) return -3;
            out[count++] = cpu;
        }
    }
    return count;
}
