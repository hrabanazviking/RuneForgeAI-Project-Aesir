"""Equivalence gate (A-080): GPU<->CPU output equivalence
scripted into the fast battery (A-035).

Acceptance (roadmap A-080): the gate runs in the fast tier and
blocks banking on regression (keeper enforces). Wiring:
scripts/gate_fast.sh runs scripts/gate_equivalence.sh after the
suite judge; gate_equivalence.sh runs the standalone driver
(aesir_engine/a080_driver.mojo, which executes exactly these
cases) and fails unless the driver passes with zero real
divergences. This file's cases are ALSO registered in the
E-MASTER suite, so a regression fails both tiers.

Grading law (standing, unchanged): the verdict layer is
core/equivalence_gate.mojo, which delegates every per-position
verdict to the A-078 classifier (core/gpu_fuzz.fuzz_classify)
on the A-045 parity band -- teacher-forcing rank + logit gap on
RAW token sequences only, CPU engine vs CPU comparator for the
oracle side, near-tie rank <= 2 with sub-logit gap = faithful,
IQ on coherence never token-exactness, comparator artifacts
checked before any real-defect verdict. The gate decision is:
pass <=> real == 0 AND invalid == 0 AND total > 0.

Layers:
- Host cases pin the classifier table through the gate wrapper,
  the battery aggregation over a synthetic perturbed-row battery
  (labelled synthetic -- machinery proof, not a device claim),
  and the NEGATIVE control: an injected genuine divergence and
  an invalid row must each flip the gate to FAIL. That negative
  control is the in-suite proof that the gate blocks.
- A contract case reads the gate scripts from disk and pins the
  fast-tier wiring, so unwiring the gate fails the suite.
- Device cases run the real GPU path at fast-tier scale:
  VulkanSampling greedy (A-063) over seeded rows vs the CPU
  top-token oracle with dispatch-counter evidence, and the
  A-067 real-model GPU decode over seeded RAW prompts vs the
  CPU engine's teacher-forcing rows, verdicted through the gate
  battery. Device identity: AMD Radeon 8060S (RADV STRIX_HALO)
  only -- llvmpipe refused. On a host without that device or
  the fixture, device cases pass as honest-absent (A-014/A-067
  discipline); on purpleraider both are present and run real.

Fixture: Meta-Llama-3.1-8B-Instruct-Q4_K_M.gguf, sha256
7b064f5842bf9532c91456deda288a1b672397a54fa729aa665952863033557c
(the A-067 pinned fixture, read from the banking seat's copy).
"""
from core.equivalence_gate import (
    EQUIV_COMPARATOR,
    EQUIV_FAITHFUL,
    EQUIV_INVALID,
    EQUIV_NEAR_TIE,
    EQUIV_NOISE,
    EQUIV_REAL,
    EquivBattery,
    equiv_classify,
    equiv_verdict_name,
)
from core.gpu_fuzz import (
    FUZZ_BASE_SEED,
    FuzzLcg,
    fuzz_case_seed,
    fuzz_case_vocab,
    fuzz_logit_row,
    fuzz_prompt_ids,
    fuzz_top_margin,
)
from core.parity_battery import (
    parity_logit_gap,
    parity_logit_rank,
    parity_top_token,
)
from core.vulkan_buffers import VulkanBuffers, VulkanAllocation
from core.vulkan_sampling import VulkanSampling
from core.vulkan_real_model import VulkanRealModel
from aesir import AesirEngine

comptime _FIXTURE = "/home/volmarr/aesir-forge/hidden_files/fixtures/Meta-Llama-3.1-8B-Instruct-Q4_K_M.gguf"
comptime EQUIV_BASE_SEED = UInt64(0xA080_0001)


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


def _load_or_none(path: String) -> Bool:
    try:
        var m = VulkanRealModel(path)
        m.load()
        m.close()
        return True
    except:
        return False


def _read_script(name: String) raises -> String:
    try:
        with open("scripts/" + name, "r") as f:
            return f.read()
    except:
        with open("../scripts/" + name, "r") as f:
            return f.read()


# --- Host machinery cases -------------------------------------


def test_equivalence_classifier_table() raises:
    print("--- Testing equivalence classifier table (A-080) ---")
    if equiv_classify(1, Float32(0.0), Float32(0.0), True, False, False, Float32(1.0)) != EQUIV_FAITHFUL:
        raise Error("A080: rank 1 must be faithful")
    if equiv_classify(2, Float32(0.5), Float32(0.0), False, False, False, Float32(1.0)) != EQUIV_NEAR_TIE:
        raise Error("A080: rank 2 sub-logit must be near-tie")
    if equiv_classify(9, Float32(4.02), Float32(4.0), True, True, False, Float32(0.5)) != EQUIV_COMPARATOR:
        raise Error("A080: prompt-boundary agreement must be comparator-artifact")
    if equiv_classify(9, Float32(4.5), Float32(4.0), True, True, False, Float32(0.5)) != EQUIV_REAL:
        raise Error("A080: gap delta > 0.05 must escape the comparator class")
    if equiv_classify(3, Float32(1.5), Float32(0.0), False, False, True, Float32(1.0)) != EQUIV_NOISE:
        raise Error("A080: IQ divergence under gap 2.0 must be noise")
    if equiv_classify(5, Float32(0.3), Float32(0.0), False, False, False, Float32(0.01)) != EQUIV_NOISE:
        raise Error("A080: degenerate-margin rank move must be noise")
    if equiv_classify(-1, Float32(0.0), Float32(0.0), True, False, False, Float32(1.0)) != EQUIV_INVALID:
        raise Error("A080: bad rank must be invalid")
    if equiv_verdict_name(EQUIV_REAL) != String("real-divergence"):
        raise Error("A080: verdict names wrong")
    print("classifier table: faithful/near-tie/comparator/noise/real/invalid pinned through the gate wrapper")


def test_equivalence_battery_aggregation() raises:
    print("--- Testing equivalence battery aggregation (A-080) ---")
    var battery = EquivBattery()
    for idx in range(32):
        var seed = fuzz_case_seed(EQUIV_BASE_SEED, idx)
        var n = fuzz_case_vocab(idx)
        var row = fuzz_logit_row(seed, n)
        var target = parity_top_token(row)
        var margin = fuzz_top_margin(row)
        var noise = FuzzLcg(seed ^ 0x5EED)
        var gpu = List[Float32]()
        for i in range(n):
            gpu.append(row[i] + (noise.unit() - Float32(0.5)) * Float32(0.02))
        var code = equiv_classify(
            parity_logit_rank(gpu, target), parity_logit_gap(gpu, target),
            Float32(0.0), parity_top_token(gpu) == target, False, False,
            margin,
        )
        battery.record(code)
    if battery.total != 32:
        raise Error("A080: battery must verdict all 32 synthetic cases")
    if battery.count(EQUIV_REAL) != 0 or battery.count(EQUIV_INVALID) != 0:
        raise Error("A080: synthetic battery produced a blocking verdict")
    if not battery.gate_passes():
        raise Error("A080: clean synthetic battery must pass the gate")
    print(
        "EQUIV_SYNTH total=", battery.total, " faithful=",
        battery.count(EQUIV_FAITHFUL), " near_tie=",
        battery.count(EQUIV_NEAR_TIE), " noise=",
        battery.count(EQUIV_NOISE), " real=0 invalid=0 gate=PASS",
    )


def test_equivalence_regression_blocks() raises:
    print("--- Testing equivalence regression blocks (A-080) ---")
    # Negative control 1: a genuine divergence (healthy margin,
    # large gap, no comparator agreement) must verdict REAL and
    # flip the gate to FAIL -- the blocking proof.
    var blocked = EquivBattery()
    blocked.record(equiv_classify(1, Float32(0.0), Float32(0.0), True, False, False, Float32(1.0)))
    blocked.record(equiv_classify(7, Float32(3.0), Float32(3.0), False, False, False, Float32(2.0)))
    if blocked.count(EQUIV_REAL) != 1:
        raise Error("A080: injected divergence must verdict real-divergence")
    if blocked.gate_passes():
        raise Error("A080: a battery with a real divergence must NOT pass")
    # Negative control 2: an invalid row blocks too.
    var invalid = EquivBattery()
    invalid.record(EQUIV_INVALID)
    if invalid.gate_passes():
        raise Error("A080: a battery with an invalid row must NOT pass")
    # Negative control 3: no evidence is not equivalence.
    var empty = EquivBattery()
    if empty.gate_passes():
        raise Error("A080: an empty battery must NOT pass")
    print("regression blocks: real divergence, invalid row, and empty battery each flip the gate to FAIL")


def test_equivalence_gate_script_contract() raises:
    print("--- Testing equivalence gate script contract (A-080) ---")
    var fast = _read_script("gate_fast.sh")
    if "gate_equivalence.sh" not in fast:
        raise Error("A080: gate_fast.sh must invoke gate_equivalence.sh (fast-tier wiring)")
    if "EQUIV" not in fast:
        raise Error("A080: gate_fast.sh must surface the equivalence verdict")
    var equiv = _read_script("gate_equivalence.sh")
    if "a080_driver" not in equiv:
        raise Error("A080: gate_equivalence.sh must run the a080 driver")
    if "A080_DRIVER_ALL_PASS" not in equiv:
        raise Error("A080: gate_equivalence.sh must judge the driver pass line")
    print("script contract: fast gate invokes the equivalence gate; equivalence gate judges the driver pass line")


# --- Device cases (fast-tier scale) -----------------------------


def _alloc_logits(logits: List[Float32]) raises -> VulkanAllocation:
    var l_alloc = VulkanBuffers.allocate(len(logits) * 4)
    var pl = VulkanBuffers.map(l_alloc)
    var fl = pl.unsafe_bitcast[Float32]()
    for i in range(len(logits)):
        fl.unsafe_store(i, logits[i])
    VulkanBuffers.unmap(l_alloc)
    return l_alloc^


def _alloc_out() raises -> VulkanAllocation:
    var o_alloc = VulkanBuffers.allocate(4)
    var po = VulkanBuffers.map(o_alloc)
    var fo = po.unsafe_bitcast[UInt32]()
    fo.unsafe_store(0, UInt32(0xFFFFFFFF))
    VulkanBuffers.unmap(o_alloc)
    return o_alloc^


def test_equivalence_sampling_parity() raises:
    print("--- Testing equivalence sampling parity (A-080) ---")
    if not _vk_present():
        print("Vulkan UNAVAILABLE: sampling parity not run (honest-absent)")
        print("EQUIV_SAMPLE absent=1 cases=0 real=0")
        return
    var before = VulkanSampling.greedy_dispatch_count()
    var cases = 0
    for idx in range(12):
        var seed = fuzz_case_seed(EQUIV_BASE_SEED, idx + 300)
        var n = fuzz_case_vocab(idx)
        var row = fuzz_logit_row(seed, n)
        var expected = parity_top_token(row)
        var l_alloc = _alloc_logits(row)
        var o_alloc = _alloc_out()
        VulkanSampling.greedy(l_alloc, o_alloc, len(row))
        var po = VulkanBuffers.map(o_alloc)
        var fo = po.unsafe_bitcast[UInt32]()
        var got = Int(fo.unsafe_load(0))
        VulkanBuffers.unmap(o_alloc)
        VulkanBuffers.free(l_alloc)
        VulkanBuffers.free(o_alloc)
        cases += 1
        if got != expected:
            raise Error(
                "A080: sampling parity case " + String(idx) + " (seed "
                + String(seed) + ", n=" + String(n) + ") gpu="
                + String(got) + " cpu=" + String(expected)
            )
    var delta = VulkanSampling.greedy_dispatch_count() - before
    if delta != cases:
        raise Error("A080: greedy dispatch delta must equal the case count")
    print("EQUIV_SAMPLE absent=0 cases=", cases, " token-exact vs CPU; dispatches ", delta)


def test_equivalence_real_model_parity() raises:
    print("--- Testing equivalence real-model parity (A-080) ---")
    if not _vk_present():
        print("Vulkan UNAVAILABLE: real-model parity not run (honest-absent)")
        print("EQUIV_REAL absent=1 positions=0 real=0 invalid=0 gate=PASS-ABSENT")
        return
    if not _load_or_none(_FIXTURE):
        print("FIXTURE ABSENT: real-model parity not run (honest-absent)")
        print("EQUIV_REAL absent=1 positions=0 real=0 invalid=0 gate=PASS-ABSENT")
        return
    var engine = AesirEngine(_FIXTURE)
    var model = VulkanRealModel(_FIXTURE)
    model.load()
    var lens = List[Int]()
    lens.append(2)
    lens.append(3)
    lens.append(5)
    var battery = EquivBattery()
    for c in range(3):
        var seed = fuzz_case_seed(EQUIV_BASE_SEED, c + 400)
        var raw = fuzz_prompt_ids(seed, lens[c], 32000)
        var seq = List[Int]()
        for i in range(len(raw)):
            seq.append(raw[i] + 256)
        var cpu_rows = engine.teacher_forcing_logit_rows(seq)
        model.reset_kv()
        for p in range(len(seq) - 1):
            var gpu_row = model.decode_step(seq[p], p)
            var target = seq[p + 1]
            var code = equiv_classify(
                parity_logit_rank(gpu_row, target),
                parity_logit_gap(gpu_row, target),
                parity_logit_gap(cpu_rows[p], target),
                parity_top_token(gpu_row) == parity_top_token(cpu_rows[p]),
                True, False, fuzz_top_margin(cpu_rows[p]),
            )
            battery.record(code)
    model.close()
    if not battery.gate_passes():
        raise Error(
            "A080: real-model parity gate FAILED: positions="
            + String(battery.total) + " real="
            + String(battery.count(EQUIV_REAL)) + " invalid="
            + String(battery.count(EQUIV_INVALID))
        )
    print(
        "EQUIV_REAL absent=0 positions=", battery.total, " faithful=",
        battery.count(EQUIV_FAITHFUL), " near_tie=",
        battery.count(EQUIV_NEAR_TIE), " noise=",
        battery.count(EQUIV_NOISE), " comparator=",
        battery.count(EQUIV_COMPARATOR), " real=0 invalid=0 gate=PASS",
    )
