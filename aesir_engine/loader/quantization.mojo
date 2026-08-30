# loader/quantization.mojo
# The Quantization Forge: Upstream GGML Byte Layout Validation & Oracle Reference

from std.memory import Pointer
from core.mimir_well import CompressedFormatType, Scalar, f16

@always_inline
def get_block_size_bytes(format_type: CompressedFormatType) -> Int:
    """Returns exact upstream block size in bytes for the specified quantization format."""
    if format_type.value == CompressedFormatType.Q4_K_M:
        return 144
    elif format_type.value == CompressedFormatType.Q4_0:
        return 18
    elif format_type.value == CompressedFormatType.Q4_1:
        return 20
    elif format_type.value == CompressedFormatType.Q8_0:
        return 34
    return 144

@always_inline
def get_weights_per_block(format_type: CompressedFormatType) -> Int:
    """Returns number of unpacked F16 weights represented by one quantized block."""
    if format_type.value == CompressedFormatType.Q4_K_M:
        return 256
    return 32

def validate_quantized_byte_span(
    total_bytes: Int,
    num_elements: Int,
    format_type: CompressedFormatType,
) raises:
    """
    Validates exact byte buffer span and alignment before dequantization or GEMM dispatch.
    Raises Error on truncated, unaligned, or non-divisible byte buffer spans.
    """
    if total_bytes <= 0 or num_elements <= 0:
        raise Error("validate_quantized_byte_span: byte length and num_elements must be positive")
    
    var block_size = get_block_size_bytes(format_type)
    var weights_per_block = get_weights_per_block(format_type)

    if total_bytes % block_size != 0:
        raise Error("validate_quantized_byte_span: buffer byte length is not a multiple of block size")

    var num_blocks = total_bytes // block_size
    var expected_elements = num_blocks * weights_per_block

    if num_elements != expected_elements:
        raise Error("validate_quantized_byte_span: element count mismatch for byte span")


def dequantize_q4_0_block(
    src_bytes: Pointer[Byte, MutUntrackedOrigin],
    dst_f16: Pointer[Scalar[f16], MutUntrackedOrigin],
    num_blocks: Int,
):
    """
    Dequantizes Q4_0 packed byte blocks into 32 F16 values per block.
    """
    for b in range(num_blocks):
        var src_offset = b * 18
        var dst_offset = b * 32
        var scale_ptr = src_bytes.unsafe_offset(src_offset).unsafe_bitcast[Scalar[f16]]()
        var d = scale_ptr.unsafe_load()
        for i in range(16):
            var nibbles = src_bytes.unsafe_load(src_offset + 2 + i)
            var q0 = Int(nibbles & 0x0F) - 8
            var q1 = Int((nibbles >> 4) & 0x0F) - 8
            dst_f16.unsafe_store(dst_offset + i, d * Scalar[f16](q0))
            dst_f16.unsafe_store(dst_offset + i + 16, d * Scalar[f16](q1))
