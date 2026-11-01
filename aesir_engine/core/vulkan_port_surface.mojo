"""Vulkan question: the port-surface account (Janas road J-066).

The roadmap text: "Janas reaches every GPU through Vulkan;
Aesir's proven road is CUDA. Whether a Vulkan compute path
buys Aesir anything (portability to non-NVIDIA GPUs) is
measured as a spike: a single prefill kernel both ways, or a
written verdict from the tree's existing abstractions. No
rewrite committed on a hunch."

This module is the checkable half of that verdict
(docs/janas/J066_VULKAN_QUESTION.md is its normative text).
It accounts, in pure arithmetic, exactly what a Vulkan
compute path would have to reproduce in this tree, and it
evaluates the pre-registered verdict rule (doc section 3)
over a stated evidence record. It executes nothing, opens
no device, compiles no shader, and contains no speed.
There is no path through the verdict account to BUILD_NOW
with an evidence item missing: the verdict is a conjunction
over the record, and tonight's true record (no non-NVIDIA
hardware in hand, no named consumer waiting on it, no spike
measured anywhere) evaluates to DEFER, with REFUSE reserved
for a spike that was actually measured and either failed
faithfulness or bought nothing on the target hardware.

THE PORT SURFACE (doc section 2, machine-recounted by
docs/janas/j066_inspect.py at this tree):

  packed matvec forms -- core/packed_projection.mojo:
    block_matvec_kernel (width 1) and four_matvec_kernel
    (width 4), kinds 12 (Q4_K) / 13 (Q5_K) / 14 (Q6_K),
    columns divisible by 256. The width-1 kind-12 form is
    the spike kernel named by the reopen recipe.
  llama device functions -- core/llama3_kernels.mojo: 15
    (bias, residual x2 forms, rope x4 forms, cache x2
    forms, silu x2 forms, scores, softmax, attention,
    attention_tiled).
  gemma kernels -- core/gemma4_kernels.mojo: 12 *_kernel
    functions (embedding, matvec, packed matvec, norm,
    element, rope, cache, scores, softmax, attention,
    argmax, span copy).
  cuda-compute kernels -- core/cuda_compute.mojo: 7
    (f16 GEMM, rmsnorm, silu, swiglu, rope, dequantize
    Q4_0, dequantize Q8_0).
  session kernels -- core/llama3_cuda.mojo:
    copy_hidden_kernel (1).
  fused / packed-matrix kernels: fused_attention_kernel,
    small_attention_kernel, packed_matrix_kernel (3).

  TOTAL: 40 kernel families. On top of the kernels, a
  Vulkan path needs 8 infrastructure items that today are
  CUDA-shaped or absent (doc section 2, I1-I8): device
  discovery, buffer/memory management, upload staging,
  command submission + synchronisation, a shader build
  pipeline with a driver self-check, the two session
  surfaces re-hosted, inventory/CLI truth for Vulkan
  devices, and a J-060 battery re-grade of the new
  backend. The Turing/MMA family (packed_turing_*,
  turing_mma_probe) is deliberately NOT in the surface:
  those kernels are CUDA tensor-core probes no session
  imports, and MMA capability is vendor-shaped in Vulkan
  too (cooperative-matrix extensions) -- a port does not
  inherit them and must not claim them.

THE SEAM (doc section 2): there is none at the backend
level. The two sessions are concrete structs holding a
MAX DeviceContext directly; 15 core modules import
max.gpu; 7 sites guard api() != "cuda" and fail closed.
The MAX context is the only abstraction and it is used
CUDA-only; Mojo GPU kernels in this tree compile through
MAX for CUDA, and no in-tree path emits SPIR-V, GLSL, or
any shader artefact (the only Vulkan word in .mojo code
is cli/hardware.mojo:44, "execution not implemented").

HOST CONTRACT: a future spike or port cites this account
by re-running j066_inspect.py on its tree first; if the
recounted surface differs from the pinned constants, the
account is stale and the difference is itself a finding.
Faithfulness grading for any live leg is the road's
raw-oracle discipline: ids first, then teacher-forcing
rank + logit gap against a CPU comparator on the raw
prompt; never llama-cli --single-turn.
"""

comptime VERDICT_DEFER = 0
comptime VERDICT_BUILD_NOW = 1
comptime VERDICT_REFUSE = 2

# Kernel families, pinned from j066_inspect.py at this tree.
comptime PACKED_MATVEC_FORMS = 2
comptime LLAMA_KERNEL_FUNCTIONS = 15
comptime GEMMA_KERNELS = 12
comptime CUDA_COMPUTE_KERNELS = 7
comptime SESSION_KERNELS = 1
comptime FUSED_MATRIX_KERNELS = 3

# Quantization kinds the proven CUDA prefill kernels serve
# (packed_projection kinds 12/13/14) plus the dequantize
# kinds in cuda_compute (Q4_0 / Q8_0).
comptime PREFILL_QUANT_KINDS = 3
comptime DEQUANT_KINDS = 2

# Session surfaces a port must re-host.
comptime SESSION_SURFACES = 2

# Infrastructure items I1-I8 (doc section 2).
comptime INFRA_ITEMS = 8


struct VulkanPortSurface(Copyable, ImplicitlyCopyable):
    """The full port account at this tree."""

    var packed_matvec_forms: Int
    var llama_kernel_functions: Int
    var gemma_kernels: Int
    var cuda_compute_kernels: Int
    var session_kernels: Int
    var fused_matrix_kernels: Int
    var kernel_families_total: Int
    var prefill_quant_kinds: Int
    var dequant_kinds: Int
    var session_surfaces: Int
    var infra_items: Int
    var work_items_total: Int

    def __init__(out self):
        self.packed_matvec_forms = PACKED_MATVEC_FORMS
        self.llama_kernel_functions = LLAMA_KERNEL_FUNCTIONS
        self.gemma_kernels = GEMMA_KERNELS
        self.cuda_compute_kernels = CUDA_COMPUTE_KERNELS
        self.session_kernels = SESSION_KERNELS
        self.fused_matrix_kernels = FUSED_MATRIX_KERNELS
        self.kernel_families_total = (
            PACKED_MATVEC_FORMS + LLAMA_KERNEL_FUNCTIONS + GEMMA_KERNELS
            + CUDA_COMPUTE_KERNELS + SESSION_KERNELS + FUSED_MATRIX_KERNELS
        )
        self.prefill_quant_kinds = PREFILL_QUANT_KINDS
        self.dequant_kinds = DEQUANT_KINDS
        self.session_surfaces = SESSION_SURFACES
        self.infra_items = INFRA_ITEMS
        self.work_items_total = (
            self.kernel_families_total + SESSION_SURFACES + INFRA_ITEMS
        )


def port_surface() -> VulkanPortSurface:
    """The port surface, exactly as inspected at this tree."""
    return VulkanPortSurface()


def evaluate_vulkan_verdict(
    hardware_in_hand: Bool,
    named_consumer: Bool,
    spike_measured: Bool,
    spike_faithful: Bool,
    spike_competitive: Bool,
) -> Int:
    """The pre-registered verdict rule (doc section 3).

    - A spike that ran and was not faithful is REFUSE: a
      second backend whose prefill kernel cannot match the
      proven road's numerics is a faithfulness liability,
      not a portability asset.
    - A spike that ran, was faithful, and bought nothing
      on the target hardware is REFUSE for that shape:
      portability that is slower than the CPU fallback it
      replaces buys Aesir nothing there.
    - BUILD_NOW requires all five: hardware in hand, a
      named consumer, and a spike measured faithful and
      competitive on that hardware. Unmeasured flags earn
      nothing -- faithful/competitive asserted without a
      measurement do not count.
    - Everything else is DEFER.
    """
    if spike_measured and not spike_faithful:
        return VERDICT_REFUSE
    if spike_measured and not spike_competitive:
        return VERDICT_REFUSE
    if (
        hardware_in_hand and named_consumer and spike_measured
        and spike_faithful and spike_competitive
    ):
        return VERDICT_BUILD_NOW
    return VERDICT_DEFER


def verdict_name(code: Int) raises -> String:
    if code == VERDICT_DEFER:
        return String("DEFER")
    if code == VERDICT_BUILD_NOW:
        return String("BUILD_NOW")
    if code == VERDICT_REFUSE:
        return String("REFUSE")
    raise Error("VulkanPortSurface: unknown verdict code")
