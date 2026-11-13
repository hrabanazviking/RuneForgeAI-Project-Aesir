"""GPU soak (A-077): one hour of continuous decode on the
GPU path. Acceptance: soak log with memory + thermal
traces; zero errors; RSS slope approximately 0.

The hour itself is NOT a run_all case (the suite stays a
fast gate): it runs as tests/bench_gpu_soak_a077.mojo under
hidden_files/run_a077_soak.sh, which also samples the
memory + thermal trace. Filed evidence: hidden_files/
a077_soak.log + a077_traces.tsv, judged in A077_LEDGER.md.

These cases prove the soak's judging machinery exactly
(slope fit, verdict precedence, tally accounting, the live
/proc RSS reader) and - on the real device with the A-067
fixture - that a bounded real-model GPU decode burst runs
error-free through the same VulkanRealModel path the soak
driver uses, with dispatch counts rising and the live
buffer baseline restored at close (the leak shape the
hour watches for, at burst scale). On a host without the
RADV device or the fixture the device case passes as
honest-absent (A-014/A-065 discipline).
"""
from core.gpu_soak import (
    SOAK_ERRORS,
    SOAK_LEAK,
    SOAK_PASS,
    SOAK_RSS_TOLERANCE_BYTES_PER_HOUR,
    SOAK_SHORT,
    SoakTally,
    parse_vmrss_bytes,
    self_rss_bytes,
    soak_slope_bytes_per_hour,
    soak_verdict,
    soak_verdict_name,
)
from core.vulkan_buffers import VulkanBuffers
from core.vulkan_real_model import VulkanRealModel
from aesir import AesirEngine


comptime _FIXTURE = "/home/volmarr/aesir-team-01/hidden_files/fixtures/Meta-Llama-3.1-8B-Instruct-Q4_K_M.gguf"
comptime _PROMPT = "The capital of France is"


def _vk_present() -> Bool:
    if not VulkanBuffers.runtime_available():
        return False
    if not VulkanBuffers.dispatch_available():
        return False
    try:
        var info = VulkanBuffers.device_info()
        if info.vendor_id != 0x1002:
            return False
        if info.device_type == 4:
            return False
        return VulkanBuffers.device_name_is_radv()
    except:
        return False


def test_gpu_soak_slope_flat_and_leak() raises:
    print("--- Testing soak RSS slope fit (A-077) ---")
    var times = List[Int]()
    var flat = List[Int]()
    var leak = List[Int]()
    for i in range(13):
        times.append(i * 300)
        flat.append(2_000_000_000)
        leak.append(2_000_000_000 + i * 25_000_000)
    var flat_slope = soak_slope_bytes_per_hour(times, flat)
    if flat_slope != 0.0:
        raise Error("flat RSS series must fit slope 0, got " + String(flat_slope))
    # +25 MiB per 300 s sample = +300 MiB/h: a clear leak.
    var leak_slope = soak_slope_bytes_per_hour(times, leak)
    if leak_slope < Float64(250 * 1024 * 1024):
        raise Error("growing series must fit a large slope, got " + String(leak_slope))
    if soak_slope_bytes_per_hour(List[Int](), List[Int]()) != 0.0:
        raise Error("empty series must fit slope 0")


def test_gpu_soak_verdict_precedence() raises:
    print("--- Testing soak verdict precedence (A-077) ---")
    if soak_verdict(3599, 0, 0.0) != SOAK_SHORT:
        raise Error("3599 s clean run must judge SHORT")
    if soak_verdict(3600, 1, 0.0) != SOAK_ERRORS:
        raise Error("full run with an error must judge ERRORS")
    var big = Float64(SOAK_RSS_TOLERANCE_BYTES_PER_HOUR) * 2.0
    if soak_verdict(3600, 0, big) != SOAK_LEAK:
        raise Error("full clean run at 2x tolerance slope must judge LEAK")
    if soak_verdict(3600, 0, 0.0) != SOAK_PASS:
        raise Error("full clean flat run must judge PASS")
    if soak_verdict(7200, 0, Float64(SOAK_RSS_TOLERANCE_BYTES_PER_HOUR)) != SOAK_PASS:
        raise Error("slope exactly at tolerance must judge PASS")
    if soak_verdict_name(SOAK_PASS) != "pass":
        raise Error("verdict name drift")


def test_gpu_soak_tally_accounting() raises:
    print("--- Testing soak tally accounting (A-077) ---")
    var tally = SoakTally()
    for _ in range(100):
        tally.record_step(0)
    tally.record_step(3)
    tally.record_reset()
    tally.record_reset()
    if tally.steps != 101 or tally.nonfinite_lanes != 3 or tally.resets != 2:
        raise Error("tally counts drift")
    if tally.errors != 0:
        raise Error("clean tally must hold zero errors")
    tally.record_error()
    if tally.errors != 1:
        raise Error("record_error must count exactly one")


def test_gpu_soak_live_rss_reader() raises:
    print("--- Testing soak live RSS reader (A-077) ---")
    var sample = String("Name:\tbench\nVmRSS:\t  204800 kB\nVmHWM:\t  204800 kB\n")
    if parse_vmrss_bytes(sample) != 204800 * 1024:
        raise Error("VmRSS parse drift")
    if parse_vmrss_bytes(String("Name:\tbench\n")) != -1:
        raise Error("missing VmRSS must report -1, never invent")
    var live = self_rss_bytes()
    if live <= 0:
        raise Error("live /proc/self/status RSS must read positive on this host")


def test_gpu_soak_device_burst() raises:
    print("--- Testing soak device burst, real model (A-077) ---")
    if not _vk_present():
        print("A077_BURST_ABSENT no RADV STRIX_HALO device")
        return
    try:
        with open(_FIXTURE, "r") as probe:
            _ = probe.read(1)
    except:
        print("A077_BURST_ABSENT fixture not present")
        return
    VulkanBuffers.init()
    var base_count = VulkanBuffers.live_count()
    var base_bytes = VulkanBuffers.live_bytes()
    var engine = AesirEngine(_FIXTURE)
    var model = VulkanRealModel(_FIXTURE)
    model.load()
    var ids = engine.tokenizer.encode(_PROMPT, True)
    var tally = SoakTally()
    var q0 = VulkanBuffers.q4k_gemv_dispatch_count()
    model.reset_kv()
    var row = List[Float32]()
    for p in range(len(ids)):
        row = model.decode_step(ids[p], p)
        tally.record_step(model.last_nonfinite_count)
    var pos = len(ids)
    for _ in range(8):
        var best = 0
        for i in range(len(row)):
            if row[i] > row[best]:
                best = i
        if best == 128001 or best == 128009 or pos >= 500:
            tally.record_reset()
            break
        row = model.decode_step(best, pos)
        tally.record_step(model.last_nonfinite_count)
        pos += 1
    var q1 = VulkanBuffers.q4k_gemv_dispatch_count()
    model.close()
    if tally.errors != 0 or tally.nonfinite_lanes != 0:
        raise Error("burst must be error-free with zero non-finite lanes")
    if tally.steps != len(ids) + 8 and tally.resets == 0:
        raise Error("burst step accounting drift")
    if q1 <= q0:
        raise Error("burst must raise the Q4_K GEMV dispatch count (device evidence)")
    if VulkanBuffers.live_count() != base_count or VulkanBuffers.live_bytes() != base_bytes:
        raise Error("live buffer baseline must be restored at close")
    print("A077_BURST steps=", tally.steps, " q4k_delta=", q1 - q0)
