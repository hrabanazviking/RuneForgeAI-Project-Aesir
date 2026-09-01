"""Measured host quantized-GEMM selection with bounded in-memory caching.

This module owns selection policy and measurements. Format-specific math stays
in ``core.compute``; device discovery stays in the hardware gateways; callers
own all scratch memory. A tuning miss runs two real execution strategies,
requires their outputs to agree, measures both with CLOCK_MONOTONIC, and only
then publishes a result to the caller and cache.
"""

from std.collections import InlineArray
from std.ffi import external_call
from std.math import isinf, isnan
from std.memory import Pointer

from .mimir_well import CompressedFormatType, RuneTensor, f16
from .compute import dequantize_compressed_tensor, gemm_f16


struct QuantizationStorageKind:
    comptime INLINE_FIXED = 0
    comptime EXTERNAL_METADATA = 1


struct QuantizedGEMMStrategy:
    comptime FUSED_RAW = 0
    comptime DEQUANTIZE_F16 = 1


comptime TUNING_CACHE_HEADER = "AESIR_QGEMM_TUNING_CACHE_V1"
comptime MAX_TUNING_CACHE_BYTES = 1024 * 1024


struct QuantizationFormatInfo(Copyable):
    """Exact fixed-block facts or an explicit external-metadata boundary."""

    var format_name: String
    var block_weights: Int
    var block_bytes: Int
    var nominal_bits_per_weight: Float32
    var storage_kind: Int
    var raw_host_tunable: Bool
    var is_extreme: Bool

    def __init__(
        out self,
        format_name: String,
        block_weights: Int,
        block_bytes: Int,
        nominal_bits_per_weight: Float32,
        storage_kind: Int,
        raw_host_tunable: Bool,
        is_extreme: Bool = False,
    ):
        self.format_name = format_name
        self.block_weights = block_weights
        self.block_bytes = block_bytes
        self.nominal_bits_per_weight = nominal_bits_per_weight
        self.storage_kind = storage_kind
        self.raw_host_tunable = raw_host_tunable
        self.is_extreme = is_extreme

    def __copyinit__(out self, existing: Self):
        self.format_name = existing.format_name
        self.block_weights = existing.block_weights
        self.block_bytes = existing.block_bytes
        self.nominal_bits_per_weight = existing.nominal_bits_per_weight
        self.storage_kind = existing.storage_kind
        self.raw_host_tunable = existing.raw_host_tunable
        self.is_extreme = existing.is_extreme

    def exact_bits_per_weight(self) raises -> Float32:
        if self.storage_kind != QuantizationStorageKind.INLINE_FIXED:
            raise Error("format storage rate depends on external metadata")
        if self.block_weights <= 0 or self.block_bytes <= 0:
            raise Error("fixed quantization metadata is invalid")
        return Float32(self.block_bytes * 8) / Float32(self.block_weights)


def _fixed_format(
    name: String,
    block_weights: Int,
    block_bytes: Int,
    is_extreme: Bool = False,
) -> QuantizationFormatInfo:
    return QuantizationFormatInfo(
        name,
        block_weights,
        block_bytes,
        Float32(block_bytes * 8) / Float32(block_weights),
        QuantizationStorageKind.INLINE_FIXED,
        True,
        is_extreme,
    )


def _external_format(
    name: String, nominal_bits: Float32
) -> QuantizationFormatInfo:
    return QuantizationFormatInfo(
        name,
        0,
        0,
        nominal_bits,
        QuantizationStorageKind.EXTERNAL_METADATA,
        False,
    )


def get_quantization_format_info(
    format: CompressedFormatType,
) raises -> QuantizationFormatInfo:
    """Return truthful format metadata; unknown values never fall back."""
    var value = format.value
    if value == CompressedFormatType.Q2_K:
        return _fixed_format("Q2_K", 256, 84)
    if (
        value == CompressedFormatType.Q3_K_S
        or value == CompressedFormatType.Q3_K_M
        or value == CompressedFormatType.Q3_K_L
    ):
        return _fixed_format(format.name(), 256, 110)
    if value == CompressedFormatType.Q4_0:
        return _fixed_format("Q4_0", 32, 18)
    if value == CompressedFormatType.Q4_1:
        return _fixed_format("Q4_1", 32, 20)
    if (
        value == CompressedFormatType.Q4_K_S
        or value == CompressedFormatType.Q4_K_M
    ):
        return _fixed_format(format.name(), 256, 144)
    if value == CompressedFormatType.Q5_0:
        return _fixed_format("Q5_0", 32, 22)
    if value == CompressedFormatType.Q5_1:
        return _fixed_format("Q5_1", 32, 24)
    if (
        value == CompressedFormatType.Q5_K_S
        or value == CompressedFormatType.Q5_K_M
    ):
        return _fixed_format(format.name(), 256, 176)
    if value == CompressedFormatType.Q6_K:
        return _fixed_format("Q6_K", 256, 210)
    if value == CompressedFormatType.Q8_0:
        return _fixed_format("Q8_0", 32, 34)
    if value == CompressedFormatType.Q8_1:
        return _fixed_format("Q8_1", 32, 40)
    if value == CompressedFormatType.FP8_E4M3:
        return _fixed_format("FP8_E4M3", 1, 1)
    if value == CompressedFormatType.FP8_E5M2:
        return _fixed_format("FP8_E5M2", 1, 1)
    if value == CompressedFormatType.IQ1_S:
        return _fixed_format("IQ1_S", 256, 50, True)
    if value == CompressedFormatType.IQ2_XXS:
        return _fixed_format("IQ2_XXS", 256, 66, True)
    if value == CompressedFormatType.TQ1_0:
        return _fixed_format("TQ1_0", 256, 54, True)
    if value == CompressedFormatType.GPTQ_4BIT:
        return _external_format("GPTQ_4BIT", 4.0)
    if value == CompressedFormatType.GPTQ_8BIT:
        return _external_format("GPTQ_8BIT", 8.0)
    if value == CompressedFormatType.AWQ_4BIT:
        return _external_format("AWQ_4BIT", 4.0)
    if value == CompressedFormatType.EXL2_VARBIT:
        return _external_format("EXL2_VARBIT", 0.0)
    if value == CompressedFormatType.HQQ:
        return _external_format("HQQ", 4.0)
    if value == CompressedFormatType.SMOOTHQUANT_INT8:
        return _external_format("SMOOTHQUANT_INT8", 8.0)
    raise Error(
        "get_quantization_format_info: unknown compressed format "
        + String(value)
    )


def monotonic_nanoseconds() raises -> Int:
    var timestamp = InlineArray[Int64, 2](fill=0)
    if (
        external_call["clock_gettime", Int32](
            Int32(1), timestamp.unsafe_ptr()
        )
        != 0
    ):
        raise Error("quantization autotuner cannot observe monotonic clock")
    if (
        timestamp[0] < 0
        or timestamp[0] > 9223372036
        or timestamp[1] < 0
        or timestamp[1] >= 1000000000
    ):
        raise Error("quantization autotuner observed invalid monotonic time")
    var whole = Int(timestamp[0]) * 1000000000
    var fraction = Int(timestamp[1])
    if whole > 9223372036854775807 - fraction:
        raise Error("quantization autotuner monotonic time overflow")
    return whole + fraction


def _validate_cache_identity(value: String, label: String) raises:
    var source = value.as_bytes()
    if len(source) <= 0 or len(source) > 128:
        raise Error("quantization autotuner " + label + " must be 1..128 bytes")
    for index in range(len(source)):
        if source[index] < 32 or source[index] > 126:
            raise Error(
                "quantization autotuner " + label + " must be printable ASCII"
            )


def _cache_hex_encode(value: String) -> String:
    var digits = String("0123456789abcdef")
    var result = String("")
    var source = value.as_bytes()
    for index in range(len(source)):
        var code = Int(source[index])
        result += String(digits[byte=code >> 4 : (code >> 4) + 1])
        result += String(digits[byte=code & 15 : (code & 15) + 1])
    return result


def _cache_hex_nibble(code: Int) raises -> Int:
    if code >= 48 and code <= 57:
        return code - 48
    if code >= 97 and code <= 102:
        return code - 87
    raise Error("quantization tuning cache contains invalid lowercase hex")


def _cache_hex_decode(value: String) raises -> String:
    var source = value.as_bytes()
    if len(source) == 0 or len(source) > 256 or len(source) % 2 != 0:
        raise Error("quantization tuning cache identity hex length is invalid")
    var decoded = List[Int8]()
    for index in range(0, len(source), 2):
        var high = _cache_hex_nibble(Int(source[index]))
        var low = _cache_hex_nibble(Int(source[index + 1]))
        decoded.append(Int8((high << 4) | low))
    decoded.append(0)
    return String(unsafe_from_utf8_ptr=decoded.unsafe_ptr())


def _parse_cache_int(value: String, label: String, maximum: Int) raises -> Int:
    var source = value.as_bytes()
    if len(source) == 0 or len(source) > 20:
        raise Error("quantization tuning cache " + label + " length is invalid")
    for index in range(len(source)):
        if source[index] < 48 or source[index] > 57:
            raise Error("quantization tuning cache " + label + " must be decimal")
    var parsed: Int
    try:
        parsed = atol(value)
    except:
        raise Error("quantization tuning cache " + label + " is out of range")
    if parsed < 0 or parsed > maximum:
        raise Error("quantization tuning cache " + label + " exceeds its limit")
    return parsed


def _cache_checksum(body: String) -> String:
    var hash: UInt64 = 14695981039346656037
    var source = body.as_bytes()
    for index in range(len(source)):
        hash = (hash ^ UInt64(source[index])) * 1099511628211
    var digits = String("0123456789abcdef")
    var result = String("")
    for shift in range(60, -4, -4):
        var nibble = Int((hash >> UInt64(shift)) & 15)
        result += String(digits[byte=nibble : nibble + 1])
    return result


struct QuantizedGEMMTuneResult(Copyable):
    var strategy: Int
    var fused_total_ns: Int
    var dequantized_total_ns: Int
    var iterations: Int
    var cache_hit: Bool

    def __init__(
        out self,
        strategy: Int,
        fused_total_ns: Int,
        dequantized_total_ns: Int,
        iterations: Int,
        cache_hit: Bool,
    ):
        self.strategy = strategy
        self.fused_total_ns = fused_total_ns
        self.dequantized_total_ns = dequantized_total_ns
        self.iterations = iterations
        self.cache_hit = cache_hit

    def __copyinit__(out self, existing: Self):
        self.strategy = existing.strategy
        self.fused_total_ns = existing.fused_total_ns
        self.dequantized_total_ns = existing.dequantized_total_ns
        self.iterations = existing.iterations
        self.cache_hit = existing.cache_hit


struct _TuneCacheEntry(Copyable):
    var device_key: String
    var format_value: Int
    var rows: Int
    var outputs: Int
    var shared: Int
    var strategy: Int
    var fused_total_ns: Int
    var dequantized_total_ns: Int
    var iterations: Int

    def __init__(
        out self,
        device_key: String,
        format_value: Int,
        rows: Int,
        outputs: Int,
        shared: Int,
        result: QuantizedGEMMTuneResult,
    ):
        self.device_key = device_key
        self.format_value = format_value
        self.rows = rows
        self.outputs = outputs
        self.shared = shared
        self.strategy = result.strategy
        self.fused_total_ns = result.fused_total_ns
        self.dequantized_total_ns = result.dequantized_total_ns
        self.iterations = result.iterations

    def __copyinit__(out self, existing: Self):
        self.device_key = existing.device_key
        self.format_value = existing.format_value
        self.rows = existing.rows
        self.outputs = existing.outputs
        self.shared = existing.shared
        self.strategy = existing.strategy
        self.fused_total_ns = existing.fused_total_ns
        self.dequantized_total_ns = existing.dequantized_total_ns
        self.iterations = existing.iterations

    def matches(
        self,
        device_key: String,
        format_value: Int,
        rows: Int,
        outputs: Int,
        shared: Int,
    ) -> Bool:
        return (
            self.device_key == device_key
            and self.format_value == format_value
            and self.rows == rows
            and self.outputs == outputs
            and self.shared == shared
        )


def _run_fused(
    A: RuneTensor[f16], B: RuneTensor[f16], mut output: RuneTensor[f16]
) raises:
    gemm_f16(A, B, output)


def _run_dequantized(
    A: RuneTensor[f16],
    B: RuneTensor[f16],
    dequantized_weights: Pointer[Scalar[f16], MutUntrackedOrigin],
    mut output: RuneTensor[f16],
) raises:
    dequantize_compressed_tensor(
        B.quant_format,
        B.data.unsafe_bitcast[UInt8](),
        dequantized_weights,
        B.rows * B.cols,
    )
    var dense_weights = RuneTensor[f16](
        B.rows, B.cols, dequantized_weights, False
    )
    gemm_f16(A, dense_weights, output)


def _validate_candidate_outputs(
    fused: Pointer[Scalar[f16], MutUntrackedOrigin],
    dequantized: Pointer[Scalar[f16], MutUntrackedOrigin],
    elements: Int,
    tolerance: Float32,
) raises:
    for index in range(elements):
        var left = fused.unsafe_load(index).cast[DType.float32]()
        var right = dequantized.unsafe_load(index).cast[DType.float32]()
        if isnan(left) or isinf(left) or isnan(right) or isinf(right):
            raise Error("quantization autotuner candidate produced non-finite output")
        var difference = left - right
        if difference < 0.0:
            difference = -difference
        if difference > tolerance:
            raise Error(
                "quantization autotuner candidate correctness mismatch at output "
                + String(index)
            )


def _copy_output(
    source: Pointer[Scalar[f16], MutUntrackedOrigin],
    destination: Pointer[Scalar[f16], MutUntrackedOrigin],
    elements: Int,
):
    for index in range(elements):
        destination.unsafe_store(index, source.unsafe_load(index))


def _checked_product(left: Int, right: Int, label: String) raises -> Int:
    if left <= 0 or right <= 0:
        raise Error("quantization autotuner " + label + " must be positive")
    if left > 9223372036854775807 // right:
        raise Error("quantization autotuner " + label + " overflow")
    return left * right


def _ranges_overlap(
    left_start: Int,
    left_bytes: Int,
    right_start: Int,
    right_bytes: Int,
) raises -> Bool:
    if left_start <= 1 or right_start <= 1 or left_bytes <= 0 or right_bytes <= 0:
        raise Error("quantization autotuner observed an invalid memory range")
    if (
        left_start > 9223372036854775807 - left_bytes
        or right_start > 9223372036854775807 - right_bytes
    ):
        raise Error("quantization autotuner memory range overflow")
    return (
        left_start < right_start + right_bytes
        and right_start < left_start + left_bytes
    )


struct QuantizedGEMMAutotuner:
    """Bounded exact-shape cache for measured host execution strategies."""

    var max_entries: Int
    var entries: List[_TuneCacheEntry]
    var cache_hits: Int
    var cache_misses: Int

    def __init__(out self, max_entries: Int = 64) raises:
        if max_entries <= 0 or max_entries > 4096:
            raise Error("quantization autotuner cache capacity must be 1..4096")
        self.max_entries = max_entries
        self.entries = List[_TuneCacheEntry]()
        self.cache_hits = 0
        self.cache_misses = 0

    def cache_size(self) -> Int:
        return len(self.entries)

    def clear(mut self):
        self.entries.clear()
        self.cache_hits = 0
        self.cache_misses = 0

    def serialize_cache(self, build_fingerprint: String) raises -> String:
        """Return a bounded, checksummed v1 cache for caller-owned persistence."""
        _validate_cache_identity(build_fingerprint, "build fingerprint")
        if len(self.entries) > self.max_entries:
            raise Error("quantization tuning cache exceeds configured capacity")
        var lines = List[String]()
        lines.append(TUNING_CACHE_HEADER)
        lines.append("BUILD:" + _cache_hex_encode(build_fingerprint))
        lines.append("COUNT:" + String(len(self.entries)))
        for index in range(len(self.entries)):
            var entry = self.entries[index].copy()
            _validate_cache_identity(entry.device_key, "device key")
            lines.append(
                "ENTRY:"
                + _cache_hex_encode(entry.device_key)
                + ":"
                + String(entry.format_value)
                + ":"
                + String(entry.rows)
                + ":"
                + String(entry.outputs)
                + ":"
                + String(entry.shared)
                + ":"
                + String(entry.strategy)
                + ":"
                + String(entry.fused_total_ns)
                + ":"
                + String(entry.dequantized_total_ns)
                + ":"
                + String(entry.iterations)
            )
        var body = String("\n").join(lines)
        var encoded = body + "\nCHECKSUM:" + _cache_checksum(body)
        if encoded.byte_length() > MAX_TUNING_CACHE_BYTES:
            raise Error("serialized quantization tuning cache exceeds 1 MiB")
        return encoded

    def restore_cache(
        mut self, raw: String, expected_build_fingerprint: String
    ) raises:
        """Transactionally restore a v1 cache or leave current entries unchanged."""
        _validate_cache_identity(
            expected_build_fingerprint, "build fingerprint"
        )
        if raw.byte_length() == 0 or raw.byte_length() > MAX_TUNING_CACHE_BYTES:
            raise Error("quantization tuning cache size is invalid")
        var lines = raw.split("\n")
        if len(lines) < 4 or String(lines[0]) != TUNING_CACHE_HEADER:
            raise Error("unsupported or missing quantization tuning cache version")
        var build_line = String(lines[1])
        if not build_line.startswith("BUILD:"):
            raise Error("quantization tuning cache is missing build identity")
        var build_fingerprint = _cache_hex_decode(
            String(build_line[byte=6:])
        )
        _validate_cache_identity(build_fingerprint, "build fingerprint")
        if build_fingerprint != expected_build_fingerprint:
            raise Error("quantization tuning cache build fingerprint mismatch")
        var count_line = String(lines[2])
        if not count_line.startswith("COUNT:"):
            raise Error("quantization tuning cache is missing entry count")
        var count = _parse_cache_int(
            String(count_line[byte=6:]), "entry count", self.max_entries
        )
        if len(lines) != count + 4:
            raise Error("quantization tuning cache entry count mismatch")
        var checksum_line = String(lines[len(lines) - 1])
        if not checksum_line.startswith("CHECKSUM:"):
            raise Error("quantization tuning cache is missing checksum")
        var body_lines = List[String]()
        for index in range(len(lines) - 1):
            body_lines.append(String(lines[index]))
        var body = String("\n").join(body_lines)
        if String(checksum_line[byte=9:]) != _cache_checksum(body):
            raise Error("quantization tuning cache checksum mismatch")

        var candidate = List[_TuneCacheEntry]()
        for index in range(count):
            var fields = String(lines[index + 3]).split(":")
            if len(fields) != 10 or String(fields[0]) != "ENTRY":
                raise Error("quantization tuning cache entry is malformed")
            var device_key = _cache_hex_decode(String(fields[1]))
            _validate_cache_identity(device_key, "device key")
            var format_value = _parse_cache_int(
                String(fields[2]), "format", 25
            )
            var rows = _parse_cache_int(String(fields[3]), "rows", 1000000000)
            var outputs = _parse_cache_int(
                String(fields[4]), "outputs", 1000000000
            )
            var shared = _parse_cache_int(
                String(fields[5]), "shared", 1000000000
            )
            var strategy = _parse_cache_int(String(fields[6]), "strategy", 1)
            var fused_ns = _parse_cache_int(
                String(fields[7]), "fused duration", 9223372036854775807
            )
            var dequantized_ns = _parse_cache_int(
                String(fields[8]),
                "dequantized duration",
                9223372036854775807,
            )
            var iterations = _parse_cache_int(
                String(fields[9]), "iterations", 10000
            )
            if (
                rows <= 0
                or outputs <= 0
                or shared <= 0
                or fused_ns <= 0
                or dequantized_ns <= 0
                or iterations <= 0
            ):
                raise Error("quantization tuning cache entry contains zero values")
            var info = get_quantization_format_info(
                CompressedFormatType(format_value)
            )
            if not info.raw_host_tunable or shared % info.block_weights != 0:
                raise Error("quantization tuning cache entry format is not tunable")
            for existing_index in range(len(candidate)):
                if candidate[existing_index].matches(
                    device_key, format_value, rows, outputs, shared
                ):
                    raise Error("quantization tuning cache contains duplicate key")
            var result = QuantizedGEMMTuneResult(
                strategy,
                fused_ns,
                dequantized_ns,
                iterations,
                False,
            )
            candidate.append(
                _TuneCacheEntry(
                    device_key,
                    format_value,
                    rows,
                    outputs,
                    shared,
                    result,
                )
            )
        self.entries = candidate^
        self.cache_hits = 0
        self.cache_misses = 0

    def tune_and_execute(
        mut self,
        device_key: String,
        A: RuneTensor[f16],
        B: RuneTensor[f16],
        mut C: RuneTensor[f16],
        dequantized_weights: Pointer[Scalar[f16], MutUntrackedOrigin],
        dequantized_weight_elements: Int,
        fused_output: Pointer[Scalar[f16], MutUntrackedOrigin],
        dequantized_output: Pointer[Scalar[f16], MutUntrackedOrigin],
        scratch_output_elements: Int,
        warmup_iterations: Int = 1,
        measured_iterations: Int = 3,
        tolerance: Float32 = 0.0,
    ) raises -> QuantizedGEMMTuneResult:
        _validate_cache_identity(device_key, "device key")
        if A.rows <= 0 or A.cols <= 0 or B.rows <= 0 or B.cols <= 0:
            raise Error("quantization autotuner dimensions must be positive")
        if A.cols != B.cols or C.rows != A.rows or C.cols != B.rows:
            raise Error("quantization autotuner matrix shape mismatch")
        if not B.is_quantized:
            raise Error("quantization autotuner requires quantized weights")
        if warmup_iterations < 0 or warmup_iterations > 100:
            raise Error("quantization autotuner warmups must be 0..100")
        if measured_iterations <= 0 or measured_iterations > 10000:
            raise Error("quantization autotuner measurements must be 1..10000")
        if tolerance < 0.0:
            raise Error("quantization autotuner tolerance must not be negative")
        var input_elements = _checked_product(A.rows, A.cols, "input size")
        var weight_elements = _checked_product(B.rows, B.cols, "weight size")
        var output_elements = _checked_product(A.rows, B.rows, "output size")
        if dequantized_weight_elements != weight_elements:
            raise Error("quantization autotuner weight scratch length mismatch")
        if scratch_output_elements != output_elements:
            raise Error("quantization autotuner output scratch length mismatch")
        if (
            Int(A.data) <= 1
            or Int(B.data) <= 1
            or Int(dequantized_weights) <= 1
            or Int(fused_output) <= 1
            or Int(dequantized_output) <= 1
            or Int(C.data) <= 1
        ):
            raise Error("quantization autotuner scratch pointers must be valid")
        if (
            Int(fused_output) == Int(dequantized_output)
            or Int(C.data) == Int(fused_output)
            or Int(C.data) == Int(dequantized_output)
        ):
            raise Error("quantization autotuner output buffers must be distinct")

        var info = get_quantization_format_info(B.quant_format)
        if not info.raw_host_tunable:
            raise Error(
                "quantization autotuner requires the format's metadata-bearing API: "
                + info.format_name
            )
        if B.cols % info.block_weights != 0:
            raise Error("quantization autotuner requires complete format blocks")
        var packed_row_bytes = _checked_product(
            B.cols // info.block_weights,
            info.block_bytes,
            "packed row size",
        )
        var packed_bytes = _checked_product(
            B.rows, packed_row_bytes, "packed weight size"
        )
        var input_bytes = _checked_product(input_elements, 2, "input bytes")
        var dense_weight_bytes = _checked_product(
            weight_elements, 2, "weight scratch bytes"
        )
        var output_bytes = _checked_product(
            output_elements, 2, "output bytes"
        )
        var a_address = Int(A.data)
        var b_address = Int(B.data)
        var c_address = Int(C.data)
        var weight_address = Int(dequantized_weights)
        var fused_address = Int(fused_output)
        var dequantized_address = Int(dequantized_output)
        if (
            _ranges_overlap(a_address, input_bytes, b_address, packed_bytes)
            or _ranges_overlap(a_address, input_bytes, c_address, output_bytes)
            or _ranges_overlap(a_address, input_bytes, weight_address, dense_weight_bytes)
            or _ranges_overlap(a_address, input_bytes, fused_address, output_bytes)
            or _ranges_overlap(a_address, input_bytes, dequantized_address, output_bytes)
            or _ranges_overlap(b_address, packed_bytes, c_address, output_bytes)
            or _ranges_overlap(b_address, packed_bytes, weight_address, dense_weight_bytes)
            or _ranges_overlap(b_address, packed_bytes, fused_address, output_bytes)
            or _ranges_overlap(b_address, packed_bytes, dequantized_address, output_bytes)
            or _ranges_overlap(c_address, output_bytes, weight_address, dense_weight_bytes)
            or _ranges_overlap(c_address, output_bytes, fused_address, output_bytes)
            or _ranges_overlap(c_address, output_bytes, dequantized_address, output_bytes)
            or _ranges_overlap(weight_address, dense_weight_bytes, fused_address, output_bytes)
            or _ranges_overlap(weight_address, dense_weight_bytes, dequantized_address, output_bytes)
            or _ranges_overlap(fused_address, output_bytes, dequantized_address, output_bytes)
        ):
            raise Error("quantization autotuner buffers must not overlap")

        var fused_tensor = RuneTensor[f16](
            A.rows, B.rows, fused_output, False
        )
        var dequantized_tensor = RuneTensor[f16](
            A.rows, B.rows, dequantized_output, False
        )
        for index in range(len(self.entries)):
            if self.entries[index].matches(
                device_key,
                B.quant_format.value,
                A.rows,
                B.rows,
                A.cols,
            ):
                var entry = self.entries[index].copy()
                if entry.strategy == QuantizedGEMMStrategy.FUSED_RAW:
                    _run_fused(A, B, fused_tensor)
                    _copy_output(fused_output, C.data, output_elements)
                elif entry.strategy == QuantizedGEMMStrategy.DEQUANTIZE_F16:
                    _run_dequantized(
                        A, B, dequantized_weights, dequantized_tensor
                    )
                    _copy_output(dequantized_output, C.data, output_elements)
                else:
                    raise Error("quantization autotuner cache strategy is invalid")
                self.cache_hits += 1
                return QuantizedGEMMTuneResult(
                    entry.strategy,
                    entry.fused_total_ns,
                    entry.dequantized_total_ns,
                    entry.iterations,
                    True,
                )

        for _ in range(warmup_iterations):
            _run_fused(A, B, fused_tensor)
            _run_dequantized(A, B, dequantized_weights, dequantized_tensor)
        _validate_candidate_outputs(
            fused_output,
            dequantized_output,
            output_elements,
            tolerance,
        )

        var start = monotonic_nanoseconds()
        for _ in range(measured_iterations):
            _run_fused(A, B, fused_tensor)
        var fused_elapsed = monotonic_nanoseconds() - start
        start = monotonic_nanoseconds()
        for _ in range(measured_iterations):
            _run_dequantized(A, B, dequantized_weights, dequantized_tensor)
        var dequantized_elapsed = monotonic_nanoseconds() - start
        if fused_elapsed <= 0 or dequantized_elapsed <= 0:
            raise Error("quantization autotuner clock resolution was insufficient")
        _validate_candidate_outputs(
            fused_output,
            dequantized_output,
            output_elements,
            tolerance,
        )

        var strategy = QuantizedGEMMStrategy.FUSED_RAW
        if dequantized_elapsed < fused_elapsed:
            strategy = QuantizedGEMMStrategy.DEQUANTIZE_F16
        var result = QuantizedGEMMTuneResult(
            strategy,
            fused_elapsed,
            dequantized_elapsed,
            measured_iterations,
            False,
        )
        if len(self.entries) >= self.max_entries:
            _ = self.entries.pop(0)
        self.entries.append(
            _TuneCacheEntry(
                device_key,
                B.quant_format.value,
                A.rows,
                B.rows,
                A.cols,
                result,
            )
        )
        self.cache_misses += 1
        if strategy == QuantizedGEMMStrategy.FUSED_RAW:
            _copy_output(fused_output, C.data, output_elements)
        else:
            _copy_output(dequantized_output, C.data, output_elements)
        return result^
