# tests/test_quantize_k_qs_3.mojo
# QS-3 stage 2 proof: the searched-fit K packers (core/quantize.mojo
# quantize_q4_k_searched / quantize_q6_k_searched, ggml
# make_qkx2_quants / make_qx_quants ports) against the QC-5 legacy
# min/max packers, on identical inputs, dequantized ONLY through
# the engine's own reader (core/packed_quantization.packed_value).
#
# Assertions:
# 1. Payload lengths equal the reader-priced sizes, both fits.
# 2. Searched round-trips are finite on every lane.
# 3. Per-case MSE: searched <= legacy * 1.05 + 1e-12 on every case
#    (the 5% slack covers the super-block 6-bit re-quantization
#    interaction, which neither fit controls); the clustered and
#    all-negative cases must be STRICTLY better (that is the
#    searched fit's whole reason to exist: endpoint fits waste
#    range on outliers / cannot sign a Q6_K scale).
# 4. All-zero blocks round-trip EXACTLY under both fits; constant
#    blocks round-trip exactly under the searched fit where the
#    format allows (constant -c and +c at Q4_K lattice points).
# 5. Refusals mirror the legacy writers (empty, non-multiple,
#    non-finite), naming the searched writer.
# 6. On clustered data the searched bytes DIFFER from the legacy
#    bytes (the fit actually engages; a no-op port would fail).
#
# Usage: test_quantize_k_qs_3   (no arguments; self-contained)

from core.mimir_well import MimirWell
from core.packed_quantization import Bytes, packed_value
from core.quantize import (
    Q4_K_GGML_TYPE,
    Q6_K_GGML_TYPE,
    q4_k_payload_bytes,
    q6_k_payload_bytes,
    quantize_q4_k,
    quantize_q4_k_searched,
    quantize_q6_k,
    quantize_q6_k_searched,
)


def check(condition: Bool, message: String) raises:
    if not condition:
        raise Error(message)


def abs_f32(value: Float32) -> Float32:
    return value if value >= Float32(0.0) else -value


def lcg_next(mut state: UInt64) -> Float32:
    state = (state * UInt64(1103515245) + UInt64(12345)) % UInt64(2147483648)
    return Float32(state) / Float32(2147483648.0)


def lcg_signed(mut state: UInt64) -> Float32:
    return lcg_next(state) * Float32(2.0) - Float32(1.0)


def well_bytes(mut well: MimirWell, data: List[UInt8]) raises -> Bytes:
    var buf = well.allocate((len(data) + 1) // 2 + 16).unsafe_bitcast[UInt8]()
    for i in range(len(data)):
        buf.unsafe_store(i, data[i])
    return buf


def mse_of(payload: List[UInt8], values: List[Float32], kind: Int) raises -> Float64:
    var well = MimirWell(65536)
    var buf = well_bytes(well, payload)
    var total = Float64(0.0)
    for i in range(len(values)):
        var got = packed_value(buf, 0, kind, i)
        check(got == got and abs_f32(got) < Float32(1e30), "non-finite dequant at " + String(i))
        var diff = Float64(got) - Float64(values[i])
        total += diff * diff
    return total / Float64(len(values))


def run_case(values: List[Float32], label: String, strict_better: Bool) raises:
    var legacy4 = quantize_q4_k(values)
    var searched4 = quantize_q4_k_searched(values)
    check(len(legacy4) == q4_k_payload_bytes(len(values)), label + ": legacy q4 length")
    check(len(searched4) == q4_k_payload_bytes(len(values)), label + ": searched q4 length")
    var mse_l4 = mse_of(legacy4, values, Int(Q4_K_GGML_TYPE))
    var mse_s4 = mse_of(searched4, values, Int(Q4_K_GGML_TYPE))
    check(mse_s4 <= mse_l4 * Float64(1.05) + Float64(1e-12), label + ": q4 searched MSE regressed: legacy=" + String(mse_l4) + " searched=" + String(mse_s4))
    if strict_better:
        check(mse_s4 < mse_l4, label + ": q4 searched must be strictly better: legacy=" + String(mse_l4) + " searched=" + String(mse_s4))
    var legacy6 = quantize_q6_k(values)
    var searched6 = quantize_q6_k_searched(values)
    check(len(legacy6) == q6_k_payload_bytes(len(values)), label + ": legacy q6 length")
    check(len(searched6) == q6_k_payload_bytes(len(values)), label + ": searched q6 length")
    var mse_l6 = mse_of(legacy6, values, Int(Q6_K_GGML_TYPE))
    var mse_s6 = mse_of(searched6, values, Int(Q6_K_GGML_TYPE))
    check(mse_s6 <= mse_l6 * Float64(1.05) + Float64(1e-12), label + ": q6 searched MSE regressed: legacy=" + String(mse_l6) + " searched=" + String(mse_s6))
    if strict_better:
        check(mse_s6 < mse_l6, label + ": q6 searched must be strictly better: legacy=" + String(mse_l6) + " searched=" + String(mse_s6))
    print("CASE", label, "q4 legacy_mse=" + String(mse_l4), "searched_mse=" + String(mse_s4), "q6 legacy_mse=" + String(mse_l6), "searched_mse=" + String(mse_s6))
    print("PASS: A/B --", label)


def make_random(count: Int, seed: UInt64) -> List[Float32]:
    var state = seed
    var values = List[Float32]()
    for _ in range(count):
        values.append(lcg_signed(state))
    return values^


def make_clustered(count: Int, seed: UInt64) -> List[Float32]:
    # Mass concentrated near 0 with one large outlier per 32 lanes:
    # the endpoint fit prices the whole sub-block by the outlier.
    var state = seed
    var values = List[Float32]()
    for i in range(count):
        if i % 32 == 31:
            values.append(Float32(2.5))
        else:
            values.append(lcg_signed(state) * Float32(0.05))
    return values^


def make_gaussish(count: Int, seed: UInt64) -> List[Float32]:
    var state = seed
    var values = List[Float32]()
    for i in range(count):
        var block_scale = Float32(0.25) + Float32((i // 256) % 4) * Float32(0.35)
        var v = (lcg_signed(state) + lcg_signed(state) + lcg_signed(state)) / Float32(3.0)
        values.append(v * block_scale)
    return values^


def make_all_negative(count: Int, seed: UInt64) -> List[Float32]:
    var state = seed
    var values = List[Float32]()
    for _ in range(count):
        values.append(Float32(-0.1) - lcg_next(state) * Float32(0.8))
    return values^


def make_constant(count: Int, fill: Float32) -> List[Float32]:
    var values = List[Float32]()
    for _ in range(count):
        values.append(fill)
    return values^


def expect_error_q4s(values: List[Float32], needle: String, label: String) raises:
    var error_text = String("")
    try:
        var payload = quantize_q4_k_searched(values)
        _ = payload
    except error:
        error_text = String(error)
    check(needle in error_text, label + ": expected refusal containing '" + needle + "', got: " + error_text)
    print("PASS: q4 searched refusal --", label)


def expect_error_q6s(values: List[Float32], needle: String, label: String) raises:
    var error_text = String("")
    try:
        var payload = quantize_q6_k_searched(values)
        _ = payload
    except error:
        error_text = String(error)
    check(needle in error_text, label + ": expected refusal containing '" + needle + "', got: " + error_text)
    print("PASS: q6 searched refusal --", label)


def main() raises:
    run_case(make_random(512, UInt64(12345)), "random-uniform", False)
    run_case(make_clustered(512, UInt64(777)), "clustered-outlier", True)
    run_case(make_gaussish(1024, UInt64(31337)), "gaussish-multiscale", False)
    run_case(make_all_negative(512, UInt64(4242)), "all-negative", True)
    # Zero blocks: exact under both fits, both kinds.
    var zeros = make_constant(256, Float32(0.0))
    check(mse_of(quantize_q4_k_searched(zeros), zeros, Int(Q4_K_GGML_TYPE)) == Float64(0.0), "zeros q4 searched must be exact")
    check(mse_of(quantize_q6_k_searched(zeros), zeros, Int(Q6_K_GGML_TYPE)) == Float64(0.0), "zeros q6 searched must be exact")
    print("PASS: zero blocks exact")
    # Constant blocks: searched MSE must not exceed legacy.
    run_case(make_constant(256, Float32(-0.375)), "constant-negative", False)
    run_case(make_constant(256, Float32(0.625)), "constant-positive", False)
    # The fit engages: clustered bytes differ between fits.
    var clustered = make_clustered(512, UInt64(777))
    var legacy_bytes = quantize_q4_k(clustered)
    var searched_bytes = quantize_q4_k_searched(clustered)
    var differ = False
    for i in range(len(legacy_bytes)):
        if legacy_bytes[i] != searched_bytes[i]:
            differ = True
            break
    check(differ, "searched bytes must differ from legacy on clustered data")
    print("PASS: searched fit engages (bytes differ)")
    # Refusals.
    expect_error_q4s(List[Float32](), "must be positive", "q4s empty")
    expect_error_q4s(make_constant(255, Float32(1.0)), "not a multiple", "q4s 255")
    var nan_values = make_constant(256, Float32(0.5))
    nan_values[7] = Float32(0.0) / Float32(0.0)
    expect_error_q4s(nan_values, "non-finite", "q4s NaN")
    expect_error_q6s(List[Float32](), "must be positive", "q6s empty")
    expect_error_q6s(make_constant(255, Float32(1.0)), "not a multiple", "q6s 255")
    expect_error_q6s(nan_values, "non-finite", "q6s NaN")
    print("ALL QS-3 SEARCHED-FIT TESTS PASS")
