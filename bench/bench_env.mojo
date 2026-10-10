# bench/bench_env.mojo
# H161 — MÍMISBRUNNR C9 benchmark harness: environment capture, trial
# statistics, thermal settle, and JSON emission (Domain D1/D4/D5, pure Mojo).
#
# This is the single harness every C9 measurement runs through. It captures
# the environment (cpufreq governor + frequencies, SoC temperature at start
# and end, Mojo version, harness version), waits for thermal settle before
# timing, computes median/min/max/stddev over the trials, and emits one JSON
# document per benchmark into data/bench/<name>.json.
#
# Clock pinning itself is done by the caller (bench/run.sh): governor ->
# "performance", taskset to one core. The harness VERIFIES and RECORDS the
# pin state; it never silently measures on an unpinned machine (the JSON
# carries whatever the governors actually were).

from std.ffi import external_call
from std.memory import Pointer
from std.memory.alloc import unsafe_alloc
from std.origin import MutUntrackedOrigin


def harness_version() -> String:
    return "1.0.0"


def _cstr(s: String) -> Pointer[Int8, MutUntrackedOrigin]:
    # NUL-terminated copy of s for external_call path arguments.
    var src = s.as_bytes()
    var buf = unsafe_alloc[Int8](len(src) + 1)
    for i in range(len(src)):
        buf.unsafe_offset(i).unsafe_store(Int8(src[i]))
    buf.unsafe_offset(len(src)).unsafe_store(0)
    return buf


def bench_read_text(path: String) raises -> String:
    # Read a small sysfs/proc text file, strip trailing newlines.
    var cp = _cstr(path)
    var fd = external_call["open64", Int32](cp, Int32(0), Int32(0))
    cp.unsafe_free()
    if fd < 0:
        raise Error("bench_env: cannot open " + path)
    var buf = unsafe_alloc[UInt8](4096)
    var total = 0
    while total < 4095:
        var got = external_call["read", Int](Int(fd), buf.unsafe_offset(total), 4095 - total)
        if got <= 0:
            break
        total += Int(got)
    _ = external_call["close", Int32](fd)
    var out = String("")
    for i in range(total):
        var c = buf.unsafe_offset(i).unsafe_load()
        if c == 10 or c == 13:
            break
        var b = List[Int8]()
        b.append(Int8(c))
        b.append(0)
        out += String(unsafe_from_utf8_ptr=b.unsafe_ptr())
    buf.unsafe_free()
    return out


def bench_try_read_text(path: String) -> String:
    # Non-raising variant: returns "" when the file cannot be read
    # (missing cpufreq policy, permission, ...). No try/except needed.
    var src = path.as_bytes()
    var buf = unsafe_alloc[Int8](len(src) + 1)
    for i in range(len(src)):
        buf.unsafe_offset(i).unsafe_store(Int8(src[i]))
    buf.unsafe_offset(len(src)).unsafe_store(0)
    var fd = external_call["open64", Int32](buf, Int32(0), Int32(0))
    buf.unsafe_free()
    if fd < 0:
        return String("")
    var rbuf = unsafe_alloc[UInt8](4096)
    var total = 0
    while total < 4095:
        var got = external_call["read", Int](Int(fd), rbuf.unsafe_offset(total), 4095 - total)
        if got <= 0:
            break
        total += Int(got)
    _ = external_call["close", Int32](fd)
    var out = String("")
    for i in range(total):
        var c = rbuf.unsafe_offset(i).unsafe_load()
        if c == 10 or c == 13:
            break
        var b = List[Int8]()
        b.append(Int8(c))
        b.append(0)
        out += String(unsafe_from_utf8_ptr=b.unsafe_ptr())
    rbuf.unsafe_free()
    return out


def bench_temp_c() raises -> Float64:
    # Pi SoC temperature in degrees Celsius (thermal_zone0, millidegrees).
    var raw = bench_read_text("/sys/class/thermal/thermal_zone0/temp")
    return Float64(Int(raw)) / 1000.0


def bench_governors() -> String:
    # Comma-joined scaling_governor for policies 0..3 (missing -> "?").
    var out = String("")
    for p in range(4):
        var path = String("/sys/devices/system/cpu/cpufreq/policy") + String(p) + String("/scaling_governor")
        var g = bench_try_read_text(path)
        if g == "":
            g = String("?")
        if p > 0:
            out += ","
        out += g
    return out


def bench_freqs_khz() -> String:
    # Comma-joined scaling_cur_freq (kHz) for policies 0..3.
    var out = String("")
    for p in range(4):
        var path = String("/sys/devices/system/cpu/cpufreq/policy") + String(p) + String("/scaling_cur_freq")
        var f = bench_try_read_text(path)
        if f == "":
            f = String("?")
        if p > 0:
            out += ","
        out += f
    return out


def bench_sleep_s(secs: Int):
    _ = external_call["sleep", UInt32](UInt32(secs))


struct TrialStats:
    # Accumulates trial durations (ns) and reports median/min/max/stddev.
    # Median is the headline (robust to IRQ/thermal outliers); min/max are
    # published alongside so no cherry-picking is possible.
    var s: List[Float64]

    def __init__(out self):
        self.s = List[Float64]()

    def record(mut self, ns: Float64):
        self.s.append(ns)

    def count(self) -> Int:
        return len(self.s)

    def _sorted_copy(self) -> List[Float64]:
        var v = self.s.copy()
        var n = len(v)
        for i in range(1, n):
            var key = v[i]
            var j = i - 1
            while j >= 0 and v[j] > key:
                v[j + 1] = v[j]
                j -= 1
            v[j + 1] = key
        return v.copy()

    def median_ns(self) -> Float64:
        var v = self._sorted_copy()
        var n = len(v)
        if n == 0:
            return 0.0
        if n % 2 == 1:
            return v[n // 2]
        return (v[n // 2 - 1] + v[n // 2]) / 2.0

    def min_ns(self) -> Float64:
        var m = self.s[0]
        for i in range(1, len(self.s)):
            if self.s[i] < m:
                m = self.s[i]
        return m

    def max_ns(self) -> Float64:
        var m = self.s[0]
        for i in range(1, len(self.s)):
            if self.s[i] > m:
                m = self.s[i]
        return m

    def mean_ns(self) -> Float64:
        var t = 0.0
        for i in range(len(self.s)):
            t += self.s[i]
        return t / Float64(len(self.s))

    def stddev_ns(self) -> Float64:
        var mu = self.mean_ns()
        var t = 0.0
        for i in range(len(self.s)):
            var d = self.s[i] - mu
            t += d * d
        return (t / Float64(len(self.s))) ** 0.5


def bench_rss_pages() raises -> Int64:
    # Resident set size in OS pages, from /proc/self/statm field 2.
    # Used by H173 to prove zero per-step allocation (RSS must stay flat).
    var txt = bench_try_read_text("/proc/self/statm")
    if txt == "":
        return Int64(-1)
    # Second whitespace-separated field.
    var i = 0
    var n = len(txt.as_bytes())
    while i < n and txt.as_bytes()[i] != 32:
        i += 1
    while i < n and txt.as_bytes()[i] == 32:
        i += 1
    var num = String("")
    while i < n and txt.as_bytes()[i] != 32:
        var b = List[Int8]()
        b.append(Int8(txt.as_bytes()[i]))
        b.append(0)
        num += String(unsafe_from_utf8_ptr=b.unsafe_ptr())
        i += 1
    if num == "":
        return Int64(-1)
    return Int64(Int(num))


def bench_thermal_settle(max_wait_s: Int = 60) raises -> Float64:
    # Wait until the SoC temperature is stable: sample every 5 s; stop when
    # two consecutive samples differ by < 1.0 C or the budget is exhausted.
    # Returns the settled temperature. (H161: no timing starts on a hot,
    # still-ramping SoC.)
    var prev = bench_temp_c()
    var waited = 0
    while waited < max_wait_s:
        bench_sleep_s(5)
        waited += 5
        var cur = bench_temp_c()
        var d = cur - prev
        if d < 0:
            d = -d
        print("bench: thermal settle: " + String(cur) + " C (waited " + String(waited) + "s)")
        if d < 1.0:
            return cur
        prev = cur
    print("bench: thermal settle: budget exhausted at " + String(prev) + " C")
    return prev


def _json_escape(s: String) -> String:
    var out = String("")
    var bs = s.as_bytes()
    for i in range(len(bs)):
        var c = bs[i]
        if c == 34:
            out += "\\\""
        elif c == 92:
            out += "\\\\"
        elif c == 10:
            out += "\\n"
        elif c == 13:
            out += "\\r"
        elif c == 9:
            out += "\\t"
        else:
            var b = List[Int8]()
            b.append(Int8(c))
            b.append(0)
            out += String(unsafe_from_utf8_ptr=b.unsafe_ptr())
    return out


def bench_write_file(path: String, text: String) raises:
    var src = text.as_bytes()
    var cp = _cstr(path)
    var fd = external_call["open64", Int32](cp, Int32(577), Int32(0o644))
    cp.unsafe_free()
    if fd < 0:
        raise Error("bench_env: cannot open output: " + path)
    var buf = unsafe_alloc[UInt8](len(src))
    for i in range(len(src)):
        buf.unsafe_offset(i).unsafe_store(src[i])
    var n = len(src)
    var done = 0
    while done < n:
        var w = external_call["write", Int](Int(fd), buf.unsafe_offset(done), n - done)
        if w <= 0:
            buf.unsafe_free()
            _ = external_call["close", Int32](fd)
            raise Error("bench_env: short write on: " + path)
        done += Int(w)
    buf.unsafe_free()
    _ = external_call["close", Int32](fd)


def bench_env_json(
    mojo_version: String, pin_desc: String, temp_start: Float64, temp_end: Float64
) raises -> String:
    # The environment block every benchmark JSON carries.
    var j = String("  \"harness_version\": \"") + harness_version() + String("\",\n")
    j += String("  \"mojo_version\": \"") + _json_escape(mojo_version) + String("\",\n")
    j += String("  \"device\": \"Mimir (Raspberry Pi 5 Model B Rev 1.1, 16GB RAM, aarch64)\",\n")
    j += String("  \"pin\": \"") + _json_escape(pin_desc) + String("\",\n")
    j += String("  \"governors\": \"") + _json_escape(bench_governors()) + String("\",\n")
    j += String("  \"freqs_khz\": \"") + _json_escape(bench_freqs_khz()) + String("\",\n")
    j += String("  \"temp_c_start\": ") + String(temp_start) + String(",\n")
    j += String("  \"temp_c_end\": ") + String(temp_end) + String(",\n")
    return j


def bench_stats_json(name: String, unit: String, work: Float64, mut st: TrialStats) -> String:
    # One benchmark's statistics block. work = FLOPs (GFLOPS), bytes (GB/s),
    # or tokens (tok/s); rate = work / ns. (FLOP/ns == GFLOPS exactly.)
    var med = st.median_ns()
    var r_med = work / med
    var r_min = work / st.max_ns()
    var r_max = work / st.min_ns()
    var sd = work / med - work / (med + st.stddev_ns())
    var j = String("    \"name\": \"") + _json_escape(name) + String("\",\n")
    j += String("    \"unit\": \"") + _json_escape(unit) + String("\",\n")
    j += String("    \"trials\": ") + String(st.count()) + String(",\n")
    j += String("    \"median\": ") + String(r_med) + String(",\n")
    j += String("    \"p50\": ") + String(r_med) + String(",\n")
    j += String("    \"min\": ") + String(r_min) + String(",\n")
    j += String("    \"max\": ") + String(r_max) + String(",\n")
    j += String("    \"stddev\": ") + String(sd) + String(",\n")
    j += String("    \"median_ns\": ") + String(med) + String(",\n")
    j += String("    \"min_ns\": ") + String(st.min_ns()) + String(",\n")
    j += String("    \"max_ns\": ") + String(st.max_ns()) + String(",\n")
    j += String("    \"stddev_ns\": ") + String(st.stddev_ns())
    return j
