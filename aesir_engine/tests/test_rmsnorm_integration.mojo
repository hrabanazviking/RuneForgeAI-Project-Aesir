"""End-to-end RMSNorm checks through the inference output-normalization path."""

from loader.gguf import GGUFSeer
from core.inference import forward_pass
from core.mimir_well import KVCache, MimirWell, RuneTensor, Scalar, f16


def test_rmsnorm_inference_integration() raises:
    var well = MimirWell(1024 * 1024)
    var seer = GGUFSeer("rmsnorm-integration.gguf")
    var embedding = RuneTensor[f16](2, 3, well.allocate(6), False)
    embedding.data.unsafe_store(0, Scalar[f16](1.0))
    embedding.data.unsafe_store(1, Scalar[f16](2.0))
    embedding.data.unsafe_store(2, Scalar[f16](3.0))
    embedding.data.unsafe_store(3, Scalar[f16](-1.0))
    embedding.data.unsafe_store(4, Scalar[f16](0.0))
    embedding.data.unsafe_store(5, Scalar[f16](1.0))
    seer.tensors["token_embd.weight"] = embedding.copy()

    var output_norm = RuneTensor[f16](1, 3, well.allocate(3), False)
    for index in range(output_norm.size):
        output_norm.data.unsafe_store(index, Scalar[f16](1.0))
    seer.tensors["output_norm.weight"] = output_norm.copy()

    var output_weight = RuneTensor[f16](2, 3, well.allocate(6), False)
    output_weight.data.unsafe_store(0, Scalar[f16](0.0))
    output_weight.data.unsafe_store(1, Scalar[f16](0.0))
    output_weight.data.unsafe_store(2, Scalar[f16](1.0))
    output_weight.data.unsafe_store(3, Scalar[f16](1.0))
    output_weight.data.unsafe_store(4, Scalar[f16](0.0))
    output_weight.data.unsafe_store(5, Scalar[f16](0.0))
    seer.tensors["output.weight"] = output_weight.copy()

    var tokens = List[Int]()
    tokens.append(0)
    var cache = KVCache(2, 3, well, 1)
    var offset_before_valid = well.offset
    var selected = forward_pass(tokens, seer, well, cache, 0, 1, 3, 1)
    if selected != 0:
        raise Error("inference output normalization selected an unexpected token")
    if well.offset != offset_before_valid:
        raise Error("successful inference failed to restore arena offset")

    # The consumer must surface the RMSNorm contract when its output weight is
    # too short, proving that this path reaches the shared kernel admission.
    seer.tensors["output_norm.weight"] = RuneTensor[f16](1, 2, well.allocate(2), False)
    var offset_before_rejection = well.offset
    var rejected = False
    try:
        _ = forward_pass(tokens, seer, well, 1, 3, 1)
    except error:
        rejected = True
        if "rmsnorm: weight dimension mismatch" not in String(error):
            raise Error("inference surfaced an unexpected RMSNorm failure")
    if not rejected:
        raise Error("inference admitted a short output RMSNorm weight")
    if well.offset != offset_before_rejection:
        raise Error("rejected output RMSNorm failed to restore arena offset")

    var valid_output_norm = RuneTensor[f16](1, 3, well.allocate(3), False)
    for index in range(valid_output_norm.size):
        valid_output_norm.data.unsafe_store(index, Scalar[f16](1.0))
    seer.tensors["output_norm.weight"] = valid_output_norm.copy()
    seer.config.rms_epsilon = Float32(1.0) / Float32(0.0)
    var offset_before_epsilon = well.offset
    var invalid_epsilon_rejected = False
    try:
        _ = forward_pass(tokens, seer, well, 1, 3, 1)
    except error:
        invalid_epsilon_rejected = True
        if "rmsnorm: epsilon must be finite and positive" not in String(error):
            raise Error("inference surfaced an unexpected epsilon failure")
    if not invalid_epsilon_rejected:
        raise Error("inference admitted a non-finite RMSNorm epsilon")
    if well.offset != offset_before_epsilon:
        raise Error("rejected output epsilon failed to restore arena offset")
    print("PASS: RMSNorm inference output-normalization integration")


def main() raises:
    test_rmsnorm_inference_integration()
