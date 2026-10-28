"""Unit tests for loader/mmproj.mojo discovery naming and tensor geometry.

The real-file parse of a downloaded mmproj is covered by the opt-in
tests/inspect_mmproj.mojo program (model weights stay outside Git, per
TESTING_PROTOCOL.md); everything testable without weights lives here.
"""
from loader.mmproj import (
    VisionTowerSpec,
    find_mmproj_beside,
    mmproj_candidate_paths,
    mmproj_tensor_byte_count,
    pick_mmproj_sibling,
    split_model_path,
)


def _expect(condition: Bool, message: String) raises:
    if not condition:
        raise Error(message)


def test_split_model_path() raises:
    var parts = split_model_path("/store/gemma-4-E2B-it-heretic-v1.Q4_K_M.gguf")
    _expect(parts[0] == "/store/", "directory keeps its trailing slash")
    _expect(
        parts[1] == "gemma-4-E2B-it-heretic-v1.Q4_K_M",
        "stem strips the .gguf suffix",
    )
    var bare = split_model_path("model.gguf")
    _expect(bare[0] == "", "bare file name has an empty directory")
    _expect(bare[1] == "model", "bare file name stem")
    print("mmproj split_model_path: PASS")


def test_mmproj_candidate_paths() raises:
    var candidates = mmproj_candidate_paths("/store/heretic.Q4_K_M.gguf")
    _expect(len(candidates) == 7, "seven explicit candidate spellings")
    _expect(
        candidates[0] == "/store/mmproj-heretic.Q4_K_M.gguf",
        "llama.cpp mmproj- prefix spelling comes first",
    )
    var saw_suffix = False
    var saw_quant_suffix = False
    for i in range(len(candidates)):
        if candidates[i] == "/store/heretic.Q4_K_M.mmproj.gguf":
            saw_suffix = True
        if candidates[i] == "/store/heretic.Q4_K_M.mmproj-Q8_0.gguf":
            saw_quant_suffix = True
    _expect(saw_suffix, "stem.mmproj.gguf spelling is probed")
    _expect(saw_quant_suffix, "stem.mmproj-Q8_0.gguf spelling is probed")
    print("mmproj candidate paths: PASS")


def test_pick_mmproj_sibling() raises:
    var listing = List[String]()
    listing.append("gemma-4-E2B-it-heretic-v1.Q4_K_M.gguf")
    listing.append("gemma-4-E2B-it-heretic-v1.mmproj-Q8_0.gguf")
    listing.append("gemma-4-E2B-it-heretic-v1.mmproj-f16.gguf")
    listing.append("README.md")
    var pick = pick_mmproj_sibling(listing, "gemma-4-E2B-it-heretic-v1.Q4_K_M")
    _expect(
        pick == "gemma-4-E2B-it-heretic-v1.mmproj-Q8_0.gguf",
        "sibling pick prefers the stem-matching, lexicographically first "
        "mmproj name, got: " + pick,
    )
    var none = List[String]()
    none.append("some-model.gguf")
    none.append("notes.txt")
    _expect(
        pick_mmproj_sibling(none, "some-model") == "",
        "no mmproj in the listing picks nothing",
    )
    print("mmproj pick sibling: PASS")


def test_mmproj_tensor_byte_count() raises:
    # Real gemma4 mmproj: v.patch_embd.weight is F32 [16, 16, 3, 768].
    var patch = List[Int]()
    patch.append(16)
    patch.append(16)
    patch.append(3)
    patch.append(768)
    _expect(
        mmproj_tensor_byte_count(0, patch) == 2359296,
        "F32 rank-4 patch embedding byte count",
    )
    # Real gemma4 mmproj: v.blk.0.attn_k.weight is Q8_0 [768, 768]:
    # 768*768/32 blocks of 34 bytes = 626688 (matches the file's offsets).
    var attn = List[Int]()
    attn.append(768)
    attn.append(768)
    _expect(
        mmproj_tensor_byte_count(8, attn) == 626688,
        "Q8_0 vision attention byte count",
    )
    # Real gemma4 mmproj: mm.input_projection.weight is Q8_0 [768, 1536].
    var projector = List[Int]()
    projector.append(768)
    projector.append(1536)
    _expect(
        mmproj_tensor_byte_count(8, projector) == 1253376,
        "Q8_0 projector byte count",
    )
    var raised = False
    try:
        var bad = List[Int]()
        bad.append(100)  # not Q8_0 block aligned
        bad.append(768)
        _ = mmproj_tensor_byte_count(8, bad)
    except:
        raised = True
    _expect(raised, "block-misaligned innermost dimension is rejected")
    print("mmproj tensor byte count: PASS")


def test_find_mmproj_beside_missing() raises:
    _expect(
        find_mmproj_beside("/nonexistent-dir-xyz/no-model.gguf") == "",
        "a missing directory reads as no mmproj, not an error",
    )
    print("mmproj discovery absence: PASS")


def test_mmproj() raises:
    """Aggregate entry point; run_all registration lands with the ledger
    entry so the counted totals stay synchronized (see design doc)."""
    test_split_model_path()
    test_mmproj_candidate_paths()
    test_pick_mmproj_sibling()
    test_mmproj_tensor_byte_count()
    test_find_mmproj_beside_missing()
    test_vision_spec_language_match()


def test_vision_spec_language_match() raises:
    # The real gemma4 pairing: projector output 1536 == E2B hidden 1536.
    var spec = VisionTowerSpec()
    spec.present = True
    spec.projection_dim = 1536
    spec.check_language_match(1536)
    var raised = False
    try:
        spec.check_language_match(1024)
    except:
        raised = True
    _expect(raised, "a projection/hidden mismatch is rejected")
    spec.image_size = 224
    spec.patch_size = 16
    _expect(spec.patch_count() == 196, "224/16 patches tile to 196")
    print("mmproj spec language match: PASS")


def main() raises:
    test_mmproj()
