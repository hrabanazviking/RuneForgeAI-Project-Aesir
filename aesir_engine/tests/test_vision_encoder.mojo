"""Unit tests for core/vision_encoder.mojo patch embedding (Slice 3a).

The real-weights proof lives in tests/patch_embed_mmproj.mojo; these
small-geometry cases pin the weight index math exactly.
"""
from core.vision_encoder import patch_embed


def _expect(condition: Bool, message: String) raises:
    if not condition:
        raise Error(message)


def _close(actual: Float32, expected: Float32, message: String) raises:
    var diff = actual - expected
    if diff < 0.0:
        diff = -diff
    if diff > 0.00001:
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


def main() raises:
    test_patch_embed_single_pixel()
    test_patch_embed_position_sensitive()
