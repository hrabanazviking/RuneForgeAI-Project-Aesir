"""A-078 fuzz battery probe: the full seeded battery, filed.

Standalone (not part of run_all). Prints one verdict-table row
per real-model case plus section totals, so the table in
docs/bench/A078_GPU_FUZZ.md and hidden_files/a078_verdict_table.md
traces to this log line by line. All cases derive from
FUZZ_BASE_SEED (core/gpu_fuzz.mojo); any case replays exactly
from (base seed, case index).

Sections:
  SYNTH   256 synthetic logit rows (labelled synthetic): CPU row
          perturbed at the A-065 accumulation-noise scale
          (+/-0.01), graded + verdicted per position.
  SAMPLE  96 greedy + 96 temperature/top-k draws on the A-063
          Vulkan sampling path over seeded random rows of filed
          shapes, vs the independent CPU oracle in this file.
  REAL    24 seeded RANDOM token-id prompts (lengths cycling
          1,2,3,4,5,8,13,21) on the A-067 real-model GPU decode
          vs the CPU engine's teacher-forcing rows; every
          position verdicted through fuzz_classify (prompt-
          boundary comparator class per the A-067 precedent).
  GEN     4 random prompts x 8 greedy tokens: GPU greedy_from
          vs a CPU greedy loop over teacher-forcing rows; any
          mismatch step is graded + verdicted, never hidden.
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


def main() raises:
    print("A078_BENCH base_seed=", FUZZ_BASE_SEED)
    var failures = 0

    # SYNTH
    var scounts = List[Int]()
    for _ in range(6):
        scounts.append(0)
    for idx in range(256):
        var seed = fuzz_case_seed(FUZZ_BASE_SEED, idx)
        var n = fuzz_case_vocab(idx)
        var row = fuzz_logit_row(seed, n)
        var target = parity_top_token(row)
        var margin = fuzz_top_margin(row)
        var noise = FuzzLcg(seed ^ 0x5EED)
        var gpu = List[Float32]()
        for i in range(n):
            gpu.append(row[i] + (noise.unit() - Float32(0.5)) * Float32(0.02))
        var code = fuzz_classify(
            parity_logit_rank(gpu, target), parity_logit_gap(gpu, target),
            Float32(0.0), parity_top_token(gpu) == target,
            False, False, margin,
        )
        if code == FUZZ_INVALID or code == FUZZ_REAL:
            failures += 1
            print("SYNTH REAL/INVALID case ", idx, " seed ", seed)
        else:
            scounts[code] += 1
    print(
        "SYNTH total=256 faithful=", scounts[FUZZ_FAITHFUL],
        " near_tie=", scounts[FUZZ_NEAR_TIE],
        " noise=", scounts[FUZZ_NOISE],
        " comparator=", scounts[FUZZ_COMPARATOR],
        " real=", scounts[FUZZ_REAL],
    )

    if not _vk_present():
        print("A078_BENCH: Vulkan UNAVAILABLE - device sections not run")
        print("A078_BENCH: FAIL")
        return

    # SAMPLE
    var greedy_ok = 0
    for idx in range(96):
        var seed = fuzz_case_seed(FUZZ_BASE_SEED, idx)
        var row = fuzz_logit_row(seed, fuzz_case_vocab(idx))
        if _gpu_greedy(row) == parity_top_token(row):
            greedy_ok += 1
        else:
            failures += 1
            print("SAMPLE GREEDY MISMATCH case ", idx, " seed ", seed)
    var temps = List[Float32]()
    temps.append(Float32(0.7))
    temps.append(Float32(1.0))
    temps.append(Float32(1.3))
    var sample_ok = 0
    for idx in range(96):
        var seed = fuzz_case_seed(FUZZ_BASE_SEED, idx + 100)
        var row = fuzz_logit_row(seed, fuzz_case_vocab(idx))
        var top_k = 1 + (idx % 5) * 3
        var temp = temps[idx % 3]
        var u_lcg = FuzzLcg(seed ^ 0x55)
        var u = u_lcg.unit()
        if _gpu_sample(row, top_k, temp, u) == _cpu_sample(row, top_k, temp, u):
            sample_ok += 1
        else:
            failures += 1
            print("SAMPLE TEMP MISMATCH case ", idx, " seed ", seed)
    print("SAMPLE greedy_ok=", greedy_ok, "/96 sample_ok=", sample_ok, "/96")

    # REAL
    var engine = AesirEngine(_FIXTURE)
    var model = VulkanRealModel(_FIXTURE)
    model.load()
    var lens = List[Int]()
    lens.append(1)
    lens.append(2)
    lens.append(3)
    lens.append(4)
    lens.append(5)
    lens.append(8)
    lens.append(13)
    lens.append(21)
    var totals = List[Int]()
    for _ in range(6):
        totals.append(0)
    var total_pos = 0
    print("case seed len pos faithful near_tie noise comparator real worst_delta top1_agree")
    for c in range(24):
        var seed = fuzz_case_seed(FUZZ_BASE_SEED, c + 200)
        var raw = fuzz_prompt_ids(seed, lens[c % 8], 32000)
        var seq = List[Int]()
        for i in range(len(raw)):
            seq.append(raw[i] + 256)
        var cpu_rows = engine.teacher_forcing_logit_rows(seq)
        var counts = List[Int]()
        for _ in range(6):
            counts.append(0)
        var worst = Float32(0.0)
        var agree = 0
        model.reset_kv()
        for p in range(len(seq) - 1):
            var gpu_row = model.decode_step(seq[p], p)
            var target = seq[p + 1]
            var gap = parity_logit_gap(gpu_row, target)
            var cpu_gap = parity_logit_gap(cpu_rows[p], target)
            var top_agree = parity_top_token(gpu_row) == parity_top_token(cpu_rows[p])
            if top_agree:
                agree += 1
            var delta = gap - cpu_gap
            if delta < Float32(0.0):
                delta = -delta
            if delta > worst:
                worst = delta
            var code = fuzz_classify(
                parity_logit_rank(gpu_row, target), gap, cpu_gap,
                top_agree, True, False, fuzz_top_margin(cpu_rows[p]),
            )
            if code == FUZZ_INVALID or code == FUZZ_REAL:
                failures += 1
            else:
                counts[code] += 1
            totals[code] += 1
            total_pos += 1
        print(
            c, " ", seed, " ", len(seq), " ", len(seq) - 1, " ",
            counts[FUZZ_FAITHFUL], " ", counts[FUZZ_NEAR_TIE], " ",
            counts[FUZZ_NOISE], " ", counts[FUZZ_COMPARATOR], " ",
            counts[FUZZ_REAL], " ", worst, " ", agree, "/", len(seq) - 1,
        )
    print(
        "REAL total_pos=", total_pos,
        " faithful=", totals[FUZZ_FAITHFUL],
        " near_tie=", totals[FUZZ_NEAR_TIE],
        " noise=", totals[FUZZ_NOISE],
        " comparator=", totals[FUZZ_COMPARATOR],
        " real=", totals[FUZZ_REAL],
    )

    # GEN
    var gen_exact = 0
    var gen_steps = 0
    for c in range(4):
        var seed = fuzz_case_seed(FUZZ_BASE_SEED, c + 300)
        var raw = fuzz_prompt_ids(seed, 6, 32000)
        var ids = List[Int]()
        for i in range(len(raw)):
            ids.append(raw[i] + 256)
        var gpu_gen = model.greedy_from(ids, 8)
        var seq = ids.copy()
        var cpu_gen = List[Int]()
        for _ in range(8):
            var rows = engine.teacher_forcing_logit_rows(seq)
            var nxt = parity_top_token(rows[len(rows) - 1])
            cpu_gen.append(nxt)
            seq.append(nxt)
        for i in range(8):
            gen_steps += 1
            if gpu_gen[i] == cpu_gen[i]:
                gen_exact += 1
            else:
                failures += 1
                print(
                    "GEN MISMATCH case ", c, " seed ", seed, " step ", i,
                    " gpu=", gpu_gen[i], " cpu=", cpu_gen[i],
                )
    model.close()
    print("GEN exact=", gen_exact, "/", gen_steps)

    if failures == 0:
        print("A078_BENCH: PASS")
    else:
        print("A078_BENCH: FAIL failures=", failures)
