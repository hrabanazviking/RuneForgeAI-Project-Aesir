"""GPU soak accounting (A-077): one hour of continuous decode
on the GPU path, judged on evidence, not impressions.

Acceptance (roadmap A-077): soak log with memory + thermal
traces; zero errors; RSS slope approximately 0.

This module is the pure accounting half of the soak. The
stress half lives in tests/bench_gpu_soak_a077.mojo, which
loads the A-067 real-model fixture on the Vulkan GPU path
(A-066 decode loop) and free-runs greedy decode continuously
for a caller-fixed duration, printing A077_* progress lines.
An external sampler (hidden_files/run_a077_soak.sh) records
the memory + thermal trace (process RSS, GTT/VRAM use,
MemAvailable, amdgpu hwmon temperature + power, load) at a
fixed 10 s cadence into a TSV beside the soak log.

Verdict law for this slice:
- duration must reach SOAK_REQUIRED_SECONDS (3600 s of
  decode; load/compile time does not count - the driver
  starts its clock after the model is loaded and the prompt
  is fed);
- errors must be exactly zero (a raised driver or a
  live-buffer baseline drift at close counts as an error;
  non-finite logit lanes sanitized under the A-067 policy
  are reported in the DONE line, not counted as errors);
- the least-squares RSS slope over the decode-phase samples
  (sampler rows at or after the driver's start mark, so the
  one-off compiler/loader processes never enter the fit)
  must sit within +/- SOAK_RSS_TOLERANCE_BYTES_PER_HOUR
  (16 MiB/h): "slope approximately 0" made a number BEFORE
  the run, not a judgement made after it.
"""
from std.math import abs as f64_abs


comptime SOAK_REQUIRED_SECONDS = 3600
comptime SOAK_RSS_TOLERANCE_BYTES_PER_HOUR = 16 * 1024 * 1024

comptime SOAK_PASS = 0
comptime SOAK_SHORT = 1
comptime SOAK_ERRORS = 2
comptime SOAK_LEAK = 3


def soak_verdict_name(code: Int) -> String:
    if code == SOAK_PASS:
        return String("pass")
    if code == SOAK_SHORT:
        return String("short")
    if code == SOAK_ERRORS:
        return String("errors")
    if code == SOAK_LEAK:
        return String("leak")
    return String("unknown")


def soak_slope_bytes_per_hour(times_s: List[Int], rss_bytes: List[Int]) -> Float64:
    """Least-squares slope of RSS against time, in bytes/hour.

    Returns 0.0 for fewer than two samples or a zero time
    span (no evidence of drift is not a leak claim; the
    duration leg of the verdict handles short runs)."""
    var n = len(times_s)
    if n < 2 or len(rss_bytes) != n:
        return Float64(0.0)
    var mt = Float64(0.0)
    var mr = Float64(0.0)
    for i in range(n):
        mt += Float64(times_s[i])
        mr += Float64(rss_bytes[i])
    mt /= Float64(n)
    mr /= Float64(n)
    var num = Float64(0.0)
    var den = Float64(0.0)
    for i in range(n):
        var dt = Float64(times_s[i]) - mt
        num += dt * (Float64(rss_bytes[i]) - mr)
        den += dt * dt
    if den == 0.0:
        return Float64(0.0)
    return (num / den) * Float64(3600.0)


def soak_verdict(duration_s: Int, errors: Int, slope_bytes_per_hour: Float64) -> Int:
    """The A-077 verdict, in precedence order: a short run is
    short even if clean; a full run with errors fails on
    errors; a full clean run fails only on a real RSS slope."""
    if duration_s < SOAK_REQUIRED_SECONDS:
        return SOAK_SHORT
    if errors != 0:
        return SOAK_ERRORS
    if f64_abs(slope_bytes_per_hour) > Float64(SOAK_RSS_TOLERANCE_BYTES_PER_HOUR):
        return SOAK_LEAK
    return SOAK_PASS


def parse_vmrss_bytes(text: String) -> Int:
    """Parse the VmRSS line of /proc/self/status text into
    bytes. Returns -1 when the field is absent (an unreadable
    source is reported, never invented)."""
    var lines = text.split("\n")
    for i in range(len(lines)):
        var line = String(lines[i])
        if line.startswith("VmRSS:"):
            var fields = line.split()
            if len(fields) >= 2:
                try:
                    return Int(fields[1]) * 1024
                except:
                    return -1
            return -1
    return -1


def self_rss_bytes() -> Int:
    """This process's live RSS, read from /proc/self/status.
    -1 when unreadable."""
    try:
        with open("/proc/self/status", "r") as source:
            return parse_vmrss_bytes(source.read())
    except:
        return -1


struct SoakTally(Copyable, ImplicitlyCopyable):
    """Running soak counters. Every decode step records
    exactly once; EOS/KV resets are events, not errors."""

    var steps: Int
    var errors: Int
    var nonfinite_lanes: Int
    var resets: Int

    def __init__(out self):
        self.steps = 0
        self.errors = 0
        self.nonfinite_lanes = 0
        self.resets = 0

    def record_step(mut self, nonfinite: Int):
        self.steps += 1
        self.nonfinite_lanes += nonfinite

    def record_error(mut self):
        self.errors += 1

    def record_reset(mut self):
        self.resets += 1
