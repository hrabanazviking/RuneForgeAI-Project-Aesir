"""Real measurements, correctness gates, and cache behavior for host tuning."""

from core.mimir_well import MimirWell, RuneTensor, CompressedFormatType, f16
from core.compute import gemm_f16
from core.quantization_autotuner import (
    QuantizationStorageKind,
    QuantizedGEMMStrategy,
    QuantizedGEMMAutotuner,
    get_quantization_format_info,
)


def test_quantization_format_metadata() raises:
    for value in range(26):
        var info = get_quantization_format_info(CompressedFormatType(value))
        if info.format_name == "UNKNOWN":
            raise Error("known quantization format was not described")
        if info.storage_kind == QuantizationStorageKind.INLINE_FIXED:
            if info.block_weights <= 0 or info.block_bytes <= 0:
                raise Error("fixed quantization format lacks exact block metadata")
            if info.exact_bits_per_weight() <= 0.0:
                raise Error("fixed quantization format has invalid storage rate")
        elif info.storage_kind == QuantizationStorageKind.EXTERNAL_METADATA:
            if info.block_weights != 0 or info.block_bytes != 0:
                raise Error("external-metadata format fabricated a fixed block")
        else:
            raise Error("quantization storage kind is invalid")

    if (
        get_quantization_format_info(
            CompressedFormatType(CompressedFormatType.Q4_K_M)
        ).exact_bits_per_weight()
        != Float32(4.5)
    ):
        raise Error("Q4_K exact storage rate mismatch")
    if (
        get_quantization_format_info(
            CompressedFormatType(CompressedFormatType.TQ1_0)
        ).exact_bits_per_weight()
        != Float32(1.6875)
    ):
        raise Error("TQ1_0 exact storage rate mismatch")
    var rejected = False
    try:
        _ = get_quantization_format_info(CompressedFormatType(999))
    except:
        rejected = True
    if not rejected:
        raise Error("unknown quantization metadata silently fell back")
    print("truthful all-format quantization metadata: PASS")


def test_measured_quantized_gemm_autotuner() raises:
    var well = MimirWell(4 * 1024 * 1024)
    var rows = 4
    var shared = 256
    var outputs = 4
    var input_ptr = well.allocate(rows * shared)
    for index in range(rows * shared):
        input_ptr.unsafe_store(index, Float16((index % 13) - 6) / Float16(8))
    var A = RuneTensor[f16](rows, shared, input_ptr, False)

    var block_count = outputs * (shared // 32)
    var packed = well.allocate(block_count * 18).unsafe_bitcast[UInt8]()
    for index in range(block_count * 18):
        packed.unsafe_store(index, UInt8(0))
    for block in range(block_count):
        packed.unsafe_offset(block * 18).unsafe_bitcast[Float16]().unsafe_store(
            Float16(0.25)
        )
        for lane in range(16):
            packed.unsafe_store(
                block * 18 + 2 + lane,
                UInt8((block * 17 + lane * 29 + 3) % 256),
            )
    var B = RuneTensor[f16](
        outputs,
        shared,
        packed.unsafe_bitcast[Float16](),
        True,
        CompressedFormatType(CompressedFormatType.Q4_0),
    )
    var output_elements = rows * outputs
    var expected_ptr = well.allocate(output_elements)
    var expected = RuneTensor[f16](rows, outputs, expected_ptr, False)
    gemm_f16(A, B, expected)

    var output_ptr = well.allocate(output_elements)
    var output = RuneTensor[f16](rows, outputs, output_ptr, False)
    var dequantized_weights = well.allocate(outputs * shared)
    var fused_scratch = well.allocate(output_elements)
    var dequantized_scratch = well.allocate(output_elements)
    var tuner = QuantizedGEMMAutotuner(max_entries=2)
    var first = tuner.tune_and_execute(
        "host:test-cpu",
        A,
        B,
        output,
        dequantized_weights,
        outputs * shared,
        fused_scratch,
        dequantized_scratch,
        output_elements,
        warmup_iterations=1,
        measured_iterations=3,
        tolerance=Float32(0.0),
    )
    if first.cache_hit or first.fused_total_ns <= 0 or first.dequantized_total_ns <= 0:
        raise Error("autotuner did not record real candidate measurements")
    if (
        first.strategy != QuantizedGEMMStrategy.FUSED_RAW
        and first.strategy != QuantizedGEMMStrategy.DEQUANTIZE_F16
    ):
        raise Error("autotuner selected an unknown strategy")
    for index in range(output_elements):
        if output.data.unsafe_load(index) != expected.data.unsafe_load(index):
            raise Error("autotuner output differs from direct quantized GEMM")

    for index in range(output_elements):
        output.data.unsafe_store(index, Float16(99.0))
    var second = tuner.tune_and_execute(
        "host:test-cpu",
        A,
        B,
        output,
        dequantized_weights,
        outputs * shared,
        fused_scratch,
        dequantized_scratch,
        output_elements,
        warmup_iterations=1,
        measured_iterations=3,
    )
    if not second.cache_hit or tuner.cache_hits != 1 or tuner.cache_misses != 1:
        raise Error("autotuner exact-shape cache did not serve the second call")
    if second.strategy != first.strategy:
        raise Error("autotuner cache changed the selected strategy")
    for index in range(output_elements):
        if output.data.unsafe_load(index) != expected.data.unsafe_load(index):
            raise Error("cached autotuner output differs from direct GEMM")

    var serialized = tuner.serialize_cache("test-build-fingerprint")
    var restored = QuantizedGEMMAutotuner(max_entries=2)
    restored.restore_cache(serialized, "test-build-fingerprint")
    if restored.cache_size() != 1:
        raise Error("serialized autotuner cache did not restore its entry")
    var rejected_restore = False
    try:
        restored.restore_cache(serialized, "different-build")
    except error:
        rejected_restore = "fingerprint mismatch" in String(error)
    if not rejected_restore or restored.cache_size() != 1:
        raise Error("build-mismatched cache restore was not transactional")
    rejected_restore = False
    try:
        restored.restore_cache(serialized + "x", "test-build-fingerprint")
    except error:
        rejected_restore = "checksum mismatch" in String(error)
    if not rejected_restore or restored.cache_size() != 1:
        raise Error("corrupt cache restore was not transactional")
    for index in range(output_elements):
        output.data.unsafe_store(index, Float16(88.0))
    var restored_result = restored.tune_and_execute(
        "host:test-cpu",
        A,
        B,
        output,
        dequantized_weights,
        outputs * shared,
        fused_scratch,
        dequantized_scratch,
        output_elements,
    )
    if not restored_result.cache_hit:
        raise Error("restored autotuner cache did not serve the exact key")
    for index in range(output_elements):
        if output.data.unsafe_load(index) != expected.data.unsafe_load(index):
            raise Error("restored-cache output differs from direct GEMM")

    var rejected_output = RuneTensor[f16](
        rows, outputs, well.allocate(output_elements), False
    )
    for index in range(output_elements):
        rejected_output.data.unsafe_store(index, Float16(77.0))
    var external_weights = RuneTensor[f16](
        outputs,
        shared,
        packed.unsafe_bitcast[Float16](),
        True,
        CompressedFormatType(CompressedFormatType.GPTQ_4BIT),
    )
    var rejected = False
    try:
        _ = tuner.tune_and_execute(
            "host:test-cpu",
            A,
            external_weights,
            rejected_output,
            dequantized_weights,
            outputs * shared,
            fused_scratch,
            dequantized_scratch,
            output_elements,
        )
    except error:
        rejected = "metadata-bearing API" in String(error)
    if not rejected:
        raise Error("autotuner admitted a metadata-bearing format without metadata")
    for index in range(output_elements):
        if rejected_output.data.unsafe_load(index) != Float16(77.0):
            raise Error("rejected autotuning request mutated output")
    print("measured correctness-gated quantized GEMM autotuner: PASS")
