"""Vision encoder forward stages for the mmproj tower (built stage by stage).

Slice 3a: the patch-embedding projection — each patch vector
(patch_size * patch_size * 3 values, in the layout loader/image_prep
produces) is linearly mapped to the vision hidden size by
``v.patch_embd.weight`` (F32, dims [patch, patch, 3, hidden], GGUF
innermost-first). No bias tensor exists for this layer in the file.

Slice 3b: the full forward — factorized position-embedding add, the 16
transformer blocks, the average pooler, and the projector — with the
semantics pinned in docs/VISION_MMPROJ_DEVELOPMENT.md section 5
(llama.cpp mtmd gemma4v). Proven stage by stage against an independent
numpy oracle on the real weights (tests/encode_mmproj.mojo; worst
relative divergence 7.7e-06, Float32 accumulation, 2026-10-27).
"""


def patch_embed(
    patch_vectors: List[Float32],
    weights: List[Float32],
    patch_count: Int,
    patch_size: Int,
    hidden: Int,
) raises -> List[Float32]:
    """Projects patch vectors to hidden-size embeddings.

    ``weights`` is the raw F32 patch-embedding tensor in file order:
    element ((oc * 3 + c) * patch_size + h) * patch_size + w belongs to
    output channel oc, input position (h, w, c). ``patch_vectors`` uses
    the matching input order (h, then w, then c) per patch.
    """
    var patch_values = patch_size * patch_size * 3
    if len(patch_vectors) != patch_count * patch_values:
        raise Error("vision: patch vector buffer does not match geometry")
    if len(weights) != patch_values * hidden:
        raise Error("vision: patch embedding weight count does not match geometry")
    var out = List[Float32]()
    out.reserve(patch_count * hidden)
    for p in range(patch_count):
        var base = p * patch_values
        for oc in range(hidden):
            var acc = Float32(0.0)
            for h in range(patch_size):
                for w in range(patch_size):
                    for c in range(3):
                        var input_index = (h * patch_size + w) * 3 + c
                        var weight_index = ((oc * 3 + c) * patch_size + h) * patch_size + w
                        acc += patch_vectors[base + input_index] * weights[weight_index]
            out.append(acc)
    return out^


# ---------------------------------------------------------------------------
# Slice 3b stages: position embeddings, transformer blocks, pooler, projector.
# Semantics pinned in docs/VISION_MMPROJ_DEVELOPMENT.md section 5 (llama.cpp
# mtmd gemma4v): RMS norms with eps from the spec, ClippableLinear block
# linears (clamp iff the four calibration scalars exist), per-head Q/K RMS
# norms, 2D NEOX RoPE (theta 100) on Q/K, weightless RMS norm on V,
# attention at scale 1.0 with no mask, tanh GELU geglu FFN, post norms
# before each residual add, average pooling with kernel = stride = 3 and a
# sqrt(hidden) scale, and a plain-RMS + linear projector.
# ---------------------------------------------------------------------------
from std.math import cos, exp, log, sin, sqrt, tanh
from loader.mmproj import MmprojFile, VisionTowerSpec
from loader.image_prep import RgbImage, load_image_file, preprocess_image


def _rms_norm(
    x: List[Float32],
    rows: Int,
    width: Int,
    weight: List[Float32],
    weighted: Bool,
    eps: Float32,
) raises -> List[Float32]:
    """Row-wise RMS norm: x * rsqrt(mean(x^2) + eps), optionally weighted."""
    if len(x) != rows * width:
        raise Error("vision: rms norm buffer does not match geometry")
    if weighted and len(weight) != width:
        raise Error("vision: rms norm weight does not match width")
    var out = List[Float32]()
    out.reserve(rows * width)
    for r in range(rows):
        var base = r * width
        var acc = Float32(0.0)
        for i in range(width):
            var v = x[base + i]
            acc += v * v
        var scale = Float32(1.0) / sqrt(acc / Float32(width) + eps)
        for i in range(width):
            var v = x[base + i] * scale
            if weighted:
                v *= weight[i]
            out.append(v)
    return out^


def rms_norm_weighted(
    x: List[Float32], rows: Int, width: Int, weight: List[Float32], eps: Float32
) raises -> List[Float32]:
    return _rms_norm(x, rows, width, weight, True, eps)


def rms_norm_plain(
    x: List[Float32], rows: Int, width: Int, eps: Float32
) raises -> List[Float32]:
    var empty = List[Float32]()
    return _rms_norm(x, rows, width, empty, False, eps)


def linear_q8(
    mmproj: MmprojFile,
    x: List[Float32],
    rows: Int,
    in_width: Int,
    out_width: Int,
    base: String,
) raises -> List[Float32]:
    """A ClippableLinear over a Q8_0 weight named ``base + ".weight"``.

    The dequantized weight list is in file order for dims [in, out], so
    output channel oc reads the contiguous row starting at oc * in_width.
    Input and output clamps apply iff the calibration scalar pair exists
    (``base + ".input_min"`` etc.); a half-present pair is a file anomaly
    and raises, matching the reference's fail-closed posture. With no
    scalars the linear is plain (the projector in this file is one).
    """
    if len(x) != rows * in_width:
        raise Error("vision: linear input does not match geometry: " + base)
    var weights = mmproj.tensor_q8_0_f32(base + ".weight")
    if len(weights) != in_width * out_width:
        raise Error("vision: linear weight count mismatch: " + base)
    var has_in = mmproj.has_tensor(base + ".input_min")
    var has_in_max = mmproj.has_tensor(base + ".input_max")
    var has_out = mmproj.has_tensor(base + ".output_min")
    var has_out_max = mmproj.has_tensor(base + ".output_max")
    if has_in != has_in_max or has_out != has_out_max:
        raise Error("vision: partial calibration scalars for " + base)
    var in_min = Float32(0.0)
    var in_max = Float32(0.0)
    var out_min = Float32(0.0)
    var out_max = Float32(0.0)
    if has_in:
        in_min = mmproj.tensor_scalar_f32(base + ".input_min")
        in_max = mmproj.tensor_scalar_f32(base + ".input_max")
    if has_out:
        out_min = mmproj.tensor_scalar_f32(base + ".output_min")
        out_max = mmproj.tensor_scalar_f32(base + ".output_max")
    var out = List[Float32]()
    out.reserve(rows * out_width)
    for t in range(rows):
        var x_base = t * in_width
        for oc in range(out_width):
            var w_base = oc * in_width
            var acc = Float32(0.0)
            for ic in range(in_width):
                var v = x[x_base + ic]
                if has_in:
                    if v < in_min:
                        v = in_min
                    elif v > in_max:
                        v = in_max
                acc += v * weights[w_base + ic]
            if has_out:
                if acc < out_min:
                    acc = out_min
                elif acc > out_max:
                    acc = out_max
            out.append(acc)
    return out^


def add_rows(a: List[Float32], b: List[Float32]) raises -> List[Float32]:
    if len(a) != len(b):
        raise Error("vision: residual add length mismatch")
    var out = List[Float32]()
    out.reserve(len(a))
    for i in range(len(a)):
        out.append(a[i] + b[i])
    return out^


def mul_rows(a: List[Float32], b: List[Float32]) raises -> List[Float32]:
    if len(a) != len(b):
        raise Error("vision: elementwise multiply length mismatch")
    var out = List[Float32]()
    out.reserve(len(a))
    for i in range(len(a)):
        out.append(a[i] * b[i])
    return out^


def gelu_tanh_rows(x: List[Float32]) -> List[Float32]:
    """ggml gelu: the tanh approximation, not the erf form."""
    var out = List[Float32]()
    out.reserve(len(x))
    for i in range(len(x)):
        var v = x[i]
        out.append(
            Float32(0.5) * v
            * (Float32(1.0) + tanh(Float32(0.7978846) * v * (Float32(1.0) + Float32(0.044715) * v * v)))
        )
    return out^


def add_position_embeddings(
    x: List[Float32],
    pos_table: List[Float32],
    tokens: Int,
    grid: Int,
    hidden: Int,
    pos_rows: Int,
) raises -> List[Float32]:
    """Adds the factorized position embeddings (FPE) to patch embeddings.

    ``pos_table`` is v.position_embd.weight in file order for dims
    [hidden, pos_rows, 2]: slab 0 is the X table, slab 1 the Y table, and
    the element for (slab, row, component) sits at
    component + hidden * (row + pos_rows * slab). Patch t (raster order)
    takes pos_x = t % grid, pos_y = t // grid.
    """
    if len(x) != tokens * hidden:
        raise Error("vision: position add buffer does not match geometry")
    if len(pos_table) != hidden * pos_rows * 2:
        raise Error("vision: position table size mismatch")
    var out = x.copy()
    for t in range(tokens):
        var pos_x = t % grid
        var pos_y = t // grid
        var base = t * hidden
        var x_row = pos_x * hidden
        var y_row = (pos_rows + pos_y) * hidden
        for e in range(hidden):
            out[base + e] += pos_table[x_row + e] + pos_table[y_row + e]
    return out^


def rope_2d_rows(
    x: List[Float32], tokens: Int, heads: Int, head_dim: Int, grid: Int
) raises -> List[Float32]:
    """2D NEOX RoPE over token rows of Q or K, per head.

    Dims [0, head_dim/2) rotate with pos_x, dims [head_dim/2, head_dim)
    with pos_y; pairs are (j, j + head_dim/4) within each half and the
    angle for pair j is pos * 100^(-j / (head_dim/4)).
    """
    if head_dim % 4 != 0:
        raise Error("vision: head_dim must be divisible by 4 for 2D RoPE")
    var width = heads * head_dim
    if len(x) != tokens * width:
        raise Error("vision: rope buffer does not match geometry")
    var half = head_dim // 2
    var quarter = head_dim // 4
    # Per-pair frequency ratio: 100^(-1/quarter), since the angle for
    # pair j is pos * 100^(-j/quarter).
    var ratio = exp(-log(Float32(100.0)) / Float32(quarter))
    var out = x.copy()
    for t in range(tokens):
        var positions = List[Int]()
        positions.append(t % grid)
        positions.append(t // grid)
        for h in range(heads):
            var head_base = t * width + h * head_dim
            for half_index in range(2):
                var pos = positions[half_index]
                var seg = head_base + half_index * half
                var freq = Float32(1.0)
                for j in range(quarter):
                    var angle = Float32(pos) * freq
                    var c = cos(angle)
                    var s = sin(angle)
                    var a = out[seg + j]
                    var b = out[seg + j + quarter]
                    out[seg + j] = a * c - b * s
                    out[seg + j + quarter] = b * c + a * s
                    freq *= ratio
    return out^


def attention_2d(
    q: List[Float32],
    k: List[Float32],
    v: List[Float32],
    tokens: Int,
    heads: Int,
    head_dim: Int,
) raises -> List[Float32]:
    """Bidirectional attention at scale 1.0 (no mask), per head."""
    var width = heads * head_dim
    if len(q) != tokens * width or len(k) != tokens * width or len(v) != tokens * width:
        raise Error("vision: attention buffers do not match geometry")
    var out = List[Float32]()
    out.reserve(tokens * width)
    for _ in range(tokens * width):
        out.append(Float32(0.0))
    for h in range(heads):
        var h_base = h * head_dim
        for t in range(tokens):
            var q_base = t * width + h_base
            var scores = List[Float32]()
            scores.reserve(tokens)
            var peak = Float32(0.0)
            for j in range(tokens):
                var k_base = j * width + h_base
                var acc = Float32(0.0)
                for d in range(head_dim):
                    acc += q[q_base + d] * k[k_base + d]
                scores.append(acc)
                if j == 0 or acc > peak:
                    peak = acc
            var weights = List[Float32]()
            weights.reserve(tokens)
            var denom = Float32(0.0)
            for j in range(tokens):
                var e = exp(scores[j] - peak)
                weights.append(e)
                denom += e
            for d in range(head_dim):
                var acc = Float32(0.0)
                for j in range(tokens):
                    acc += (weights[j] / denom) * v[j * width + h_base + d]
                out[q_base + d] = acc
    return out^


def vision_block(
    mmproj: MmprojFile, x: List[Float32], spec: VisionTowerSpec, block_index: Int
) raises -> List[Float32]:
    """One gemma4v block, in the pinned order (design doc section 5)."""
    var hidden = spec.embedding_length
    var tokens = spec.patch_count()
    var grid = spec.patch_grid()
    var heads = spec.head_count
    var head_dim = spec.head_dim()
    var ffn = spec.feed_forward_length
    var eps = spec.layer_norm_epsilon
    var prefix = "v.blk." + String(block_index) + "."
    var h = rms_norm_weighted(
        x, tokens, hidden, mmproj.tensor_f32(prefix + "ln1.weight"), eps
    )
    var q = linear_q8(mmproj, h, tokens, hidden, hidden, prefix + "attn_q")
    var k = linear_q8(mmproj, h, tokens, hidden, hidden, prefix + "attn_k")
    var v = linear_q8(mmproj, h, tokens, hidden, hidden, prefix + "attn_v")
    q = rms_norm_weighted(
        q, tokens * heads, head_dim,
        mmproj.tensor_f32(prefix + "attn_q_norm.weight"), eps,
    )
    k = rms_norm_weighted(
        k, tokens * heads, head_dim,
        mmproj.tensor_f32(prefix + "attn_k_norm.weight"), eps,
    )
    q = rope_2d_rows(q, tokens, heads, head_dim, grid)
    k = rope_2d_rows(k, tokens, heads, head_dim, grid)
    v = rms_norm_plain(v, tokens * heads, head_dim, eps)
    var a = attention_2d(q, k, v, tokens, heads, head_dim)
    var ao = linear_q8(mmproj, a, tokens, hidden, hidden, prefix + "attn_out")
    var post = rms_norm_weighted(
        ao, tokens, hidden, mmproj.tensor_f32(prefix + "attn_post_norm.weight"), eps
    )
    var residual = add_rows(x, post)
    var h3 = rms_norm_weighted(
        residual, tokens, hidden, mmproj.tensor_f32(prefix + "ln2.weight"), eps
    )
    var gate = gelu_tanh_rows(
        linear_q8(mmproj, h3, tokens, hidden, ffn, prefix + "ffn_gate")
    )
    var up = linear_q8(mmproj, h3, tokens, hidden, ffn, prefix + "ffn_up")
    var f = linear_q8(mmproj, mul_rows(gate, up), tokens, ffn, hidden, prefix + "ffn_down")
    var fpost = rms_norm_weighted(
        f, tokens, hidden, mmproj.tensor_f32(prefix + "ffn_post_norm.weight"), eps
    )
    return add_rows(residual, fpost)


def pool_tokens(
    x: List[Float32], grid: Int, hidden: Int, merge: Int
) raises -> List[Float32]:
    """Average-pools the patch grid with kernel = stride = merge, then
    scales by sqrt(hidden). Windows start at multiples of merge; token
    order keeps x fastest (ox + out_grid * oy)."""
    if merge <= 0 or merge > grid:
        raise Error("vision: pool merge must be within the patch grid")
    var tokens = grid * grid
    if len(x) != tokens * hidden:
        raise Error("vision: pool buffer does not match geometry")
    # Windows start at multiples of merge; a tail of grid % merge rows
    # and columns is not covered by any window (grid 14, merge 3 pools
    # rows/cols 0..11 into 4x4).
    var out_grid = (grid - merge) // merge + 1
    var scale = sqrt(Float32(hidden))
    var area = Float32(merge * merge)
    var out = List[Float32]()
    out.reserve(out_grid * out_grid * hidden)
    for oy in range(out_grid):
        for ox in range(out_grid):
            for e in range(hidden):
                var acc = Float32(0.0)
                for wy in range(merge):
                    for wx in range(merge):
                        var row = merge * oy + wy
                        var col = merge * ox + wx
                        acc += x[(row * grid + col) * hidden + e]
                out.append(acc / area * scale)
    return out^


def project_tokens(
    mmproj: MmprojFile, pooled: List[Float32], spec: VisionTowerSpec
) raises -> List[Float32]:
    """Projector: plain RMS norm per token, then the input projection."""
    var hidden = spec.embedding_length
    if len(pooled) % hidden != 0:
        raise Error("vision: pooled buffer does not match hidden size")
    var rows = len(pooled) // hidden
    var normed = rms_norm_plain(pooled, rows, hidden, spec.layer_norm_epsilon)
    return linear_q8(
        mmproj, normed, rows, hidden, spec.projection_dim, "mm.input_projection"
    )


def encode_image_pixels(
    mmproj_path: String, image: RgbImage
) raises -> List[Float32]:
    """Runs the proven encoder stage sequence on an already-decoded
    image and returns the projected soft-token rows (Float32,
    row-major [n_soft, projection_dim]). Callers that hold PNG/JPEG
    inputs decode them through loader/image_codecs.load_any into
    the same RgbImage prep path first. The stage sequence is the
    one tests/encode_mmproj.mojo proved against the oracle."""
    var mmproj = MmprojFile(mmproj_path)
    var spec = mmproj.vision_spec()
    if not spec.present:
        raise Error("encode_image: mmproj carries no vision tower")
    var tokens = spec.patch_count()
    var grid = spec.patch_grid()
    var hidden = spec.embedding_length
    var patches = preprocess_image(image, spec)
    # Input scaling 2x-1 before the patch projection (gemma4v.cpp:9-11).
    var scaled = List[Float32]()
    scaled.reserve(len(patches))
    for i in range(len(patches)):
        scaled.append(patches[i] * Float32(2.0) - Float32(1.0))
    var patch_weights = mmproj.tensor_f32("v.patch_embd.weight")
    var x = patch_embed(scaled, patch_weights, tokens, spec.patch_size, hidden)
    var pos_table = mmproj.tensor_f32("v.position_embd.weight")
    var pos_rows = mmproj.tensors["v.position_embd.weight"].d1
    x = add_position_embeddings(x, pos_table, tokens, grid, hidden, pos_rows)
    for b in range(spec.block_count):
        x = vision_block(mmproj, x, spec, b)
    var pooled = pool_tokens(x, grid, hidden, 3)
    return project_tokens(mmproj, pooled, spec)


def encode_image_rows(
    mmproj_path: String, image_path: String
) raises -> List[Float32]:
    """Loads an image file (PPM route) and returns the projected
    soft-token rows; see encode_image_pixels for the stage sequence."""
    var image = load_image_file(image_path)
    return encode_image_pixels(mmproj_path, image)
