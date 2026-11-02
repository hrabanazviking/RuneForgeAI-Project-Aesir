"""Draft-check placement: drafts + placement (Janas road J-081).

The roadmap text: "Drafts + placement. Draft-check passes
placed by Part III's engine (GPU check of CPU drafts and the
reverse), the fastest honest combination kept."

THE QUESTION. A speculative round (J-071/J-072) has two
passes on possibly different hardware: the DRAFT pass, which
proposes k tokens in k sequential width-1 steps, and the
CHECK (verify) pass, which forwards k+1 positions in ONE
batched pass over the target model. Part III's placement
engine (J-035--J-052) decides what runs where; J-042 built
the draft-check CHOOSER, which today can only file
NO-MEASURED-FALLBACK because no draft-check pass exists to
measure (gap G1). This module is the missing planning layer
J-042/J-071 name as J-081's input: given a proposer/target
PAIR, a DEVICE SET, and a ROUND SHAPE, it prices every
placement combination in the road's own currencies and
returns a verdict per combination, refusing combinations
whose required pieces do not exist in-tree BY NAME.

THE VERDICT RULE, pre-registered (written here and in
docs/janas/J081_DRAFTS_PLACEMENT.md section 1 before any
combination below was priced):

- GLOBAL BLOCKERS cap every combination at PLAN class:
  (G-PROPOSER) no proposer implementation exists in-tree
  for any kind on any device, and (G-EXECUTOR) no
  verify-pass executor exists in-tree --
  require_draft_check_use() (J-036) still raises and the
  facade's speculative_generate still raises
  not-implemented. Because of these, NO combination in
  this module is an executable or measured claim, and no
  speed, wall, or tok/s is stated or implied anywhere in
  its accounts. A combination may be KEPT as the recorded
  placement POLICY -- the placement the engine will use
  when the global blockers land -- never as measured speed.
- COMBINATION-SPECIFIC REFUSALS, checked in this order,
  first applicable name wins: (1) a device the combination
  needs is absent from the stated device set; (2) a
  conversation proposer placed off the host CPU -- it has
  no model to place (J-071: copied text, no KV); (3) any
  pass on an integrated GPU -- no iGPU backend exists
  (J-066 DEFER; J-067 teaches its shape, builds no
  executor); (4) an MoE model placed on a discrete GPU --
  no MoE device admission/profile, no device expert
  payload store, no OLMoE device block maths (J-031's
  named missing pieces); (5) a GPU check pass whose width
  w = k+1 is not the one proven tile shape -- width 4,
  and then only on the tile-admitted profile (J-054:
  widths 1 and 4 are the proven shapes; width 4 is
  admitted only for the exercised Llama 3.2 3B profile).
  A refused combination is still PRICED as a plan (its
  byte/crossing account is stated), so the cost of
  building it stays visible.
- KEEP ELIGIBILITY + RANKING. Among combinations that are
  not refused: the check pass is the target model's pass,
  the expensive pass of the round, so accelerator-first
  (the Aesir standing law: NPU, then GPU, then CPU spill
  only) binds it first -- keep-eligible combinations are
  exactly those whose check device is the highest-ranked
  check device among the non-refused combinations
  (discrete GPU above iGPU above CPU). Among the
  eligible, the kept combination is the one with
  (a) fewest synchronised crossings per round, then
  (b) fewest total device-crossing bytes per round
  (H2D + D2H), then (c) fewest contended bytes, then
  (d) the lowest combination code (deterministic order:
  draft CPU, then GPU, then iGPU). Exactly one
  combination is kept per (pair, device set, round shape).

PRICING, in the road's own currencies (all per round):

- TOKEN IDS cross at 4 bytes each (J-031's token account).
  Draft tokens cross once when draft and check devices
  differ (k ids, draft -> check direction). The target's
  greedy list (w = k+1 ids) crosses back to the host CPU
  session when the check ran on a discrete GPU.
- SYNCHRONISED CROSSINGS: a width-1 pass on a discrete
  GPU synchronises once per token (J-053/J-054 decode
  discipline), so a GPU draft pays k; a batched GPU check
  pays 1 for the pass plus 1 per inter-device transfer
  batch plus, for an MoE check, 1 per miss layer (J-031:
  uploads batch per miss layer). CPU passes pay 0. iGPU
  passes pay 0 copy crossings -- there is no bus (J-067).
- COUPLED PROPOSERS: an MTP head shares the target's
  forward state and an assistant model reads the target's
  KV (J-071), so splitting a coupled proposer's draft
  away from the check device crosses the target hidden
  vector once per draft step (k x hidden bytes, check ->
  draft direction, k extra synchronised crossings when a
  discrete GPU is one side). A cross-model proposer
  carries its own KV and a conversation proposer has no
  state: for them only token ids cross.
- EXPERT STREAM (J-080's currency): the caller states the
  verify batch's streamed bytes for the round
  (batch_streamed_bytes, J-080's BATCH-ALL account for the
  round, waste included, normalised per emitted token in
  J-080's own tables). A CPU check streams them on the
  host (host_streamed_bytes, no device crossing). A
  discrete-GPU check RE-PAYS exactly those bytes as an
  H2D upload (J-031: GPU assistance relocates compute, it
  does not shrink byte traffic). An iGPU check pays them
  as contended bytes, never copy bytes (J-067). A draft
  model's own streamed bytes are priced the same way by
  its own device.
- iGPU CONTENDED BYTES: a pass on an iGPU touches its
  weights on the shared fabric -- the draft k times
  (width-1 steps re-read), the check once (batched) --
  plus any streamed bytes above. Zero copy bytes, always.
- OPEN-TIME residency (weights uploaded once, staging
  chunks per J-031/J-054) is NOT a per-round cost and is
  not charged here.

This module is pure arithmetic: it executes no forward,
opens no device, times nothing, and lifts no gate. It does
not register in run_all (the J-031 precedent: registration
rides with the counted run the VM's memory gate does not
permit; the standalone suite is the filed evidence).

HOST CONTRACT: the caller states the pair and round shape
from directory-true facts (the opened files' shapes, the
J-071 proposer shape via plan_proposer, the device set
from J-037 inventory truth, streamed bytes from the expert
cache's own statistics in J-080's accounting); garbage
inputs are refused where detectable. When the global
blockers land, the host places each round by
choose_draft_check_placement() once per session (the
J-042 session-keeping pattern) and files the kept plan's
account beside the round's J-071 account.
"""
from core.speculative_verify import plan_proposer

# Devices.
comptime DC_DEV_CPU = 0
comptime DC_DEV_GPU = 1
comptime DC_DEV_IGPU = 2

# Combination-specific missing pieces, in check order.
comptime DC_MISSING_NONE = 0
comptime DC_MISSING_DEVICE_ABSENT = 1
comptime DC_MISSING_CONVERSATION_DEVICE = 2
comptime DC_MISSING_IGPU_BACKEND = 3
comptime DC_MISSING_MOE_GPU_ADMISSION = 4
comptime DC_MISSING_VERIFY_WIDTH = 5

# Per-combination verdicts.
comptime DC_VERDICT_PRICED = 0
comptime DC_VERDICT_REFUSED_UNBUILT = 1

# Token ids cross at 4 bytes (J-031's token account).
comptime DC_TOKEN_ID_BYTES = 4


def dc_device_name(code: Int) raises -> String:
    if code == DC_DEV_CPU:
        return String("cpu")
    if code == DC_DEV_GPU:
        return String("gpu")
    if code == DC_DEV_IGPU:
        return String("igpu")
    raise Error("SpeculativePlacement: unknown device code")


def dc_missing_name(code: Int) raises -> String:
    if code == DC_MISSING_NONE:
        return String("none")
    if code == DC_MISSING_DEVICE_ABSENT:
        return String("device absent from the stated device set")
    if code == DC_MISSING_CONVERSATION_DEVICE:
        return String(
            "conversation proposer has no device model to place"
            " (J-071: copied text, no model, no KV)"
        )
    if code == DC_MISSING_IGPU_BACKEND:
        return String(
            "no iGPU backend exists in-tree (J-066 DEFER;"
            " J-067 teaches the shape, builds no executor)"
        )
    if code == DC_MISSING_MOE_GPU_ADMISSION:
        return String(
            "no MoE device admission: no MoE device profile,"
            " no device expert payload store, no OLMoE device"
            " block maths (J-031)"
        )
    if code == DC_MISSING_VERIFY_WIDTH:
        return String(
            "GPU verify-batch executor at this width unbuilt"
            " (J-054: only width 1 and width 4 are proven"
            " shapes, width 4 only on the tile-admitted"
            " Llama 3.2 3B profile)"
        )
    raise Error("SpeculativePlacement: unknown missing-piece code")


def dc_verdict_name(code: Int) raises -> String:
    if code == DC_VERDICT_PRICED:
        return String("PRICED")
    if code == DC_VERDICT_REFUSED_UNBUILT:
        return String("REFUSED_UNBUILT")
    raise Error("SpeculativePlacement: unknown verdict code")


def dc_combo_code(draft_device: Int, check_device: Int) -> Int:
    """Deterministic combination order: draft-major, then
    check, each CPU, GPU, iGPU."""
    return draft_device * 3 + check_device


struct DraftCheckShape(Copyable, ImplicitlyCopyable):
    """One (pair, device set, round shape) stated in full.

    Every field is caller-stated from directory-true facts;
    plan_draft_check_combo refuses the detectable garbage.
    tile4_profile states that the TARGET profile is the one
    tile-admitted profile of J-054 (Llama 3.2 3B shape).
    batch_streamed_bytes / miss_layers are the target's
    verify-batch expert facts (J-080/J-031); the draft's own
    pair is draft_streamed_bytes / draft_miss_layers.
    """

    var proposer_kind: Int
    var k: Int
    var target_is_moe: Bool
    var draft_is_moe: Bool
    var tile4_profile: Bool
    var has_gpu: Bool
    var has_igpu: Bool
    var target_hidden_bytes: Int
    var draft_hidden_bytes: Int
    var target_layers: Int
    var draft_layers: Int
    var target_weight_bytes: Int
    var draft_weight_bytes: Int
    var batch_streamed_bytes: Int
    var miss_layers: Int
    var draft_streamed_bytes: Int
    var draft_miss_layers: Int

    def __init__(
        out self,
        proposer_kind: Int,
        k: Int,
        target_is_moe: Bool,
        draft_is_moe: Bool,
        tile4_profile: Bool,
        has_gpu: Bool,
        has_igpu: Bool,
        target_hidden_bytes: Int,
        draft_hidden_bytes: Int,
        target_layers: Int,
        draft_layers: Int,
        target_weight_bytes: Int,
        draft_weight_bytes: Int,
        batch_streamed_bytes: Int,
        miss_layers: Int,
        draft_streamed_bytes: Int,
        draft_miss_layers: Int,
    ):
        self.proposer_kind = proposer_kind
        self.k = k
        self.target_is_moe = target_is_moe
        self.draft_is_moe = draft_is_moe
        self.tile4_profile = tile4_profile
        self.has_gpu = has_gpu
        self.has_igpu = has_igpu
        self.target_hidden_bytes = target_hidden_bytes
        self.draft_hidden_bytes = draft_hidden_bytes
        self.target_layers = target_layers
        self.draft_layers = draft_layers
        self.target_weight_bytes = target_weight_bytes
        self.draft_weight_bytes = draft_weight_bytes
        self.batch_streamed_bytes = batch_streamed_bytes
        self.miss_layers = miss_layers
        self.draft_streamed_bytes = draft_streamed_bytes
        self.draft_miss_layers = draft_miss_layers

    def verify_width(self) -> Int:
        return self.k + 1


struct DraftCheckPlan(Copyable, ImplicitlyCopyable):
    """One combination's priced account and verdict."""

    var draft_device: Int
    var check_device: Int
    var verdict: Int
    var missing: Int
    var keep_eligible: Bool
    var h2d_bytes: Int
    var d2h_bytes: Int
    var contended_bytes: Int
    var sync_crossings: Int
    var host_streamed_bytes: Int
    var expert_h2d_bytes: Int

    def __init__(
        out self,
        draft_device: Int,
        check_device: Int,
        verdict: Int,
        missing: Int,
        keep_eligible: Bool,
        h2d_bytes: Int,
        d2h_bytes: Int,
        contended_bytes: Int,
        sync_crossings: Int,
        host_streamed_bytes: Int,
        expert_h2d_bytes: Int,
    ):
        self.draft_device = draft_device
        self.check_device = check_device
        self.verdict = verdict
        self.missing = missing
        self.keep_eligible = keep_eligible
        self.h2d_bytes = h2d_bytes
        self.d2h_bytes = d2h_bytes
        self.contended_bytes = contended_bytes
        self.sync_crossings = sync_crossings
        self.host_streamed_bytes = host_streamed_bytes
        self.expert_h2d_bytes = expert_h2d_bytes

    def total_crossing_bytes(self) -> Int:
        return self.h2d_bytes + self.d2h_bytes

    def combo_code(self) -> Int:
        return dc_combo_code(self.draft_device, self.check_device)

    def describe(self) raises -> String:
        return (
            "draft="
            + dc_device_name(self.draft_device)
            + " check="
            + dc_device_name(self.check_device)
            + " verdict="
            + dc_verdict_name(self.verdict)
            + " missing="
            + dc_missing_name(self.missing)
            + " keep_eligible="
            + String(self.keep_eligible)
            + " h2d_bytes="
            + String(self.h2d_bytes)
            + " d2h_bytes="
            + String(self.d2h_bytes)
            + " contended_bytes="
            + String(self.contended_bytes)
            + " sync_crossings="
            + String(self.sync_crossings)
            + " host_streamed_bytes="
            + String(self.host_streamed_bytes)
            + " expert_h2d_bytes="
            + String(self.expert_h2d_bytes)
        )


def _device_present(shape: DraftCheckShape, device: Int) -> Bool:
    if device == DC_DEV_CPU:
        return True
    if device == DC_DEV_GPU:
        return shape.has_gpu
    return shape.has_igpu


def _check_rank(device: Int) -> Int:
    if device == DC_DEV_GPU:
        return 2
    if device == DC_DEV_IGPU:
        return 1
    return 0


def plan_draft_check_combo(
    shape: DraftCheckShape, draft_device: Int, check_device: Int
) raises -> DraftCheckPlan:
    """Price one combination and return its verdict.

    keep_eligible on a single-combo plan states only the
    accelerator-first half of the rule as far as one combo
    can state it (check on a discrete GPU, or check on CPU
    when the set holds no discrete GPU); the full ranking
    over all combinations is choose_draft_check_placement's,
    which additionally requires the check device to be the
    highest-ranked among the NON-REFUSED combinations.
    Refused combinations are priced exactly like priced
    ones -- the account is the cost of building them.
    """
    var proposer = plan_proposer(shape.proposer_kind)
    if shape.k < 1 or shape.k > proposer.max_k:
        raise Error(
            "SpeculativePlacement: k outside 1..the proposer's"
            " stated cap (J-071)"
        )
    if draft_device < 0 or draft_device > 2 or check_device < 0 or check_device > 2:
        raise Error("SpeculativePlacement: device code out of range")
    if shape.target_hidden_bytes <= 0 or shape.draft_hidden_bytes <= 0:
        raise Error("SpeculativePlacement: hidden sizes must be positive")
    if shape.target_layers <= 0 or shape.draft_layers <= 0:
        raise Error("SpeculativePlacement: layer counts must be positive")
    if shape.target_weight_bytes <= 0 or shape.draft_weight_bytes <= 0:
        raise Error("SpeculativePlacement: weight sizes must be positive")
    if shape.batch_streamed_bytes < 0 or shape.draft_streamed_bytes < 0:
        raise Error("SpeculativePlacement: streamed bytes out of range")
    if shape.miss_layers < 0 or shape.miss_layers > shape.target_layers:
        raise Error("SpeculativePlacement: miss layers out of range")
    if shape.draft_miss_layers < 0 or shape.draft_miss_layers > shape.draft_layers:
        raise Error("SpeculativePlacement: draft miss layers out of range")
    var k = shape.k
    var w = shape.verify_width()
    var coupled = (
        shape.proposer_kind == 0 or shape.proposer_kind == 1
    )  # MTP head / assistant model share target state (J-071).

    # --- pricing (per round; see the module header) ---
    var h2d = 0
    var d2h = 0
    var contended = 0
    var syncs = 0
    var host_streamed = 0
    var expert_h2d = 0
    # Draft pass synchronisations: width-1 steps on a
    # discrete GPU synchronise once per token.
    if draft_device == DC_DEV_GPU:
        syncs += k
    # Check pass synchronisation: one batched pass.
    if check_device == DC_DEV_GPU:
        syncs += 1
    # Inter-device draft-token transfer.
    if draft_device != check_device:
        var involves_gpu = draft_device == DC_DEV_GPU or check_device == DC_DEV_GPU
        if involves_gpu:
            syncs += 1
            if draft_device == DC_DEV_CPU and check_device == DC_DEV_GPU:
                h2d += k * DC_TOKEN_ID_BYTES
            elif draft_device == DC_DEV_GPU:
                d2h += k * DC_TOKEN_ID_BYTES
            else:
                h2d += k * DC_TOKEN_ID_BYTES
        else:
            # CPU <-> iGPU: shared fabric, no copy.
            contended += k * DC_TOKEN_ID_BYTES
    # Coupled proposers split from the check device cross
    # the target hidden vector once per draft step.
    if coupled and draft_device != check_device:
        var coupled_involves_gpu = (
            draft_device == DC_DEV_GPU or check_device == DC_DEV_GPU
        )
        if coupled_involves_gpu:
            syncs += k
            if check_device == DC_DEV_GPU:
                # State lives with the GPU check; the CPU or
                # iGPU draft reads it device -> host.
                d2h += k * shape.target_hidden_bytes
            else:
                h2d += k * shape.target_hidden_bytes
        else:
            contended += k * shape.target_hidden_bytes
    # The target greedy list returns to the host session
    # when the check ran on a discrete GPU and the draft
    # did not already carry the tokens device -> host
    # (same-device GPU/GPU still returns its list).
    if check_device == DC_DEV_GPU:
        d2h += w * DC_TOKEN_ID_BYTES
    # Expert stream interplay (target).
    if shape.target_is_moe or shape.batch_streamed_bytes > 0:
        if check_device == DC_DEV_CPU:
            host_streamed += shape.batch_streamed_bytes
        elif check_device == DC_DEV_GPU:
            expert_h2d += shape.batch_streamed_bytes
            h2d += shape.batch_streamed_bytes
            syncs += shape.miss_layers
        else:
            contended += shape.batch_streamed_bytes
    # Expert stream interplay (draft model, when it is MoE).
    if shape.draft_is_moe or shape.draft_streamed_bytes > 0:
        if draft_device == DC_DEV_CPU:
            host_streamed += shape.draft_streamed_bytes
        elif draft_device == DC_DEV_GPU:
            expert_h2d += shape.draft_streamed_bytes
            h2d += shape.draft_streamed_bytes
            syncs += shape.draft_miss_layers
        else:
            contended += shape.draft_streamed_bytes
    # iGPU contended weight traffic.
    if draft_device == DC_DEV_IGPU:
        contended += k * shape.draft_weight_bytes
    if check_device == DC_DEV_IGPU:
        contended += shape.target_weight_bytes

    # --- combination-specific refusals, in rule order ---
    var missing = DC_MISSING_NONE
    if not _device_present(shape, draft_device) or not _device_present(
        shape, check_device
    ):
        missing = DC_MISSING_DEVICE_ABSENT
    elif shape.proposer_kind == 3 and draft_device != DC_DEV_CPU:
        missing = DC_MISSING_CONVERSATION_DEVICE
    elif draft_device == DC_DEV_IGPU or check_device == DC_DEV_IGPU:
        missing = DC_MISSING_IGPU_BACKEND
    elif (shape.target_is_moe and check_device == DC_DEV_GPU) or (
        shape.draft_is_moe and draft_device == DC_DEV_GPU
    ):
        missing = DC_MISSING_MOE_GPU_ADMISSION
    elif check_device == DC_DEV_GPU and not (
        w == 4 and shape.tile4_profile
    ):
        missing = DC_MISSING_VERIFY_WIDTH
    var verdict = DC_VERDICT_PRICED
    if missing != DC_MISSING_NONE:
        verdict = DC_VERDICT_REFUSED_UNBUILT
    var keep_eligible = False
    if verdict == DC_VERDICT_PRICED:
        if check_device == DC_DEV_GPU:
            keep_eligible = True
        elif check_device == DC_DEV_CPU and not shape.has_gpu:
            keep_eligible = True
    return DraftCheckPlan(
        draft_device,
        check_device,
        verdict,
        missing,
        keep_eligible,
        h2d,
        d2h,
        contended,
        syncs,
        host_streamed,
        expert_h2d,
    )


def choose_draft_check_placement(
    shape: DraftCheckShape,
) raises -> DraftCheckPlan:
    """The kept combination for one (pair, set, shape).

    Evaluates all nine combinations, restricts to the
    non-refused ones whose check device is the
    highest-ranked among them (accelerator-first for the
    check pass), and ranks those by (synchronised
    crossings, total crossing bytes, contended bytes,
    combination code). Raises when every combination is
    refused -- a state the stated shapes cannot reach
    (both-on-CPU is never refused), stated as a refusal
    rather than a silent default.
    """
    var best_rank = -1
    for draft in range(3):
        for check in range(3):
            var plan = plan_draft_check_combo(shape, draft, check)
            if plan.verdict == DC_VERDICT_PRICED:
                var rank = _check_rank(check)
                if rank > best_rank:
                    best_rank = rank
    if best_rank < 0:
        raise Error(
            "SpeculativePlacement: every combination is refused;"
            " no placement can be kept for this shape"
        )
    var kept = plan_draft_check_combo(shape, DC_DEV_CPU, DC_DEV_CPU)
    var have_kept = False
    for draft in range(3):
        for check in range(3):
            if _check_rank(check) != best_rank:
                continue
            var plan = plan_draft_check_combo(shape, draft, check)
            if plan.verdict != DC_VERDICT_PRICED:
                continue
            if not have_kept:
                kept = plan
                have_kept = True
                continue
            var better = False
            if plan.sync_crossings < kept.sync_crossings:
                better = True
            elif plan.sync_crossings == kept.sync_crossings:
                if plan.total_crossing_bytes() < kept.total_crossing_bytes():
                    better = True
                elif plan.total_crossing_bytes() == kept.total_crossing_bytes():
                    if plan.contended_bytes < kept.contended_bytes:
                        better = True
                    elif (
                        plan.contended_bytes == kept.contended_bytes
                        and plan.combo_code() < kept.combo_code()
                    ):
                        better = True
            if better:
                kept = plan
    if not have_kept:
        raise Error(
            "SpeculativePlacement: no keep-eligible combination"
            " at the highest non-refused check rank"
        )
    kept.keep_eligible = True
    return kept
