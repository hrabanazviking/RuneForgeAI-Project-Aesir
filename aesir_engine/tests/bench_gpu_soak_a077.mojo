# tests/bench_gpu_soak_a077.mojo
# A-077: GPU soak driver (standalone, not in run_all).
#
# Usage: bench_gpu_soak_a077 <fixture.gguf> <duration_s>
#
# Loads the A-067 real-model fixture ONCE on the Vulkan GPU
# path and free-runs greedy decode continuously for
# duration_s seconds of DECODE time (the clock starts after
# load + prompt feed, so compile/load never inflate or
# shorten the soak). On an EOS token or at the KV capacity
# the driver resets the KV cache and re-feeds the RAW prompt
# (add_bos=True, no chat template - the A-004/A-045
# standard); resets are events, not errors. Any raised error
# aborts the driver and the wrapper records a non-zero exit
# - that IS the soak's error evidence, never hidden.
#
# Prints A077_* lines: DEVICE (identity), LOAD, START (with
# the sampler's decode-phase mark), PROGRESS every 25 steps
# (elapsed, steps, steps/s, non-finite lanes sanitized,
# live buffers/bytes, cumulative Q4_K dispatches - the
# device-execution evidence), and DONE (duration, steps,
# resets, sanitizer count, baseline-restored flag).

from std.sys import argv
from std.time import perf_counter_ns

from core.gpu_soak import SoakTally
from core.observation_integer import bounded_decimal
from core.vulkan_buffers import VulkanBuffers
from core.vulkan_real_model import VulkanRealModel
from aesir import AesirEngine


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


def _argmax(row: List[Float32]) -> Int:
    var best = 0
    for i in range(len(row)):
        if row[i] > row[best]:
            best = i
    return best


def main() raises:
    var args = argv()
    if len(args) != 3:
        raise Error("usage: bench_gpu_soak_a077 <fixture.gguf> <duration_s>")
    var path = String(args[1])
    var duration_s = bounded_decimal(String(args[2]))
    if duration_s <= 0:
        raise Error("duration_s must be positive")
    if not _vk_present():
        print("A077_ABSENT no RADV STRIX_HALO device on this host")
        return
    VulkanBuffers.init()
    var info = VulkanBuffers.device_info()
    print("A077_DEVICE vendor=", info.vendor_id, " type=", info.device_type, flush=True)
    var base_count = VulkanBuffers.live_count()
    var base_bytes = VulkanBuffers.live_bytes()
    var engine = AesirEngine(path)
    var model = VulkanRealModel(path)
    model.load()
    print(
        "A077_LOAD layers=", model.layers, " dim=", model.dim,
        " vocab=", model.vocab, " live_count=", VulkanBuffers.live_count(),
        " live_bytes=", VulkanBuffers.live_bytes(), flush=True,
    )
    var prompt = String("The capital of France is")
    var ids = engine.tokenizer.encode(prompt, True)
    var tally = SoakTally()
    # Prompt feed (not counted as soak time).
    model.reset_kv()
    var row = List[Float32]()
    for p in range(len(ids)):
        row = model.decode_step(ids[p], p)
        tally.record_step(model.last_nonfinite_count)
    var pos = len(ids)
    var next_token = _argmax(row)
    var prompt_steps = tally.steps
    var t_start = perf_counter_ns()
    var deadline = t_start + duration_s * 1_000_000_000
    print(
        "A077_START duration_s=", duration_s, " prompt_steps=", prompt_steps,
        flush=True,
    )
    var since_print = 0
    while perf_counter_ns() < deadline:
        if next_token == 128001 or next_token == 128009 or pos >= 500:
            tally.record_reset()
            model.reset_kv()
            row = List[Float32]()
            for p in range(len(ids)):
                row = model.decode_step(ids[p], p)
                tally.record_step(model.last_nonfinite_count)
            pos = len(ids)
            next_token = _argmax(row)
            continue
        row = model.decode_step(next_token, pos)
        tally.record_step(model.last_nonfinite_count)
        pos += 1
        next_token = _argmax(row)
        since_print += 1
        if since_print >= 25:
            since_print = 0
            var elapsed = (perf_counter_ns() - t_start) // 1_000_000_000
            var gen_steps = tally.steps - prompt_steps
            print(
                "A077_PROGRESS elapsed_s=", elapsed, " steps=", tally.steps,
                " gen_steps=", gen_steps, " resets=", tally.resets,
                " nonfinite=", tally.nonfinite_lanes,
                " live_count=", VulkanBuffers.live_count(),
                " live_bytes=", VulkanBuffers.live_bytes(),
                " q4k_total=", VulkanBuffers.q4k_gemv_dispatch_count(),
                flush=True,
            )
    var elapsed_s = (perf_counter_ns() - t_start) // 1_000_000_000
    model.close()
    var restored = (
        VulkanBuffers.live_count() == base_count
        and VulkanBuffers.live_bytes() == base_bytes
    )
    print(
        "A077_DONE duration_s=", elapsed_s, " steps=", tally.steps,
        " gen_steps=", tally.steps - prompt_steps, " resets=", tally.resets,
        " nonfinite=", tally.nonfinite_lanes, " errors=", tally.errors,
        " baseline_restored=", restored,
        " q4k_total=", VulkanBuffers.q4k_gemv_dispatch_count(),
        flush=True,
    )
    if not restored:
        raise Error("live buffer baseline not restored at close")
