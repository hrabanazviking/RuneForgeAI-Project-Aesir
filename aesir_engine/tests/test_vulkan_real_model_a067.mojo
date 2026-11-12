"""Vulkan real-model decode (A-067): a 7-8B-class Q4_K_M
fixture decoding on the GPU, graded against the CPU engine
oracle under raw-oracle discipline.

Fixture: Meta-Llama-3.1-8B-Instruct-Q4_K_M.gguf, sha256
7b064f5842bf9532c91456deda288a1b672397a54fa729aa665952863033557c
(verified against the Hugging Face LFS etag before the first
run; the file lives in hidden_files/fixtures/ and is not in
git). Geometry: llama, 32 layers, dim 4096, ffn 14336,
32 heads / 8 KV heads / head_dim 128, vocab 128256.

Acceptance (roadmap A-067): teacher-forcing rank/logit-gap
battery vs the CPU oracle judged per law 3 + a coherence-
graded generation sample filed (docs/bench/
A067_REAL_MODEL_GPU_DECODE.md). The battery grades the RAW
prompt "The capital of France is" (add_bos=True, no chat
template - the A-004/A-045 standard) plus the CPU engine's
own 8-token greedy continuation, teacher-forced through both
engines. Positions split per the A-045 precedent:
continuation positions (target beyond the prompt) must all
land in the law-3 faithful band (verdict faithful or
near-tie: rank <= 2 with gap < 1.0, via core/parity_battery);
prompt-internal positions are the prompt-boundary comparator
class - the target is unlikely under BOTH engines - and are
judged by cross-engine agreement instead: |gpu_gap - cpu_gap|
<= 0.05 (measured worst 0.01 in the driver) and top-1
agreement at every position (measured 13/13).

Generation case: the GPU greedy continuation must reproduce
the CPU engine's greedy token ids exactly for 16 tokens
(measured 16/16; the filed sample text is in the bench doc).

Dispatch evidence (law 6), exact per decode step on this
fixture (measured in the driver): q4k GEMV 192 (6 per layer),
q6k GEMV 36 (1 per layer + 4 lm_head chunks), q5k 0,
rmsnorm 65 (2 per layer + final), rope 64, attention 32,
elementwise 96. One loaded model holds exactly 32 live
buffers (streamed residency under the shim's 128-slot cap).

On a host without the RADV device, or without the fixture,
the device cases pass as honest-absent (A-014/A-065
discipline). The sanitizer and permutation cases are pure
host and always run.
"""
from std.memory import bitcast
from core.vulkan_buffers import VulkanBuffers
from core.vulkan_gemv import VulkanGemv
from core.vulkan_norm_rope import VulkanNormRope
from core.vulkan_attention import VulkanAttention
from core.vulkan_elementwise import VulkanElementwise
from core.sampler import sanitize_logit
from core.parity_battery import (
    parity_logit_gap,
    parity_logit_rank,
    parity_top_token,
    parity_verdict_code,
)
from core.vulkan_real_model import (
    VulkanRealModel,
    sanitize_logit_row,
    permute_rope_pairs,
)
from aesir import AesirEngine

comptime _FIXTURE = "/home/volmarr/aesir-team-03/hidden_files/fixtures/Meta-Llama-3.1-8B-Instruct-Q4_K_M.gguf"
comptime _PROMPT = "The capital of France is"


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
    """True when the fixture loads; False = honest-absent."""
    try:
        var m = VulkanRealModel(path)
        m.load()
        m.close()
        return True
    except:
        return False


def test_vulkan_real_model_sanitize_policy() raises:
    print("--- Testing Vulkan real-model logit sanitization (A-067) ---")
    var nan = bitcast[DType.float32](UInt32(0x7FC00000))
    var inf = bitcast[DType.float32](UInt32(0x7F800000))
    var ninf = bitcast[DType.float32](UInt32(0xFF800000))
    var row = List[Float32]()
    row.append(Float32(0.5))
    row.append(nan)
    row.append(inf)
    row.append(ninf)
    row.append(Float32(-3.25))
    row.append(Float32(1.0e9))
    var original = row.copy()
    var replaced = sanitize_logit_row(row)
    if replaced != 3:
        raise Error("sanitize: expected 3 replaced lanes, got " + String(replaced))
    for i in range(len(row)):
        if row[i] != sanitize_logit(original[i]):
            raise Error("sanitize: lane " + String(i) + " differs from the CPU sampler policy")
    if row[1] != Float32(-1.0e9) or row[2] != Float32(-1.0e9) or row[3] != Float32(-1.0e9):
        raise Error("sanitize: non-finite lanes must become -1e9")
    var clean = List[Float32]()
    clean.append(Float32(1.0))
    clean.append(Float32(-2.0))
    if sanitize_logit_row(clean) != 0:
        raise Error("sanitize: clean row must report 0 replacements")
    var empty = List[Float32]()
    if sanitize_logit_row(empty) != 0:
        raise Error("sanitize: empty row must report 0 replacements")
    print("sanitize policy: NaN/+Inf/-Inf -> -1e9, counts exact, CPU-policy identical")


def test_vulkan_real_model_rope_permutation() raises:
    print("--- Testing Vulkan real-model RoPE layout permutation (A-067) ---")
    var x = List[Float32]()
    for i in range(8):
        x.append(Float32(i))
    var p = permute_rope_pairs(x, 8)
    var want = List[Float32]()
    want.append(Float32(0))
    want.append(Float32(2))
    want.append(Float32(4))
    want.append(Float32(6))
    want.append(Float32(1))
    want.append(Float32(3))
    want.append(Float32(5))
    want.append(Float32(7))
    if len(p) != len(want):
        raise Error("permute: length drift")
    for i in range(len(want)):
        if p[i] != want[i]:
            raise Error("permute: lane " + String(i) + " wrong")
    var two = List[Float32]()
    for i in range(16):
        two.append(Float32(100 + i))
    var p2 = permute_rope_pairs(two, 8)
    if p2[0] != Float32(100) or p2[4] != Float32(101) or p2[8] != Float32(108) or p2[12] != Float32(109):
        raise Error("permute: second head row not permuted independently")
    var pair = List[Float32]()
    pair.append(Float32(7.0))
    pair.append(Float32(9.0))
    var p3 = permute_rope_pairs(pair, 2)
    if p3[0] != Float32(7.0) or p3[1] != Float32(9.0):
        raise Error("permute: head_dim 2 must be the identity")
    print("rope permutation: interleaved -> rotate-half reindex exact")


def test_vulkan_real_model_fixture_config() raises:
    print("--- Testing Vulkan real-model fixture config (A-067) ---")
    if not _vk_present():
        print("Vulkan UNAVAILABLE: fixture config not run (honest-absent)")
        return
    if not _load_or_none(_FIXTURE):
        print("FIXTURE ABSENT: config not run (honest-absent)")
        return
    var before = VulkanBuffers.live_count()
    var m = VulkanRealModel(_FIXTURE)
    m.load()
    if m.layers != 32 or m.dim != 4096 or m.ffn != 14336:
        raise Error("config: layer/dim/ffn geometry mismatch")
    if m.heads != 32 or m.kv_heads != 8 or m.head_dim != 128:
        raise Error("config: head geometry mismatch")
    if m.vocab != 128256:
        raise Error("config: vocab mismatch")
    var held = VulkanBuffers.live_count() - before
    if held != 32:
        raise Error("config: loaded model must hold exactly 32 live buffers, got " + String(held))
    m.close()
    if VulkanBuffers.live_count() - before != 0:
        raise Error("config: close() must release every buffer")
    print("fixture config: llama 32L dim 4096 ffn 14336 vocab 128256, 32 live buffers, close releases all")


def test_vulkan_real_model_teacher_forcing() raises:
    print("--- Testing Vulkan real-model teacher-forcing battery (A-067) ---")
    if not _vk_present():
        print("Vulkan UNAVAILABLE: battery not run (honest-absent)")
        return
    if not _load_or_none(_FIXTURE):
        print("FIXTURE ABSENT: battery not run (honest-absent)")
        return
    var engine = AesirEngine(_FIXTURE)
    var ids = engine.tokenizer.encode(_PROMPT, True)
    var cont = engine.generate_tokens(_PROMPT, 8)
    var seq = ids.copy()
    for i in range(len(cont.token_ids)):
        seq.append(cont.token_ids[i])
    var cpu_rows = engine.teacher_forcing_logit_rows(seq)
    var model = VulkanRealModel(_FIXTURE)
    model.load()
    model.reset_kv()
    var agree = 0
    var cont_positions = 0
    for p in range(len(seq) - 1):
        var gpu_row = model.decode_step(seq[p], p)
        var target = seq[p + 1]
        var rank = parity_logit_rank(gpu_row, target)
        var gap = parity_logit_gap(gpu_row, target)
        var code = parity_verdict_code(rank, gap)
        if parity_top_token(gpu_row) == parity_top_token(cpu_rows[p]):
            agree += 1
        if p + 1 >= len(ids):
            cont_positions += 1
            if code != 0 and code != 1:
                raise Error(
                    "battery: continuation pos " + String(p)
                    + " left the faithful band: rank=" + String(rank)
                    + " gap=" + String(gap)
                )
        else:
            var cpu_gap = parity_logit_gap(cpu_rows[p], target)
            var delta = gap - cpu_gap
            if delta < Float32(0.0):
                delta = -delta
            if delta > Float32(0.05):
                raise Error(
                    "battery: prompt-boundary pos " + String(p)
                    + " cross-engine gap delta " + String(delta)
                    + " exceeds the filed 0.05"
                )
    if agree != len(seq) - 1:
        raise Error("battery: top-1 agreement " + String(agree) + " of " + String(len(seq) - 1))
    model.close()
    print(
        "battery: continuation faithful-band ", cont_positions, "/",
        cont_positions, ", top-1 agreement ", agree, "/", len(seq) - 1,
    )


def test_vulkan_real_model_generation() raises:
    print("--- Testing Vulkan real-model GPU greedy generation (A-067) ---")
    if not _vk_present():
        print("Vulkan UNAVAILABLE: generation not run (honest-absent)")
        return
    if not _load_or_none(_FIXTURE):
        print("FIXTURE ABSENT: generation not run (honest-absent)")
        return
    var engine = AesirEngine(_FIXTURE)
    var ids = engine.tokenizer.encode(_PROMPT, True)
    var cpu = engine.generate_tokens(_PROMPT, 16)
    var model = VulkanRealModel(_FIXTURE)
    model.load()
    var gpu = model.greedy_from(ids, 16)
    model.close()
    if len(gpu) != 16:
        raise Error("generation: expected 16 GPU tokens, got " + String(len(gpu)))
    if gpu[0] != 264:
        raise Error("generation: first GPU token must be 264 (Paris), got " + String(gpu[0]))
    for i in range(16):
        if gpu[i] != cpu.token_ids[i]:
            raise Error(
                "generation: GPU/CPU greedy divergence at token "
                + String(i) + ": gpu=" + String(gpu[i])
                + " cpu=" + String(cpu.token_ids[i])
            )
    print("generation: GPU greedy == CPU greedy 16/16, first token 264")


def test_vulkan_real_model_dispatch_evidence() raises:
    print("--- Testing Vulkan real-model dispatch evidence (A-067) ---")
    if not _vk_present():
        print("Vulkan UNAVAILABLE: dispatch evidence not run (honest-absent)")
        return
    if not _load_or_none(_FIXTURE):
        print("FIXTURE ABSENT: dispatch evidence not run (honest-absent)")
        return
    var model = VulkanRealModel(_FIXTURE)
    model.load()
    model.reset_kv()
    var q4k0 = VulkanBuffers.q4k_gemv_dispatch_count()
    var q60 = VulkanGemv.q6_dispatch_count()
    var q50 = VulkanGemv.q5_dispatch_count()
    var rms0 = VulkanNormRope.rmsnorm_dispatch_count()
    var rope0 = VulkanNormRope.rope_dispatch_count()
    var attn0 = VulkanAttention.dispatch_count()
    var elem0 = VulkanElementwise.elementwise_dispatch_count()
    _ = model.decode_step(128000, 0)
    var dq4k = VulkanBuffers.q4k_gemv_dispatch_count() - q4k0
    var dq6 = VulkanGemv.q6_dispatch_count() - q60
    var dq5 = VulkanGemv.q5_dispatch_count() - q50
    var drms = VulkanNormRope.rmsnorm_dispatch_count() - rms0
    var drope = VulkanNormRope.rope_dispatch_count() - rope0
    var dattn = VulkanAttention.dispatch_count() - attn0
    var delem = VulkanElementwise.elementwise_dispatch_count() - elem0
    model.close()
    if dq4k != 192 or dq6 != 36 or dq5 != 0:
        raise Error(
            "dispatch: GEMV deltas q4k=" + String(dq4k) + " q6k="
            + String(dq6) + " q5k=" + String(dq5) + " (want 192/36/0)"
        )
    if drms != 65 or drope != 64 or dattn != 32 or delem != 96:
        raise Error(
            "dispatch: kernel deltas rms=" + String(drms) + " rope="
            + String(drope) + " attn=" + String(dattn) + " elem="
            + String(delem) + " (want 65/64/32/96)"
        )
    print("dispatch evidence: one step = q4k 192, q6k 36, rmsnorm 65, rope 64, attn 32, elementwise 96 on RADV")


def test_vulkan_real_model_rejection() raises:
    print("--- Testing Vulkan real-model rejection (A-067) ---")
    var cold = VulkanRealModel(_FIXTURE)
    var raised = False
    try:
        _ = cold.decode_step(128000, 0)
    except:
        raised = True
    if not raised:
        raise Error("rejection: decode_step before load must raise")
    raised = False
    try:
        var bad = VulkanRealModel("/nonexistent/a067.gguf")
        bad.load()
    except:
        raised = True
    if not raised:
        raise Error("rejection: missing fixture load must raise")
    if not _vk_present():
        print("Vulkan UNAVAILABLE: loaded-model rejection not run (honest-absent)")
        return
    if not _load_or_none(_FIXTURE):
        print("FIXTURE ABSENT: loaded-model rejection not run (honest-absent)")
        return
    var m = VulkanRealModel(_FIXTURE)
    m.load()
    m.reset_kv()
    raised = False
    try:
        _ = m.decode_step(m.vocab, 0)
    except:
        raised = True
    if not raised:
        raise Error("rejection: token == vocab must raise")
    raised = False
    try:
        _ = m.decode_step(-1, 0)
    except:
        raised = True
    if not raised:
        raise Error("rejection: negative token must raise")
    raised = False
    try:
        _ = m.decode_step(128000, 1)
    except:
        raised = True
    if not raised:
        raise Error("rejection: non-sequential position must raise")
    m.close()
    print("rejection: pre-load, bad path, bad token, skipped position all raise pre-dispatch")
