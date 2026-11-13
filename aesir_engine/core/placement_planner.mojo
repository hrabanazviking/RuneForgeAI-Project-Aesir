# core/placement_planner.mojo
# A-100: Placement planner.
# Per-op device assignment driven by the MEASURED cost tables
# from Parts III-IV, not by hand-waving. The tables are encoded
# as data below, each row carrying its source slice; the planner
# is a pure function of (registry, context, request), so its
# decisions on the standard fixtures are unit-testable and are
# pinned by tests/test_placement_planner_a100.mojo (the A-107
# regression battery will pin them again in the full tier).
#
# Measured sources consumed (all banked, all on this Z13):
# - A-094 (docs/bench/A094_NPU_SHAPED_OPS.md): NPU dispatch
#   floor ~93.0 us warm; cubic i16 GEMM crosses the CPU oracle
#   between 32^3 (NPU loses, 0.29x) and 64^3 (1.88x); prefill
#   projection GEMM M >= 64 is the FIT candidate (99x vs the
#   oracle CPU at 128x1024x1024); decode GEMV is NOT FIT
#   (tile M = 32, ~19 ms/token of dispatch alone, DERIVED);
#   embedding lookup is NOT FIT (no arithmetic); norm /
#   elementwise classes are FUSION-ONLY standalone.
# - A-095: the prefill projection dispatch exists behind the
#   registry (flag-gated, resident context, exact parity);
#   verdict NEUTRAL-WITH-VALUE. The planner's NPU choices are
#   only reachable when the context says NPU execution is
#   proven for that path -- presence alone never places
#   (A-017 honesty law, unchanged).
# - A-096: overlap POSITIVE -- an NPU prefill chunk computed
#   inside the GPU decode shadow was fully hidden (median
#   benefit 4,198 / 4,289 / 3,819 us over serial, 3 runs).
# - A-097: NPU sampler NOT FIT -- argmax loses to a plain CPU
#   scan at both vocab sizes (104.8 vs 19.9 us at V=32768;
#   165.2 vs 76.7 us at V=131072). Sampling stays on CPU.
# - A-098 (docs/bench/A098_NPU_POWER_PROFILE.md): at the
#   prefill shape 128x1024x1024 the GPU is the latency AND
#   perf-per-watt winner (67.5 us, 51.20 GFLOP/s/W gross);
#   the NPU draws 22.1 W package vs the GPU's 77.7 W, so its
#   measured value is power-capped and overlapped work.
# - A-086: Vulkan is the first-class GPU backend, HIP is
#   probe-only and is NEVER placed by this planner.
# - A-099: every NPU placement carries its fallback in the
#   decision record -- on any NPU failure the op degrades to
#   CPU with FALLBACK_<NAME> logged; the planner names CPU
#   as the fallback for every NPU decision it makes.
# - A-017: kinds with no measured table entry (generic,
#   transfer, unknown) delegate to the standing device
#   policy, unchanged.
#
# Honesty: accelerator-visible is not accelerator-run. This
# module decides and logs; it does not execute. Estimated
# latencies are reported only where a measured row matches
# the request shape exactly; otherwise the estimate is -1
# (unknown) and the decision rests on the measured class
# verdict, named in the reason.

from core.backend_registry import (
    BackendRegistry,
    gpu_first_class_runtime,
)
from core.device_policy import (
    DEVICE_CPU,
    DEVICE_GPU,
    DEVICE_NONE,
    DEVICE_NPU,
    OP_ATTENTION,
    OP_ELEMENTWISE,
    OP_EMBEDDING,
    OP_GENERIC,
    OP_MATMUL,
    OP_SAMPLING,
    OP_TRANSFER,
    PlacementPolicy,
    device_class_name,
)

comptime OP_PREFILL_PROJECTION = "prefill_projection"
comptime OP_GEMM = "gemm"
comptime OP_GEMV = "gemv"
comptime OP_EMBEDDING_PROJECTION = "embedding_projection"
comptime OP_EMBEDDING_LOOKUP = "embedding_lookup"

# A-094 measured law, as constants.
comptime NPU_DISPATCH_FLOOR_US_X10 = 930  # 93.0 us warm dispatch
comptime PLANNER_MIN_M = 64  # A-095 band: prefill rows for NPU
comptime PLANNER_MIN_MACS = 100000  # ~0.1M MACs per dispatch


struct GemmLatencyRow(Copyable, ImplicitlyCopyable):
    """One A-094 measured GEMM row (medians, warm, this Z13).

    Times are tenths of a microsecond. The CPU column is the
    in-program oracle (single-thread naive i16->i32), exactly
    as filed in A-094 -- an upper-bound comparator, named as
    such wherever it is used.
    """

    var label: String
    var m: Int
    var k: Int
    var n: Int
    var npu_us_x10: Int
    var cpu_oracle_us_x10: Int

    def __init__(
        out self,
        label: String,
        m: Int,
        k: Int,
        n: Int,
        npu_us_x10: Int,
        cpu_oracle_us_x10: Int,
    ):
        self.label = label
        self.m = m
        self.k = k
        self.n = n
        self.npu_us_x10 = npu_us_x10
        self.cpu_oracle_us_x10 = cpu_oracle_us_x10


def npu_gemm_latency_table() -> List[GemmLatencyRow]:
    """The A-094 sweep, verbatim (docs/bench/A094, section 1)."""
    var rows = List[GemmLatencyRow]()
    rows.append(GemmLatencyRow("32x32x32", 32, 32, 32, 930, 272))
    rows.append(GemmLatencyRow("64x64x64", 64, 64, 64, 1026, 1928))
    rows.append(GemmLatencyRow("128x128x128", 128, 128, 128, 1059, 8114))
    rows.append(
        GemmLatencyRow("256x256x256", 256, 256, 256, 3490, 120654)
    )
    rows.append(
        GemmLatencyRow("512x512x512", 512, 512, 512, 20940, 789335)
    )
    rows.append(
        GemmLatencyRow("32x1024x1024", 32, 1024, 1024, 6545, 676175)
    )
    rows.append(
        GemmLatencyRow(
            "128x1024x1024", 128, 1024, 1024, 25583, 2541693
        )
    )
    return rows^


struct PowerCostRow(Copyable, ImplicitlyCopyable):
    """One A-098 power-table row for the prefill shape.

    Shape: prefill projection GEMM 128x1024x1024, RAPL
    package-0, pooled over 3 runs per path. us_x10 is tenths
    of a microsecond per op; perf_w_x100 is GFLOP/s/W gross
    x100; package_w_x10 is gross package watts x10;
    j_op_x100000 is gross J/op x100000.
    """

    var device: String
    var us_x10: Int
    var perf_w_x100: Int
    var package_w_x10: Int
    var j_op_x100000: Int

    def __init__(
        out self,
        device: String,
        us_x10: Int,
        perf_w_x100: Int,
        package_w_x10: Int,
        j_op_x100000: Int,
    ):
        self.device = device
        self.us_x10 = us_x10
        self.perf_w_x100 = perf_w_x100
        self.package_w_x10 = package_w_x10
        self.j_op_x100000 = j_op_x100000


def prefill_power_table() -> List[PowerCostRow]:
    """The A-098 power table, verbatim (gross package basis)."""
    var rows = List[PowerCostRow]()
    rows.append(PowerCostRow("GPU", 675, 5120, 777, 524))
    rows.append(PowerCostRow("CPU", 6325, 534, 794, 5023))
    rows.append(PowerCostRow("NPU", 22582, 539, 221, 4985))
    return rows^


struct SamplerLatencyRow(Copyable, ImplicitlyCopyable):
    """One A-097 measured argmax row (run 1 medians, warm)."""

    var vocab: Int
    var npu_us_x10: Int
    var cpu_us_x10: Int

    def __init__(
        out self, vocab: Int, npu_us_x10: Int, cpu_us_x10: Int
    ):
        self.vocab = vocab
        self.npu_us_x10 = npu_us_x10
        self.cpu_us_x10 = cpu_us_x10


def sampler_latency_table() -> List[SamplerLatencyRow]:
    """The A-097 headline rows, verbatim (run 1)."""
    var rows = List[SamplerLatencyRow]()
    rows.append(SamplerLatencyRow(32768, 1048, 199))
    rows.append(SamplerLatencyRow(131072, 1652, 767))
    return rows^


struct PlannerContext(Copyable, ImplicitlyCopyable):
    """What the caller knows that the registry cannot say.

    npu_execution_proven must only be True when the A-095
    proven dispatch path is the one being planned for; XRT
    presence in the registry alone never sets it (A-017).
    """

    var npu_execution_proven: Bool

    def __init__(out self, npu_execution_proven: Bool = False):
        self.npu_execution_proven = npu_execution_proven


def standard_context() -> PlannerContext:
    """The standard-fixture context: the A-095 proven path."""
    return PlannerContext(True)


struct PlannerRequest(Copyable, ImplicitlyCopyable):
    """One op to place: kind, GEMM shape (m x k x n; m is the
    row/token count, n the vocab for sampling), and the two
    workload flags the measured tables turn on."""

    var op_kind: String
    var m: Int
    var k: Int
    var n: Int
    var overlap_available: Bool
    var power_capped: Bool

    def __init__(
        out self,
        op_kind: String,
        m: Int,
        k: Int,
        n: Int,
        overlap_available: Bool = False,
        power_capped: Bool = False,
    ):
        self.op_kind = op_kind
        self.m = m
        self.k = k
        self.n = n
        self.overlap_available = overlap_available
        self.power_capped = power_capped

    def macs(self) -> Int:
        return self.m * self.k * self.n


struct PlannerDecision(Copyable, ImplicitlyCopyable):
    """One planner verdict with its measured reasoning.

    est_us_x10 is tenths of a microsecond from the matching
    measured row, or -1 when no row matches the shape exactly
    (the decision then rests on the named class verdict).
    fallback names the A-099 degradation target for NPU
    decisions (CPU, with FALLBACK_<NAME> logged on failure);
    it is empty for non-NPU decisions.
    """

    var op_kind: String
    var device_class: Int
    var backend: String
    var reason: String
    var est_us_x10: Int
    var fallback: String

    def __init__(
        out self,
        op_kind: String,
        device_class: Int,
        backend: String,
        reason: String,
        est_us_x10: Int,
        fallback: String,
    ):
        self.op_kind = op_kind
        self.device_class = device_class
        self.backend = backend
        self.reason = reason
        self.est_us_x10 = est_us_x10
        self.fallback = fallback

    def line(self) -> String:
        var text = (
            self.op_kind
            + " -> "
            + device_class_name(self.device_class)
            + " ("
            + self.backend
            + "): "
            + self.reason
        )
        if self.est_us_x10 >= 0:
            text += (
                " [measured est "
                + String(self.est_us_x10 // 10)
                + "."
                + String(self.est_us_x10 % 10)
                + " us]"
            )
        if self.fallback != "":
            text += " [fallback: " + self.fallback + "]"
        return text


def _gpu_backend(registry: BackendRegistry) -> String:
    """The GPU backend the planner may place, or ''.

    Mirrors the A-017/A-086 policy rule exactly: a decided
    first-class winner is the only GPU placed (the probe-only
    loser never is); while pending, HIP -> Vulkan among the
    available non-probe-only backends.
    """
    var first_class = gpu_first_class_runtime(registry)
    if first_class == "HIP" and registry.hip.is_available():
        return String("HIP")
    if first_class == "Vulkan" and registry.vulkan.is_available():
        return String("Vulkan")
    if first_class != "":
        return String("")
    if registry.hip.is_available() and not registry.hip.is_probe_only_gpu():
        return String("HIP")
    if registry.vulkan.is_available() and not registry.vulkan.is_probe_only_gpu():
        return String("Vulkan")
    return String("")


def _npu_placeable(
    registry: BackendRegistry, context: PlannerContext
) -> Bool:
    """NPU placement needs BOTH device presence and proven
    execution for the planned path (A-017 honesty law)."""
    return registry.xrt.is_available() and context.npu_execution_proven


def _exact_gemm_row(m: Int, k: Int, n: Int) -> Int:
    """Index into npu_gemm_latency_table() for an exact shape
    match, or -1."""
    var table = npu_gemm_latency_table()
    for i in range(len(table)):
        if table[i].m == m and table[i].k == k and table[i].n == n:
            return i
    return -1


def _none(request: PlannerRequest, reason: String) -> PlannerDecision:
    return PlannerDecision(
        request.op_kind, DEVICE_NONE, String("none"), reason, -1, String("")
    )


def plan_op(
    registry: BackendRegistry,
    context: PlannerContext,
    request: PlannerRequest,
) -> PlannerDecision:
    """Place one op from the measured tables.

    Rule order (each rule names its measured source):
    sampling -> CPU (A-097); embedding lookup -> CPU and
    standalone elementwise -> CPU (A-094 NOT FIT / FUSION-
    ONLY); attention -> GPU (A-017 class + Vulkan road);
    decode GEMV -> GPU (A-094 NOT FIT on NPU); GEMM class ->
    floor rule, then power-capped -> NPU (A-098), overlap ->
    NPU (A-096), default -> GPU (A-098 winner), GPU absent ->
    NPU when in the A-094 FIT band, else CPU spillover;
    every other kind delegates to the A-017 policy.
    """
    var gpu = _gpu_backend(registry)
    var cpu_ok = registry.cpu.is_available()
    var npu_ok = _npu_placeable(registry, context)
    var kind = request.op_kind

    if kind == OP_SAMPLING:
        if cpu_ok:
            var est = -1
            var table = sampler_latency_table()
            for i in range(len(table)):
                if table[i].vocab == request.n:
                    est = table[i].cpu_us_x10
            return PlannerDecision(
                kind,
                DEVICE_CPU,
                String("CPU"),
                String(
                    "MEASURED_A097: NPU argmax loses to the CPU"
                    " scan at both vocab sizes (104.8 vs 19.9 us"
                    " at V=32768; 165.2 vs 76.7 us at V=131072)"
                    " -- floor-bound, NOT FIT on NPU"
                ),
                est,
                String(""),
            )
        if gpu != "":
            return PlannerDecision(
                kind,
                DEVICE_GPU,
                gpu,
                String("CPU unavailable; GPU sampling road is"
                       " the remaining measured path"),
                -1,
                String(""),
            )
        return _none(request, String("no device can take sampling"))

    if kind == OP_EMBEDDING_LOOKUP or kind == OP_EMBEDDING:
        if cpu_ok:
            return PlannerDecision(
                kind,
                DEVICE_CPU,
                String("CPU"),
                String(
                    "NOT_FIT_A094: embedding lookup is a gather"
                    " with no arithmetic; no NPU crossover exists"
                ),
                -1,
                String(""),
            )
        return _none(request, String("no device can take embedding lookup"))

    if kind == OP_ELEMENTWISE:
        if cpu_ok:
            return PlannerDecision(
                kind,
                DEVICE_CPU,
                String("CPU"),
                String(
                    "FUSION_ONLY_A094: standalone elementwise"
                    " can never repay the 93.0 us NPU dispatch"
                    " floor at decode sizes; value only fused"
                    " inside a resident GEMM design"
                ),
                -1,
                String(""),
            )
        if gpu != "":
            return PlannerDecision(
                kind,
                DEVICE_GPU,
                gpu,
                String("CPU unavailable; GPU elementwise road"),
                -1,
                String(""),
            )
        return _none(request, String("no device can take elementwise"))

    if kind == OP_ATTENTION:
        if gpu != "":
            return PlannerDecision(
                kind,
                DEVICE_GPU,
                gpu,
                String(
                    "A017_CLASS: attention is memory-bound over"
                    " the KV cache and is not NPU-shaped in this"
                    " engine; the Vulkan attention road owns it"
                ),
                -1,
                String(""),
            )
        if cpu_ok:
            return PlannerDecision(
                kind,
                DEVICE_CPU,
                String("CPU"),
                String("CPU spillover: no GPU can take attention"),
                -1,
                String(""),
            )
        return _none(request, String("no device can take attention"))

    var is_gemm_class = (
        kind == OP_PREFILL_PROJECTION
        or kind == OP_EMBEDDING_PROJECTION
        or kind == OP_GEMM
        or kind == OP_MATMUL
        or kind == OP_GEMV
    )
    if is_gemm_class:
        if kind == OP_GEMV or request.m == 1:
            # Decode shape: A-094 NOT FIT on the NPU as stood up.
            if gpu != "":
                return PlannerDecision(
                    kind,
                    DEVICE_GPU,
                    gpu,
                    String(
                        "NOT_FIT_A094: decode GEMV (M=1) is not"
                        " expressible in the stood-up NPU design"
                        " (tile M=32) and per-op dispatch would"
                        " cost ~19 ms/token across 32 layers;"
                        " the Vulkan decode road owns decode"
                    ),
                    -1,
                    String(""),
                )
            if cpu_ok:
                return PlannerDecision(
                    kind,
                    DEVICE_CPU,
                    String("CPU"),
                    String(
                        "CPU spillover: decode GEMV with no GPU;"
                        " NPU stays NOT FIT per A-094"
                    ),
                    -1,
                    String(""),
                )
            return _none(request, String("no device can take decode GEMV"))
        if request.macs() < PLANNER_MIN_MACS:
            # Below the A-094 floor: the 32^3 row loses on NPU.
            if cpu_ok:
                var est_cpu = -1
                var row = _exact_gemm_row(request.m, request.k, request.n)
                if row >= 0:
                    var table = npu_gemm_latency_table()
                    est_cpu = table[row].cpu_oracle_us_x10
                return PlannerDecision(
                    kind,
                    DEVICE_CPU,
                    String("CPU"),
                    String(
                        "BELOW_FLOOR_A094: under ~0.1M MACs the"
                        " 93.0 us NPU dispatch floor dominates"
                        " (32x32x32 measured NPU 93.0 us vs CPU"
                        " oracle 27.2 us, 0.29x)"
                    ),
                    est_cpu,
                    String(""),
                )
            if gpu != "":
                return PlannerDecision(
                    kind,
                    DEVICE_GPU,
                    gpu,
                    String("CPU unavailable; small GEMM to GPU"),
                    -1,
                    String(""),
                )
            return _none(request, String("no device can take small GEMM"))
        # Large GEMM class (in or above the A-094 FIT band).
        if request.power_capped and npu_ok:
            var est_npu = -1
            if (
                request.m == 128
                and request.k == 1024
                and request.n == 1024
            ):
                est_npu = 22582
            return PlannerDecision(
                kind,
                DEVICE_NPU,
                String("XRT"),
                String(
                    "POWER_CAPPED_A098: NPU package draw is"
                    " 22.1 W vs GPU 77.7 W at this shape class"
                    " and its net-of-idle J/op beats CPU"
                    " (0.0298 vs 0.0446); under a power cap"
                    " that is the measured optimum"
                ),
                est_npu,
                String("CPU (A-099 FALLBACK_<NAME>)"),
            )
        if request.overlap_available and npu_ok:
            return PlannerDecision(
                kind,
                DEVICE_NPU,
                String("XRT"),
                String(
                    "OVERLAP_A096: NPU prefill computed inside"
                    " the GPU decode shadow was fully hidden"
                    " (median benefit 4,198 us over serial);"
                    " overlapped, the NPU is the optimum"
                ),
                -1,
                String("CPU (A-099 FALLBACK_<NAME>)"),
            )
        if gpu != "":
            var est_gpu = -1
            if (
                request.m == 128
                and request.k == 1024
                and request.n == 1024
            ):
                est_gpu = 675
            return PlannerDecision(
                kind,
                DEVICE_GPU,
                gpu,
                String(
                    "MEASURED_OPTIMUM_A098: at 128x1024x1024"
                    " the GPU is fastest (67.5 us) and the"
                    " perf-per-watt winner (51.20 GFLOP/s/W"
                    " gross vs NPU 5.39, CPU 5.34); first-class"
                    " GPU backend per A-086"
                ),
                est_gpu,
                String(""),
            )
        if npu_ok and request.m >= PLANNER_MIN_M:
            return PlannerDecision(
                kind,
                DEVICE_NPU,
                String("XRT"),
                String(
                    "FIT_A094: prefill projection GEMM with"
                    " M >= 64 and >= ~0.1M MACs is the measured"
                    " FIT candidate (99x vs the oracle CPU at"
                    " 128x1024x1024); no GPU is placeable here"
                ),
                -1,
                String("CPU (A-099 FALLBACK_<NAME>)"),
            )
        if npu_ok:
            return PlannerDecision(
                kind,
                DEVICE_NPU,
                String("XRT"),
                String(
                    "CROSSOVER_A094: cubic GEMM crosses the"
                    " CPU oracle between 32^3 and 64^3 and the"
                    " projection proxy 32x1024x1024 measured"
                    " 103x vs the oracle CPU; no GPU placeable"
                ),
                -1,
                String("CPU (A-099 FALLBACK_<NAME>)"),
            )
        if cpu_ok:
            return PlannerDecision(
                kind,
                DEVICE_CPU,
                String("CPU"),
                String(
                    "CPU spillover: no accelerator can take"
                    " this GEMM (GPU unplaceable; NPU absent or"
                    " execution unproven -- presence only)"
                ),
                -1,
                String(""),
            )
        return _none(request, String("no device can take this GEMM"))

    # No measured table entry: the standing A-017 policy decides.
    var policy = PlacementPolicy()
    var delegated = policy.decide(registry, kind)
    return PlannerDecision(
        kind,
        delegated.device_class,
        delegated.backend,
        String("A017_POLICY_DELEGATE (no A-100 measured row): ")
        + delegated.reason,
        -1,
        String(""),
    )


struct StandardFixture(Copyable, ImplicitlyCopyable):
    """One standard fixture: a request plus the measured
    optimum it must land on, under the standard registry
    (all backends present, Vulkan first-class per A-086)
    and the standard context (A-095 proven path)."""

    var name: String
    var request: PlannerRequest
    var expected_device_class: Int
    var expected_backend: String
    var source: String

    def __init__(
        out self,
        name: String,
        request: PlannerRequest,
        expected_device_class: Int,
        expected_backend: String,
        source: String,
    ):
        self.name = name
        self.request = request
        self.expected_device_class = expected_device_class
        self.expected_backend = expected_backend
        self.source = source


def standard_fixtures() -> List[StandardFixture]:
    """The A-100 standard fixture set (acceptance deliverable)."""
    var fixtures = List[StandardFixture]()
    fixtures.append(
        StandardFixture(
            "prefill_default",
            PlannerRequest(OP_PREFILL_PROJECTION, 128, 1024, 1024),
            DEVICE_GPU,
            "Vulkan",
            "A-098 power table: GPU 67.5 us, 51.20 GFLOP/s/W",
        )
    )
    fixtures.append(
        StandardFixture(
            "prefill_power_capped",
            PlannerRequest(
                OP_PREFILL_PROJECTION, 128, 1024, 1024, False, True
            ),
            DEVICE_NPU,
            "XRT",
            "A-098: NPU package 22.1 W vs GPU 77.7 W",
        )
    )
    fixtures.append(
        StandardFixture(
            "prefill_overlap",
            PlannerRequest(
                OP_PREFILL_PROJECTION, 128, 1024, 1024, True, False
            ),
            DEVICE_NPU,
            "XRT",
            "A-096: overlap POSITIVE, prefill fully hidden",
        )
    )
    fixtures.append(
        StandardFixture(
            "gemm_small_32",
            PlannerRequest(OP_GEMM, 32, 32, 32),
            DEVICE_CPU,
            "CPU",
            "A-094: 32^3 NPU loses 0.29x (floor-bound)",
        )
    )
    fixtures.append(
        StandardFixture(
            "decode_gemv",
            PlannerRequest(OP_GEMV, 1, 4096, 4096),
            DEVICE_GPU,
            "Vulkan",
            "A-094: decode GEMV NOT FIT on NPU (tile M=32)",
        )
    )
    fixtures.append(
        StandardFixture(
            "sampling_vocab_131072",
            PlannerRequest(OP_SAMPLING, 1, 0, 131072),
            DEVICE_CPU,
            "CPU",
            "A-097: NPU argmax 165.2 us vs CPU 76.7 us",
        )
    )
    fixtures.append(
        StandardFixture(
            "attention_prefill",
            PlannerRequest(OP_ATTENTION, 128, 4096, 4096),
            DEVICE_GPU,
            "Vulkan",
            "A-017 class: KV memory-bound, not NPU-shaped",
        )
    )
    fixtures.append(
        StandardFixture(
            "embedding_lookup",
            PlannerRequest(OP_EMBEDDING_LOOKUP, 128, 0, 4096),
            DEVICE_CPU,
            "CPU",
            "A-094: gather, no arithmetic, NOT FIT",
        )
    )
    fixtures.append(
        StandardFixture(
            "elementwise_decode_row",
            PlannerRequest(OP_ELEMENTWISE, 1, 0, 4096),
            DEVICE_CPU,
            "CPU",
            "A-094: fusion-only class, floor arithmetic",
        )
    )
    fixtures.append(
        StandardFixture(
            "embedding_projection_default",
            PlannerRequest(OP_EMBEDDING_PROJECTION, 128, 1024, 1024),
            DEVICE_GPU,
            "Vulkan",
            "A-094 FIT class; A-098 GPU optimum at the shape",
        )
    )
    fixtures.append(
        StandardFixture(
            "prefill_below_m_band",
            PlannerRequest(OP_PREFILL_PROJECTION, 32, 1024, 1024),
            DEVICE_GPU,
            "Vulkan",
            "A-095 band excludes NPU below M=64; GPU owns it",
        )
    )
    fixtures.append(
        StandardFixture(
            "transfer_default",
            PlannerRequest(OP_TRANSFER, 0, 0, 0),
            DEVICE_GPU,
            "Vulkan",
            "No A-100 row: A-017 policy delegate",
        )
    )
    return fixtures^


def planner_fixture_lines(registry: BackendRegistry) -> List[String]:
    """The `doctor` rendering: every standard fixture decided
    on this registry under the standard context, with the
    measured source named per fixture."""
    var lines = List[String]()
    lines.append(
        String(
            "placement planner (A-100): standard fixtures under"
            " the A-095 proven context; decisions from the"
            " measured tables of A-094/A-096/A-097/A-098"
        )
    )
    var context = standard_context()
    for fixture in standard_fixtures():
        var decision = plan_op(registry, context, fixture.request)
        lines.append(
            fixture.name
            + ": "
            + decision.line()
            + " [source: "
            + fixture.source
            + "]"
        )
    return lines^


def planner_summary() -> String:
    """One-line planner summary (doctor JSON rendering)."""
    return String(
        "A-100 placement planner: 12 standard fixtures decided"
        " from measured tables (A-094 floor 93.0 us, A-096"
        " overlap, A-097 sampler, A-098 power); GPU default"
        " optimum, NPU for power-capped / overlapped prefill,"
        " CPU below the floor and for NOT FIT classes"
    )
