"""GPU fuzz (A-078): random prompts / shapes / context lengths
vs the CPU oracle, every divergence verdicted.

Battery (core/gpu_fuzz.mojo): every case derives from the filed
base seed FUZZ_BASE_SEED -- case index + base seed regenerate
the identical prompt ids, logit rows, and sampling uniforms, so
any case replays exactly from its seed alone.

Layers, mirroring the banked precedents:
- Host cases prove the machinery: seed replay determinism, the
  case-table coverage (prompt lengths 1..32, shapes from the
  filed table incl. odd sizes, gen lengths 1..8), the verdict
  classifier's full table (faithful / near-tie / noise /
  comparator-artifact / real / invalid), and a 64-case synthetic
  row battery (labelled synthetic) where a CPU row perturbed at
  accumulation-noise scale must never produce an un-verdicted or
  real divergence.
- Device cases fuzz the real GPU path: VulkanSampling greedy +
  temperature/top-k (A-063) over seeded random rows of random
  shapes vs the independent CPU sampling oracle written in this
  file, and the A-067 real-model GPU decode over seeded RANDOM
  token-id prompts of random lengths (1..13) vs the CPU engine's
  teacher-forcing rows. Random-prompt positions are the A-067
  prompt-boundary comparator class: targets are unlikely under
  BOTH engines, judged by top-1 agreement + cross-engine gap
  delta through fuzz_classify. Any position landing in the
  real-divergence class fails the case with its seed filed in
  the error, so it replays exactly.

Device-execution evidence (law 6): the selected device must be
the AMD Radeon 8060S (RADV STRIX_HALO) -- llvmpipe is refused by
the identity check -- and the sampling dispatch counters must
advance by exactly the dispatches performed. On a host without
that device, or without the A-067 fixture, the device cases
pass as honest-absent (A-014/A-067 discipline).

Fixture: Meta-Llama-3.1-8B-Instruct-Q4_K_M.gguf, sha256
7b064f5842bf9532c91456deda288a1b672397a54fa729aa665952863033557c
(the A-067 pinned fixture, read from the banking seat's copy).
"""
from std.math import exp
from core.gpu_fuzz import (
    FUZZ_BASE_SEED,
    FUZZ_COMPARATOR,
    FUZZ_FAITHFUL,
    FUZZ_INVALID,
    FUZZ_NEAR_TIE,
    FUZZ_NOISE,
    FUZZ_REAL,
    FuzzLcg,
    fuzz_case_gen_len,
    fuzz_case_prompt_len,
    fuzz_case_seed,
    fuzz_case_vocab,
    fuzz_classify,
    fuzz_logit_row,
    fuzz_prompt_ids,
    fuzz_top_margin,
    fuzz_verdict_name,
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


def _abs32(v: Float32) -> Float32:
    return -v if v < Float32(0.0) else v


def _load_or_none(path: String) -> Bool:
    try:
        var m = VulkanRealModel(path)
        m.load()
        m.close()
        return True
    except:
        return False


# --- Host machinery cases -------------------------------------


def test_gpu_fuzz_seed_replay() raises:
    print("--- Testing GPU fuzz seed replay (A-078) ---")
    for idx in range(16):
        var s1 = fuzz_case_seed(FUZZ_BASE_SEED, idx)
        var s2 = fuzz_case_seed(FUZZ_BASE_SEED, idx)
        if s1 != s2:
            raise Error("A078: case seed must replay exactly")
        var ids1 = fuzz_prompt_ids(s1, 12, 4096)
        var ids2 = fuzz_prompt_ids(s2, 12, 4096)
        for i in range(12):
            if ids1[i] != ids2[i]:
                raise Error("A078: prompt ids must replay exactly")
        var row1 = fuzz_logit_row(s1, 64)
        var row2 = fuzz_logit_row(s2, 64)
        for i in range(64):
            if row1[i] != row2[i]:
                raise Error("A078: logit rows must replay exactly")
    var seen = List[UInt64]()
    for idx in range(16):
        var s = fuzz_case_seed(FUZZ_BASE_SEED, idx)
        for j in range(len(seen)):
            if seen[j] == s:
                raise Error("A078: case seeds must be distinct")
        seen.append(s)
    print("seed replay: 16 cases regenerate identical ids + rows; seeds distinct")


def test_gpu_fuzz_case_coverage() raises:
    print("--- Testing GPU fuzz case coverage (A-078) ---")
    var min_len = 100
    var max_len = 0
    for idx in range(64):
        var plen = fuzz_case_prompt_len(FUZZ_BASE_SEED, idx)
        if plen < 1 or plen > 32:
            raise Error("A078: prompt length out of the filed 1..32 range")
        if plen < min_len:
            min_len = plen
        if plen > max_len:
            max_len = plen
        var vocab = fuzz_case_vocab(idx)
        if vocab < 16 or vocab > 4096:
            raise Error("A078: shape out of the filed table range")
        var glen = fuzz_case_gen_len(idx)
        if glen < 1 or glen > 8:
            raise Error("A078: gen length out of the filed 1..8 range")
    if min_len > 4 or max_len < 24:
        raise Error(
            "A078: 64 cases must span short and long contexts, got "
            + String(min_len) + ".." + String(max_len)
        )
    var shapes = List[Int]()
    for idx in range(8):
        shapes.append(fuzz_case_vocab(idx))
    if shapes[1] != 37 or shapes[4] != 251:
        raise Error("A078: odd fuzz shapes (37, 251) must be in the table")
    print(
        "coverage: prompt lens span ", min_len, "..", max_len,
        " over 64 cases; shapes incl. odd 37/251; gen lens 1..8",
    )


def test_gpu_fuzz_verdict_classifier() raises:
    print("--- Testing GPU fuzz verdict classifier (A-078) ---")
    # faithful / near-tie come straight from the parity band.
    if fuzz_classify(1, Float32(0.0), Float32(0.0), True, False, False, Float32(1.0)) != FUZZ_FAITHFUL:
        raise Error("A078: rank 1 must be faithful")
    if fuzz_classify(2, Float32(0.5), Float32(0.0), False, False, False, Float32(1.0)) != FUZZ_NEAR_TIE:
        raise Error("A078: rank 2 sub-logit must be near-tie")
    # Prompt-boundary comparator class: gaps agree, top-1 agrees.
    if fuzz_classify(9, Float32(4.02), Float32(4.0), True, True, False, Float32(0.5)) != FUZZ_COMPARATOR:
        raise Error("A078: prompt-boundary agreement must be comparator-artifact")
    # Same rank/gap WITHOUT the comparator agreement is real.
    if fuzz_classify(9, Float32(4.02), Float32(4.0), False, True, False, Float32(0.5)) != FUZZ_REAL:
        raise Error("A078: prompt-boundary disagreement must be real")
    if fuzz_classify(9, Float32(4.5), Float32(4.0), True, True, False, Float32(0.5)) != FUZZ_REAL:
        raise Error("A078: gap delta > 0.05 must escape the comparator class")
    # A-078 step-0 tail rule: a deep-tail random target (cpu_gap >= 4)
    # whose gap agrees within 3% relative, top-1 agreeing, is the same
    # prompt-boundary comparator class (filed: a078_diag.log, worst
    # relative delta 2.86% over 16 step-0 positions).
    if fuzz_classify(43697, Float32(9.195), Float32(9.311), True, True, False, Float32(0.09)) != FUZZ_COMPARATOR:
        raise Error("A078: deep-tail step-0 agreement within 3% must be comparator-artifact")
    if fuzz_classify(43697, Float32(12.0), Float32(9.311), True, True, False, Float32(0.09)) != FUZZ_REAL:
        raise Error("A078: deep-tail step-0 delta beyond 3% must be real")
    if fuzz_classify(50, Float32(3.2), Float32(3.0), True, True, False, Float32(0.5)) != FUZZ_REAL:
        raise Error("A078: shallow target (cpu_gap < 4) gets no relative comparator rule")
    # IQ quant noise.
    if fuzz_classify(3, Float32(1.5), Float32(0.0), False, False, True, Float32(1.0)) != FUZZ_NOISE:
        raise Error("A078: IQ divergence under gap 2.0 must be noise")
    if fuzz_classify(3, Float32(2.5), Float32(0.0), False, False, True, Float32(1.0)) != FUZZ_REAL:
        raise Error("A078: IQ divergence at gap 2.5 must be real")
    # Degenerate-margin noise.
    if fuzz_classify(5, Float32(0.3), Float32(0.0), False, False, False, Float32(0.01)) != FUZZ_NOISE:
        raise Error("A078: degenerate-margin rank move must be noise")
    if fuzz_classify(5, Float32(0.3), Float32(0.0), False, False, False, Float32(0.5)) != FUZZ_REAL:
        raise Error("A078: healthy-margin rank move must be real")
    # Invalid sentinels.
    if fuzz_classify(-1, Float32(0.0), Float32(0.0), True, False, False, Float32(1.0)) != FUZZ_INVALID:
        raise Error("A078: bad rank must be invalid")
    if fuzz_verdict_name(FUZZ_COMPARATOR) != String("comparator-artifact"):
        raise Error("A078: verdict names wrong")
    print("classifier: faithful/near-tie/comparator/IQ-noise/margin-noise/real/invalid all pinned")


def test_gpu_fuzz_synthetic_row_battery() raises:
    print("--- Testing GPU fuzz synthetic row battery (A-078) ---")
    var counts = List[Int]()
    for _ in range(6):
        counts.append(0)
    var total = 0
    for idx in range(64):
        var seed = fuzz_case_seed(FUZZ_BASE_SEED, idx)
        var n = fuzz_case_vocab(idx)
        var row = fuzz_logit_row(seed, n)
        var target = parity_top_token(row)
        var margin = fuzz_top_margin(row)
        # Perturbed "GPU" row: independent LCG noise at +/-0.01,
        # the accumulation-order scale measured at A-065.
        var noise = FuzzLcg(seed ^ 0x5EED)
        var gpu = List[Float32]()
        for i in range(n):
            gpu.append(row[i] + (noise.unit() - Float32(0.5)) * Float32(0.02))
        var rank = parity_logit_rank(gpu, target)
        var gap = parity_logit_gap(gpu, target)
        var code = fuzz_classify(
            rank, gap, Float32(0.0),
            parity_top_token(gpu) == target, False, False, margin,
        )
        if code == FUZZ_INVALID:
            raise Error("A078: synthetic case " + String(idx) + " invalid")
        if code == FUZZ_REAL:
            raise Error(
                "A078: synthetic case " + String(idx) + " (seed "
                + String(seed) + ") produced an un-verdicted real "
                + "divergence: rank=" + String(rank) + " gap=" + String(gap)
            )
        counts[code] += 1
        total += 1
    if total != 64 or counts[FUZZ_FAITHFUL] == 0:
        raise Error("A078: synthetic battery must verdict all 64 cases")
    print(
        "synthetic battery: 64/64 verdicted, 0 real; faithful ",
        counts[FUZZ_FAITHFUL], " near-tie ", counts[FUZZ_NEAR_TIE],
        " noise ", counts[FUZZ_NOISE],
    )


# --- Device sampling fuzz (A-063 path) -------------------------

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


def _read_token(o_alloc: VulkanAllocation) raises -> Int:
    var po = VulkanBuffers.map(o_alloc)
    var fo = po.unsafe_bitcast[UInt32]()
    var tok = Int(fo.unsafe_load(0))
    VulkanBuffers.unmap(o_alloc)
    return tok


def _gpu_greedy(logits: List[Float32]) raises -> Int:
    var l_alloc = _alloc_logits(logits)
    var o_alloc = _alloc_out()
    VulkanSampling.greedy(l_alloc, o_alloc, len(logits))
    var tok = _read_token(o_alloc)
    VulkanBuffers.free(l_alloc)
    VulkanBuffers.free(o_alloc)
    return tok


def _gpu_sample(
    logits: List[Float32], top_k: Int, temperature: Float32, u: Float32,
) raises -> Int:
    var l_alloc = _alloc_logits(logits)
    var o_alloc = _alloc_out()
    VulkanSampling.sample(l_alloc, o_alloc, len(logits), top_k, temperature, u)
    var tok = _read_token(o_alloc)
    VulkanBuffers.free(l_alloc)
    VulkanBuffers.free(o_alloc)
    return tok


def _ranked(
    logits: List[Float32], temperature: Float32, kept: Int,
    mut ids: List[Int], mut vals: List[Float32],
):
    """A-063 CPU oracle kept set, copied verbatim in semantics:
    the stable total order (scaled logit descending, id ascending
    on ties) by repeated selection."""
    var prev_val = Float32(1.0e30)
    var prev_idx = -1
    for _ in range(kept):
        var best_idx = -1
        var best_val = Float32(-1.0e30)
        for i in range(len(logits)):
            var v = logits[i] / temperature
            var after = v < prev_val or (v == prev_val and i > prev_idx)
            if after and (best_idx < 0 or v > best_val or (v == best_val and i < best_idx)):
                best_val = v
                best_idx = i
        ids.append(best_idx)
        vals.append(best_val)
        prev_val = best_val
        prev_idx = best_idx


def _cpu_sample(
    logits: List[Float32], top_k: Int, temperature: Float32, u: Float32,
) -> Int:
    var kept = len(logits)
    if 0 < top_k and top_k < kept:
        kept = top_k
    var ids = List[Int]()
    var vals = List[Float32]()
    _ranked(logits, temperature, kept, ids, vals)
    var total = Float32(0.0)
    for r in range(kept):
        total += exp(vals[r] - vals[0])
    var target = u * total
    var acc = Float32(0.0)
    for r in range(kept):
        acc += exp(vals[r] - vals[0])
        if target <= acc:
            return ids[r]
    return ids[kept - 1]


def test_gpu_fuzz_sampling_greedy() raises:
    print("--- Testing GPU fuzz sampling greedy (A-078) ---")
    if not _vk_present():
        print("Vulkan UNAVAILABLE: greedy fuzz not run (honest-absent)")
        return
    var before = VulkanSampling.greedy_dispatch_count()
    var cases = 0
    for idx in range(24):
        var seed = fuzz_case_seed(FUZZ_BASE_SEED, idx)
        var n = fuzz_case_vocab(idx)
        var row = fuzz_logit_row(seed, n)
        var expected = parity_top_token(row)
        var got = _gpu_greedy(row)
        cases += 1
        if got != expected:
            var rank = parity_logit_rank(row, got)
            raise Error(
                "A078: greedy fuzz case " + String(idx) + " (seed "
                + String(seed) + ", n=" + String(n) + ") gpu="
                + String(got) + " cpu=" + String(expected)
                + " gpu-token rank in cpu row=" + String(rank)
            )
    var delta = VulkanSampling.greedy_dispatch_count() - before
    if delta != cases:
        raise Error("A078: greedy dispatch delta must equal the case count")
    print("greedy fuzz: 24 seeded rows, shapes 16..4096, token-exact vs CPU; dispatches ", delta)


def test_gpu_fuzz_sampling_temperature() raises:
    print("--- Testing GPU fuzz sampling temperature (A-078) ---")
    if not _vk_present():
        print("Vulkan UNAVAILABLE: temperature fuzz not run (honest-absent)")
        return
    var temps = List[Float32]()
    temps.append(Float32(0.7))
    temps.append(Float32(1.0))
    temps.append(Float32(1.3))
    var cases = 0
    for idx in range(18):
        var seed = fuzz_case_seed(FUZZ_BASE_SEED, idx + 100)
        var n = fuzz_case_vocab(idx)
        var row = fuzz_logit_row(seed, n)
        var top_k = 1 + (idx % 5) * 3
        var temp = temps[idx % 3]
        var u_lcg = FuzzLcg(seed ^ 0x55)
        var u = u_lcg.unit()
        var expected = _cpu_sample(row, top_k, temp, u)
        var got = _gpu_sample(row, top_k, temp, u)
        cases += 1
        if got != expected:
            raise Error(
                "A078: sample fuzz case " + String(idx) + " (seed "
                + String(seed) + ", n=" + String(n) + ", top_k="
                + String(top_k) + ") gpu=" + String(got)
                + " cpu=" + String(expected)
            )
    print("temperature fuzz: ", cases, " seeded draws exact vs the CPU sampling oracle")


# --- Device real-model fuzz (A-067 path) -----------------------

def test_gpu_fuzz_real_model_random_prompts() raises:
    print("--- Testing GPU fuzz real-model random prompts (A-078) ---")
    if not _vk_present():
        print("Vulkan UNAVAILABLE: real-model fuzz not run (honest-absent)")
        return
    if not _load_or_none(_FIXTURE):
        print("FIXTURE ABSENT: real-model fuzz not run (honest-absent)")
        return
    var engine = AesirEngine(_FIXTURE)
    var model = VulkanRealModel(_FIXTURE)
    model.load()
    var lens = List[Int]()
    lens.append(1)
    lens.append(2)
    lens.append(3)
    lens.append(5)
    lens.append(8)
    lens.append(13)
    var counts = List[Int]()
    for _ in range(6):
        counts.append(0)
    var positions = 0
    for c in range(6):
        var seed = fuzz_case_seed(FUZZ_BASE_SEED, c + 200)
        var raw = fuzz_prompt_ids(seed, lens[c], 32000)
        var seq = List[Int]()
        for i in range(len(raw)):
            seq.append(raw[i] + 256)
        var cpu_rows = engine.teacher_forcing_logit_rows(seq)
        model.reset_kv()
        for p in range(len(seq) - 1):
            var gpu_row = model.decode_step(seq[p], p)
            var target = seq[p + 1]
            var rank = parity_logit_rank(gpu_row, target)
            var gap = parity_logit_gap(gpu_row, target)
            var cpu_gap = parity_logit_gap(cpu_rows[p], target)
            var code = fuzz_classify(
                rank, gap, cpu_gap,
                parity_top_token(gpu_row) == parity_top_token(cpu_rows[p]),
                True, False, fuzz_top_margin(cpu_rows[p]),
            )
            if code == FUZZ_INVALID or code == FUZZ_REAL:
                model.close()
                raise Error(
                    "A078: real-model fuzz case " + String(c)
                    + " (seed " + String(seed) + ") pos " + String(p)
                    + " verdict " + fuzz_verdict_name(code)
                    + ": rank=" + String(rank) + " gap=" + String(gap)
                    + " cpu_gap=" + String(cpu_gap)
                )
            counts[code] += 1
            positions += 1
    model.close()
    print(
        "real-model fuzz: 6 random prompts, ", positions,
        " positions verdicted, 0 real; comparator ",
        counts[FUZZ_COMPARATOR], " faithful ", counts[FUZZ_FAITHFUL],
        " near-tie ", counts[FUZZ_NEAR_TIE], " noise ", counts[FUZZ_NOISE],
    )
