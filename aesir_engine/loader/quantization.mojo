# loader/quantization.mojo
# The Quantization Forge: Upstream GGML Byte Layout Validation & Oracle Reference

from core.mimir_well import CompressedFormatType

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
