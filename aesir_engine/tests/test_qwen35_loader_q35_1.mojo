# tests/test_qwen35_loader_q35_1.mojo
# Q35-1 loader truth: synthetic qwen35 fixtures with correct SSM geometry.
#
# Fixtures are generated deterministically by scripts/make_qwen35_fixtures.py
# (tiny geometry: hidden 32, ffn 64, vocab 16, 4 blocks / interval 4,
# groups 2, state 8, dt_rank 3, inner 24, qkv_width 2*2*8+24 = 56).
# Usage: test_qwen35_loader_q35_1 <good.gguf> <bad_qkv.gguf> <type_probe.gguf>
#
# Proves:
#  (a) the good fixture passes _validate_qwen35_tensors via the loader
#      path (GGUFSeer.mmap_and_load reaches VALIDATED);
#  (b) the mutated fixture (attn_qkv rows 88 instead of 56) is rejected
#      with the shape error naming attn_qkv.weight;
#  (c) U2 probe: the type-probe fixture stores blk.*.attn_gate.weight as
#      F16 while the validator records Q8_0 for it, and still validates --
#      tensor types are recorded, not enforced; validation is shape-driven.

from std.sys import argv

from core.mimir_well import MimirWell
from loader.gguf import GGMLType, GGUFSeer, GGUFState
from loader.tokenizer import RuneWeaver


def test_good_fixture(path: String) raises:
    var pool = MimirWell(1 << 20)
    var tokenizer = RuneWeaver()
    var seer = GGUFSeer(path)
    seer.mmap_and_load(pool, tokenizer)
    if not seer.is_loaded or seer.state != GGUFState.VALIDATED:
        raise Error("good qwen35 fixture did not reach VALIDATED state")
    if seer.config.architecture != "qwen35":
        raise Error("good fixture architecture is not qwen35")
    if seer.config.ssm_inner_size != 24 or seer.config.ssm_group_count != 2:
        raise Error("good fixture SSM config mismatch")
    ref qkv = seer.tensors["blk.0.attn_qkv.weight"]
    if qkv.rows != 56 or qkv.cols != 32:
        raise Error("good fixture attn_qkv shape is not 56x32")
    ref conv = seer.tensors["blk.0.ssm_conv1d.weight"]
    if conv.rows != 56 or conv.cols != 4:
        raise Error("good fixture ssm_conv1d shape is not 56x4")
    if seer.tensor_types.get("blk.0.attn_qkv.weight", UInt32(99)) != GGMLType.Q8_0:
        raise Error("good fixture attn_qkv type is not recorded as Q8_0")
    print("PASS (a): good qwen35 fixture validates via loader path, attn_qkv 56x32 Q8_0, ssm_conv1d 56x4")


def test_bad_qkv_fixture(path: String) raises:
    var pool = MimirWell(1 << 20)
    var tokenizer = RuneWeaver()
    var seer = GGUFSeer(path)
    var error_text = String("")
    try:
        seer.mmap_and_load(pool, tokenizer)
    except error:
        error_text = String(error)
    if "attn_qkv.weight" not in error_text or "invalid shape" not in error_text:
        raise Error("mutated qkv fixture was not rejected with the attn_qkv shape error: " + error_text)
    if seer.is_loaded:
        raise Error("mutated qkv fixture must not be marked loaded")
    print("PASS (b): mutated qkv fixture rejected:", error_text)


def test_type_probe_fixture(path: String) raises:
    var pool = MimirWell(1 << 20)
    var tokenizer = RuneWeaver()
    var seer = GGUFSeer(path)
    seer.mmap_and_load(pool, tokenizer)
    if not seer.is_loaded or seer.state != GGUFState.VALIDATED:
        raise Error("type-probe fixture did not reach VALIDATED state")
    var recorded = seer.tensor_types.get("blk.0.attn_gate.weight", UInt32(99))
    if recorded != GGMLType.F16:
        raise Error("type-probe fixture attn_gate type is not recorded as F16")
    print("PASS (c) U2: attn_gate stored F16 (validator records Q8_0) still validates; types recorded, not enforced")


def main() raises:
    var arguments = argv()
    if len(arguments) != 4:
        raise Error("usage: test_qwen35_loader_q35_1 <good.gguf> <bad_qkv.gguf> <type_probe.gguf>")
    test_good_fixture(arguments[1])
    test_bad_qkv_fixture(arguments[2])
    test_type_probe_fixture(arguments[3])
    print("Q35-1 qwen35 loader validation: ALL PASS")
