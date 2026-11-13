"""
A-104 - Big-model placement: GPU/CPU layer split over the
128 GB unified pool.

Roadmap A-104: the largest sha-pinned fixture that fits the
128 GB pool runs with a GPU/CPU layer split. Acceptance:
coherent generation + placement + memory accounting filed.

This module is the split solver + accounting ledger the
acceptance rests on. It builds on banked surfaces only:

- A-100 placement planner (core/placement_planner.mojo):
  per-op placement inside a layer (decode GEMV + attention
  to GPU, sampling/embedding to CPU). This module is the
  per-LAYER counterpart the planner deliberately does not
  own (it takes no byte sizes and no layer index).
- A-076 GpuPressureGovernor (core/gpu_pressure.mojo): the
  GPU budget a split may spend is the governor's effective
  room - min(gpu_cap, available - reserve) - gpu_live -
  never a hand-picked number; budget_from_pressure() is
  that call, verbatim.
- A-064 GPU weight residency: GPU-placed layers are the
  ones resident_allocate() admits, one unified allocation
  per tensor; CPU-placed layers stay on the host path over
  the same unified pages (A-076 spill semantics).
- A-049 oversized fixture class: a model is placeable only
  when its full accounting fits the pool; fits_pool is a
  hard gate, not a hope.

Split convention (measured from the llama.cpp -ngl
executor the live run uses, so plan and execution stay
comparable): GPU layers are a SUFFIX of the layer stack
(the executor offloads the last N layers); the token
embedding rides on the GPU with them, while the output +
final-norm block stays on the host in a partial split
(measured on the pinned fixture at -ngl 16: Vulkan model
buffer 2,290.21 MiB vs embedding + last-16 spans
2,404,941,824 B - the 0.14% delta is inter-tensor
padding the allocator does not charge; host buffer
2,395.10 MiB vs first-16 + output spans 2,507,956,480 B,
the mirror delta). In a full split everything is GPU;
in a zero split everything is CPU. A layer is never
split across devices. KV cache bytes follow their layer
in the plan; the executor's measured KV split carries a
one-layer shift (240 GPU / 272 CPU MiB at -ngl 16, total
exactly the planned 512 MiB) - filed in the bench doc.

Honesty law: this module executes nothing. Device
execution evidence for the A-104 split lives in
docs/bench/A104_BIG_MODEL_PLACEMENT.md (llama.cpp Vulkan
on RADV STRIX_HALO, gfx1151) and hidden_files/a104/.
"""

from .gpu_pressure import GpuPressureConfig


# The Strix Halo unified pool the roadmap names: 128 GB.
# The live machine reports MemTotal 127,396,532 KiB
# (hidden_files/a104/meminfo.txt); plans take pool_bytes
# as an input so tests can pin the exact figure.
alias POOL_128GB_BYTES = 128 * 1024 * 1024 * 1024


def budget_from_pressure(
    gpu_cap_bytes: Int, available_bytes: Int, reserve_bytes: Int, gpu_live_bytes: Int
) -> Int:
    """The A-076 governor's effective GPU room, verbatim.

    min(gpu_cap, available - reserve) - gpu_live, floored
    at 0; unknown availability (available < 0) leaves the
    cap alone - exactly GpuPressureConfig.effective_gpu_room.
    """
    var config = GpuPressureConfig(gpu_cap_bytes, 0, reserve_bytes)
    return config.effective_gpu_room(available_bytes, gpu_live_bytes)


def kv_bytes_for_layers(
    layers: Int, ctx_tokens: Int, kv_heads: Int, head_dim: Int, dtype_bytes: Int = 2
) -> Int:
    """KV cache bytes for `layers` layers: K and V, f16 by
    default. Per token per layer: kv_heads * head_dim * 2
    tensors * dtype_bytes."""
    if layers <= 0 or ctx_tokens <= 0:
        return 0
    return layers * ctx_tokens * kv_heads * head_dim * 2 * dtype_bytes


struct LayerSplitPlan(Copyable, ImplicitlyCopyable):
    """One solved split with its full memory accounting.

    All byte counts are exact sums of the inputs; the
    invariant gpu_weight_bytes + cpu_weight_bytes ==
    total_weight_bytes holds by construction and is
    suite-checked. KV follows the layer it belongs to.
    """

    var gpu_layers: Int
    var cpu_layers: Int
    var gpu_weight_bytes: Int
    var cpu_weight_bytes: Int
    var kv_gpu_bytes: Int
    var kv_cpu_bytes: Int
    var total_weight_bytes: Int
    var pool_bytes: Int
    var fits_pool: Bool

    def __init__(
        out self,
        gpu_layers: Int,
        cpu_layers: Int,
        gpu_weight_bytes: Int,
        cpu_weight_bytes: Int,
        kv_gpu_bytes: Int,
        kv_cpu_bytes: Int,
        total_weight_bytes: Int,
        pool_bytes: Int,
        fits_pool: Bool,
    ):
        self.gpu_layers = gpu_layers
        self.cpu_layers = cpu_layers
        self.gpu_weight_bytes = gpu_weight_bytes
        self.cpu_weight_bytes = cpu_weight_bytes
        self.kv_gpu_bytes = kv_gpu_bytes
        self.kv_cpu_bytes = kv_cpu_bytes
        self.total_weight_bytes = total_weight_bytes
        self.pool_bytes = pool_bytes
        self.fits_pool = fits_pool

    def total_accounted_bytes(self) -> Int:
        """Weights + KV, both devices: what the pool holds."""
        return self.total_weight_bytes + self.kv_gpu_bytes + self.kv_cpu_bytes

    def line(self) -> String:
        var fit = "FITS_POOL" if self.fits_pool else "EXCEEDS_POOL"
        return (
            "split gpu_layers="
            + String(self.gpu_layers)
            + " cpu_layers="
            + String(self.cpu_layers)
            + " gpu_weights="
            + String(self.gpu_weight_bytes)
            + " cpu_weights="
            + String(self.cpu_weight_bytes)
            + " kv_gpu="
            + String(self.kv_gpu_bytes)
            + " kv_cpu="
            + String(self.kv_cpu_bytes)
            + " total="
            + String(self.total_accounted_bytes())
            + " pool="
            + String(self.pool_bytes)
            + " "
            + fit
        )


def plan_layer_split(
    layer_bytes: List[Int],
    embed_bytes: Int,
    output_bytes: Int,
    gpu_budget_bytes: Int,
    pool_bytes: Int,
    ctx_tokens: Int,
    kv_heads: Int,
    head_dim: Int,
) -> LayerSplitPlan:
    """Solve the GPU/CPU layer split under a byte budget.

    The embedding block is charged to the GPU first when
    the budget covers it AND at least one (suffix) layer
    also fits; otherwise the plan is all-CPU (a GPU holding
    only the embedding with zero layers is not a split).
    Layers fill from the END of the stack (the executor's
    suffix convention); a layer that does not fit stops
    the fill. The output block rides the GPU only in a
    full split; in a partial split it stays on the CPU,
    as measured.
    """
    var total_layers = len(layer_bytes)
    var total_weights = embed_bytes + output_bytes
    for i in range(total_layers):
        total_weights += layer_bytes[i]
    var kv_total = kv_bytes_for_layers(total_layers, ctx_tokens, kv_heads, head_dim)
    var fits = (total_weights + kv_total) <= pool_bytes
    var gpu_layers = 0
    var gpu_weights = 0
    if gpu_budget_bytes >= embed_bytes and total_layers > 0:
        var room = gpu_budget_bytes - embed_bytes
        var spent = 0
        for i in range(total_layers):
            var layer = layer_bytes[total_layers - 1 - i]
            if spent + layer <= room:
                spent += layer
                gpu_layers += 1
            else:
                break
        if gpu_layers > 0:
            gpu_weights = embed_bytes + spent
            if gpu_layers == total_layers:
                gpu_weights += output_bytes
    var cpu_weights = total_weights - gpu_weights
    var kv_gpu = kv_bytes_for_layers(gpu_layers, ctx_tokens, kv_heads, head_dim)
    var kv_cpu = kv_total - kv_gpu
    return LayerSplitPlan(
        gpu_layers,
        total_layers - gpu_layers,
        gpu_weights,
        cpu_weights,
        kv_gpu,
        kv_cpu,
        total_weights,
        pool_bytes,
        fits,
    )


def llama31_8b_q4km_layer_bytes() -> List[Int]:
    """Per-layer GGUF directory spans (offset deltas, so
    alignment padding between tensors is included) of the
    sha-pinned A-067 fixture
    Meta-Llama-3.1-8B-Instruct-Q4_K_M.gguf, sha256
    7b064f5842bf9532c91456deda288a1b672397a54fa729aa665952863033557c.
    Measured on purpleraider with the llama.cpp gguf-py
    reader (hidden_files/a104/layer_bytes.txt): layers sum
    to 4,186,439,680 and the non-layer block (token_embd +
    output + output_norm) spans 726,458,624; the tensor
    payload total is 4,912,898,304 of the 4,920,739,232-byte
    file (the rest is GGUF metadata)."""
    var layers = List[Int]()
    layers.append(138936320)
    layers.append(138936320)
    layers.append(138936320)
    layers.append(138936320)
    layers.append(122716160)
    layers.append(122716160)
    layers.append(138936320)
    layers.append(122716160)
    layers.append(122716160)
    layers.append(122716160)
    layers.append(138936320)
    layers.append(122716160)
    layers.append(122716160)
    layers.append(138936320)
    layers.append(122716160)
    layers.append(122716160)
    layers.append(138936320)
    layers.append(122716160)
    layers.append(122716160)
    layers.append(138936320)
    layers.append(122716160)
    layers.append(138936320)
    layers.append(122716160)
    layers.append(122716160)
    layers.append(138936320)
    layers.append(122716160)
    layers.append(122716160)
    layers.append(138936320)
    layers.append(138936320)
    layers.append(138936320)
    layers.append(138936320)
    layers.append(138936320)
    return layers^


alias LLAMA31_8B_NON_LAYER_BYTES = 726458624
alias LLAMA31_8B_EMBED_BYTES = 295501824
alias LLAMA31_8B_OUTPUT_BYTES = 430956800
alias LLAMA31_8B_KV_HEADS = 8
alias LLAMA31_8B_HEAD_DIM = 128
