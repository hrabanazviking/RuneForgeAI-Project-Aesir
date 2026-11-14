# tests/test_quantize_q8_0_qc_2.mojo
# QC-2 proof: the Q8_0 quantizer (core/quantize.mojo) is the exact
# inverse of the engine's own Q8_0 dequantizers, proven three ways:
#
# 1. Byte layout: hand-computed blocks (incl. round-half-away-from-
#    zero tie cases at x.5, the ggml quantize_row_q8_0_ref rule)
#    match the emitted payload byte for byte.
# 2. Property round-trip: adversarial + random F32 vectors are
#    quantized, then dequantized through BOTH existing engine paths
#    (loader/quantization.mojo dequantize_q8_0_block -- the path
#    core/inference.mojo uses for Q8_0 rows -- and core/compute.mojo
#    dequantize_q8_0). The two dequantizers must agree exactly, and
#    every element must satisfy the proven per-block bound
#      err <= d_hat/2 + 127*|d_hat - d| + amax*2^-10 + d_hat*0.002 + 1e-7
#    where d = amax/127 (f32), d_hat = the stored f16 scale.
#    Values already on a power-of-two Q8_0 lattice must round-trip
#    EXACTLY (error 0).
# 3. File round-trip (QC-1 harness style): quantized tensors are
#    emitted as a real GGUF through loader/gguf_writer.mojo with
#    general.file_type = 7 (Q8_0); the file's payload bytes must be
#    byte-identical to the quantizer's payloads, GGUFSeer must map
#    the tensors (stopping only at required-tensor validation, the
#    codebase's synthetic baseline), PackedGGUF must construct in
#    full, and dequantizing the GGUFSeer-mapped tensor bytes through
#    the engine path must satisfy the same bound. One tensor holds
#    1,048,576 elements to prove no index overflow at scale.
#
# Usage: test_quantize_q8_0_qc_2   (no arguments; self-contained)

from std.ffi import external_call
from std.memory import Pointer, bitcast

from core.compute import BlockQ8_0, dequantize_q8_0
from core.mimir_well import MimirWell, f16, f32
from core.quantize import (
    Q8_0_BLOCK_BYTES,
    Q8_0_BLOCK_ELEMENTS,
    q8_0_payload_bytes,
    quantize_q8_0,
)
from loader.gguf import GGUFSeer
from loader.gguf_writer import (
    GGUFModelDesc,
    GGUFWriterTensor,
    gguf_kv_bool,
    gguf_kv_f32,
    gguf_kv_i32_array,
    gguf_kv_f32_array,
    gguf_kv_string,
    gguf_kv_string_array,
    gguf_kv_u32,
    read_gguf_header_copy,
    write_gguf_file,
)
from loader.packed_gguf import PackedGGUF
from loader.quantization import dequantize_q8_0_block
from loader.tokenizer import RuneWeaver


def check(condition: Bool, message: String) raises:
    if not condition:
        raise Error(message)


def abs_f32(value: Float32) -> Float32:
    return value if value >= Float32(0.0) else -value


def q8_0_error_bound(amax: Float32, d: Float32, d_hat: Float32) -> Float32:
    """The bound proven in core/quantize.mojo's header, per block."""
    return (
        Float32(0.5) * d_hat
        + Float32(127.0) * abs_f32(d_hat - d)
        + amax * Float32(0.0009765625)
        + d_hat * Float32(0.002)
        + Float32(0.0000001)
    )


def block_amax(values: List[Float32], base: Int) -> Float32:
    var amax = Float32(0.0)
    for i in range(Q8_0_BLOCK_ELEMENTS):
        var magnitude = abs_f32(values[base + i])
        if magnitude > amax:
            amax = magnitude
    return amax


def payload_d_hat(payload: List[UInt8], block: Int) -> Float32:
    var offset = block * Q8_0_BLOCK_BYTES
    var bits = UInt16(payload[offset]) | (UInt16(payload[offset + 1]) << 8)
    return bitcast[DType.float16](bits).cast[f32]()


struct RoundTripStats(Copyable, Movable):
    var max_err: Float32
    var mean_err: Float32
    var worst_ratio: Float32

    def __init__(out self, max_err: Float32, mean_err: Float32, worst_ratio: Float32):
        self.max_err = max_err
        self.mean_err = mean_err
        self.worst_ratio = worst_ratio


def check_dequant(
    dst: Pointer[Scalar[f16], MutUntrackedOrigin],
    values: List[Float32],
    payload: List[UInt8],
    label: String,
    exact: Bool,
) raises -> RoundTripStats:
    """Elementwise proof of one dequantized buffer against the source
    values: exactness where demanded, the proven bound everywhere,
    and max/mean error statistics."""
    var blocks = len(values) // Q8_0_BLOCK_ELEMENTS
    var max_err = Float32(0.0)
    var sum_err = Float64(0.0)
    var worst_ratio = Float32(0.0)
    for block in range(blocks):
        var base = block * Q8_0_BLOCK_ELEMENTS
        var amax = block_amax(values, base)
        var bound = q8_0_error_bound(amax, amax / Float32(127.0), payload_d_hat(payload, block))
        for i in range(Q8_0_BLOCK_ELEMENTS):
            var index = base + i
            var err = abs_f32(dst.unsafe_load(index).cast[f32]() - values[index])
            if exact:
                check(
                    err == Float32(0.0),
                    label + ": lattice value must round-trip exactly, index "
                    + String(index) + " err " + String(err),
                )
            check(
                err <= bound,
                label + ": error " + String(err) + " at index " + String(index)
                + " exceeds the proven bound " + String(bound),
            )
            if err > max_err:
                max_err = err
            sum_err += Float64(err)
            if bound > Float32(0.0):
                var ratio = err / bound
                if ratio > worst_ratio:
                    worst_ratio = ratio
    var mean_err = Float32(sum_err / Float64(len(values)))
    print(
        "PASS:", label, "— n =", len(values), " blocks =", blocks,
        " max_err =", max_err, " mean_err =", mean_err,
        " worst err/bound =", worst_ratio,
    )
    return RoundTripStats(max_err, mean_err, worst_ratio)


def run_roundtrip(values: List[Float32], label: String, exact: Bool) raises -> RoundTripStats:
    """Quantize, then dequantize through BOTH engine dequantizers;
    they must agree exactly, and the loader path must satisfy the
    bound (via check_dequant)."""
    var payload = quantize_q8_0(values)
    check(
        len(payload) == q8_0_payload_bytes(len(values)),
        label + ": payload length != q8_0_payload_bytes",
    )
    var blocks = len(values) // Q8_0_BLOCK_ELEMENTS
    var well = MimirWell((blocks * 17 + len(values) * 2 + 64) * 2 + 1024)
    var src_f16 = well.allocate(blocks * 17)
    var src_bytes = src_f16.unsafe_bitcast[UInt8]()
    for i in range(len(payload)):
        src_bytes.unsafe_store(i, payload[i])
    var dst_loader = well.allocate(len(values))
    dequantize_q8_0_block(src_bytes, dst_loader, blocks)
    var dst_core = well.allocate(len(values))
    dequantize_q8_0(src_f16.unsafe_bitcast[BlockQ8_0](), dst_core, blocks)
    for i in range(len(values)):
        check(
            dst_loader.unsafe_load(i) == dst_core.unsafe_load(i),
            label + ": engine dequantizers disagree at index " + String(i),
        )
    return check_dequant(dst_loader, values, payload, label, exact)


def lcg_next(mut state: UInt64) -> Float32:
    """Deterministic unit-interval generator (glibc LCG constants,
    state kept below 2^31 so no arithmetic can overflow)."""
    state = (state * UInt64(1103515245) + UInt64(12345)) % UInt64(2147483648)
    return Float32(state) / Float32(2147483648.0)


def lcg_signed(mut state: UInt64) -> Float32:
    return lcg_next(state) * Float32(2.0) - Float32(1.0)


def make_list(count: Int, fill: Float32) -> List[Float32]:
    var values = List[Float32]()
    for _ in range(count):
        values.append(fill)
    return values^


def test_layout_and_ties() raises:
    # Block A: amax = 127 -> d = 1.0 exactly. x.5 values pin the
    # round-half-away-from-zero tie rule (ggml roundf).
    var values_a = List[Float32]()
    var raw_a: List[Float32] = [
        0.5, 1.5, 2.5, 3.5, -0.5, -1.5, -2.5, -3.5,
        63.5, -63.5, 127.0, -127.0, 0.0, 126.5, -126.5, 64.5,
        -64.5, 32.5, -32.5, 1.0, -1.0, 2.0, -2.0, 0.25,
        -0.25, 100.5, -100.5, 5.5, -5.5, 6.5, -6.5, 127.0,
    ]
    for value in raw_a:
        values_a.append(value)
    var expected_a: List[Int] = [
        1, 2, 3, 4, -1, -2, -3, -4,
        64, -64, 127, -127, 0, 127, -127, 65,
        -65, 33, -33, 1, -1, 2, -2, 0,
        0, 101, -101, 6, -6, 7, -7, 127,
    ]
    var payload_a = quantize_q8_0(values_a)
    check(len(payload_a) == 34, "layout A: payload must be 34 bytes")
    check(
        payload_a[0] == UInt8(0x00) and payload_a[1] == UInt8(0x3C),
        "layout A: f16 scale bits for d = 1.0 must be 0x3C00 little-endian",
    )
    for i in range(32):
        check(
            payload_a[2 + i] == UInt8(expected_a[i] & 0xFF),
            "layout A: quant mismatch at lane " + String(i),
        )
    print("PASS: layout + tie rule — d = 1.0 block bytes exact (round half away from zero, incl. 2.5 -> 3, -2.5 -> -3, 0.25 -> 0)")
    # Block B: amax = 63.5 -> d = 0.5 exactly; ties at the half step.
    var values_b = make_list(32, Float32(0.0))
    values_b[0] = Float32(63.5)
    values_b[1] = Float32(-63.5)
    values_b[2] = Float32(31.75)
    values_b[3] = Float32(-31.75)
    values_b[4] = Float32(0.25)
    values_b[5] = Float32(-0.25)
    values_b[6] = Float32(16.0)
    values_b[7] = Float32(-16.0)
    var expected_b: List[Int] = [127, -127, 64, -64, 1, -1, 32, -32]
    var payload_b = quantize_q8_0(values_b)
    check(
        payload_b[0] == UInt8(0x00) and payload_b[1] == UInt8(0x38),
        "layout B: f16 scale bits for d = 0.5 must be 0x3800 little-endian",
    )
    for i in range(8):
        check(
            payload_b[2 + i] == UInt8(expected_b[i] & 0xFF),
            "layout B: quant mismatch at lane " + String(i),
        )
    print("PASS: layout — d = 0.5 block bytes exact (31.75 -> 64 and 0.25 -> 1 are half-step ties, rounded away from zero)")
    _ = run_roundtrip(values_a, "roundtrip of tie block A (d = 1.0)", False)
    _ = run_roundtrip(values_b, "roundtrip of tie block B (d = 0.5)", False)


def test_zero_and_equal() raises:
    _ = run_roundtrip(make_list(320, Float32(0.0)), "all-zero (10 blocks, d = 0)", True)
    _ = run_roundtrip(make_list(64, Float32(3.25)), "all-equal 3.25 (every lane is the amax, q = 127)", False)
    _ = run_roundtrip(make_list(64, Float32(-7.5)), "all-equal -7.5", False)
    var payload = quantize_q8_0(make_list(32, Float32(0.0)))
    for i in range(34):
        check(payload[i] == UInt8(0), "zero block: every payload byte must be 0")
    print("PASS: zero block emits 34 zero bytes (d = 0, qs = 0)")


def test_outlier_and_range() raises:
    var outlier = make_list(32, Float32(0.001))
    outlier[0] = Float32(100.0)
    for i in range(1, 32):
        if i % 2 == 0:
            outlier[i] = Float32(-0.001)
    _ = run_roundtrip(outlier, "single outlier 100.0 among 0.001 (small lanes quantize to 0)", False)
    # Dynamic range 1e10 inside one block, capped at amax = 1e4: the
    # engine dequantizers write F16, so a block whose amax exceeds
    # the f16 ceiling (65504) dequantizes to Inf through the engine
    # path even though its payload is ggml-valid (llama.cpp
    # dequantizes to f32). That reader range property is recorded in
    # QC-2-NOTES.md; the quantizer proof stays inside it.
    var wide = make_list(64, Float32(0.0))
    wide[0] = Float32(10000.0)
    wide[1] = Float32(-10000.0)
    wide[2] = Float32(1.0)
    wide[3] = Float32(0.000001)
    wide[4] = Float32(-0.000001)
    wide[32] = Float32(-10000.0)
    wide[33] = Float32(9999.0)
    _ = run_roundtrip(wide, "large dynamic range in-block (1e4 beside 1e-6)", False)
    var state = UInt64(424243)
    var negative = List[Float32]()
    for _ in range(128):
        negative.append(-abs_f32(lcg_signed(state)) * Float32(50.0))
    _ = run_roundtrip(negative, "negative-only random (4 blocks, scale 50)", False)
    var positive = List[Float32]()
    for _ in range(128):
        positive.append(abs_f32(lcg_signed(state)) * Float32(0.03125))
    _ = run_roundtrip(positive, "positive-only random (4 blocks, scale 1/32)", False)


def test_tiny_values() raises:
    # amax = 1e-7: d = 7.9e-10 underflows f16 entirely (d_hat == 0);
    # the block collapses to zero and the error is the values
    # themselves, still inside the proven bound (127*|d_hat - d|).
    var tiny = List[Float32]()
    for i in range(32):
        tiny.append(Float32(0.0000001) * Float32((i % 5) - 2) / Float32(2.0))
    tiny[3] = Float32(0.0000001)
    var payload = quantize_q8_0(tiny)
    check(payload_d_hat(payload, 0) == Float32(0.0), "tiny: d_hat must underflow to exactly 0")
    _ = run_roundtrip(tiny, "tiny values amax = 1e-7 (f16 scale underflows to 0)", False)
    # amax = 1e-4: d lands in the f16 subnormal range.
    var small = List[Float32]()
    var state = UInt64(777001)
    for _ in range(96):
        small.append(lcg_signed(state) * Float32(0.0001))
    small[0] = Float32(0.0001)
    _ = run_roundtrip(small, "small values amax = 1e-4 (f16 subnormal scale)", False)


def test_lattice_exact() raises:
    var ks: List[Int] = [
        -127, -100, -64, -33, -2, -1, 0, 1, 2, 33, 64, 100,
        127, 5, -5, 17, -17, 126, -126, 3, -3, 7, -7, 11,
        -11, 13, -13, 127, -127, 0, 42, -42,
    ]
    var lattice = List[Float32]()
    for k in ks:
        lattice.append(Float32(k) * Float32(0.25))
    for k in ks:
        lattice.append(Float32(k) * Float32(2.0))
    _ = run_roundtrip(lattice, "exact lattice (d = 0.25 and d = 2.0 blocks, incl. +/-127)", True)


def test_random_multiscale() raises:
    var scales: List[Float32] = [
        0.0001, 0.001, 0.01, 0.1, 1.0, 10.0, 100.0, 1000.0, 10000.0,
    ]
    var values = List[Float32]()
    var state = UInt64(20261114)
    for block in range(288):
        var scale = scales[block % len(scales)]
        for _ in range(32):
            values.append(lcg_signed(state) * scale)
        values[block * 32] = scale
    _ = run_roundtrip(values, "random multi-scale (288 blocks, scales 1e-4..1e4)", False)


def expect_quantize_error(values: List[Float32], needle: String, label: String) raises:
    var error_text = String("")
    try:
        var payload = quantize_q8_0(values)
        _ = payload
    except error:
        error_text = String(error)
    if needle not in error_text:
        raise Error(label + ": expected refusal containing '" + needle + "', got: " + error_text)
    print("PASS: quantizer refusal —", label, "->", error_text)


def test_refusals() raises:
    expect_quantize_error(List[Float32](), "must be positive", "empty input")
    expect_quantize_error(make_list(31, Float32(1.0)), "not a multiple of the 32-value Q8_0 block", "31 values (not block-aligned)")
    expect_quantize_error(make_list(33, Float32(1.0)), "not a multiple of the 32-value Q8_0 block", "33 values (not block-aligned)")
    expect_quantize_error(make_list(100, Float32(1.0)), "not a multiple of the 32-value Q8_0 block", "100 values (not block-aligned)")
    var with_nan = make_list(32, Float32(1.0))
    with_nan[7] = bitcast[DType.float32](UInt32(0x7FC00000))
    expect_quantize_error(with_nan, "non-finite value at index 7", "NaN element")
    var with_inf = make_list(32, Float32(1.0))
    with_inf[31] = bitcast[DType.float32](UInt32(0x7F800000))
    expect_quantize_error(with_inf, "non-finite value at index 31", "+Inf element")
    var huge = make_list(32, Float32(0.0))
    huge[0] = Float32(10000000000.0)
    expect_quantize_error(huge, "overflows the f16 range", "amax 1e10 (scale overflows f16)")
    var huge_neg = make_list(32, Float32(0.0))
    huge_neg[5] = Float32(-10000000000.0)
    expect_quantize_error(huge_neg, "overflows the f16 range", "amax -1e10 (scale overflows f16)")
    print("PASS: all quantizer refusals fire with named errors")


def append_u32_le(mut bytes: List[UInt8], value: UInt32):
    for shift in range(4):
        bytes.append(UInt8((value >> UInt32(shift * 8)) & 0xff))


def read_file_bytes(path: String) raises -> List[UInt8]:
    var path_bytes = List[Int8]()
    for byte in path.as_bytes():
        path_bytes.append(Int8(byte))
    path_bytes.append(0)
    var fd = external_call["open64", Int32](path_bytes.unsafe_ptr(), Int32(0), Int32(0))
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


def unlink_path(path: String):
    var bytes = List[Int8]()
    for byte in path.as_bytes():
        bytes.append(Int8(byte))
    bytes.append(0)
    _ = external_call["unlink", Int32](bytes.unsafe_ptr())


def find_kv_u32(path: String, key: String) raises -> UInt32:
    var head = read_gguf_header_copy(path)
    for kv in head.kvs:
        if kv.key == key:
            return kv.value.as_u32()
    raise Error("metadata key not found: " + key)


def test_file_roundtrip() raises:
    var state = UInt64(1357911)
    # quant.weight: 256 x 64 = 16384 elements, per-chunk scale growth.
    var quant_values = List[Float32]()
    for i in range(16384):
        quant_values.append(lcg_signed(state) * Float32(1 + (i // 4096)))
    var quant_payload = quantize_q8_0(quant_values)
    # big.weight: 32768 x 32 = 1,048,576 elements (no index overflow),
    # with a 50.0 spike every 65536 elements.
    var big_values = List[Float32]()
    for _ in range(1048576):
        big_values.append(lcg_signed(state) * Float32(2.0))
    for k in range(1, 16):
        big_values[k * 65536] = Float32(50.0)
    var big_payload = quantize_q8_0(big_values)
    check(len(big_payload) == 32768 * 34, "file: big payload must be 1114112 bytes")
    var desc = GGUFModelDesc()
    desc.add_kv(gguf_kv_string("general.architecture", "llama"))
    desc.add_kv(gguf_kv_string("general.name", "qc2-q8_0-roundtrip"))
    desc.add_kv(gguf_kv_u32("general.alignment", 32))
    desc.add_kv(gguf_kv_u32("general.file_type", 7))
    desc.add_kv(gguf_kv_u32("llama.context_length", 128))
    desc.add_kv(gguf_kv_u32("llama.embedding_length", 256))
    desc.add_kv(gguf_kv_u32("llama.block_count", 1))
    desc.add_kv(gguf_kv_u32("llama.feed_forward_length", 512))
    desc.add_kv(gguf_kv_u32("llama.attention.head_count", 4))
    desc.add_kv(gguf_kv_u32("llama.attention.head_count_kv", 4))
    desc.add_kv(gguf_kv_u32("llama.rope.dimension_count", 8))
    desc.add_kv(gguf_kv_f32("llama.rope.freq_base", Float32(10000.0)))
    desc.add_kv(gguf_kv_f32("llama.attention.layer_norm_rms_epsilon", Float32(0.00001)))
    desc.add_kv(gguf_kv_string("tokenizer.ggml.model", "llama"))
    var tokens = List[String]()
    tokens.append("<unk>")
    tokens.append("<s>")
    tokens.append("</s>")
    desc.add_kv(gguf_kv_string_array("tokenizer.ggml.tokens", tokens))
    var scores = List[Float32]()
    scores.append(Float32(0.0))
    scores.append(Float32(0.0))
    scores.append(Float32(0.0))
    desc.add_kv(gguf_kv_f32_array("tokenizer.ggml.scores", scores))
    var types = List[Int32]()
    types.append(Int32(1))
    types.append(Int32(1))
    types.append(Int32(1))
    desc.add_kv(gguf_kv_i32_array("tokenizer.ggml.token_type", types))
    desc.add_kv(gguf_kv_u32("tokenizer.ggml.unknown_token_id", 0))
    desc.add_kv(gguf_kv_u32("tokenizer.ggml.bos_token_id", 1))
    desc.add_kv(gguf_kv_u32("tokenizer.ggml.eos_token_id", 2))
    desc.add_kv(gguf_kv_bool("tokenizer.ggml.add_bos_token", True))
    var norm_payload = List[UInt8]()
    for i in range(32):
        append_u32_le(norm_payload, bitcast[DType.uint32](Float32(i - 16) * Float32(0.25)))
    var norm_dims = List[UInt64]()
    norm_dims.append(UInt64(32))
    desc.add_tensor(GGUFWriterTensor("norm.weight", norm_dims, UInt32(0), norm_payload))
    var quant_dims = List[UInt64]()
    quant_dims.append(UInt64(256))
    quant_dims.append(UInt64(64))
    desc.add_tensor(GGUFWriterTensor("quant.weight", quant_dims, UInt32(8), quant_payload))
    var big_dims = List[UInt64]()
    big_dims.append(UInt64(32768))
    big_dims.append(UInt64(32))
    desc.add_tensor(GGUFWriterTensor("big.weight", big_dims, UInt32(8), big_payload))
    var path = String("/tmp/aesir-qc2-roundtrip.gguf")
    var written = write_gguf_file(path, desc)
    var file_bytes = read_file_bytes(path)
    check(len(file_bytes) == written, "file: readback length differs from written size")
    check(
        find_kv_u32(path, "general.file_type") == UInt32(7),
        "file: general.file_type must be 7 for Q8_0",
    )
    print("PASS: whole-file emission carries general.file_type = 7 (Q8_0)")
    var head = read_gguf_header_copy(path)
    check(len(head.directory) == 3, "file: directory must hold 3 tensors")
    # Byte-identity net (QC-1 harness style): the emitted payload
    # bytes are the quantizer's payload bytes, exactly.
    for entry_index in range(3):
        ref entry = head.directory[entry_index]
        ref tensor = desc.tensors[entry_index]
        check(entry.relative_offset % 32 == 0, "file: tensor offset not 32-aligned")
        check(entry.byte_size == len(tensor.payload), "file: byte size mismatch")
        for j in range(entry.byte_size):
            check(
                file_bytes[head.data_offset + entry.relative_offset + j] == tensor.payload[j],
                "file: payload byte mismatch, tensor " + entry.name + " byte " + String(j),
            )
    print("PASS: emitted file payload bytes == quantizer payload bytes exactly (incl. 1114112-byte big tensor)")
    # GGUFSeer maps the tensors; the load then stops ONLY at
    # required-tensor validation (the synthetic baseline pattern).
    var seer = GGUFSeer(path)
    var tokenizer = RuneWeaver()
    var pool = MimirWell(65536)
    var error_text = String("")
    try:
        seer.mmap_and_load(pool, tokenizer)
    except error:
        error_text = String(error)
    check(
        "GGUF is missing required tensor:" in error_text,
        "file: GGUFSeer load did not reach required-tensor validation: " + error_text,
    )
    check(seer.tensor_types["quant.weight"] == UInt32(8), "file: seer type mismatch for quant.weight")
    check(seer.tensor_types["big.weight"] == UInt32(8), "file: seer type mismatch for big.weight")
    ref quant_tensor = seer.tensors["quant.weight"]
    check(quant_tensor.rows == 64 and quant_tensor.cols == 256, "file: quant.weight shape must map as 64x256")
    ref big_tensor = seer.tensors["big.weight"]
    check(big_tensor.rows == 32 and big_tensor.cols == 32768, "file: big.weight shape must map as 32x32768")
    print("PASS: GGUFSeer maps both Q8_0 tensors at the written offsets/types/shapes")
    # Dequantize through the engine path from the file image at the
    # offsets GGUFSeer itself parsed. The seer's tensor data
    # pointers must NOT be dereferenced here: mmap_and_load's except
    # path runs _cleanup(), which munmaps the file before re-raising
    # (loader/gguf.mojo) -- after a failed load the mapped pointers
    # dangle by design, and the first version of this test segfaulted
    # proving it. The mmap region is the file bytes, so the file
    # image at the seer-parsed offsets is the same bytes the engine
    # path would read on a fully validated load (whose production
    # dequant-from-tensor.data use passes its own suites).
    var quant_offset = seer.tensor_file_offsets["quant.weight"]
    var big_offset = seer.tensor_file_offsets["big.weight"]
    check(quant_offset == head.data_offset + head.directory[1].relative_offset, "file: seer offset != copy offset for quant.weight")
    check(big_offset == head.data_offset + head.directory[2].relative_offset, "file: seer offset != copy offset for big.weight")
    var well = MimirWell(3400000)
    var src_quant = well.allocate(17408 // 2 + 1)
    var src_quant_bytes = src_quant.unsafe_bitcast[UInt8]()
    for j in range(17408):
        src_quant_bytes.unsafe_store(j, file_bytes[quant_offset + j])
    var dst_quant = well.allocate(16384)
    dequantize_q8_0_block(src_quant_bytes, dst_quant, 512)
    _ = check_dequant(dst_quant, quant_values, quant_payload, "file round-trip quant.weight via GGUFSeer offsets + engine dequant", False)
    var src_big = well.allocate(1114112 // 2 + 1)
    var src_big_bytes = src_big.unsafe_bitcast[UInt8]()
    for j in range(1114112):
        src_big_bytes.unsafe_store(j, file_bytes[big_offset + j])
    var dst_big = well.allocate(1048576)
    dequantize_q8_0_block(src_big_bytes, dst_big, 32768)
    _ = check_dequant(dst_big, big_values, big_payload, "file round-trip big.weight (1048576 elements) via GGUFSeer offsets + engine dequant", False)
    # PackedGGUF constructs in full.
    var packed = PackedGGUF(path)
    check(len(packed.tensors) == 3, "file: packed tensor count mismatch")
    check(packed.tensors["quant.weight"].kind == 8, "file: packed kind mismatch for quant.weight")
    check(packed.tensors["quant.weight"].byte_count == 17408, "file: packed byte_count mismatch for quant.weight")
    check(packed.tensors["big.weight"].kind == 8, "file: packed kind mismatch for big.weight")
    check(packed.tensors["big.weight"].byte_count == 1114112, "file: packed byte_count mismatch for big.weight")
    print("PASS: PackedGGUF loads the emitted file in full (kinds/byte counts agree)")
    unlink_path(path)


def main() raises:
    test_layout_and_ties()
    test_zero_and_equal()
    test_outlier_and_range()
    test_tiny_values()
    test_lattice_exact()
    test_random_multiscale()
    test_refusals()
    test_file_roundtrip()
    print("QC-2 Q8_0 quantizer proof: ALL PASS")
