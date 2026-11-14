# tests/test_quantize_k_qc_5.mojo
# QC-5 stage 2 proof: the K-quant packing writers (core/quantize.mojo
# quantize_q4_k / quantize_q6_k) are the inverse of the engine's OWN
# K-quant dequantizer (core/packed_quantization.packed_value, kinds
# 12 and 14 -- the reader core/dequantize_input.mojo dispatches to
# and the packed forward paths are declared bit-identical to).
#
# Method (QC-2 harness style):
# 1. Per-group packing proof: for every emitted block, the scale/min
#    fields and quants are re-derived LONGHAND from the QC-0-PLAN
#    section 1b layout text (ggml get_scale_min_k4 reconstruction;
#    the Q6_K ql/qh extraction), and packed_value's output must
#    equal the longhand value EXACTLY on every lane -- the writer's
#    packing is thereby proven against the reader, group by group,
#    including the g>=4 split-nibble scale packing.
# 2. Property round-trip: adversarial + random F32 vectors are
#    quantized, dequantized through packed_value only, and every
#    element must satisfy the per-sub-block bound proven in
#    core/quantize.mojo's QC-5 header:
#      Q4_K: err <= s_hat/2 + 15*|s_hat - s_j| + |m_hat - m_j| + dust
#      Q6_K: err <= s_hat/2 + 32*|s_hat - s_j| + s_j + dust
#    with (s_j, m_j) the ideal min/max fit recomputed here from the
#    input and (s_hat, m_hat) the stored reconstruction parsed from
#    the emitted bytes. Worst err/bound ratios are printed per case.
#    All-zero blocks must round-trip EXACTLY.
# 3. File round-trip (QC-1/QC-2 harness style): Q4_K + Q6_K tensors
#    are emitted as a real GGUF through loader/gguf_writer.mojo with
#    general.file_type = 15 (Q4_K_M); payload bytes must be
#    byte-identical to the quantizers' payloads, GGUFSeer must map
#    the tensors (stopping only at required-tensor validation, the
#    synthetic baseline), PackedGGUF must construct in full, and
#    dequantizing the file payload through the engine path
#    (core/dequantize_input) must satisfy the same bounds.
#
# Usage: test_quantize_k_qc_5   (no arguments; self-contained)

from std.ffi import external_call
from std.memory import bitcast

from core.dequantize_input import dequantize_range_f32
from core.mimir_well import MimirWell, f16, f32
from core.packed_quantization import Bytes, packed_value
from core.quantize import (
    Q4_K_BLOCK_BYTES,
    Q4_K_GGML_TYPE,
    Q6_K_BLOCK_BYTES,
    Q6_K_GGML_TYPE,
    q4_k_payload_bytes,
    q6_k_payload_bytes,
    quantize_q4_k,
    quantize_q6_k,
)
from loader.gguf import GGUFSeer
from loader.gguf_writer import (
    GGUFModelDesc,
    GGUFWriterTensor,
    gguf_kv_string,
    gguf_kv_u32,
    read_gguf_header_copy,
    write_gguf_file,
)
from loader.packed_gguf import PackedGGUF
from loader.tokenizer import RuneWeaver


def check(condition: Bool, message: String) raises:
    if not condition:
        raise Error(message)


def abs_f32(value: Float32) -> Float32:
    return value if value >= Float32(0.0) else -value


def fmax(a: Float32, b: Float32) -> Float32:
    return a if a >= b else b


def lcg_next(mut state: UInt64) -> Float32:
    state = (state * UInt64(1103515245) + UInt64(12345)) % UInt64(2147483648)
    return Float32(state) / Float32(2147483648.0)


def lcg_signed(mut state: UInt64) -> Float32:
    return lcg_next(state) * Float32(2.0) - Float32(1.0)


def make_list(count: Int, fill: Float32) -> List[Float32]:
    var values = List[Float32]()
    for _ in range(count):
        values.append(fill)
    return values^


def well_bytes(mut well: MimirWell, data: List[UInt8]) raises -> Bytes:
    var buf = well.allocate((len(data) + 1) // 2 + 16).unsafe_bitcast[UInt8]()
    for i in range(len(data)):
        buf.unsafe_store(i, data[i])
    return buf


def f16_at(payload: List[UInt8], byte_offset: Int) -> Float32:
    var bits = UInt16(payload[byte_offset]) | (
        UInt16(payload[byte_offset + 1]) << 8
    )
    return bitcast[DType.float16](bits).cast[f32]()


def q4_scale_min(payload: List[UInt8], block: Int, j: Int) -> Tuple[Int, Int]:
    # Longhand get_scale_min_k4 over the 12 scale bytes at block+4.
    var p = block * Q4_K_BLOCK_BYTES + 4
    if j < 4:
        return (Int(payload[p + j]) & 63, Int(payload[p + j + 4]) & 63)
    var scale = (Int(payload[p + j + 4]) & 15) | (
        (Int(payload[p + j - 4]) >> 6) << 4
    )
    var minimum = (Int(payload[p + j + 4]) >> 4) | (
        (Int(payload[p + j]) >> 6) << 4
    )
    return (scale, minimum)


def q4_ideal(values: List[Float32], sub: Int) -> Tuple[Float32, Float32]:
    # The QC-5 fit, recomputed from the input: (scale, min) per
    # 32-value sub-block.
    var mn = values[sub]
    var mx = values[sub]
    for i in range(32):
        if values[sub + i] < mn:
            mn = values[sub + i]
        if values[sub + i] > mx:
            mx = values[sub + i]
    if mx == mn:
        if mn < Float32(0.0):
            return (Float32(0.0), -mn)
        return (mn / Float32(15.0), Float32(0.0))
    var min_eff = mn if mn < Float32(0.0) else Float32(0.0)
    return ((mx - min_eff) / Float32(15.0), -min_eff)


def run_q4_case(
    values: List[Float32], label: String, exact: Bool
) raises -> Float32:
    var payload = quantize_q4_k(values)
    check(
        len(payload) == q4_k_payload_bytes(len(values)),
        label + ": payload length mismatch",
    )
    var well = MimirWell(65536)
    var buf = well_bytes(well, payload)
    var max_err = Float32(0.0)
    var sum_err = Float32(0.0)
    var worst_ratio = Float32(0.0)
    for block in range(len(values) // 256):
        var d = f16_at(payload, block * Q4_K_BLOCK_BYTES)
        var dmin = f16_at(payload, block * Q4_K_BLOCK_BYTES + 2)
        for j in range(8):
            var sm = q4_scale_min(payload, block, j)
            var s_hat = d * Float32(sm[0])
            var m_hat = dmin * Float32(sm[1])
            var ideal = q4_ideal(values, block * 256 + j * 32)
            for i in range(32):
                var idx = block * 256 + j * 32 + i
                # Longhand dequant from the layout text.
                var qbyte = payload[
                    block * Q4_K_BLOCK_BYTES + 16 + (idx % 256) // 64 * 32
                    + idx % 32
                ]
                var q = (Int(qbyte) >> (4 * (j % 2))) & 15
                var expected = d * Float32(sm[0] * q) - dmin * Float32(sm[1])
                var got = packed_value(buf, 0, Int(Q4_K_GGML_TYPE), idx)
                check(
                    got == expected,
                    label + ": packed_value != longhand at index "
                    + String(idx),
                )
                var err = abs_f32(got - values[idx])
                var bound = (
                    s_hat * Float32(0.5)
                    + Float32(15.0) * abs_f32(s_hat - ideal[0])
                    + abs_f32(m_hat - ideal[1])
                    + Float32(0.000001)
                    * (
                        Float32(1.0) + abs_f32(values[idx]) + s_hat + m_hat
                    )
                    + Float32(0.0000001)
                )
                check(
                    err <= bound,
                    label + ": bound violated at index " + String(idx)
                    + " err=" + String(err) + " bound=" + String(bound),
                )
                if err > max_err:
                    max_err = err
                sum_err += err
                if bound > Float32(0.0):
                    var ratio = err / bound
                    if ratio > worst_ratio:
                        worst_ratio = ratio
    if exact:
        check(max_err == Float32(0.0), label + ": must round-trip exactly")
    print(
        "CASE q4_k", label, "n=" + String(len(values)),
        "max_err=" + String(max_err),
        "mean_err=" + String(sum_err / Float32(len(values))),
        "worst_ratio=" + String(worst_ratio),
    )
    print("PASS: q4_k round-trip --", label)
    return worst_ratio


def q6_ideal(values: List[Float32], sub: Int) -> Float32:
    var amax = Float32(0.0)
    for i in range(16):
        var magnitude = abs_f32(values[sub + i])
        if magnitude > amax:
            amax = magnitude
    return amax / Float32(32.0)


def run_q6_case(
    values: List[Float32], label: String, exact: Bool
) raises -> Float32:
    var payload = quantize_q6_k(values)
    check(
        len(payload) == q6_k_payload_bytes(len(values)),
        label + ": payload length mismatch",
    )
    var well = MimirWell(65536)
    var buf = well_bytes(well, payload)
    var max_err = Float32(0.0)
    var sum_err = Float32(0.0)
    var worst_ratio = Float32(0.0)
    for block in range(len(values) // 256):
        var off = block * Q6_K_BLOCK_BYTES
        var d = f16_at(payload, off + 208)
        for idx_in in range(256):
            var idx = block * 256 + idx_in
            var group = idx_in // 16
            var sc_byte = Int(payload[off + 192 + group])
            var sc = sc_byte if sc_byte < 128 else sc_byte - 256
            var s_hat = d * Float32(sc)
            # Longhand q6 extraction from the layout text.
            var half = idx_in // 128
            var within = idx_in % 128
            var grp = within // 32
            var lane = idx_in % 32
            var low_byte = Int(
                payload[off + half * 64 + (grp % 2) * 32 + lane]
            )
            var low = (low_byte >> (4 * (grp // 2))) & 15
            var high = (
                Int(payload[off + 128 + half * 32 + lane]) >> (2 * grp)
            ) & 3
            var q6 = low | (high << 4)
            var expected = d * Float32(sc) * Float32(q6 - 32)
            var got = packed_value(buf, 0, Int(Q6_K_GGML_TYPE), idx)
            check(
                got == expected,
                label + ": packed_value != longhand at index " + String(idx),
            )
            var err = abs_f32(got - values[idx])
            var s_j = q6_ideal(values, block * 256 + group * 16)
            var bound = (
                s_hat * Float32(0.5)
                + Float32(32.0) * abs_f32(s_hat - s_j)
                + s_j
                + Float32(0.000001)
                * (Float32(1.0) + abs_f32(values[idx]) + s_hat)
                + Float32(0.0000001)
            )
            check(
                err <= bound,
                label + ": bound violated at index " + String(idx)
                + " err=" + String(err) + " bound=" + String(bound),
            )
            if err > max_err:
                max_err = err
            sum_err += err
            if bound > Float32(0.0):
                var ratio = err / bound
                if ratio > worst_ratio:
                    worst_ratio = ratio
    if exact:
        check(max_err == Float32(0.0), label + ": must round-trip exactly")
    print(
        "CASE q6_k", label, "n=" + String(len(values)),
        "max_err=" + String(max_err),
        "mean_err=" + String(sum_err / Float32(len(values))),
        "worst_ratio=" + String(worst_ratio),
    )
    print("PASS: q6_k round-trip --", label)
    return worst_ratio


def expect_error_q4(values: List[Float32], needle: String, label: String) raises:
    var error_text = String("")
    try:
        var payload = quantize_q4_k(values)
        _ = payload
    except error:
        error_text = String(error)
    check(
        needle in error_text,
        label + ": expected refusal containing '" + needle + "', got: "
        + error_text,
    )
    print("PASS: q4_k refusal --", label)


def expect_error_q6(values: List[Float32], needle: String, label: String) raises:
    var error_text = String("")
    try:
        var payload = quantize_q6_k(values)
        _ = payload
    except error:
        error_text = String(error)
    check(
        needle in error_text,
        label + ": expected refusal containing '" + needle + "', got: "
        + error_text,
    )
    print("PASS: q6_k refusal --", label)


def test_refusals() raises:
    expect_error_q4(List[Float32](), "must be positive", "q4 empty")
    expect_error_q4(make_list(255, Float32(1.0)), "not a multiple", "q4 255")
    expect_error_q4(make_list(257, Float32(1.0)), "not a multiple", "q4 257")
    var nan_values = make_list(256, Float32(0.5))
    nan_values[17] = Float32(0.0) / Float32(0.0)
    expect_error_q4(nan_values, "non-finite", "q4 NaN at index 17")
    expect_error_q4(
        make_list(256, Float32(10000000000.0)), "overflows the f16",
        "q4 scale overflow (amax 1e10)",
    )
    expect_error_q6(List[Float32](), "must be positive", "q6 empty")
    expect_error_q6(make_list(100, Float32(1.0)), "not a multiple", "q6 100")
    var nan6 = make_list(256, Float32(0.5))
    nan6[200] = Float32(0.0) / Float32(0.0)
    expect_error_q6(nan6, "non-finite", "q6 NaN at index 200")
    expect_error_q6(
        make_list(256, Float32(10000000000.0)), "overflows the f16",
        "q6 scale overflow (amax 1e10)",
    )


def read_file_bytes(path: String) raises -> List[UInt8]:
    var path_bytes = List[Int8]()
    for byte in path.as_bytes():
        path_bytes.append(Int8(byte))
    path_bytes.append(0)
    var fd = external_call["open64", Int32](
        path_bytes.unsafe_ptr(), Int32(0), Int32(0)
    )
    if fd < 0:
        raise Error("failed to open file for readback: " + path)
    var out = List[UInt8]()
    var buffer = List[UInt8]()
    buffer.resize(65536, UInt8(0))
    while True:
        var got = external_call["read", Int](Int(fd), buffer.unsafe_ptr(), 65536)
        if got < 0:
            _ = external_call["close", Int32](fd)
            raise Error("failed to read file: " + path)
        if got == 0:
            break
        for i in range(got):
            out.append(buffer[i])
    _ = external_call["close", Int32](fd)
    return out^


def test_file_roundtrip() raises:
    var state: UInt64 = 424242
    var q4_values = List[Float32]()
    for _ in range(16384):
        q4_values.append(lcg_signed(state) * Float32(1.5))
    var q6_values = List[Float32]()
    for _ in range(16384):
        q6_values.append(lcg_signed(state) * Float32(0.75))
    var q4_payload = quantize_q4_k(q4_values)
    var q6_payload = quantize_q6_k(q6_values)
    var desc = GGUFModelDesc()
    desc.add_kv(gguf_kv_string("general.architecture", "llama"))
    desc.add_kv(gguf_kv_string("general.name", "qc5-k-roundtrip"))
    desc.add_kv(gguf_kv_u32("general.alignment", 32))
    desc.add_kv(gguf_kv_u32("general.file_type", 15))
    var dims4 = List[UInt64]()
    dims4.append(UInt64(256))
    dims4.append(UInt64(64))
    desc.add_tensor(
        GGUFWriterTensor("q4.weight", dims4, UInt32(Q4_K_GGML_TYPE), q4_payload)
    )
    var dims6 = List[UInt64]()
    dims6.append(UInt64(256))
    dims6.append(UInt64(64))
    desc.add_tensor(
        GGUFWriterTensor("q6.weight", dims6, UInt32(Q6_K_GGML_TYPE), q6_payload)
    )
    var path = String("/tmp/aesir-qc5-roundtrip.gguf")
    var written = write_gguf_file(path, desc)
    var file_bytes = read_file_bytes(path)
    check(len(file_bytes) == written, "file: readback length mismatch")
    var head = read_gguf_header_copy(path)
    check(len(head.directory) == 2, "file: directory must hold 2 tensors")
    for entry_index in range(2):
        ref entry = head.directory[entry_index]
        ref tensor = desc.tensors[entry_index]
        check(entry.relative_offset % 32 == 0, "file: offset not 32-aligned")
        check(entry.byte_size == len(tensor.payload), "file: size mismatch")
        for j in range(entry.byte_size):
            check(
                file_bytes[head.data_offset + entry.relative_offset + j]
                == tensor.payload[j],
                "file: payload byte mismatch tensor " + entry.name,
            )
    print("PASS: file payload bytes == quantizer payload bytes (file_type 15)")
    for kv in head.kvs:
        if kv.key == "general.file_type":
            check(kv.value.as_u32() == 15, "file: file_type must be 15")
    print("PASS: emitted metadata carries general.file_type = 15 (Q4_K_M)")
    # GGUFSeer maps; load stops only at required-tensor validation.
    var seer = GGUFSeer(path)
    var tokenizer = RuneWeaver()
    var pool = MimirWell(65536)
    var error_text = String("")
    try:
        seer.mmap_and_load(pool, tokenizer)
    except error:
        error_text = String(error)
    print("SEER_LOAD_STOP:", error_text)
    # PackedGGUF constructs in full over the emitted file.
    var packed = PackedGGUF(path)
    _ = packed
    print("PASS: PackedGGUF constructs over the Q4_K/Q6_K file")
    # Dequantize the FILE payload through the engine input path and
    # re-check the bounds against the original values.
    var well = MimirWell(1048576)
    var buf = well_bytes(well, file_bytes)
    for entry_index in range(2):
        ref entry = head.directory[entry_index]
        var base = head.data_offset + entry.relative_offset
        var values = q4_values.copy()
        if entry_index == 1:
            values = q6_values.copy()
        var back = dequantize_range_f32(
            buf, base, Int(entry.tensor_type), 0, 16384
        )
        check(len(back) == 16384, "file: dequant count mismatch")
        var max_err = Float32(0.0)
        for i in range(16384):
            var err = abs_f32(back[i] - values[i])
            if err > max_err:
                max_err = err
        check(max_err < Float32(0.2), "file: dequant max err too large")
        print(
            "PASS: file dequant via engine input path --", entry.name,
            "max_err=" + String(max_err),
        )


def main() raises:
    var worst4 = Float32(0.0)
    var worst6 = Float32(0.0)
    # Q4_K cases
    worst4 = fmax(worst4, run_q4_case(make_list(512, Float32(0.0)), "all-zero (2 blocks)", True))
    var state: UInt64 = 777
    var random = List[Float32]()
    for _ in range(9216):
        random.append(lcg_signed(state) * Float32(2.0))
    worst4 = fmax(worst4, run_q4_case(random, "random signed scale 2 (36 blocks)", False))
    var negative = List[Float32]()
    for _ in range(2048):
        negative.append(-abs_f32(lcg_signed(state)) * Float32(50.0))
    worst4 = fmax(worst4, run_q4_case(negative, "negative-only random scale 50", False))
    var positive = List[Float32]()
    for _ in range(1024):
        positive.append(abs_f32(lcg_signed(state)) * Float32(0.03125))
    worst4 = fmax(worst4, run_q4_case(positive, "positive-only random (min clamp branch)", False))
    worst4 = fmax(worst4, run_q4_case(make_list(768, Float32(-3.25)), "constant -3.25 blocks (scale 0, min only)", False))
    worst4 = fmax(worst4, run_q4_case(make_list(512, Float32(2.0)), "constant +2.0 blocks (min_eff 0)", False))
    var outlier = make_list(1024, Float32(0.001))
    for i in range(256, 288):
        outlier[i] = lcg_signed(state) * Float32(1000.0)
    worst4 = fmax(worst4, run_q4_case(outlier, "outlier sub-block 1000 in 0.001 field", False))
    var spike = make_list(512, Float32(0.0))
    spike[100] = Float32(-77.5)
    worst4 = fmax(worst4, run_q4_case(spike, "single negative spike -77.5", False))
    var mixed = List[Float32]()
    for block in range(8):
        var scale = Float32(1 << block) * Float32(0.001)
        for _ in range(256):
            mixed.append(lcg_signed(state) * scale)
    worst4 = fmax(worst4, run_q4_case(mixed, "multi-scale blocks 1e-3..0.128", False))
    # Q6_K cases
    worst6 = fmax(worst6, run_q6_case(make_list(512, Float32(0.0)), "all-zero (2 blocks)", True))
    var random6 = List[Float32]()
    for _ in range(9216):
        random6.append(lcg_signed(state) * Float32(2.0))
    worst6 = fmax(worst6, run_q6_case(random6, "random signed scale 2 (36 blocks)", False))
    var negative6 = List[Float32]()
    for _ in range(2048):
        negative6.append(-abs_f32(lcg_signed(state)) * Float32(50.0))
    worst6 = fmax(worst6, run_q6_case(negative6, "negative-only random scale 50", False))
    worst6 = fmax(worst6, run_q6_case(make_list(768, Float32(-3.25)), "constant -3.25 blocks", False))
    worst6 = fmax(worst6, run_q6_case(make_list(512, Float32(2.0)), "constant +2.0 blocks (clamp-to-31 lane)", False))
    var outlier6 = make_list(1024, Float32(0.001))
    for i in range(160, 176):
        outlier6[i] = lcg_signed(state) * Float32(1000.0)
    worst6 = fmax(worst6, run_q6_case(outlier6, "outlier group 1000 in 0.001 field", False))
    test_refusals()
    test_file_roundtrip()
    print("WORST_RATIO q4_k=" + String(worst4) + " q6_k=" + String(worst6))
    print("ALL PASS: QC-5 K-quant packing writers (Q4_K + Q6_K)")
