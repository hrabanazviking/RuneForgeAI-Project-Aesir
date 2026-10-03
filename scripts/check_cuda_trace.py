#!/usr/bin/env python3
"""Read-only, bounded admission of an Nsight 2023 CUDA SQLite export."""
import argparse
from contextlib import closing
from collections import defaultdict
import json
import os
from pathlib import Path
import sqlite3
import stat

MAX_BYTES = 512 * 1024 * 1024
MAX_ROWS = 2_000_000


def integer(value, low=0, high=2**63 - 1):
    if type(value) is not int or not low <= value <= high:
        raise ValueError("Invalid integer in CUDA trace")
    return value


def union_ns(intervals):
    total = 0
    previous = None
    for start, end in sorted(intervals):
        if previous is None or start > previous:
            total += end - start
        elif end > previous:
            total += end - previous
        previous = max(previous or 0, end)
    return total


def analyze(path, expected_executable="aesir", *, expected_pid=None, nvtx_range=None):
    """Accept concrete tables only, one actual CUDA PID, matched kernel launches.

    The descriptor-backed immutable URI avoids symlink/replacement races on Linux.
    Export must be closed, without WAL/journal sidecars; query_only and an authorizer
    deny writes and executable extensions. No database-provided SQL is executed.
    """
    path = Path(path).absolute()
    for suffix in ("-wal", "-shm", "-journal"):
        if Path(str(path) + suffix).exists():
            raise ValueError("Export has active journal sidecars")
    fd = os.open(path, os.O_RDONLY | os.O_NONBLOCK | os.O_NOFOLLOW)
    try:
        info = os.fstat(fd)
        if not stat.S_ISREG(info.st_mode) or not 100 <= info.st_size <= MAX_BYTES:
            raise ValueError("Expected bounded regular SQLite export")
        with closing(sqlite3.connect(f"file:/proc/self/fd/{fd}?mode=ro&immutable=1", uri=True)) as db:
            db.execute("PRAGMA query_only=ON")
            db.execute("PRAGMA trusted_schema=OFF")
            db.set_authorizer(lambda action, *_: sqlite3.SQLITE_OK if action in
                              (sqlite3.SQLITE_SELECT, sqlite3.SQLITE_READ) else sqlite3.SQLITE_DENY)
            # Time-bound the SQLite VM, including malformed schema/query work.
            import time
            deadline = time.monotonic() + 30
            db.set_progress_handler(lambda: int(time.monotonic() > deadline), 1000)
            tables = dict(db.execute("SELECT name,type FROM sqlite_master"))

            def rows(table, columns, required=True):
                if table not in tables:
                    if required:
                        raise ValueError(f"Missing trace table {table}")
                    return []
                if tables[table] != "table":
                    raise ValueError("Trace views are not admitted")
                # All identifiers below are hardcoded, never sourced from input.
                result = db.execute(f'SELECT {columns} FROM "{table}" LIMIT {MAX_ROWS + 1}').fetchall()
                if len(result) > MAX_ROWS:
                    raise ValueError("Trace row limit exceeded")
                return result

            metadata = rows("META_DATA_EXPORT", "name,value")
            if len(metadata) != len(dict(metadata)):
                raise ValueError("Duplicate export metadata")
            meta = dict(metadata)
            if meta.get("EXPORT_PRODUCT_NAME") != "NVIDIA Nsight Systems" or not str(
                    meta.get("EXPORT_PRODUCT_VERSION", "")).startswith("2023."):
                raise ValueError("Unsupported exporter; validate its schema separately")
            strings = {}
            for key, value in rows("StringIds", "id,value"):
                integer(key)
                if key in strings or type(value) is not str or not 0 <= len(value) <= 16384:
                    raise ValueError("Invalid string dictionary")
                strings[key] = value
            if len(strings) > 16384 or sum(map(len, strings.values())) > 8 * 1024 * 1024:
                raise ValueError("String dictionary limit exceeded")

            def name(key):
                integer(key)
                if key not in strings or not strings[key]:
                    raise ValueError("Unknown trace string ID")
                return strings[key]

            analysis = rows("ANALYSIS_DETAILS", "duration,startTime,stopTime")
            if len(analysis) != 1:
                raise ValueError("Expected one complete trace interval")
            duration, begin, stop = map(integer, analysis[0])
            if not begin < stop or duration != stop - begin:
                raise ValueError("Invalid trace interval")

            def interval(start, end):
                integer(start); integer(end)
                if not begin <= start < end <= stop:
                    raise ValueError("CUDA interval outside capture")
                return start, end

            kernels = rows("CUPTI_ACTIVITY_KIND_KERNEL",
                           "start,end,deviceId,contextId,streamId,correlationId,globalPid,shortName")
            if not kernels:
                raise ValueError("No actual CUDA kernels")
            pids = {integer(k[6], 1) for k in kernels}
            devices = {integer(k[2]) for k in kernels}
            if len(pids) != 1 or len(devices) != 1:
                raise ValueError("Expected one owned CUDA PID/device")
            pid = pids.pop()
            process = [r for r in rows("PROCESSES", "globalPid,pid,name") if r[0] == pid]
            if len(process) != 1 or type(process[0][2]) is not str or Path(
                    process[0][2]).name != expected_executable:
                raise ValueError("CUDA executable identity mismatch")
            integer(process[0][1], 1)
            if expected_pid is not None and integer(expected_pid, 1) != process[0][1]:
                raise ValueError("CUDA process differs from native probe PID")
            owned_range = None
            if nvtx_range is not None:
                if type(nvtx_range) is not str or not 1 <= len(nvtx_range) <= 128:
                    raise ValueError("Invalid expected NVTX range")
                candidates = []
                for start, end, kind, tid, end_tid, text, text_id in rows(
                        "NVTX_EVENTS", "start,end,eventType,globalTid,endGlobalTid,text,textId"):
                    if (text is not None and (type(text) is not str or len(text) > 16384)) or (
                            text is not None and text_id is not None):
                        raise ValueError("Invalid or ambiguous NVTX label")
                    label = text if text_id is None else name(text_id)
                    if label == nvtx_range:
                        # Nsight2023 event type59 is a completed same-thread push/pop.
                        if kind != 59 or end is None or end_tid not in (None, tid):
                            raise ValueError("Incomplete or foreign-thread NVTX range")
                        interval(start, end); integer(tid, 1)
                        if (tid >> 24) << 24 != pid:
                            raise ValueError("Foreign NVTX process")
                        candidates.append((start, end, tid))
                if len(candidates) != 1:
                    raise ValueError("Expected exactly one named NVTX prefill range")
                owned_range = candidates[0]
            gpu = [r for r in rows("TARGET_INFO_GPU", "id,name,computeMajor,computeMinor,totalMemory")
                   if r[0] in devices]
            if len(gpu) != 1 or type(gpu[0][1]) is not str:
                raise ValueError("Missing GPU identity")
            integer(gpu[0][2]); integer(gpu[0][3]); integer(gpu[0][4], 1)
            groups = defaultdict(lambda: {"count": 0, "total_ns": 0})
            api_groups = defaultdict(lambda: {"count": 0, "total_ns": 0, "return_values": {}})
            launches = {}
            selected_launches = set()
            for start, end, tid, correlation, key, status in rows(
                    "CUPTI_ACTIVITY_KIND_RUNTIME", "start,end,globalTid,correlationId,nameId,returnValue"):
                interval(start, end)
                integer(tid, 1); integer(correlation); integer(status)
                if (tid >> 24) << 24 != pid:
                    raise ValueError("Foreign CUDA API process")
                label = name(key)
                selected = owned_range is None or (
                    tid == owned_range[2] and owned_range[0] <= start < end <= owned_range[1])
                if selected:
                    group = api_groups[label]
                    group["count"] += 1; group["total_ns"] += end - start
                    returns = group["return_values"]
                    returns[str(status)] = returns.get(str(status), 0) + 1
                if "LaunchKernel" in label:
                    if correlation in launches or status != 0:
                        raise ValueError("Duplicate or failed CUDA kernel launch")
                    if owned_range is not None and start < owned_range[1] and end > owned_range[0] and not selected:
                        raise ValueError("Kernel launch crosses owned NVTX thread/range")
                    launches[correlation] = start
                    if selected: selected_launches.add(correlation)
            active = []
            matched = set()
            kernel_intervals = []
            for start, end, device, context, stream, correlation, owner, key in kernels:
                interval(start, end)
                integer(context, 1); integer(stream); integer(correlation, 1)
                kernel_name = name(key)
                if correlation not in launches or correlation in matched or launches[correlation] > start:
                    raise ValueError("Unmatched, repeated or reversed kernel correlation")
                matched.add(correlation)
                if correlation not in selected_launches:
                    if owned_range is not None and start < owned_range[1] and end > owned_range[0]:
                        raise ValueError("Unselected kernel overlaps owned NVTX range")
                    continue
                if owned_range is not None and not owned_range[0] <= start < end <= owned_range[1]:
                    raise ValueError("Kernel outside synchronized NVTX range")
                group = groups[kernel_name]
                group["count"] += 1; group["total_ns"] += end - start
                kernel_intervals.append((start, end))
                active.append((start, end))
            if matched != set(launches):
                raise ValueError("Incomplete launch/kernel trace")
            copies = defaultdict(lambda: {"count": 0, "bytes": 0, "total_ns": 0})
            for start, end, owner, size, kind in rows("CUPTI_ACTIVITY_KIND_MEMCPY",
                                                     "start,end,globalPid,bytes,copyKind", False):
                interval(start, end); integer(size, 1); integer(kind)
                if owner != pid:
                    raise ValueError("Foreign CUDA copy process")
                if owned_range is not None and not owned_range[0] <= start < end <= owned_range[1]:
                    if start < owned_range[1] and end > owned_range[0]:
                        raise ValueError("Copy crosses synchronized NVTX range")
                    continue
                group = copies[str(kind)]
                group["count"] += 1; group["bytes"] += size; group["total_ns"] += end - start
                active.append((start, end))
            for start, end, owner in rows("CUPTI_ACTIVITY_KIND_MEMSET", "start,end,globalPid", False):
                interval(start, end)
                if owner != pid:
                    raise ValueError("Foreign CUDA memset process")
                if owned_range is not None and not owned_range[0] <= start < end <= owned_range[1]:
                    if start < owned_range[1] and end > owned_range[0]:
                        raise ValueError("Memset crosses synchronized NVTX range")
                    continue
                active.append((start, end))
            if not kernel_intervals:
                raise ValueError("No actual kernels inside owned scope")
            first = min(s for s, _ in kernel_intervals)
            last = max(e for _, e in kernel_intervals)
            clipped = [(max(s, first), min(e, last)) for s, e in active if s < last and e > first]
            busy = union_ns(clipped)
            return {"schema": 1, "exporter": meta["EXPORT_PRODUCT_VERSION"],
                    "process": {"pid": process[0][1], "name": expected_executable},
                    "gpu": {"name": gpu[0][1], "compute": f"{gpu[0][2]}.{gpu[0][3]}", "bytes": gpu[0][4]},
                    "capture_ns": duration, "kernel_count": len(kernel_intervals),
                    "scope": "complete_capture" if owned_range is None else "owned_nvtx_prefill",
                    "complete_capture_kernel_count": len(kernels),
                    "excluded_kernel_count": len(kernels) - len(kernel_intervals),
                    "kernel_window_ns": last - first, "gpu_busy_in_kernel_window_ns": busy,
                    "uncovered_in_kernel_window_ns": last - first - busy,
                    "kernel_groups": dict(sorted(groups.items(), key=lambda p: -p[1]["total_ns"])),
                    "api_groups": dict(sorted(api_groups.items(), key=lambda p: -p[1]["total_ns"])),
                    "copies_by_kind": dict(copies),
                    "owned_nvtx_range": None if owned_range is None else {
                        "name": nvtx_range, "start_ns": owned_range[0], "end_ns": owned_range[1],
                        "duration_ns": owned_range[1] - owned_range[0], "global_tid": owned_range[2]},
                    "limits": "Profiled timings only. Optional named range selects observed prefill launches after full-capture validation. API synchronization overlaps GPU work; do not sum them. Uncovered timeline is observed, not proven CPU launch delay. No per-layer projection labels or quality/speed-lead certification."}
    finally:
        os.close(fd)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("export", type=Path)
    parser.add_argument("--output", type=Path, required=True)
    options = parser.parse_args()
    with options.output.open("x", encoding="utf-8") as stream:
        try:
            result = {"passed": True, "trace": analyze(options.export)}
        except (ValueError, OSError, sqlite3.Error) as error:
            result = {"passed": False, "error": str(error)}
        json.dump(result, stream, indent=2); stream.write("\n")
    return 0 if result["passed"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
