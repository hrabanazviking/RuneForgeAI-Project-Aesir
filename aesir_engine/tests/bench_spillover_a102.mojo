# tests/bench_spillover_a102.mojo
# A-102 standalone oversized-model run (not part of run_all: it
# drives a 4.9 GB real fixture and real Vulkan device buffers).
# Pattern follows the A-049/A-067 standalone benches: bench +
# docs/bench doc + hidden_files ledger; the policy arithmetic
# itself is proven in-suite by tests/test_spillover_policy_a102.
#
# Fixture (A-049 fixture class - largest obtainable, sha-pinned,
# real tensors): Meta-Llama-3.1-8B-Instruct-Q4_K_M.gguf, sha256
# 7b064f5842bf9532c91456deda288a1b672397a54fa729aa665952863033557c
# (the A-067/A-081 pin), 4,920,739,232 bytes, 292 tensors,
# 32 layers. hidden_files/run_a102_bench.sh verifies the sha256
# before and after the run.
#
# Legs, all numbers printed from live measurement:
# 1. Layer table: per-layer byte sizes summed from the loader's
#    own tensor byte math (the A-064 WeightResidency discipline:
#    sizes from GGUFSeer._tensor_byte_size, never re-derived).
#    The table must sum to the loader's payload total.
# 2. Oversized placement: GPU capacity fixed at 1 GiB - far
#    below the 4.9 GB model, i.e. genuine capacity pressure -
#    under the live pool figures. The plan must hold: prefix on
#    the accelerator, remainder spilled to CPU, totals summing
#    to the model payload, every layer logged with its reason.
# 3. Reproducibility: the identical plan computed again must
#    produce a byte-identical log and digest.
# 4. Execution: the first GPU-placed layer's file span is copied
#    into a real Vulkan buffer on the RADV STRIX_HALO device
#    (llvmpipe refused by identity), read back through the
#    device mapping and checksummed - equal to the source span
#    checksum or the leg fails. The first CPU-spilled layer's
#    span is checksummed on the host mapping (the CPU path's
#    placement on the unified pool). Buffers freed back to the
#    shim baseline.
# 5. Roomy control: capacity above the model size places every
#    layer on the accelerator - spill is a pressure behaviour,
#    never the default (accelerator-first).

from std.sys import argv

from core.gpu_pressure import GpuPressureConfig, live_pressure
from core.mimir_well import MimirWell
from core.spillover_policy import LayerSpec, fnv1a64, plan_spillover
from core.vulkan_buffers import VulkanBuffers
from core.weight_residency import WeightResidency
from loader.gguf import GGUFSeer
from loader.tokenizer import RuneWeaver

comptime GPU_CAP = 1024 * 1024 * 1024
comptime SPILL_CAP = 16 * 1024 * 1024 * 1024


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


def _fnv_span(base: Pointer[UInt8, MutUntrackedOrigin], start: Int, length: Int) -> UInt64:
    var hash: UInt64 = 14695981039346656037
    var prime: UInt64 = 1099511628211
    for i in range(length):
        hash = hash ^ UInt64(base[start + i])
        hash = hash * prime
    return hash


def main() raises:
    var arguments = argv()
    if len(arguments) != 2:
        raise Error("usage: bench_spillover_a102 <fixture.gguf>")
    if not _vk_present():
        print("A102_ABSENT no RADV STRIX_HALO device on this host")
        return
    VulkanBuffers.init()
    var info = VulkanBuffers.device_info()
    print("A102_DEVICE vendor=", info.vendor_id, " type=", info.device_type, " radv=", VulkanBuffers.device_name_is_radv())

    var pool = MimirWell(2 * 1024 * 1024)
    var tokenizer = RuneWeaver()
    var seer = GGUFSeer(arguments[1])
    seer.mmap_and_load(pool, tokenizer)
    if seer.tensor_count != 292:
        raise Error("A102: fixture tensor count is not 292 (wrong fixture?)")
    print("file_bytes:", Int(seer.file_size))
    print("tensor_count:", seer.tensor_count)
    var acct = WeightResidency.account(seer)
    print("tensor_payload_bytes:", acct.tensor_payload_bytes)

    # Leg 1 - layer table from the loader's own byte math.
    var names = List[String]()
    for name in seer.tensors.keys():
        names.append(String(name))
    var layer_names = List[String]()
    var layer_bytes = List[Int]()
    var layer_start = List[Int]()
    var layer_end = List[Int]()
    layer_names.append(String("embed"))
    layer_bytes.append(0)
    layer_start.append(0)
    layer_end.append(0)
    var n_layers = 0
    for cand in range(128):
        var prefix = String("blk.") + String(cand) + String(".")
        var found = False
        for ni in range(len(names)):
            if names[ni].startswith(prefix):
                found = True
                break
        if not found:
            break
        n_layers = cand + 1
        layer_names.append(String("blk.") + String(cand))
        layer_bytes.append(0)
        layer_start.append(0)
        layer_end.append(0)
    layer_names.append(String("output"))
    layer_bytes.append(0)
    layer_start.append(0)
    layer_end.append(0)
    print("layers_in_model:", n_layers)
    if n_layers != 32:
        raise Error("A102: fixture layer count is not 32")
    for ni in range(len(names)):
        var nm = names[ni].copy()
        var tensor = seer.tensors[nm].copy()
        var size = seer._tensor_byte_size(tensor.rows * tensor.cols, seer.tensor_types[nm])
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
            li = len(layer_names) - 1
        layer_bytes[li] += size
        if layer_start[li] == 0 or off < layer_start[li]:
            layer_start[li] = off
        if off + size > layer_end[li]:
            layer_end[li] = off + size
    var payload_sum = 0
    for li in range(len(layer_bytes)):
        payload_sum += layer_bytes[li]
    print("layer_table_payload_sum:", payload_sum)
    if payload_sum != acct.tensor_payload_bytes:
        raise Error("A102: layer table does not sum to the loader payload total")

    # Leg 2 - oversized placement under live pool figures.
    var layers = List[LayerSpec]()
    for li in range(len(layer_names)):
        layers.append(LayerSpec(layer_names[li].copy(), layer_bytes[li], True))
    var reading = live_pressure()
    print("live_avail:", reading.available_bytes, " live_total:", reading.total_bytes)
    var cfg = GpuPressureConfig(GPU_CAP, SPILL_CAP, 0)
    var plan = plan_spillover(cfg, layers, reading.available_bytes, reading.total_bytes)
    if not plan.ok:
        raise Error("A102: oversized plan refused - " + plan.refusal_reason)
    print(plan.log_text())
    print("A102_PLAN_DIGEST", plan.digest)
    if plan.gpu_bytes + plan.cpu_bytes() != payload_sum:
        raise Error("A102: plan totals do not sum to the model payload")
    if plan.gpu_layers == 0 or plan.cpu_layers == 0:
        raise Error("A102: oversized run did not split across accelerator and CPU")
    # Prefix property: once a layer spills, no later layer is on GPU.
    var seen_spill = False
    var first_gpu = -1
    var first_spill = -1
    for li in range(len(layers)):
        var line = plan.entries[li + 1]
        if String("place=CPU_SPILL") in line:
            seen_spill = True
            if first_spill < 0:
                first_spill = li
        elif String("place=GPU") in line:
            if seen_spill:
                raise Error("A102: GPU placement after a spill - not a prefix split")
            if first_gpu < 0:
                first_gpu = li
    print("first_gpu_layer:", first_gpu, " first_spill_layer:", first_spill)

    # Leg 3 - reproducibility: same inputs, byte-identical log.
    var plan2 = plan_spillover(cfg, layers, reading.available_bytes, reading.total_bytes)
    if plan2.log_text() != plan.log_text() or plan2.digest != plan.digest:
        raise Error("A102: placement not reproducible from identical inputs")
    print("A102_REPRODUCIBLE digest=", plan2.digest)

    # Leg 4 - execution of the placement on the real device.
    var base = seer.mmap_ptr.unsafe_bitcast[UInt8]()
    var gstart = layer_start[first_gpu]
    var glen = layer_end[first_gpu] - layer_start[first_gpu]
    var src_sum = _fnv_span(base, gstart, glen)
    var before = VulkanBuffers.live_bytes()
    var alloc = VulkanBuffers.allocate(glen)
    var dst = VulkanBuffers.map(alloc)
    for i in range(glen):
        dst[i] = base[gstart + i]
    VulkanBuffers.unmap(alloc)
    var back = VulkanBuffers.map(alloc)
    var dev_sum: UInt64 = 14695981039346656037
    var prime: UInt64 = 1099511628211
    for i in range(glen):
        dev_sum = dev_sum ^ UInt64(back[i])
        dev_sum = dev_sum * prime
    VulkanBuffers.unmap(alloc)
    VulkanBuffers.free(alloc)
    if dev_sum != src_sum:
        raise Error("A102: device readback checksum differs from the placed layer span")
    if VulkanBuffers.live_bytes() != before:
        raise Error("A102: shim live bytes not at baseline after free")
    print("A102_GPU_LAYER_EXEC name=", layer_names[first_gpu], " span_bytes=", glen, " checksum=", src_sum)
    var sstart = layer_start[first_spill]
    var slen = layer_end[first_spill] - layer_start[first_spill]
    var cpu_sum = _fnv_span(base, sstart, slen)
    print("A102_CPU_LAYER name=", layer_names[first_spill], " span_bytes=", slen, " checksum=", cpu_sum)

    # Leg 5 - roomy control: capacity above the model, no spill.
    var roomy = plan_spillover(
        GpuPressureConfig(16 * 1024 * 1024 * 1024, SPILL_CAP, 0),
        layers, reading.available_bytes, reading.total_bytes,
    )
    if not roomy.ok or roomy.cpu_layers != 0 or roomy.gpu_bytes != payload_sum:
        raise Error("A102: roomy control spilled without pressure")
    print("A102_ROOMY_DIGEST", roomy.digest)
    # Lifetime anchor, same discipline as the A-049 bench: keep
    # seer alive across every mapping read above.
    print("seer_alive_at_end: tensors=", seer.tensor_count, " file_bytes=", Int(seer.file_size))
    print("A102_SPILLOVER: PASS")
