#!/usr/bin/env python3
"""J-023 bounded browser-class co-runner (SIMULATED load, named and capped).

Simulates a busy desktop browser's machine footprint, deliberately bounded:
  * N CPU spinner workers (default 4 of 16 logical CPUs = 25%) doing
    floating-point churn -- a busy-tab / JS-heavy page class of load.
  * One memory holder allocating a capped anonymous region (default
    10 GiB), touching every page so it is genuinely resident, which
    pressures the page cache the streamed GGUF reads through.

Safety bounds (hard): worker count and holder bytes are fixed arguments,
printed at start; the holder refuses to allocate if MemAvailable at
start is below holder + 12 GiB reserve; the process exits cleanly on
SIGTERM/SIGINT and the driver verifies it is gone afterwards. It never
forks beyond the stated workers and never grows after the initial fill.
"""
import os
import signal
import sys
import time

_stop = False


def _handle(signum, frame):
    global _stop
    _stop = True


def mem_available_bytes():
    with open("/proc/meminfo") as f:
        for line in f:
            if line.startswith("MemAvailable:"):
                return int(line.split()[1]) * 1024
    return 0


def spinner():
    x = 1.0000001
    while not _stop:
        for _ in range(200000):
            x = x * 1.0000001 + 0.0000001
            if x > 2.0:
                x = 1.0000001
    return x


def main():
    workers = int(sys.argv[1]) if len(sys.argv) > 1 else 4
    holder_gib = float(sys.argv[2]) if len(sys.argv) > 2 else 10.0
    holder_bytes = int(holder_gib * (1 << 30))
    reserve = 12 * (1 << 30)
    avail = mem_available_bytes()
    print(f"CORUNNER workers={workers} holder_bytes={holder_bytes} "
          f"mem_available_at_start={avail}", flush=True)
    if avail < holder_bytes + reserve:
        print("CORUNNER REFUSED: MemAvailable below holder + 12 GiB reserve",
              flush=True)
        return 2
    signal.signal(signal.SIGTERM, _handle)
    signal.signal(signal.SIGINT, _handle)
    # Fill the holder first (touch every page), then fork spinners.
    holder = bytearray(holder_bytes)
    page = 4096
    for off in range(0, holder_bytes, page):
        holder[off] = 1
    print(f"CORUNNER holder filled rss_target={holder_bytes}", flush=True)
    pids = []
    for _ in range(workers):
        pid = os.fork()
        if pid == 0:
            try:
                spinner()
            finally:
                os._exit(0)
        pids.append(pid)
    print(f"CORUNNER spinners={pids}", flush=True)
    try:
        while not _stop:
            time.sleep(0.5)
            # Re-touch a slice of the holder so pages stay hot/resident.
            for off in range(0, holder_bytes, 256 * 1024 * 1024):
                holder[off] = (holder[off] + 1) & 0xFF
    finally:
        for pid in pids:
            try:
                os.kill(pid, signal.SIGTERM)
            except ProcessLookupError:
                pass
        for pid in pids:
            try:
                os.waitpid(pid, 0)
            except ChildProcessError:
                pass
        print("CORUNNER stopped cleanly", flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
