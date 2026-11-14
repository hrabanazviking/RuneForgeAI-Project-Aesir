# tests/test_qwen35_registry_q35_2.mojo
# Q35-2 registry + profile + inspect policy proof.
#
# Usage: test_qwen35_registry_q35_2 <real-qwen35-27b.gguf>
#
# The profile path runs over PackedGGUF, whose row contract requires
# Q8_0 rows to be 32-block-aligned; the Q35-1 tiny fixture cannot be
# opened by PackedGGUF at all (its ssm_out.weight has 24 Q8_0
# columns), so -- exactly like `aesir inspect` itself -- this test
# drives the profile path against the real file, metadata-only
# ( PackedGGUF mmaps the header; nothing is materialized). The tiny
# fixture's loader-path coverage stays with the Q35-1 test.
#
# Proves:
#  (a) the real hybrid geometry (64L/5120, file_type 7 = Q8_0)
#      classifies to native_profile "qwen35", READY / COMPATIBLE,
#      with Q8_0 admitted by the qwen35-scoped quantization policy;
#  (b) the same geometry in another quantization is NOT READY, and a
#      non-pinned qwen35 geometry is COMPATIBLE without native_profile;
#  (c) mutated hybrid geometry is refused by validate_qwen35 with a
#      named error (interval not dividing block_count; inner breaking
#      inner == dt_rank * state), and a mutated tensor shape is
#      refused at the tensor contract;
#  (d) the real file validates end to end via qwen35_profile_for +
#      validate_qwen35 and via ModelArchitectureRegistry.inspect
#      (tensor_validation "passed"), and the 27B memory plan prices
#      KV for only the 16 full-attention layers plus the exact SSM
#      state and conv-ring footprints;
#  (e) regression: the existing registry and Gemma 4 profile cases
#      still pass unchanged.

from std.sys import argv

from loader.packed_gguf import PackedGGUF, PackedTensor
from core.model_registry import (
    ModelArchitectureRegistry,
    qwen35_quantization_supported,
)
from core.qwen35_profile import (
    Qwen35Profile,
    qwen35_27b_profile,
    qwen35_profile_for,
    validate_qwen35,
)
from core.inference_memory import qwen35_memory_plan
from tests.test_model_registry import test_model_architecture_registry
from tests.test_gemma4_profile import test_gemma4_profiles


def expect_refusal(model: PackedGGUF, profile: Qwen35Profile,
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


def test_classify_policy() raises:
    if not qwen35_quantization_supported("Q8_0"):
        raise Error("Q8_0 must be admitted for qwen35")
    if qwen35_quantization_supported("Q4_K_M"):
        raise Error("K-quants have no qwen35 evidence and must stay unadmitted")
    var real = ModelArchitectureRegistry.classify(
        "qwen35", "27B", 64, 5120, 262144, 7, ""
    )
    if real.native_profile != "qwen35" or real.status != "READY":
        raise Error("real qwen35 geometry did not classify to the native profile")
    if real.compatibility != "COMPATIBLE" or real.architecture != "qwen35":
        raise Error("real qwen35 compatibility verdict drifted")
    if real.tensor_naming != "qwen35/blk.*" or real.supported_quantizations != "Q8_0":
        raise Error("real qwen35 naming/quantization policy drifted")
    if real.tensor_validation != "not_run" or real.recommended_context != 8192:
        raise Error("classify fabricated inspection evidence or context drifted")
    print("PASS (a): real geometry 64L/5120 Q8_0 -> native_profile qwen35, READY/COMPATIBLE")
    var wrong_quant = ModelArchitectureRegistry.classify(
        "qwen35", "27B", 64, 5120, 262144, 2, ""
    )
    if wrong_quant.status != "NOT READY" or wrong_quant.native_profile != "qwen35":
        raise Error("non-Q8_0 qwen35 geometry was admitted")
    var other = ModelArchitectureRegistry.classify(
        "qwen35", "", 32, 4096, 131072, 7, ""
    )
    if other.native_profile != "" or other.status != "NOT READY":
        raise Error("non-pinned qwen35 geometry gained a native profile")
    if other.compatibility != "COMPATIBLE":
        raise Error("non-pinned qwen35 geometry must stay COMPATIBLE without native_profile")
    print("PASS (b): Q4_0 refused; non-pinned geometry COMPATIBLE without native_profile")


def test_tiny_formulas() raises:
    var tiny = Qwen35Profile(
        "tiny", 4, 32, 64, 4, 2, 8, 16, 64,
        4, 2, 8, 3, 24, 4, 8, Float32(10000), Float32(1e-5),
    )
    tiny.validate_relations()
    if tiny.qkv_width() != 56 or tiny.expected_tensor_count() != 56:
        raise Error("tiny qwen35 formulas drifted (qkv width / tensor count)")
    if tiny.full_attention_layers() != 1 or tiny.ssm_layers() != 3:
        raise Error("tiny qwen35 hybrid layer split drifted")
    print("PASS (d0): tiny-geometry formulas (qkv 56, 56 tensors, 1 full + 3 SSM) hold")


def test_profile_and_memory(mut model: PackedGGUF) raises:
    var profile = qwen35_profile_for(model)
    if profile.layer_count != 64 or profile.hidden_size != 5120:
        raise Error("real qwen35 profile geometry drifted")
    if profile.qkv_width() != 10240 or profile.expected_tensor_count() != 851:
        raise Error("real qwen35 formulas drifted (qkv width / tensor count)")
    if profile.vocabulary_size != 248320 or profile.ssm_time_step_rank != 48:
        raise Error("real qwen35 vocab / v-head count drifted")
    validate_qwen35(model, profile, 8192)
    print("PASS (d1): real file validates via qwen35_profile_for + validate_qwen35")

    var bad_interval = Qwen35Profile(
        "mutant", 63, 5120, 17408, 24, 4, 256, 248320, 262144,
        4, 16, 128, 48, 6144, 4, 64, Float32(10000000), Float32(1e-6),
    )
    var e1 = expect_refusal(model, bad_interval, 8192, "full_attention_interval")
    print("PASS (c1): interval mutant refused:", e1)
    var bad_inner = Qwen35Profile(
        "mutant", 64, 5120, 17408, 24, 4, 256, 248320, 262144,
        4, 16, 128, 48, 6145, 4, 64, Float32(10000000), Float32(1e-6),
    )
    var e2 = expect_refusal(model, bad_inner, 8192, "ssm_inner_size")
    print("PASS (c2): inner mutant refused:", e2)

    var qkv = model.tensors["blk.0.attn_qkv.weight"]
    model.tensors["blk.0.attn_qkv.weight"] = PackedTensor(
        qkv.offset, qkv.columns, qkv.rows + 32, qkv.kind, qkv.byte_count
    )
    var e3 = expect_refusal(model, profile, 8192, "attn_qkv.weight")
    print("PASS (c3): mutated attn_qkv tensor refused:", e3)
    model.tensors["blk.0.attn_qkv.weight"] = qkv
    validate_qwen35(model, profile, 8192)

    var inspected = ModelArchitectureRegistry.inspect(model, 0)
    if inspected.status != "READY" or inspected.native_profile != "qwen35":
        raise Error("inspect did not admit the real file under qwen35")
    if inspected.tensor_validation != "passed":
        raise Error("inspect tensor validation did not pass for the real file")
    var plan = qwen35_memory_plan(28596003296, 8192, profile)
    if inspected.estimated_vram_bytes != plan.device_bytes:
        raise Error("inspect footprint does not match the qwen35 memory plan")
    print(
        "PASS (d2): inspect READY, tensor_validation passed, estimated_vram_bytes=",
        inspected.estimated_vram_bytes,
    )

    var real = qwen35_27b_profile()
    if real.ssm_state_elements() != 37748736 or real.conv_ring_elements() != 1966080:
        raise Error("27B SSM state / conv ring element counts drifted")
    if plan.kv_bytes != 536870912:
        raise Error("27B KV must price only the 16 full-attention layers at ctx 8192")
    if plan.activation_bytes <= 150994944 + 7864320:
        raise Error("27B activations must carry SSM state + conv rings on top of scratch")
    if plan.device_bytes != 28596003296 + plan.kv_bytes + plan.activation_bytes + 4:
        raise Error("27B memory plan device total drifted")
    print(
        "PASS (d3): 27B memory plan kv_bytes=", plan.kv_bytes,
        " activation_bytes=", plan.activation_bytes,
        " device_bytes=", plan.device_bytes,
    )


def main() raises:
    var args = argv()
    if len(args) != 2:
        raise Error("usage: test_qwen35_registry_q35_2 <real-qwen35-27b.gguf>")
    test_classify_policy()
    test_tiny_formulas()
    var model = PackedGGUF(args[1])
    test_profile_and_memory(model)
    test_model_architecture_registry()
    print("PASS (e1): existing native.model_registry case still passes")
    test_gemma4_profiles()
    print("PASS (e2): existing native.gemma4_profiles case still passes")
    print("Q35-2 qwen35 registry/profile policy: ALL PASS")
