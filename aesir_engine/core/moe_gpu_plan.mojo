"""GPU-assisted expert streaming: the division plan (Janas road J-031).

J-017 D7 decided residency is not placement: the expert cache holds
device-agnostic bytes, and streamed experts are computed where later
slices measure they should land. J-030 measured the CPU line (the
streamed MoE session, core/moe_session.mojo, is host-only by
construction). This module is the GPU side of that division, stated
as arithmetic the session host can plan against:

- plan_moe_gpu_division divides one MoE model's bytes across host
  and device from directory-true inputs (the J-017 resident set, the
  routed-expert body, per-pair sizes) and a stated usable device
  budget: the resident set goes to the device first (it is small,
  read on every token, and the natural accelerator-resident
  candidate -- J-017 section 2.4); the device then holds the KV
  allowance, an activation allowance, and a device reserve; whatever
  remains is the DEVICE expert cache budget, spent on whole experts
  under exactly the J-018 byte-budget discipline (the unit is atomic:
  a remainder smaller than the largest pair buys no device cache at
  all and the plan says so). If resident + allowances exceed the
  device budget the plan is the CPU line, stated plainly, with every
  device allocation zero.
- plan_moe_gpu_token_transfers accounts one token's host<->device
  traffic per division, exactly: bytes, never time. The finding the
  accounting exists to make visible: moving streamed experts to the
  GPU does NOT reduce the bytes that move -- a device-cache miss pays
  the J-030 streamed bytes a second time as a host->device upload --
  and the resident-only division (attention on GPU, experts on host)
  pays two hidden-vector crossings per layer per token. Which
  division wins on wall time is a measurement only a live leg can
  make (J-034's gate owns it); this module makes the byte side of
  that measurement exact before anyone runs it.
- moe_gpu_upload_chunks prices a one-time upload through the tree's
  existing bounded pinned staging (core/cuda_upload.mojo,
  MAX_UPLOAD_STAGING_BYTES = 64 MiB, one synchronisation per chunk):
  the open-time cost shape of putting the resident set (and, in the
  full division, the expert body) on the device.

What this module is NOT: it executes nothing. No CUDA context is
created here, no kernel is launched, and no number in its outputs is
a speed. The kernels a live division would reuse exist in the dense
line (core/packed_projection.mojo's block_matvec_kernel serves the
Q4_K / Q5_K / Q6_K kinds OLMoE's slabs carry, at OLMoE's shapes);
the session glue, the OLMoE device profile, and the device-side
expert payload store do not exist yet -- docs/janas/
J031_STREAMING_GPU_LINE.md records the inspection and the exact
guarded recipe that builds and grades them at the J-034 gate.

HOST CONTRACT (binding on the session host that executes a plan;
this module makes no OS or device calls and fakes none):
- The host derives resident/body/pair sizes from the opened file's
  tensor directory (the J-017 section 3.3 contract), samples the
  usable device budget from the device itself (the dense CUDA
  sessions' admission figure, never total VRAM), and states the KV
  and activation allowances it charges. The plan is only as honest
  as those inputs; garbage inputs are refused where they are
  detectable (non-positive sizes, a pair larger than the body).
- A token's transfer account is taken from the expert cache's own
  statistics for that token (misses' exact streamed bytes and the
  count of layers with at least one miss), never estimated from a
  hit rate.
- Faithfulness is graded exactly as the CPU line was: generated ids
  must first equal the CPU line's ids token for token (the J-030
  section 5 set), then teacher-forcing rank + logit gap against the
  ggml CPU comparator on the raw prompt. A GPU leg that changes ids
  is a defect to bisect, not a number to file.
"""

# Division codes returned by plan_moe_gpu_division.
comptime DIVISION_CPU_ONLY = 0
comptime DIVISION_RESIDENT_GPU = 1
comptime DIVISION_RESIDENT_GPU_EXPERT_CACHE = 2
comptime DIVISION_FULL_GPU = 3

# The tree's existing upload staging bound (core/cuda_upload.mojo's
# MAX_UPLOAD_STAGING_BYTES): one pinned staging buffer, one device
# synchronisation per chunk. Restated here so this module stays a
# lightest-target, device-free planning layer; the value must move
# with cuda_upload's if that bound ever changes.
comptime UPLOAD_STAGING_BYTES = 67108864


def moe_gpu_upload_chunks(total_bytes: Int) raises -> Int:
    """Synchronised staging chunks a one-time upload of total_bytes
    costs through the existing bounded pinned staging."""
    if total_bytes < 0:
        raise Error("MoE GPU upload bytes out of range")
    if total_bytes == 0:
        return 0
    return (total_bytes + UPLOAD_STAGING_BYTES - 1) // UPLOAD_STAGING_BYTES


struct MoeGpuPlan(Copyable, ImplicitlyCopyable):
    """One host/device division of an MoE model, stated in full."""

    var division: Int
    var resident_bytes: Int
    var expert_body_bytes: Int
    var device_budget_bytes: Int
    var kv_allowance_bytes: Int
    var activation_bytes: Int
    var reserve_bytes: Int
    var device_resident_bytes: Int
    var device_expert_budget_bytes: Int
    var device_expert_pairs: Int

    def __init__(
        out self,
        division: Int,
        resident_bytes: Int,
        expert_body_bytes: Int,
        device_budget_bytes: Int,
        kv_allowance_bytes: Int,
        activation_bytes: Int,
        reserve_bytes: Int,
        device_resident_bytes: Int,
        device_expert_budget_bytes: Int,
        device_expert_pairs: Int,
    ):
        self.division = division
        self.resident_bytes = resident_bytes
        self.expert_body_bytes = expert_body_bytes
        self.device_budget_bytes = device_budget_bytes
        self.kv_allowance_bytes = kv_allowance_bytes
        self.activation_bytes = activation_bytes
        self.reserve_bytes = reserve_bytes
        self.device_resident_bytes = device_resident_bytes
        self.device_expert_budget_bytes = device_expert_budget_bytes
        self.device_expert_pairs = device_expert_pairs

    def resident_on_gpu(self) -> Bool:
        return self.division != DIVISION_CPU_ONLY

    def fixed_device_bytes(self) -> Int:
        """Bytes the device holds before any expert does: KV +
        activations + reserve, plus the resident set when it is
        device-resident."""
        var fixed = self.kv_allowance_bytes + self.activation_bytes + self.reserve_bytes
        if self.resident_on_gpu():
            fixed += self.resident_bytes
        return fixed

    def device_total_bytes(self) -> Int:
        """Every byte the plan puts on the device."""
        if not self.resident_on_gpu():
            return 0
        if self.division == DIVISION_FULL_GPU:
            return (
                self.fixed_device_bytes() + self.expert_body_bytes
            )
        return self.fixed_device_bytes() + self.device_expert_budget_bytes

    def describe(self) -> String:
        var name = String("cpu_only")
        if self.division == DIVISION_RESIDENT_GPU:
            name = String("resident_gpu")
        elif self.division == DIVISION_RESIDENT_GPU_EXPERT_CACHE:
            name = String("resident_gpu_expert_cache")
        elif self.division == DIVISION_FULL_GPU:
            name = String("full_gpu")
        return (
            "division="
            + name
            + " resident_bytes="
            + String(self.resident_bytes)
            + " expert_body_bytes="
            + String(self.expert_body_bytes)
            + " device_budget_bytes="
            + String(self.device_budget_bytes)
            + " kv_allowance_bytes="
            + String(self.kv_allowance_bytes)
            + " activation_bytes="
            + String(self.activation_bytes)
            + " reserve_bytes="
            + String(self.reserve_bytes)
            + " device_resident_bytes="
            + String(self.device_resident_bytes)
            + " device_expert_budget_bytes="
            + String(self.device_expert_budget_bytes)
            + " device_expert_pairs="
            + String(self.device_expert_pairs)
            + " device_total_bytes="
            + String(self.device_total_bytes())
        )


def plan_moe_gpu_division(
    resident_bytes: Int,
    expert_body_bytes: Int,
    mean_pair_bytes: Int,
    largest_pair_bytes: Int,
    kv_allowance_bytes: Int,
    activation_bytes: Int,
    reserve_bytes: Int,
    device_budget_bytes: Int,
) raises -> MoeGpuPlan:
    """Divide an MoE model between host and device, in bytes.

    The resident set (J-017 D1: embeddings, attention, norms,
    routers, shared experts, output head) is placed on the device
    first; KV allowance, activation allowance and device reserve are
    charged next; the remainder is the device expert cache budget.
    Divisions, in the order the budget buys them:

    - CPU_ONLY: resident + allowances exceed the device budget; the
      J-030 CPU line stands and the plan allocates nothing.
    - RESIDENT_GPU: the resident set fits but the remainder cannot
      hold even the largest whole expert (the J-017 atomic unit) --
      no device expert cache; experts stay in the host cache and
      compute on the host, at the per-layer hidden-crossing cost
      plan_moe_gpu_token_transfers states.
    - RESIDENT_GPU_EXPERT_CACHE: the remainder holds whole experts;
      streamed experts are uploaded on a device-cache miss and
      computed where they land. device_expert_pairs is derived at
      the mean pair size and labelled as such -- pair sizes are
      layer-dependent (J-015), so the byte budget governs and the
      pair count is indicative.
    - FULL_GPU: resident + allowances + the whole expert body fit;
      streaming degenerates to full residency (the J-017 section 4.3
      degenerate case, on the device).
    """
    if resident_bytes <= 0 or expert_body_bytes <= 0:
        raise Error("MoE GPU division model sizes must be positive")
    if mean_pair_bytes <= 0 or largest_pair_bytes <= 0:
        raise Error("MoE GPU division pair sizes must be positive")
    if largest_pair_bytes < mean_pair_bytes:
        raise Error("MoE GPU division largest pair below the mean pair")
    if largest_pair_bytes > expert_body_bytes:
        raise Error("MoE GPU division pair larger than the expert body")
    if (
        kv_allowance_bytes < 0
        or activation_bytes < 0
        or reserve_bytes < 0
        or device_budget_bytes < 0
    ):
        raise Error("MoE GPU division allowances out of range")
    var fixed = resident_bytes + kv_allowance_bytes + activation_bytes + reserve_bytes
    if fixed > device_budget_bytes:
        return MoeGpuPlan(
            DIVISION_CPU_ONLY,
            resident_bytes,
            expert_body_bytes,
            device_budget_bytes,
            kv_allowance_bytes,
            activation_bytes,
            reserve_bytes,
            0,
            0,
            0,
        )
    var remainder = device_budget_bytes - fixed
    if remainder >= expert_body_bytes:
        return MoeGpuPlan(
            DIVISION_FULL_GPU,
            resident_bytes,
            expert_body_bytes,
            device_budget_bytes,
            kv_allowance_bytes,
            activation_bytes,
            reserve_bytes,
            resident_bytes,
            expert_body_bytes,
            expert_body_bytes // mean_pair_bytes,
        )
    if remainder < largest_pair_bytes:
        return MoeGpuPlan(
            DIVISION_RESIDENT_GPU,
            resident_bytes,
            expert_body_bytes,
            device_budget_bytes,
            kv_allowance_bytes,
            activation_bytes,
            reserve_bytes,
            resident_bytes,
            remainder,
            0,
        )
    return MoeGpuPlan(
        DIVISION_RESIDENT_GPU_EXPERT_CACHE,
        resident_bytes,
        expert_body_bytes,
        device_budget_bytes,
        kv_allowance_bytes,
        activation_bytes,
        reserve_bytes,
        resident_bytes,
        remainder,
        remainder // mean_pair_bytes,
    )


struct MoeGpuTokenTransfers(Copyable, ImplicitlyCopyable):
    """One token's host<->device traffic under a division, in bytes.

    Crossings are synchronised transfer batches, the unit the dense
    line's upload path actually pays (one synchronisation per staged
    chunk / per copy). Bytes are exact given the caller's exact
    streamed-bytes input; no time is stated or implied.
    """

    var h2d_expert_bytes: Int
    var h2d_hidden_bytes: Int
    var d2h_hidden_bytes: Int
    var h2d_token_bytes: Int
    var d2h_token_bytes: Int
    var crossings: Int

    def __init__(
        out self,
        h2d_expert_bytes: Int,
        h2d_hidden_bytes: Int,
        d2h_hidden_bytes: Int,
        h2d_token_bytes: Int,
        d2h_token_bytes: Int,
        crossings: Int,
    ):
        self.h2d_expert_bytes = h2d_expert_bytes
        self.h2d_hidden_bytes = h2d_hidden_bytes
        self.d2h_hidden_bytes = d2h_hidden_bytes
        self.h2d_token_bytes = h2d_token_bytes
        self.d2h_token_bytes = d2h_token_bytes
        self.crossings = crossings

    def total_bytes(self) -> Int:
        return (
            self.h2d_expert_bytes
            + self.h2d_hidden_bytes
            + self.d2h_hidden_bytes
            + self.h2d_token_bytes
            + self.d2h_token_bytes
        )

    def describe(self) -> String:
        return (
            "h2d_expert_bytes="
            + String(self.h2d_expert_bytes)
            + " h2d_hidden_bytes="
            + String(self.h2d_hidden_bytes)
            + " d2h_hidden_bytes="
            + String(self.d2h_hidden_bytes)
            + " h2d_token_bytes="
            + String(self.h2d_token_bytes)
            + " d2h_token_bytes="
            + String(self.d2h_token_bytes)
            + " crossings="
            + String(self.crossings)
            + " total_bytes="
            + String(self.total_bytes())
        )


def plan_moe_gpu_token_transfers(
    plan: MoeGpuPlan,
    layer_count: Int,
    hidden: Int,
    streamed_bytes: Int,
    miss_layers: Int,
) raises -> MoeGpuTokenTransfers:
    """Account one token's transfers under a planned division.

    Inputs are the token's own facts: streamed_bytes is the exact
    byte sum the expert cache streamed for this token (its
    bytes_streamed delta), and miss_layers is the number of layers
    with at least one miss (uploads batch per layer, following the
    session's existing per-layer willneed batching). The hidden
    vector is f16: hidden * 2 bytes per crossing.

    - CPU_ONLY: no device traffic at all.
    - RESIDENT_GPU: experts compute on the host, so the normed
      hidden vector crosses device->host and the MoE output crosses
      back at EVERY layer: 2 crossings and 2 * hidden * 2 bytes per
      layer, plus the token id in and the result token out. This is
      the division's honest price, stated so it is never built by
      accident.
    - RESIDENT_GPU_EXPERT_CACHE: the layer stack never leaves the
      device; a miss's slabs are uploaded once, batched per miss
      layer (h2d_expert_bytes == streamed_bytes exactly -- GPU
      assistance re-pays the streamed bytes, it does not shrink
      them), plus token in / token out and one final synchronisation.
    - FULL_GPU: no expert traffic after warm-up; the caller's
      streamed_bytes must be 0 for a warm token (a cold token under
      FULL is an open-time upload, priced by moe_gpu_upload_chunks,
      not a per-token transfer).
    """
    if layer_count <= 0 or hidden <= 0:
        raise Error("MoE GPU transfer shape out of range")
    if streamed_bytes < 0 or miss_layers < 0 or miss_layers > layer_count:
        raise Error("MoE GPU transfer token facts out of range")
    if plan.division == DIVISION_CPU_ONLY:
        return MoeGpuTokenTransfers(0, 0, 0, 0, 0, 0)
    if plan.division == DIVISION_RESIDENT_GPU:
        var per_crossing = hidden * 2
        return MoeGpuTokenTransfers(
            0,
            per_crossing * layer_count,
            per_crossing * layer_count,
            4,
            4,
            2 * layer_count,
        )
    if plan.division == DIVISION_RESIDENT_GPU_EXPERT_CACHE:
        if (streamed_bytes == 0) != (miss_layers == 0):
            raise Error(
                "MoE GPU transfer miss facts disagree: streamed bytes"
                " and miss layers must both be zero or both nonzero"
            )
        return MoeGpuTokenTransfers(
            streamed_bytes, 0, 0, 4, 4, 1 + miss_layers
        )
    # FULL_GPU
    if streamed_bytes != 0 or miss_layers != 0:
        raise Error(
            "MoE GPU full division takes no per-token expert traffic;"
            " cold misses are open-time uploads"
        )
    return MoeGpuTokenTransfers(0, 0, 0, 4, 4, 1)
