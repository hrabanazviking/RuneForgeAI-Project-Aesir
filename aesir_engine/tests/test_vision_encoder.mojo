"""Unit tests for core/vision_encoder.mojo (Slices 3a and 3b).

The real-weights proofs live in tests/patch_embed_mmproj.mojo (3a) and
tests/encode_mmproj.mojo (3b); these small-geometry cases pin the stage
math exactly: patch embedding index order, RMS norm, 2D RoPE rotation,
tanh GELU, attention softmax, position-embedding slab layout, pooling.
"""
from core.vision_encoder import (
    add_position_embeddings,
    attention_2d,
    gelu_tanh_rows,
    patch_embed,
    pool_tokens,
    rms_norm_plain,
    rms_norm_weighted,
    rope_2d_rows,
)


def _expect(condition: Bool, message: String) raises:
    if not condition:
        raise Error(message)


def _close(actual: Float32, expected: Float32, message: String) raises:
    var diff = actual - expected
    if diff < 0.0:
        diff = -diff
    if diff > 0.00005:
        raise Error(
            message + ": got " + String(actual) + ", expected " + String(expected)
        )


def test_patch_embed_single_pixel() raises:
    # patch_size 1, one patch [r,g,b] = [1,2,3]; weights pick r for oc0
    # and g for oc1: weight index of (oc, c) is oc*3 + c at patch_size 1.
    var patches = List[Float32]()
    patches.append(1.0)
    patches.append(2.0)
    patches.append(3.0)
    var weights = List[Float32]()
    var w: List[Float32] = [1.0, 0.0, 0.0, 0.0, 1.0, 0.0]
    for i in range(len(w)):
        weights.append(w[i])
    var out = patch_embed(patches, weights, 1, 1, 2)
    _close(out[0], 1.0, "oc0 reads the red channel")
    _close(out[1], 2.0, "oc1 reads the green channel")
    print("vision patch_embed single pixel: PASS")


def test_patch_embed_position_sensitive() raises:
    # patch_size 2, hidden 1. A one-hot weight at (h=1, w=0, c=2) sits at
    # file index ((0*3+2)*2+1)*2+0 = 10 and must select input element
    # (1*2+0)*3+2 = 8 of the patch vector.
    var patches = List[Float32]()
    for i in range(12):
        patches.append(Float32(i))
    var weights = List[Float32]()
    for i in range(12):
        weights.append(Float32(1.0) if i == 10 else Float32(0.0))
    var out = patch_embed(patches, weights, 1, 2, 1)
    _close(out[0], 8.0, "one-hot weight selects patch element 8")
    # All-ones weights sum the whole patch: 0+1+...+11 = 66.
    var ones = List[Float32]()
    for _ in range(12):
        ones.append(1.0)
    var summed = patch_embed(patches, ones, 1, 2, 1)
    _close(summed[0], 66.0, "all-ones weight sums the patch")
    print("vision patch_embed position sensitive: PASS")


def test_rms_norm_plain_and_weighted() raises:
    # x = [3, 4]: mean square 12.5, rsqrt(12.5 + 1e-6) = 0.28284271...
    var x: List[Float32] = [3.0, 4.0]
    var plain = rms_norm_plain(x, 1, 2, Float32(0.000001))
    _close(plain[0], 0.8485281, "plain rms norm first component")
    _close(plain[1], 1.1313708, "plain rms norm second component")
    var w: List[Float32] = [2.0, 0.5]
    var weighted = rms_norm_weighted(x, 1, 2, w, Float32(0.000001))
    _close(weighted[0], 1.6970562, "weighted rms norm first component")
    _close(weighted[1], 0.5656854, "weighted rms norm second component")
    print("vision rms_norm: PASS")


def test_rope_quarter_turn() raises:
    # heads 1, head_dim 4 (pairs (0,1) and (2,3)), grid 4. Token 0 sits
    # at (0,0) and must not move; token 1 sits at (1,0): its first pair
    # rotates by 1 radian, its second pair (pos_y 0) stays.
    var x = List[Float32]()
    for _ in range(4):
        x.append(9.0)
    x.append(1.0)
    x.append(0.0)
    x.append(1.0)
    x.append(0.0)
    var out = rope_2d_rows(x, 2, 1, 4, 4)
    _close(out[0], 9.0, "token at origin is untouched by rope")
    _close(out[4], 0.5403023, "rope pair rotated by pos_x (cos)")
    _close(out[5], 0.8414710, "rope pair rotated by pos_x (sin)")
    _close(out[6], 1.0, "pair with pos_y 0 keeps first component")
    _close(out[7], 0.0, "pair with pos_y 0 keeps second component")
    print("vision rope_2d: PASS")


def test_gelu_tanh_values() raises:
    var x: List[Float32] = [0.0, 1.0, -1.0]
    var out = gelu_tanh_rows(x)
    _close(out[0], 0.0, "gelu of zero is zero")
    _close(out[1], 0.8411920, "gelu tanh at 1")
    _close(out[2], -0.1588080, "gelu tanh at -1")
    print("vision gelu_tanh: PASS")


def test_attention_two_token() raises:
    # q = k = v = identity rows; scores are 1 on the diagonal and 0 off
    # it, so each output row mixes the value rows by the softmax pair
    # (0.7310586, 0.2689414).
    var q: List[Float32] = [1.0, 0.0, 0.0, 1.0]
    var out = attention_2d(q, q, q, 2, 1, 2)
    _close(out[0], 0.7310586, "attention token 0 first component")
    _close(out[1], 0.2689414, "attention token 0 second component")
    _close(out[2], 0.2689414, "attention token 1 first component")
    _close(out[3], 0.7310586, "attention token 1 second component")
    print("vision attention: PASS")


def test_position_add_slabs() raises:
    # hidden 2, pos_rows 3, grid 2, tokens 4. The table entry for
    # (slab, row, component) sits at component + hidden * (row +
    # pos_rows * slab); with table[i] = i, token 1 (x=1, y=0) gains
    # slab0 row1 (2,3) plus slab1 row0 (6,7); token 3 (x=1, y=1) gains
    # (2,3) plus (8,9).
    var table = List[Float32]()
    for i in range(12):
        table.append(Float32(i))
    var x = List[Float32]()
    for _ in range(8):
        x.append(0.0)
    var out = add_position_embeddings(x, table, 4, 2, 2, 3)
    _close(out[2], 8.0, "token 1 first component adds both rows")
    _close(out[3], 10.0, "token 1 second component adds both rows")
    _close(out[6], 10.0, "token 3 first component adds both rows")
    _close(out[7], 12.0, "token 3 second component adds both rows")
    print("vision position add: PASS")


def test_pool_windows_and_tail() raises:
    # grid 4, merge 2, hidden 1: window means of the raster 0..15 are
    # 2.5, 4.5, 10.5, 12.5 in ox-fastest order; sqrt(1) scale is 1.
    var x = List[Float32]()
    for i in range(16):
        x.append(Float32(i))
    var out = pool_tokens(x, 4, 1, 2)
    _expect(len(out) == 4, "pool of grid 4 by 2 gives 4 tokens")
    _close(out[0], 2.5, "pool window (0,0)")
    _close(out[1], 4.5, "pool window (1,0)")
    _close(out[2], 10.5, "pool window (0,1)")
    _close(out[3], 12.5, "pool window (1,1)")
    # grid 5, merge 3: one window covers rows/cols 0..2 only (the tail
    # is not pooled); the mean of 0,1,2,5,6,7,10,11,12 is 6.
    var y = List[Float32]()
    for i in range(25):
        y.append(Float32(i))
    var tail = pool_tokens(y, 5, 1, 3)
    _expect(len(tail) == 1, "pool of grid 5 by 3 gives 1 token")
    _close(tail[0], 6.0, "pool tail window mean")
    print("vision pool: PASS")


def test_vision_encoder() raises:
    """Aggregate entry point; run_all registration lands with the ledger
    entry so the counted totals stay synchronized (see design doc)."""
    test_patch_embed_single_pixel()
    test_patch_embed_position_sensitive()
    test_rms_norm_plain_and_weighted()
    test_rope_quarter_turn()
    test_gelu_tanh_values()
    test_attention_two_token()
    test_position_add_slabs()
    test_pool_windows_and_tail()


def main() raises:
    test_vision_encoder()
