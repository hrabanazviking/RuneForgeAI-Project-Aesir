# tests/test_qwen35_registry_q40_1.mojo
# Q40-1 registry family-generalization policy proof.
#
# Usage: test_qwen35_registry_q40_1 <real-qwen35-40b.gguf> <real-qwen35-27b.gguf>
#
# Like the Q35-2 test, the profile path runs over PackedGGUF against
# the real files, metadata-only (nothing is materialized).
#
# Proves:
#  (a) the 40B geometry (96L/5120, file_type 7 = Q8_0) classifies to
#      native_profile "qwen35", READY / COMPATIBLE, variant "39B"
#      (the file's own general.size_label);
#  (b) admission is depth-free, not size-pinned: a hypothetical
#      128L/5120 classifies the same, while 95L (interval does not
#      divide depth) and 96L/4096 (off-family width) get no profile;
#  (c) a non-Q8_0 96L file is NOT READY (family quant policy);
#  (d) the family signature holds for both pinned constructors
#      (27B 64L and 40B 96L), the 40B formulas close (24 full + 72
#      SSM layers, qkv 10240, 1275 tensors), an off-family FFN is
#      refused by validate_qwen35_family_signature with a named
#      error, and broken hybrid relations at 96L (inner !=
#      dt_rank*state; interval not dividing blocks) are refused by
#      validate_qwen35 with named errors;
#  (e) the real 40B validates end to end and inspects READY /
#      COMPATIBLE with tensor_validation "passed" and the exact
#      formula footprint; the real 27B inspects with the banked
#      Q35-2 footprint, byte-exact (zero drift);
#  (f) regression: the existing registry and Gemma 4 profile cases
#      still pass unchanged (also covered by the Q35-2 test re-run).

from std.sys import argv

from loader.packed_gguf import PackedGGUF
from core.model_registry import ModelArchitectureRegistry
from core.qwen35_profile import (
    Qwen35Profile,
    qwen35_27b_profile,
    qwen35_40b_profile,
    qwen35_profile_for,
    validate_qwen35,
    validate_qwen35_family_signature,
)
from core.inference_memory import qwen35_memory_plan
from tests.test_model_registry import test_model_architecture_registry
from tests.test_gemma4_profile import test_gemma4_profiles


def expect_validate_refusal(model: PackedGGUF, profile: Qwen35Profile,
                            context: Int, needle: String) raises -> String:
    var error_text = String("")
    try:
        validate_qwen35(model, profile, context)
    except error:
        error_text = String(error)
    if error_text == "":
        raise Error("mutated qwen35 geometry was admitted")
    if needle not in error_text:
        raise Error("refusal did not name " + needle + ": " + error_text)
    return error_text


def expect_family_refusal(profile: Qwen35Profile, needle: String) raises -> String:
    var error_text = String("")
    try:
        validate_qwen35_family_signature(profile)
    except error:
        error_text = String(error)
    if error_text == "":
        raise Error("off-family qwen35 geometry was admitted")
    if needle not in error_text:
        raise Error("family refusal did not name " + needle + ": " + error_text)
    return error_text


def test_classify_family() raises:
    var b40 = ModelArchitectureRegistry.classify(
        "qwen35", "39B", 96, 5120, 262144, 7, ""
    )
    if b40.native_profile != "qwen35" or b40.status != "READY":
        raise Error("40B qwen35 geometry did not classify to the native profile")
    if b40.compatibility != "COMPATIBLE" or b40.model_variant != "39B":
        raise Error("40B qwen35 compatibility/variant drifted")
    if b40.tensor_naming != "qwen35/blk.*" or b40.supported_quantizations != "Q8_0":
        raise Error("40B qwen35 naming/quantization policy drifted")
    print("PASS (a): 40B geometry 96L/5120 Q8_0 -> native_profile qwen35, READY/COMPATIBLE, variant 39B")
    var deeper = ModelArchitectureRegistry.classify(
        "qwen35", "", 128, 5120, 262144, 7, ""
    )
    if deeper.native_profile != "qwen35" or deeper.status != "READY":
        raise Error("depth-free family admission failed at 128L/5120")
    var odd_depth = ModelArchitectureRegistry.classify(
        "qwen35", "", 95, 5120, 262144, 7, ""
    )
    if odd_depth.native_profile != "" or odd_depth.status != "NOT READY":
        raise Error("95L qwen35 geometry gained a native profile")
    if odd_depth.compatibility != "COMPATIBLE":
        raise Error("95L qwen35 geometry must stay COMPATIBLE without native_profile")
    var narrow = ModelArchitectureRegistry.classify(
        "qwen35", "", 96, 4096, 262144, 7, ""
    )
    if narrow.native_profile != "" or narrow.status != "NOT READY":
        raise Error("96L/4096 qwen35 geometry gained a native profile")
    print("PASS (b): depth-free admission (128L admitted); 95L and 96L/4096 refused a native profile")
    var wrong_quant = ModelArchitectureRegistry.classify(
        "qwen35", "39B", 96, 5120, 262144, 2, ""
    )
    if wrong_quant.status != "NOT READY" or wrong_quant.native_profile != "qwen35":
        raise Error("non-Q8_0 40B geometry was admitted")
    print("PASS (c): Q4_0 at 96L/5120 refused; Q8_0 is the only family quantization")


def test_family_signature() raises:
    var p40 = qwen35_40b_profile()
    p40.validate_relations()
    validate_qwen35_family_signature(p40)
    if p40.full_attention_layers() != 24 or p40.ssm_layers() != 72:
        raise Error("40B hybrid layer split drifted")
    if p40.qkv_width() != 10240 or p40.expected_tensor_count() != 1275:
        raise Error("40B formulas drifted (qkv width / tensor count)")
    if p40.ssm_state_elements() != 56623104 or p40.conv_ring_elements() != 2949120:
        raise Error("40B SSM state / conv ring element counts drifted")
    if p40.kv_elements(8192) != 402653184:
        raise Error("40B KV elements must price only the 24 full-attention layers")
    print("PASS (d0): 40B formulas (24 full + 72 SSM, qkv 10240, 1275 tensors) hold")
    var p27 = qwen35_27b_profile()
    p27.validate_relations()
    validate_qwen35_family_signature(p27)
    if p27.expected_tensor_count() != 851:
        raise Error("27B tensor-count formula drifted")
    print("PASS (d1): family signature admits both depths (27B 64L and 40B 96L)")
    var bad_ffn = Qwen35Profile(
        "mutant", 96, 5120, 17409, 24, 4, 256, 248320, 262144,
        4, 16, 128, 48, 6144, 4, 64, Float32(10000000), Float32(1e-6),
    )
    var e0 = expect_family_refusal(bad_ffn, "feed_forward_length")
    print("PASS (d2): off-family FFN refused:", e0)


def test_real_40b(mut model: PackedGGUF) raises:
    var profile = qwen35_profile_for(model)
    if profile.layer_count != 96 or profile.hidden_size != 5120:
        raise Error("real 40B profile geometry drifted")
    if profile.qkv_width() != 10240 or profile.expected_tensor_count() != 1275:
        raise Error("real 40B formulas drifted (qkv width / tensor count)")
    if profile.vocabulary_size != 248320 or profile.ssm_time_step_rank != 48:
        raise Error("real 40B vocab / v-head count drifted")
    validate_qwen35(model, profile, 8192)
    print("PASS (e0): real 40B validates via qwen35_profile_for + validate_qwen35")
    var bad_inner = Qwen35Profile(
        "mutant", 96, 5120, 17408, 24, 4, 256, 248320, 262144,
        4, 16, 128, 48, 6145, 4, 64, Float32(10000000), Float32(1e-6),
    )
    var e1 = expect_validate_refusal(model, bad_inner, 8192, "ssm_inner_size")
    print("PASS (e1): 96L inner mutant refused:", e1)
    var bad_interval = Qwen35Profile(
        "mutant", 96, 5120, 17408, 24, 4, 256, 248320, 262144,
        5, 16, 128, 48, 6144, 4, 64, Float32(10000000), Float32(1e-6),
    )
    var e2 = expect_validate_refusal(model, bad_interval, 8192, "full_attention_interval")
    print("PASS (e2): 96L interval mutant refused:", e2)
    var inspected = ModelArchitectureRegistry.inspect(model, 0)
    if inspected.status != "READY" or inspected.native_profile != "qwen35":
        raise Error("inspect did not admit the real 40B under qwen35")
    if inspected.compatibility != "COMPATIBLE" or inspected.model_variant != "39B":
        raise Error("inspect 40B compatibility/variant drifted")
    if inspected.tensor_validation != "passed":
        raise Error("inspect tensor validation did not pass for the real 40B")
    var plan = qwen35_memory_plan(41537542144, 8192, profile)
    if inspected.estimated_vram_bytes != plan.device_bytes:
        raise Error("inspect 40B footprint does not match the qwen35 memory plan")
    if plan.kv_bytes != 805306368:
        raise Error("40B KV must price only the 24 full-attention layers at ctx 8192")
    if plan.activation_bytes != 241707520:
        raise Error("40B activation bytes drifted (SSM state + conv rings + scratch)")
    if plan.device_bytes != 42584556036:
        raise Error("40B memory plan device total drifted")
    print(
        "PASS (e3): inspect 40B READY, tensor_validation passed, estimated_vram_bytes=",
        inspected.estimated_vram_bytes,
    )
    print(
        "PASS (e4): 40B memory plan kv_bytes=", plan.kv_bytes,
        " activation_bytes=", plan.activation_bytes,
        " device_bytes=", plan.device_bytes,
    )


def test_real_27b_regress(mut model: PackedGGUF) raises:
    var inspected = ModelArchitectureRegistry.inspect(model, 0)
    if inspected.status != "READY" or inspected.native_profile != "qwen35":
        raise Error("inspect no longer admits the real 27B under qwen35")
    if inspected.tensor_validation != "passed":
        raise Error("inspect tensor validation did not pass for the real 27B")
    if inspected.estimated_vram_bytes != 29295152100:
        raise Error("27B footprint drifted from the banked Q35-2 value")
    print(
        "PASS (e5): 27B inspect unchanged, estimated_vram_bytes=",
        inspected.estimated_vram_bytes,
    )


def main() raises:
    var args = argv()
    if len(args) != 3:
        raise Error("usage: test_qwen35_registry_q40_1 <real-qwen35-40b.gguf> <real-qwen35-27b.gguf>")
    test_classify_family()
    test_family_signature()
    var model40 = PackedGGUF(args[1])
    test_real_40b(model40)
    var model27 = PackedGGUF(args[2])
    test_real_27b_regress(model27)
    test_model_architecture_registry()
    print("PASS (f1): existing native.model_registry case still passes")
    test_gemma4_profiles()
    print("PASS (f2): existing native.gemma4_profiles case still passes")
    print("Q40-1 qwen35 registry family generalization: ALL PASS")
