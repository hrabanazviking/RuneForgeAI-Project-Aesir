"""Context ladder accounting (Janas road J-091).

The roadmap text: "Reading and writing measured at
1k / 4k / 8k / 16k / 32k on a dense mid-size model, CPU
line and GPU line, KV at both precisions -- the Janas
long-context table rebuilt for Aesir, on Aesir's
hardware, with llama-bench-class comparator numbers
taken under the raw-oracle discipline (conditions
stated where they cannot be identical)."

DESIGN, stated up front (the J-091 doc is its normative
text; this header records the choices the code embodies,
PRE-REGISTERED before any J-091 number was produced):

- THE LADDER. Rungs are prompt lengths 1024 / 4096 /
  8192 / 16384 / 32768 tokens. The witness shape is a
  DENSE MID-SIZE model: the ladder's live witness is
  Qwen2.5-Coder-7B Q4_K_M (28 layers, hidden 3584, ffn
  18944, 28 query heads, 4 kv heads, head_dim 128,
  vocab 152064, profile context cap 32768) -- the only
  dense mid-size profile in the tree whose cap reaches
  every rung (Llama 3 8B and Llama 3.2 3B cap at 8192).
  This module is shape-generic: every function takes
  the shape as arguments, and the tests pin the Coder
  values. No other model's ladder is filed by this
  slice.

- READING AND WRITING, DEFINED. READING at rung L is
  the prefill of a raw prompt of exactly L tokens.
  WRITING at rung L is the generation of
  LADDER_GEN_TOKENS (128) tokens immediately after that
  prompt, greedy: the first generated token attends at
  context L, the last at L + 127. One session serves
  both legs, so a rung's SESSION CONTEXT is L + 128 --
  admission and caps are judged at the session context
  for the write leg and at L for the read leg (the
  verdict function takes the direction explicitly).

- THE FRAME IS EXACT ARITHMETIC, NOT SPEED. Per rung,
  line and precision this module prices: KV bytes per
  token and in total (through core/kv_account.mojo for
  f16 and core/kv_int8.mojo for per-row int8, so the
  ladder cannot drift from J-087's census or J-088's
  store); prefill causal pairs, attention MACs and
  projection MACs (through core/prefill_anatomy.mojo,
  J-053's account, so the ladder cannot drift from the
  prefill baseline); decode KV-read traffic (each
  generated token's attention touches every cached
  position's K and V exactly once per layer -- the
  tree's attention loops' by-construction shape -- so
  the traffic of the write leg is the per-token price
  times the sum of the contexts it runs at); decode
  attention MACs on the same sum. Walls are NOT in
  this module and are NOT PROVEN by anything in this
  slice: every wall cell of the ladder is deferred
  with its recipe to the J-098 gate (J-091 doc
  section 7). A number in this module is a count of
  work a run would do, never a claim about how fast.

- CELL VERDICTS, PRE-REGISTERED (ladder_cell_verdict
  is the mechanical form). Each (line, precision,
  rung, direction) cell is exactly one of:
    ACCOUNTED -- the frame above is filled and no tree
      cap refuses the run as constructed; the wall is
      NOT PROVEN (deferred), which the verdict does
      not hide: ACCOUNTED never means measured.
    CAP_REFUSED -- a named tree cap refuses the run
      as constructed: on the CPU line the host
      generation path allocates KV for at most
      HOST_RUNTIME_CONTEXT_CAP (16000) tokens
      (aesir.mojo MAX_RUNTIME_CONTEXT; the KVCache
      append raises past capacity), so a session
      context above 16000 cannot run there today; on
      the GPU line the dense CUDA session admits at
      most the profile context cap.
    INTEGRATION_BLOCKED -- the precision is not
      integrated into any live session on that line:
      J-088 built the int8 store as a component and
      deferred session integration (its section 7);
      no session on either line constructs it today
      (inspect-asserted). An int8 cell is judged
      INTEGRATION_BLOCKED before any cap question --
      the cap would bind only after integration, and
      both facts are filed in the doc.
  The caller states the integration facts as booleans
  (this slice passes False for both lines, the tree's
  state, inspect-asserted); the module does not guess
  them.

- GPU PLACEMENT, ACCOUNTED. The GPU line's admission
  arithmetic is the tree's own: llama3_memory_plan's
  required bytes = device weights + KV elements x 2
  (f16) + activation elements x 4 + sampling bytes,
  against the usable VRAM filed by J-031 for
  purplelongship's RTX 2060 (5368709120 B). A rung is
  WHOLE_GPU when the required bytes at its session
  context fit, SPILL_REQUIRED when they do not (the
  spill session is the proven shape for this model:
  whole-GPU at 4096, spilled at 16384, GPU_2060_STATE).
  Cross-check, stated before running: at context
  16384 this arithmetic must land within 16 bytes of
  the filed whole-model refusal total 5626175108
  (GPU_2060_STATE, 2026-10-28) -- the filed run's
  device-weight accounting carried per-run conversion
  detail the file size does not state, so exact
  equality is not demanded; the inspect script checks
  the tolerance and the refusal's direction (required
  exceeds usable under both figures). The int8 GPU
  figures are a COUNTERFACTUAL, labelled as such
  wherever printed: what admission would cost if the
  deferred CUDA int8 integration (J-088 section 7
  step 2) existed with the host store's per-row
  prices. No int8 GPU run is possible today.

HOST CONTRACT: (1) price every ladder claim through
this module, never from memory; (2) a wall may be
filed in a ladder cell only from a live run under
the J-091 doc section 7 recipe (guarded window,
sha-pinned file, machine state stated, ids-first
raw-oracle grading, llama-bench comparator with its
conditions stated); (3) CAP_REFUSED and
INTEGRATION_BLOCKED cells are results, not gaps to
be smoothed over -- the J-098 gate re-cites them.
"""

from core.kv_account import (
    HOST_RUNTIME_CONTEXT_CAP,
    KV_ELEM_F16,
    kv_bytes_per_token,
    kv_total_bytes,
)
from core.kv_int8 import kv8_bytes_per_token, kv8_total_bytes
from core.prefill_anatomy import (
    prefill_attention_macs,
    prefill_attention_pairs,
    prefill_lm_head_macs,
    prefill_projection_macs_per_token,
)

comptime LADDER_RUNG_COUNT = 5
comptime LADDER_GEN_TOKENS = 128

comptime LADDER_LINE_CPU = 0
comptime LADDER_LINE_GPU = 1

comptime LADDER_PRECISION_F16 = 0
comptime LADDER_PRECISION_INT8 = 1

comptime LADDER_READ = 0
comptime LADDER_WRITE = 1

comptime LADDER_ACCOUNTED = 0
comptime LADDER_CAP_REFUSED = 1
comptime LADDER_INTEGRATION_BLOCKED = 2

comptime LADDER_GPU_WHOLE = 0
comptime LADDER_GPU_SPILL = 1


def ladder_rung(index: Int) raises -> Int:
    """The ladder's rungs, in order: the roadmap's
    1k / 4k / 8k / 16k / 32k as exact token counts."""
    if index == 0:
        return 1024
    if index == 1:
        return 4096
    if index == 2:
        return 8192
    if index == 3:
        return 16384
    if index == 4:
        return 32768
    raise Error("KVLadder: rung index outside [0, 5)")


def ladder_precision_name(code: Int) raises -> String:
    if code == LADDER_PRECISION_F16:
        return String("f16")
    if code == LADDER_PRECISION_INT8:
        return String("int8")
    raise Error("KVLadder: unknown precision code")


def ladder_line_name(code: Int) raises -> String:
    if code == LADDER_LINE_CPU:
        return String("cpu")
    if code == LADDER_LINE_GPU:
        return String("gpu")
    raise Error("KVLadder: unknown line code")


def ladder_verdict_name(code: Int) raises -> String:
    if code == LADDER_ACCOUNTED:
        return String("ACCOUNTED")
    if code == LADDER_CAP_REFUSED:
        return String("CAP_REFUSED")
    if code == LADDER_INTEGRATION_BLOCKED:
        return String("INTEGRATION_BLOCKED")
    raise Error("KVLadder: unknown verdict code")


def ladder_gpu_placement_name(code: Int) raises -> String:
    if code == LADDER_GPU_WHOLE:
        return String("WHOLE_GPU")
    if code == LADDER_GPU_SPILL:
        return String("SPILL_REQUIRED")
    raise Error("KVLadder: unknown GPU placement code")


def _check_shape(layers: Int, kv_heads: Int, head_dim: Int) raises:
    if layers <= 0 or kv_heads <= 0 or head_dim <= 0:
        raise Error("KVLadder: layers/kv_heads/head_dim must be positive")


def ladder_kv_bytes_per_token(
    layers: Int, kv_heads: Int, head_dim: Int, precision: Int
) raises -> Int:
    """KV price per token at a ladder precision, defined
    through the census (f16) and the store (int8) so the
    ladder cannot drift from J-087/J-088."""
    _check_shape(layers, kv_heads, head_dim)
    if precision == LADDER_PRECISION_F16:
        return kv_bytes_per_token(layers, kv_heads, head_dim, KV_ELEM_F16)
    if precision == LADDER_PRECISION_INT8:
        return kv8_bytes_per_token(layers, kv_heads, head_dim)
    raise Error("KVLadder: unknown precision code")


def ladder_kv_total(
    layers: Int, kv_heads: Int, head_dim: Int, precision: Int, context: Int
) raises -> Int:
    """Total KV bytes held at a stated context."""
    _check_shape(layers, kv_heads, head_dim)
    if context <= 0:
        raise Error("KVLadder: context must be positive")
    if precision == LADDER_PRECISION_F16:
        return kv_total_bytes(
            kv_bytes_per_token(layers, kv_heads, head_dim, KV_ELEM_F16),
            context,
        )
    if precision == LADDER_PRECISION_INT8:
        return kv8_total_bytes(layers, kv_heads, head_dim, context)
    raise Error("KVLadder: unknown precision code")


def ladder_prefill_pairs(rung: Int) raises -> Int:
    """Causal (query, key) pairs in one layer over the
    rung's prompt (J-053's account)."""
    return prefill_attention_pairs(rung)


def ladder_prefill_attention_macs(
    layers: Int, q_width: Int, rung: Int
) raises -> Int:
    """Attention MACs over the rung's whole prompt
    (J-053's account: pairs x q_width x 2 per layer)."""
    return prefill_attention_macs(layers, q_width, rung)


def ladder_prefill_projection_macs(
    layers: Int,
    hidden: Int,
    q_width: Int,
    kv_width: Int,
    ffn: Int,
    rung: Int,
) raises -> Int:
    """Dense projection + FFN MACs over the rung's whole
    prompt (J-053's per-token account times the rung).
    Excludes attention and the LM head, each priced
    separately so the split stays visible."""
    if rung <= 0:
        raise Error("KVLadder: rung must be positive")
    return (
        prefill_projection_macs_per_token(layers, hidden, q_width, kv_width, ffn)
        * rung
    )


def ladder_head_macs(hidden: Int, vocab: Int) raises -> Int:
    """The one LM-head pass a prompt (or a generated
    token) pays on the dense surfaces (J-053)."""
    return prefill_lm_head_macs(hidden, vocab, 1)


def ladder_decode_context_sum(rung: Int, gen_tokens: Int) raises -> Int:
    """Sum of the contexts the write leg runs at:
    rung + (rung+1) + ... + (rung+gen-1). The single
    sum every decode quantity below is priced on."""
    if rung <= 0 or gen_tokens <= 0:
        raise Error("KVLadder: rung/gen_tokens must be positive")
    return gen_tokens * rung + gen_tokens * (gen_tokens - 1) // 2


def ladder_decode_kv_read_bytes(
    kv_bytes_per_token_value: Int, rung: Int, gen_tokens: Int
) raises -> Int:
    """KV bytes the write leg's attention reads: each
    generated token touches every cached position's K
    and V once per layer, so the traffic is the
    per-token price times the context sum. A traffic
    SHAPE by construction (caches sit between it and
    any device), never a measured byte count."""
    if kv_bytes_per_token_value <= 0:
        raise Error("KVLadder: KV per-token price must be positive")
    return kv_bytes_per_token_value * ladder_decode_context_sum(
        rung, gen_tokens
    )


def ladder_decode_attention_macs(
    layers: Int, q_width: Int, rung: Int, gen_tokens: Int
) raises -> Int:
    """Attention MACs of the write leg: per generated
    token, layers x context x q_width x 2, summed over
    the leg's contexts."""
    if layers <= 0 or q_width <= 0:
        raise Error("KVLadder: attention shape must be positive")
    return (
        layers
        * q_width
        * 2
        * ladder_decode_context_sum(rung, gen_tokens)
    )


def ladder_session_context(rung: Int, direction: Int) raises -> Int:
    """The context a cell's run must be admitted at:
    the rung itself for a read leg; rung + gen for a
    write leg (one session serves the prompt and the
    generation that follows it)."""
    if rung <= 0:
        raise Error("KVLadder: rung must be positive")
    if direction == LADDER_READ:
        return rung
    if direction == LADDER_WRITE:
        return rung + LADDER_GEN_TOKENS
    raise Error("KVLadder: unknown direction code")


def ladder_cell_verdict(
    line: Int,
    precision: Int,
    rung: Int,
    direction: Int,
    int8_cpu_integrated: Bool,
    int8_gpu_integrated: Bool,
    profile_cap: Int,
) raises -> Int:
    """The pre-registered cell verdict (this module's
    header). Integration is judged before caps: an
    unintegrated precision cannot run at any length.
    The host cap is J-087's HOST_RUNTIME_CONTEXT_CAP
    (aesir.mojo MAX_RUNTIME_CONTEXT); the GPU cap is
    the model's profile context cap, stated by the
    caller from the profile."""
    if line != LADDER_LINE_CPU and line != LADDER_LINE_GPU:
        raise Error("KVLadder: unknown line code")
    if precision != LADDER_PRECISION_F16 and precision != LADDER_PRECISION_INT8:
        raise Error("KVLadder: unknown precision code")
    if profile_cap <= 0:
        raise Error("KVLadder: profile cap must be positive")
    if precision == LADDER_PRECISION_INT8:
        var integrated = (
            int8_cpu_integrated if line == LADDER_LINE_CPU else int8_gpu_integrated
        )
        if not integrated:
            return LADDER_INTEGRATION_BLOCKED
    var needed = ladder_session_context(rung, direction)
    var cap = HOST_RUNTIME_CONTEXT_CAP if line == LADDER_LINE_CPU else profile_cap
    if needed > cap:
        return LADDER_CAP_REFUSED
    return LADDER_ACCOUNTED


def ladder_gpu_required_bytes(
    weights_bytes: Int,
    kv_bytes_per_token_value: Int,
    context: Int,
    activation_fixed_elements: Int,
    activation_per_context_elements: Int,
    sampling_bytes: Int,
) raises -> Int:
    """The dense CUDA session's admission arithmetic
    (llama3_memory_plan's shape): device weights + KV
    at the stated per-token price + activation elements
    (a fixed part plus a per-context part) at 4 bytes +
    the sampler's device bytes. The KV price is a
    caller-stated input so the int8 counterfactual can
    be priced through the same admission shape; the
    shipping session's price is the f16 one."""
    if (
        weights_bytes <= 0
        or kv_bytes_per_token_value <= 0
        or context <= 0
        or activation_fixed_elements < 0
        or activation_per_context_elements < 0
        or sampling_bytes < 0
    ):
        raise Error("KVLadder: GPU admission inputs are invalid")
    var act_elements = (
        activation_fixed_elements + activation_per_context_elements * context
    )
    return (
        weights_bytes
        + kv_bytes_per_token_value * context
        + act_elements * 4
        + sampling_bytes
    )


def ladder_gpu_placement(required_bytes: Int, usable_bytes: Int) raises -> Int:
    """WHOLE_GPU when the admission total fits the
    usable device bytes, SPILL_REQUIRED when it does
    not. Placement is an admission fact, not a speed."""
    if required_bytes <= 0 or usable_bytes <= 0:
        raise Error("KVLadder: placement inputs must be positive")
    return LADDER_GPU_WHOLE if required_bytes <= usable_bytes else LADDER_GPU_SPILL
