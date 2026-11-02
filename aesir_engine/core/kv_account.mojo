"""KV precision census account (Janas road J-087).

The baseline J-088's 8-bit KV will be graded against: what
Aesir's KV cache costs today, per token, per architecture --
bytes, layout, precision -- as exact arithmetic over the
tree's own constants. The full census, with file:line
citations for every row, is docs/janas/
J087_KV_PRECISION_CENSUS.md; this module is its executable
form, in the J-067 account grain (pure arithmetic: it
allocates nothing, opens no device, and contains no speed).

THE CENSUS IN ONE PARAGRAPH (all of it proven from the tree
by docs/janas/j087_inspect.py):

- The host cache (core/mimir_well.mojo KVCache, and its
  PagedKVCache wrapper) stores K and V as two separate
  RuneTensor[f16] buffers, each laid out
  [layer][position][kv_width] row-major, fixed-capacity:
  append raises past capacity -- no wrap, no eviction.
  Every host session (generic dense, Gemma 4 CPU, Qwen3.5
  CPU, the streamed OLMoE session, the spill tail) draws
  this one cache, sized layers x context x kv_dim.
- The dense CUDA sessions (core/llama3_cuda.mojo, serving
  every DenseGQAProfile) hold ONE DType.float16 device
  buffer: per layer a K block of context x kv_width
  followed by a V block of the same size.
- The Gemma 4 CUDA session (core/gemma4_cuda.mojo) is the
  one path whose KV is NOT f16: its cache buffer is
  DType.float32, laid out per OWNING layer as K slots then
  V slots, local (sliding-window) layers capped at 512
  slots in a true ring (slot = position % capacity),
  global layers at the full session context. Part I's gate
  recorded "Aesir's KV is f16"; that is true of every path
  except this one, and this module keeps the exception
  priced in f32 where it belongs.
- No 8-bit or otherwise quantized KV storage exists
  anywhere in the tree (inspect-searched). The int8
  functions below are a PROJECTION -- the arithmetic
  J-088's design will be graded against -- never a claim
  about the tree.

FORMULAS (element size e bytes; K and V are two tensors):

- Uniform shape (every layer owns KV at one width):
  bytes/token = layers * 2 * kv_heads * head_dim * e
              = layers * 2 * kv_width * e.
- Gemma 4 host: the cache is allocated for ALL layers at
  the global width (cache width = kv_heads * global
  head_dim), written only by owning layers, and local
  rows are zero-padded from their true width -- so the
  census states three numbers (allocated / written /
  useful), never one.
- Gemma 4 CUDA: local owning layers cost a FIXED ring of
  512 slots each (they stop growing at 512 tokens); only
  global owning layers grow per token, at f32 prices.

HOST CONTRACT: a KV byte claim for a named shape is stated
through evaluate_kv_claim before it is quoted; a claim
that does not match the tree's constants for that shape
is a defect in the claim, not a rounding choice. J-088
adds its 8-bit storage beside these figures and grades
its saving against kv_bytes_per_token at KV_ELEM_F16 --
and, for the Gemma 4 CUDA path, against the f32 figures
in this module, where the honest saving is twice as
large.
"""

comptime KV_ELEM_F16 = 2
comptime KV_ELEM_F32 = 4
comptime KV_ELEM_INT8 = 1

comptime KV_PRECISION_F16 = 0
comptime KV_PRECISION_F32 = 1
comptime KV_PRECISION_INT8_PROJECTED = 2

comptime KV_CLAIM_MATCHES = 0
comptime KV_CLAIM_MISMATCH = 1

comptime GEMMA4_LOCAL_CAPACITY = 512
comptime HOST_RUNTIME_CONTEXT_CAP = 16000


def _kv_mul(a: Int, b: Int) raises -> Int:
    if a <= 0 or b <= 0 or a > 9223372036854775807 // b:
        raise Error("KVAccount: product overflow or non-positive factor")
    return a * b


def precision_name(code: Int) raises -> String:
    if code == KV_PRECISION_F16:
        return String("f16")
    if code == KV_PRECISION_F32:
        return String("f32")
    if code == KV_PRECISION_INT8_PROJECTED:
        return String("int8-projected")
    raise Error("KVAccount: unknown precision code")


def precision_elem_bytes(code: Int) raises -> Int:
    if code == KV_PRECISION_F16:
        return KV_ELEM_F16
    if code == KV_PRECISION_F32:
        return KV_ELEM_F32
    if code == KV_PRECISION_INT8_PROJECTED:
        return KV_ELEM_INT8
    raise Error("KVAccount: unknown precision code")


def kv_bytes_per_token(
    layers: Int, kv_heads: Int, head_dim: Int, elem_bytes: Int
) raises -> Int:
    """Uniform-shape KV cost: layers x (K and V) x kv width
    x element size. This is the host KVCache's and the dense
    CUDA cache's per-token price at their stated precisions."""
    if elem_bytes != KV_ELEM_F16 and elem_bytes != KV_ELEM_F32 and elem_bytes != KV_ELEM_INT8:
        raise Error("KVAccount: element size must be 1, 2 or 4 bytes")
    var width = _kv_mul(kv_heads, head_dim)
    return _kv_mul(_kv_mul(layers, 2), _kv_mul(width, elem_bytes))


def kv_bytes_per_token_width(
    layers: Int, kv_width: Int, elem_bytes: Int
) raises -> Int:
    """The same price stated at a file's kv_dim directly
    (the host sessions' own sizing form: KVCache(context,
    config.kv_dim(), well, block_count))."""
    if elem_bytes != KV_ELEM_F16 and elem_bytes != KV_ELEM_F32 and elem_bytes != KV_ELEM_INT8:
        raise Error("KVAccount: element size must be 1, 2 or 4 bytes")
    return _kv_mul(_kv_mul(layers, 2), _kv_mul(kv_width, elem_bytes))


def kv_total_bytes(per_token_bytes: Int, context: Int) raises -> Int:
    """Total KV bytes at a stated context length."""
    return _kv_mul(per_token_bytes, context)


def host_cache_context(file_context: Int) raises -> Int:
    """The context the engine's generation path actually
    allocates KV for: min(16000, the file's context) --
    aesir.mojo MAX_RUNTIME_CONTEXT applied in
    _run_generation. A model's full trained context is
    never the allocation."""
    if file_context <= 0:
        raise Error("KVAccount: file context must be positive")
    return HOST_RUNTIME_CONTEXT_CAP if file_context > HOST_RUNTIME_CONTEXT_CAP else file_context


def gemma_owning_layers(layer_count: Int, shared_kv_layers: Int) raises -> Int:
    if layer_count <= 0 or shared_kv_layers < 0 or shared_kv_layers >= layer_count:
        raise Error("KVAccount: Gemma layer/shared counts are invalid")
    return layer_count - shared_kv_layers


def gemma_local_owning_layers(
    layer_count: Int, shared_kv_layers: Int, full_attention_period: Int
) raises -> Int:
    """Owning layers whose attention is local (sliding
    window): every layer except each period-th full one,
    counted over the owning prefix only."""
    var owning = gemma_owning_layers(layer_count, shared_kv_layers)
    if full_attention_period <= 1:
        raise Error("KVAccount: Gemma full-attention period must exceed 1")
    var count = 0
    for layer in range(owning):
        if layer % full_attention_period != full_attention_period - 1:
            count += 1
    return count


def gemma_global_owning_layers(
    layer_count: Int, shared_kv_layers: Int, full_attention_period: Int
) raises -> Int:
    var owning = gemma_owning_layers(layer_count, shared_kv_layers)
    return owning - gemma_local_owning_layers(
        layer_count, shared_kv_layers, full_attention_period
    )


def gemma_host_allocated_per_token(
    layer_count: Int, kv_heads: Int, global_head_dim: Int
) raises -> Int:
    """Host Gemma 4: the KVCache is built for ALL layers at
    the global width, so allocation per token of context is
    the uniform price over every layer -- owning or not."""
    return kv_bytes_per_token(layer_count, kv_heads, global_head_dim, KV_ELEM_F16)


def gemma_host_written_per_token(
    layer_count: Int, shared_kv_layers: Int, kv_heads: Int, global_head_dim: Int
) raises -> Int:
    """Host Gemma 4 bytes actually written per token: one
    padded row (global width) per owning layer, K and V."""
    var owning = gemma_owning_layers(layer_count, shared_kv_layers)
    return kv_bytes_per_token(owning, kv_heads, global_head_dim, KV_ELEM_F16)


def gemma_host_useful_per_token(
    layer_count: Int,
    shared_kv_layers: Int,
    full_attention_period: Int,
    kv_heads: Int,
    global_head_dim: Int,
    local_head_dim: Int,
) raises -> Int:
    """Host Gemma 4 non-padding bytes per token: local
    owning layers at their true local width, global owning
    layers at the global width. (This is the figure
    J-053's table quotes for E2B: 18,432.)"""
    var local = gemma_local_owning_layers(
        layer_count, shared_kv_layers, full_attention_period
    )
    var glob = gemma_global_owning_layers(
        layer_count, shared_kv_layers, full_attention_period
    )
    var local_part = kv_bytes_per_token(local, kv_heads, local_head_dim, KV_ELEM_F16) if local > 0 else 0
    var global_part = kv_bytes_per_token(glob, kv_heads, global_head_dim, KV_ELEM_F16) if glob > 0 else 0
    return local_part + global_part


def gemma_cuda_fixed_bytes(
    layer_count: Int,
    shared_kv_layers: Int,
    full_attention_period: Int,
    kv_heads: Int,
    local_head_dim: Int,
) raises -> Int:
    """Gemma 4 CUDA: the local owning layers' rings, fixed
    at 512 slots each, f32. Paid once; never grows with
    context past 512 tokens."""
    var local = gemma_local_owning_layers(
        layer_count, shared_kv_layers, full_attention_period
    )
    if local == 0:
        return 0
    var per_layer = _kv_mul(
        _kv_mul(2, GEMMA4_LOCAL_CAPACITY),
        _kv_mul(_kv_mul(kv_heads, local_head_dim), KV_ELEM_F32),
    )
    return _kv_mul(local, per_layer)


def gemma_cuda_marginal_per_token(
    layer_count: Int,
    shared_kv_layers: Int,
    full_attention_period: Int,
    kv_heads: Int,
    global_head_dim: Int,
) raises -> Int:
    """Gemma 4 CUDA per-token growth: only the global
    owning layers, at f32."""
    var glob = gemma_global_owning_layers(
        layer_count, shared_kv_layers, full_attention_period
    )
    if glob == 0:
        return 0
    return kv_bytes_per_token(glob, kv_heads, global_head_dim, KV_ELEM_F32)


def gemma_cuda_total_bytes(fixed_bytes: Int, marginal_per_token: Int, context: Int) raises -> Int:
    """Gemma 4 CUDA total at a context: the fixed local
    rings plus the global layers' growth."""
    if fixed_bytes < 0 or marginal_per_token < 0:
        raise Error("KVAccount: Gemma CUDA parts must be nonnegative")
    if context <= 0:
        raise Error("KVAccount: context must be positive")
    if fixed_bytes == 0:
        return _kv_mul(marginal_per_token, context)
    if marginal_per_token == 0:
        return fixed_bytes
    var grown = _kv_mul(marginal_per_token, context)
    if fixed_bytes > 9223372036854775807 - grown:
        raise Error("KVAccount: Gemma CUDA total overflow")
    return fixed_bytes + grown


def kv_int8_projected_per_token(
    layers: Int, kv_heads: Int, head_dim: Int, scale_bytes_per_row: Int
) raises -> Int:
    """PROJECTION for J-088's grading (not a tree fact):
    int8 payload plus one scale of scale_bytes_per_row per
    (layer, K/V, kv-head) row. With an f32 scale (4 bytes)
    the Llama 3 8B shape projects to 67,584 B/token against
    today's 131,072 -- a ratio of 0.5156, not the naive
    0.5, because the scales are real bytes."""
    if scale_bytes_per_row <= 0:
        raise Error("KVAccount: a projection must state its scale bytes")
    var payload = kv_bytes_per_token(layers, kv_heads, head_dim, KV_ELEM_INT8)
    var rows = _kv_mul(_kv_mul(layers, 2), kv_heads)
    var scales = _kv_mul(rows, scale_bytes_per_row)
    if payload > 9223372036854775807 - scales:
        raise Error("KVAccount: projection total overflow")
    return payload + scales


def evaluate_kv_claim(
    claimed_bytes_per_token: Int,
    layers: Int,
    kv_heads: Int,
    head_dim: Int,
    elem_bytes: Int,
) raises -> Int:
    """The census's mechanical verdict: a claimed per-token
    figure MATCHES only if it equals the tree's constants
    for the stated shape and precision, exactly."""
    if claimed_bytes_per_token <= 0:
        raise Error("KVAccount: a claim must state positive bytes")
    var derived = kv_bytes_per_token(layers, kv_heads, head_dim, elem_bytes)
    return KV_CLAIM_MATCHES if claimed_bytes_per_token == derived else KV_CLAIM_MISMATCH


def claim_name(code: Int) raises -> String:
    if code == KV_CLAIM_MATCHES:
        return String("MATCHES")
    if code == KV_CLAIM_MISMATCH:
        return String("MISMATCH")
    raise Error("KVAccount: unknown claim code")
