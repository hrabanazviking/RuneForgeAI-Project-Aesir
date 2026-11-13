# tests/bench_fairness_a105.mojo
# A-105 standalone two-model fairness run (not part of
# run_all: it drives two real fixtures totalling ~4.9 GB and
# real Vulkan device buffers). Pattern follows the A-102
# bench: bench + docs/bench doc + hidden_files ledger; the
# scheduler arithmetic itself is proven in-suite by
# tests/test_fairness_a105.mojo.
#
# Fixtures (both sha-pinned, verified by the runner script
# before/after):
#   model L (large): Meta-Llama-3.1-8B-Instruct-Q4_K_M.gguf,
#     sha256 7b064f5842bf9532c91456deda288a1b672397a54
#     fa729aa665952863033557c (the A-067/A-081/A-102 pin),
#     4,920,739,232 bytes, 292 tensors, 32 layers - read from
#     the seat fixture path (read-only).
#   model S (small): stories260K.F16.gguf, sha256
#     57a81ed1c8b032ba29319eae80c3e568dbb5a16ce665a09da1a0
#     efe2e4eb69e3 (the fixture_manifest.json pin),
#     601,248 bytes, 48 tensors - read from team-01's fixture
#     copy (read-only; the seat fixture dir holds only the
#     8B file - stated plainly, not papered over).
#
# Legs, all numbers printed from live measurement:
# 1. Both fixtures resident at once (two GGUFSeer mmaps):
#    tensor counts and payload totals from the loader's own
#    byte math (A-064 discipline), layer tables built for
#    both models and summed against the payload totals.
# 2. Concurrent service under core/fair_scheduler.mojo: a
#    scripted concurrent demand built from the real models -
#    model L offers a long prefill burst plus a decode
#    trickle, model S a steady decode stream - served at a
#    fixed step budget, weights 1:1 and then 2:1. The
#    per-model latency bound (max wait <= wait_bound_steps)
#    is asserted from the measured run; served totals, max
#    waits and the Jain index are printed. (The share/lag
#    bound is a both-backlogged invariant - it is asserted
#    per-step in-suite, where both queues are held saturated;
#    here demand is deliberately unequal, so end totals
#    differ by demand, not by unfairness.)
# 3. Device interleave: scheduler steps copy real file spans
#    of BOTH models into real Vulkan buffers on the RADV
#    STRIX_HALO device (llvmpipe refused by identity) in
#    scheduler order; per-model readback checksums must equal
#    the source span checksums; buffers freed to baseline.
# 4. Solo controls: each model alone receives the whole
#    budget (work conservation) - fairness is not a tax.
# 5. Reproducibility: leg 2's 1:1 run repeated produces a
#    byte-identical fairness log and digest.

from std.sys import argv

from core.fair_scheduler import FairScheduler
from core.mimir_well import MimirWell
from core.vulkan_buffers import VulkanBuffers
from core.weight_residency import WeightResidency
from loader.gguf import GGUFSeer
from loader.tokenizer import RuneWeaver


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


def _fnv_span(
    base: Pointer[UInt8, MutUntrackedOrigin], start: Int, length: Int
) -> UInt64:
    var hash: UInt64 = 14695981039346656037
    var prime: UInt64 = 1099511628211
    for i in range(length):
        hash = hash ^ UInt64(base[start + i])
        hash = hash * prime
    return hash


struct LayerTable(Copyable):
    var names: List[String]
    var bytes: List[Int]
    var starts: List[Int]
    var ends: List[Int]
    var n_layers: Int

    def __init__(out self):
        self.names = List[String]()
        self.bytes = List[Int]()
        self.starts = List[Int]()
        self.ends = List[Int]()
        self.n_layers = 0

    def payload_sum(self) -> Int:
        var total = 0
        for i in range(len(self.bytes)):
            total += self.bytes[i]
        return total


def _layer_table(seer: GGUFSeer) raises -> LayerTable:
    """Per-layer (embed, blk.0..N-1, output) byte sizes and
    file spans from the loader's own tensor byte math - the
    A-102 bench discipline, applied to any GGUF fixture."""
    var table = LayerTable()
    var names = List[String]()
    for name in seer.tensors.keys():
        names.append(String(name))
    table.names.append(String("embed"))
    table.bytes.append(0)
    table.starts.append(0)
    table.ends.append(0)
    for cand in range(128):
        var prefix = String("blk.") + String(cand) + String(".")
        var found = False
        for ni in range(len(names)):
            if names[ni].startswith(prefix):
                found = True
                break
        if not found:
            break
        table.n_layers = cand + 1
        table.names.append(String("blk.") + String(cand))
        table.bytes.append(0)
        table.starts.append(0)
        table.ends.append(0)
    table.names.append(String("output"))
    table.bytes.append(0)
    table.starts.append(0)
    table.ends.append(0)
    for ni in range(len(names)):
        var nm = names[ni].copy()
        var tensor = seer.tensors[nm].copy()
        var size = seer._tensor_byte_size(
            tensor.rows * tensor.cols, seer.tensor_types[nm]
        )
        var off = seer.tensor_file_offsets[nm]
        var li = 0
        if nm == String("token_embd.weight"):
            li = 0
        elif nm.startswith("blk."):
            var idx = 0
            var pos = 4
            var raw = nm.as_bytes()
            while pos < len(raw) and raw[pos] != UInt8(46):
                idx = idx * 10 + Int(raw[pos]) - 48
                pos += 1
            li = idx + 1
        else:
            li = len(table.names) - 1
        table.bytes[li] += size
        if table.starts[li] == 0 or off < table.starts[li]:
            table.starts[li] = off
        if off + size > table.ends[li]:
            table.ends[li] = off + size
    return table^


struct ConcurrentRun(Copyable):
    var sched: FairScheduler
    var left_l: Int
    var left_s: Int

    def __init__(out self, sched: FairScheduler, left_l: Int, left_s: Int):
        self.sched = sched.copy()
        self.left_l = left_l
        self.left_s = left_s


def _concurrent_run(weight_l: Int, weight_s: Int) -> ConcurrentRun:
    """The leg-2 demand script: model L (the 8B) opens with
    an 8192-token prefill burst and adds 1 decode token per
    step; model S (stories260K) adds a steady 4 tokens per
    step from an opening 64. Budget 256 tokens per step,
    600 steps, then a drain phase with no refills."""
    var sched = FairScheduler(
        String("llama-8b"), weight_l, String("stories260k"), weight_s
    )
    var ql = 8192
    var qs = 64
    for _ in range(600):
        var step = sched.serve_step(256, ql, qs)
        ql -= step.alloc_a
        qs -= step.alloc_b
        ql += 1
        qs += 4
    var guard = 0
    while (ql > 0 or qs > 0) and guard < 10000:
        guard += 1
        var step = sched.serve_step(256, ql, qs)
        ql -= step.alloc_a
        qs -= step.alloc_b
    return ConcurrentRun(sched, ql, qs)


def main() raises:
    var arguments = argv()
    if len(arguments) != 3:
        raise Error("usage: bench_fairness_a105 <stories.gguf> <llama8b.gguf>")
    if not _vk_present():
        print("A105_ABSENT no RADV STRIX_HALO device on this host")
        return
    VulkanBuffers.init()
    var info = VulkanBuffers.device_info()
    print(
        "A105_DEVICE vendor=", info.vendor_id, " type=", info.device_type,
        " radv=", VulkanBuffers.device_name_is_radv(),
    )

    # Leg 1 - both real fixtures resident concurrently.
    var pool = MimirWell(2 * 1024 * 1024)
    var tokenizer = RuneWeaver()
    var seer_s = GGUFSeer(arguments[1])
    seer_s.mmap_and_load(pool, tokenizer)
    var seer_l = GGUFSeer(arguments[2])
    seer_l.mmap_and_load(pool, tokenizer)
    if seer_s.tensor_count != 48:
        raise Error("A105: stories fixture tensor count is not 48 (wrong fixture?)")
    if seer_l.tensor_count != 292:
        raise Error("A105: 8B fixture tensor count is not 292 (wrong fixture?)")
    print("stories_file_bytes:", Int(seer_s.file_size))
    print("stories_tensor_count:", seer_s.tensor_count)
    print("llama_file_bytes:", Int(seer_l.file_size))
    print("llama_tensor_count:", seer_l.tensor_count)
    var acct_s = WeightResidency.account(seer_s)
    var acct_l = WeightResidency.account(seer_l)
    print("stories_payload_bytes:", acct_s.tensor_payload_bytes)
    print("llama_payload_bytes:", acct_l.tensor_payload_bytes)
    var table_s = _layer_table(seer_s)
    var table_l = _layer_table(seer_l)
    print("stories_layers:", table_s.n_layers)
    print("llama_layers:", table_l.n_layers)
    if table_l.n_layers != 32:
        raise Error("A105: 8B fixture layer count is not 32")
    if table_s.payload_sum() != acct_s.tensor_payload_bytes:
        raise Error("A105: stories layer table does not sum to its payload total")
    if table_l.payload_sum() != acct_l.tensor_payload_bytes:
        raise Error("A105: 8B layer table does not sum to its payload total")
    print("A105_BOTH_RESIDENT payloads sum to layer tables for both models")

    # Leg 2 - concurrent service, weights 1:1 then 2:1.
    var run1 = _concurrent_run(1, 1)
    if run1.left_l != 0 or run1.left_s != 0:
        raise Error("A105: concurrent run left unserved demand")
    if run1.sched.max_wait_a > run1.sched.wait_bound_steps() or run1.sched.max_wait_b > run1.sched.wait_bound_steps():
        raise Error("A105: concurrent run broke the per-model latency bound")
    print(run1.sched.summary_line())
    print("A105_FAIR_1TO1_DIGEST", run1.sched.digest())
    var run2 = _concurrent_run(2, 1)
    if run2.left_l != 0 or run2.left_s != 0:
        raise Error("A105: weighted concurrent run left unserved demand")
    if run2.sched.max_wait_a > run2.sched.wait_bound_steps() or run2.sched.max_wait_b > run2.sched.wait_bound_steps():
        raise Error("A105: weighted run broke the per-model latency bound")
    print(run2.sched.summary_line())
    print("A105_FAIR_2TO1_DIGEST", run2.sched.digest())

    # Leg 3 - device interleave of real spans, scheduler order.
    # Unit = 256 KiB chunk; each model offers 16 units from its
    # embed span; budget 2 units per step.
    var unit = 256 * 1024
    var units_l = 16
    var units_s = 16
    var isched = FairScheduler(String("llama-8b"), 1, String("stories260k"), 1)
    var base_l = seer_l.mmap_ptr.unsafe_bitcast[UInt8]()
    var base_s = seer_s.mmap_ptr.unsafe_bitcast[UInt8]()
    var start_l = table_l.starts[0]
    var start_s = table_s.starts[0]
    var before = VulkanBuffers.live_bytes()
    var buf_l = VulkanBuffers.allocate(units_l * unit)
    var buf_s = VulkanBuffers.allocate(units_s * unit)
    var filled_l = 0
    var filled_s = 0
    var first_l = -1
    var first_s = -1
    var step_no = 0
    while units_l > 0 or units_s > 0:
        step_no += 1
        var step = isched.serve_step(2, units_l, units_s)
        units_l -= step.alloc_a
        units_s -= step.alloc_b
        if step.alloc_a > 0 and first_l < 0:
            first_l = step_no
        if step.alloc_b > 0 and first_s < 0:
            first_s = step_no
        for _ in range(step.alloc_a):
            var dst = VulkanBuffers.map(buf_l)
            for i in range(unit):
                dst[filled_l * unit + i] = base_l[start_l + filled_l * unit + i]
            VulkanBuffers.unmap(buf_l)
            filled_l += 1
        for _ in range(step.alloc_b):
            var dst = VulkanBuffers.map(buf_s)
            for i in range(unit):
                dst[filled_s * unit + i] = base_s[start_s + filled_s * unit + i]
            VulkanBuffers.unmap(buf_s)
            filled_s += 1
        if step_no > 64:
            raise Error("A105: device interleave did not drain in expected steps")
    if first_l < 1 or first_s < 1 or first_l > 2 or first_s > 2:
        raise Error("A105: a model's first device service missed the latency bound")
    if isched.max_wait_a > isched.wait_bound_steps() or isched.max_wait_b > isched.wait_bound_steps():
        raise Error("A105: device interleave broke the per-model latency bound")
    var back_l = VulkanBuffers.map(buf_l)
    var dev_l = _fnv_span(back_l, 0, 16 * unit)
    VulkanBuffers.unmap(buf_l)
    var back_s = VulkanBuffers.map(buf_s)
    var dev_s = _fnv_span(back_s, 0, 16 * unit)
    VulkanBuffers.unmap(buf_s)
    VulkanBuffers.free(buf_l)
    VulkanBuffers.free(buf_s)
    var src_l = _fnv_span(base_l, start_l, 16 * unit)
    var src_s = _fnv_span(base_s, start_s, 16 * unit)
    if dev_l != src_l:
        raise Error("A105: 8B device readback checksum differs from its file span")
    if dev_s != src_s:
        raise Error("A105: stories device readback checksum differs from its file span")
    if VulkanBuffers.live_bytes() != before:
        raise Error("A105: shim live bytes not at baseline after free")
    print(
        "A105_DEVICE_INTERLEAVE first_service_steps=", first_l, ",", first_s,
        " llama_checksum=", src_l, " stories_checksum=", src_s,
    )

    # Leg 4 - solo controls: fairness is not a tax.
    var solo = FairScheduler(String("llama-8b"), 1, String("stories260k"), 1)
    var step_l = solo.serve_step(256, 1000, 0)
    if step_l.alloc_a != 256 or step_l.alloc_b != 0:
        raise Error("A105: solo large model did not receive the whole budget")
    var step_s = solo.serve_step(256, 0, 1000)
    if step_s.alloc_b != 256 or step_s.alloc_a != 0:
        raise Error("A105: solo small model did not receive the whole budget")
    print("A105_SOLO_CONTROLS both models receive the full budget alone")

    # Leg 5 - reproducibility of the concurrent run.
    var run3 = _concurrent_run(1, 1)
    if run3.sched.log_text() != run1.sched.log_text() or run3.sched.digest() != run1.sched.digest():
        raise Error("A105: concurrent run not reproducible from identical demand")
    print("A105_REPRODUCIBLE digest=", run3.sched.digest())

    print(
        "seers_alive_at_end: stories tensors=", seer_s.tensor_count,
        " llama tensors=", seer_l.tensor_count,
    )
    print("A105_FAIRNESS: PASS")
