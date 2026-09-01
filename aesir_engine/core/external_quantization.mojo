"""Validated execution primitives for metadata-bearing quantized matrices."""

from std.memory import Pointer
from std.math import isinf, isnan


@always_inline
def _checked_product(lhs: Int, rhs: Int, label: String) raises -> Int:
    if lhs <= 0 or rhs <= 0:
        raise Error(label + ": dimensions must be positive")
    var product = lhs * rhs
    if product <= 0 or product // lhs != rhs:
        raise Error(label + ": element count overflow")
    return product


struct GPTQ4BitMatrix(Copyable, ImplicitlyCopyable):
    """AutoGPTQ 4-bit matrix metadata and packed storage.

    `qweight` has shape `[in_features / 8, out_features]`. Each UInt32 packs
    eight consecutive input-channel values, least-significant nibble first.
    `qzeros` has shape `[group_count, out_features / 8]` and stores each GPTQ
    zero point minus one. `scales` has shape `[group_count, out_features]`.
    Dequantized weights are exposed in `[out_features, in_features]` order.
    """

    var qweight: Pointer[UInt32, MutUntrackedOrigin]
    var qweight_elements: Int
    var qzeros: Pointer[UInt32, MutUntrackedOrigin]
    var qzero_elements: Int
    var scales: Pointer[Float16, MutUntrackedOrigin]
    var scale_elements: Int
    var g_idx: Pointer[Int32, MutUntrackedOrigin]
    var g_idx_elements: Int
    var in_features: Int
    var out_features: Int
    var group_size: Int
    var group_count: Int
    var has_g_idx: Bool

    def __init__(
        out self,
        qweight: Pointer[UInt32, MutUntrackedOrigin],
        qweight_elements: Int,
        qzeros: Pointer[UInt32, MutUntrackedOrigin],
        qzero_elements: Int,
        scales: Pointer[Float16, MutUntrackedOrigin],
        scale_elements: Int,
        in_features: Int,
        out_features: Int,
        group_size: Int,
        g_idx: Pointer[Int32, MutUntrackedOrigin] = Pointer[
            Int32, MutUntrackedOrigin
        ](unsafe_from_address=1),
        g_idx_elements: Int = 0,
        has_g_idx: Bool = False,
    ) raises:
        self.qweight = qweight
        self.qweight_elements = qweight_elements
        self.qzeros = qzeros
        self.qzero_elements = qzero_elements
        self.scales = scales
        self.scale_elements = scale_elements
        self.g_idx = g_idx
        self.g_idx_elements = g_idx_elements
        self.in_features = in_features
        self.out_features = out_features
        self.group_size = group_size
        self.group_count = 0
        self.has_g_idx = has_g_idx
        if self.in_features <= 0 or self.out_features <= 0:
            raise Error("GPTQ4BitMatrix: dimensions must be positive")
        if self.group_size <= 0:
            raise Error("GPTQ4BitMatrix: group_size must be positive")
        self.group_count = 1 + (self.in_features - 1) // self.group_size
        self.validate()

    def __copyinit__(out self, existing: Self):
        self.qweight = existing.qweight
        self.qweight_elements = existing.qweight_elements
        self.qzeros = existing.qzeros
        self.qzero_elements = existing.qzero_elements
        self.scales = existing.scales
        self.scale_elements = existing.scale_elements
        self.g_idx = existing.g_idx
        self.g_idx_elements = existing.g_idx_elements
        self.in_features = existing.in_features
        self.out_features = existing.out_features
        self.group_size = existing.group_size
        self.group_count = existing.group_count
        self.has_g_idx = existing.has_g_idx

    def validate(self) raises:
        if self.in_features <= 0 or self.out_features <= 0:
            raise Error("GPTQ4BitMatrix: dimensions must be positive")
        if self.group_size <= 0:
            raise Error("GPTQ4BitMatrix: group_size must be positive")
        if self.in_features % 8 != 0:
            raise Error("GPTQ4BitMatrix: in_features must be divisible by 8")
        if self.out_features % 8 != 0:
            raise Error("GPTQ4BitMatrix: out_features must be divisible by 8")
        if Int(self.qweight) <= 1 or Int(self.qzeros) <= 1 or Int(self.scales) <= 1:
            raise Error("GPTQ4BitMatrix: packed storage pointers must be valid")
        if self.has_g_idx and Int(self.g_idx) <= 1:
            raise Error("GPTQ4BitMatrix: has_g_idx requires valid group indices")

        var expected_groups = 1 + (self.in_features - 1) // self.group_size
        if self.group_count != expected_groups:
            raise Error("GPTQ4BitMatrix: group_count disagrees with matrix shape")
        var expected_qweights = _checked_product(
            self.in_features // 8, self.out_features, "GPTQ qweight"
        )
        var expected_qzeros = _checked_product(
            self.group_count, self.out_features // 8, "GPTQ qzeros"
        )
        var expected_scales = _checked_product(
            self.group_count, self.out_features, "GPTQ scales"
        )
        if self.qweight_elements != expected_qweights:
            raise Error("GPTQ4BitMatrix: qweight storage length mismatch")
        if self.qzero_elements != expected_qzeros:
            raise Error("GPTQ4BitMatrix: qzero storage length mismatch")
        if self.scale_elements != expected_scales:
            raise Error("GPTQ4BitMatrix: scale storage length mismatch")
        if self.has_g_idx and self.g_idx_elements != self.in_features:
            raise Error("GPTQ4BitMatrix: g_idx storage length mismatch")
        if not self.has_g_idx and self.g_idx_elements != 0:
            raise Error("GPTQ4BitMatrix: g_idx length requires has_g_idx")
        _ = _checked_product(self.in_features, self.out_features, "GPTQ dequantized matrix")

    def validate_group_indices(self) raises:
        if not self.has_g_idx:
            return
        for k in range(self.in_features):
            var group = Int(self.g_idx.unsafe_load(k))
            if group < 0 or group >= self.group_count:
                raise Error("GPTQ4BitMatrix: g_idx contains an out-of-range group")

    @always_inline
    def group_for(self, input_index: Int) -> Int:
        if self.has_g_idx:
            return Int(self.g_idx.unsafe_load(input_index))
        return input_index // self.group_size


@always_inline
def _gptq_4bit_weight_unchecked(
    matrix: GPTQ4BitMatrix, input_index: Int, output_index: Int
) -> Float32:
    var packed_input = input_index // 8
    var input_lane = input_index % 8
    var weight_word = matrix.qweight.unsafe_load(
        packed_input * matrix.out_features + output_index
    )
    var quantized = Int(
        (weight_word >> UInt32(input_lane * 4)) & UInt32(0xF)
    )

    var group = matrix.group_for(input_index)
    var packed_output = matrix.out_features // 8
    var zero_word = matrix.qzeros.unsafe_load(
        group * packed_output + output_index // 8
    )
    # AutoGPTQ stores zero - 1 and restores it modulo the 4-bit mask.
    var zero = (
        Int(
            (zero_word >> UInt32((output_index % 8) * 4)) & UInt32(0xF)
        )
        + 1
    ) & 0xF
    var scale = matrix.scales.unsafe_load(
        group * matrix.out_features + output_index
    ).cast[DType.float32]()
    return (Float32(quantized) - Float32(zero)) * scale


def gptq_4bit_weight(
    matrix: GPTQ4BitMatrix, input_index: Int, output_index: Int
) raises -> Float32:
    """Return one checked dequantized GPTQ weight."""
    matrix.validate()
    if input_index < 0 or input_index >= matrix.in_features:
        raise Error("gptq_4bit_weight: input index out of range")
    if output_index < 0 or output_index >= matrix.out_features:
        raise Error("gptq_4bit_weight: output index out of range")
    var group = matrix.group_for(input_index)
    if group < 0 or group >= matrix.group_count:
        raise Error("gptq_4bit_weight: g_idx contains an out-of-range group")
    return _gptq_4bit_weight_unchecked(matrix, input_index, output_index)


def dequantize_gptq_4bit_matrix(
    matrix: GPTQ4BitMatrix,
    output: Pointer[Float16, MutUntrackedOrigin],
    output_elements: Int,
) raises:
    if Int(output) <= 1:
        raise Error("dequantize_gptq_4bit_matrix: output pointer must be valid")
    matrix.validate()
    matrix.validate_group_indices()
    var expected_output = _checked_product(
        matrix.in_features, matrix.out_features, "GPTQ dequantized output"
    )
    if output_elements != expected_output:
        raise Error("dequantize_gptq_4bit_matrix: output storage length mismatch")
    for output_index in range(matrix.out_features):
        for input_index in range(matrix.in_features):
            output.unsafe_store(
                output_index * matrix.in_features + input_index,
                _gptq_4bit_weight_unchecked(
                    matrix, input_index, output_index
                ).cast[DType.float16](),
            )


def gemm_gptq_4bit_matrix(
    input: Pointer[Float16, MutUntrackedOrigin],
    input_elements: Int,
    input_rows: Int,
    matrix: GPTQ4BitMatrix,
    output: Pointer[Float16, MutUntrackedOrigin],
    output_elements: Int,
) raises:
    if Int(input) <= 1 or Int(output) <= 1:
        raise Error("gemm_gptq_4bit_matrix: input and output pointers must be valid")
    matrix.validate()
    var expected_input = _checked_product(
        input_rows, matrix.in_features, "GPTQ GEMM input"
    )
    var expected_output = _checked_product(
        input_rows, matrix.out_features, "GPTQ GEMM output"
    )
    if input_elements != expected_input:
        raise Error("gemm_gptq_4bit_matrix: input storage length mismatch")
    if output_elements != expected_output:
        raise Error("gemm_gptq_4bit_matrix: output storage length mismatch")
    matrix.validate_group_indices()

    for row in range(input_rows):
        for output_index in range(matrix.out_features):
            var accumulator = Float32(0.0)
            for input_index in range(matrix.in_features):
                accumulator += input.unsafe_load(
                    row * matrix.in_features + input_index
                ).cast[DType.float32]() * _gptq_4bit_weight_unchecked(
                    matrix, input_index, output_index
                )
            output.unsafe_store(
                row * matrix.out_features + output_index,
                accumulator.cast[DType.float16](),
            )


struct GPTQ8BitMatrix(Copyable, ImplicitlyCopyable):
    """AutoGPTQ 8-bit matrix with exact backing-storage bounds."""

    var qweight: Pointer[UInt32, MutUntrackedOrigin]
    var qweight_elements: Int
    var qzeros: Pointer[UInt32, MutUntrackedOrigin]
    var qzero_elements: Int
    var scales: Pointer[Float16, MutUntrackedOrigin]
    var scale_elements: Int
    var g_idx: Pointer[Int32, MutUntrackedOrigin]
    var g_idx_elements: Int
    var in_features: Int
    var out_features: Int
    var group_size: Int
    var group_count: Int
    var has_g_idx: Bool

    def __init__(
        out self,
        qweight: Pointer[UInt32, MutUntrackedOrigin],
        qweight_elements: Int,
        qzeros: Pointer[UInt32, MutUntrackedOrigin],
        qzero_elements: Int,
        scales: Pointer[Float16, MutUntrackedOrigin],
        scale_elements: Int,
        in_features: Int,
        out_features: Int,
        group_size: Int,
        g_idx: Pointer[Int32, MutUntrackedOrigin] = Pointer[
            Int32, MutUntrackedOrigin
        ](unsafe_from_address=1),
        g_idx_elements: Int = 0,
        has_g_idx: Bool = False,
    ) raises:
        self.qweight = qweight
        self.qweight_elements = qweight_elements
        self.qzeros = qzeros
        self.qzero_elements = qzero_elements
        self.scales = scales
        self.scale_elements = scale_elements
        self.g_idx = g_idx
        self.g_idx_elements = g_idx_elements
        self.in_features = in_features
        self.out_features = out_features
        self.group_size = group_size
        self.group_count = 0
        self.has_g_idx = has_g_idx
        if self.in_features <= 0 or self.out_features <= 0:
            raise Error("GPTQ8BitMatrix: dimensions must be positive")
        if self.group_size <= 0:
            raise Error("GPTQ8BitMatrix: group_size must be positive")
        self.group_count = 1 + (self.in_features - 1) // self.group_size
        self.validate()

    def __copyinit__(out self, existing: Self):
        self.qweight = existing.qweight
        self.qweight_elements = existing.qweight_elements
        self.qzeros = existing.qzeros
        self.qzero_elements = existing.qzero_elements
        self.scales = existing.scales
        self.scale_elements = existing.scale_elements
        self.g_idx = existing.g_idx
        self.g_idx_elements = existing.g_idx_elements
        self.in_features = existing.in_features
        self.out_features = existing.out_features
        self.group_size = existing.group_size
        self.group_count = existing.group_count
        self.has_g_idx = existing.has_g_idx

    def validate(self) raises:
        if self.in_features <= 0 or self.out_features <= 0:
            raise Error("GPTQ8BitMatrix: dimensions must be positive")
        if self.group_size <= 0:
            raise Error("GPTQ8BitMatrix: group_size must be positive")
        if self.in_features % 4 != 0:
            raise Error("GPTQ8BitMatrix: in_features must be divisible by 4")
        if self.out_features % 4 != 0:
            raise Error("GPTQ8BitMatrix: out_features must be divisible by 4")
        if Int(self.qweight) <= 1 or Int(self.qzeros) <= 1 or Int(self.scales) <= 1:
            raise Error("GPTQ8BitMatrix: packed storage pointers must be valid")
        if self.has_g_idx and Int(self.g_idx) <= 1:
            raise Error("GPTQ8BitMatrix: has_g_idx requires valid group indices")

        var expected_groups = 1 + (self.in_features - 1) // self.group_size
        if self.group_count != expected_groups:
            raise Error("GPTQ8BitMatrix: group_count disagrees with matrix shape")
        var expected_qweights = _checked_product(
            self.in_features // 4, self.out_features, "GPTQ 8-bit qweight"
        )
        var expected_qzeros = _checked_product(
            self.group_count, self.out_features // 4, "GPTQ 8-bit qzeros"
        )
        var expected_scales = _checked_product(
            self.group_count, self.out_features, "GPTQ 8-bit scales"
        )
        if self.qweight_elements != expected_qweights:
            raise Error("GPTQ8BitMatrix: qweight storage length mismatch")
        if self.qzero_elements != expected_qzeros:
            raise Error("GPTQ8BitMatrix: qzero storage length mismatch")
        if self.scale_elements != expected_scales:
            raise Error("GPTQ8BitMatrix: scale storage length mismatch")
        if self.has_g_idx and self.g_idx_elements != self.in_features:
            raise Error("GPTQ8BitMatrix: g_idx storage length mismatch")
        if not self.has_g_idx and self.g_idx_elements != 0:
            raise Error("GPTQ8BitMatrix: g_idx length requires has_g_idx")
        _ = _checked_product(
            self.in_features, self.out_features, "GPTQ 8-bit matrix"
        )

    def validate_group_indices(self) raises:
        if not self.has_g_idx:
            return
        for input_index in range(self.in_features):
            var group = Int(self.g_idx.unsafe_load(input_index))
            if group < 0 or group >= self.group_count:
                raise Error("GPTQ8BitMatrix: g_idx contains an out-of-range group")

    @always_inline
    def group_for(self, input_index: Int) -> Int:
        if self.has_g_idx:
            return Int(self.g_idx.unsafe_load(input_index))
        return input_index // self.group_size


@always_inline
def _gptq_8bit_weight_unchecked(
    matrix: GPTQ8BitMatrix, input_index: Int, output_index: Int
) -> Float32:
    var weight_word = matrix.qweight.unsafe_load(
        (input_index // 4) * matrix.out_features + output_index
    )
    var quantized = Int(
        (weight_word >> UInt32((input_index % 4) * 8)) & UInt32(0xFF)
    )
    var group = matrix.group_for(input_index)
    var zero_word = matrix.qzeros.unsafe_load(
        group * (matrix.out_features // 4) + output_index // 4
    )
    var zero = (
        Int(
            (zero_word >> UInt32((output_index % 4) * 8))
            & UInt32(0xFF)
        )
        + 1
    ) & 0xFF
    var scale = matrix.scales.unsafe_load(
        group * matrix.out_features + output_index
    ).cast[DType.float32]()
    return (Float32(quantized) - Float32(zero)) * scale


def gptq_8bit_weight(
    matrix: GPTQ8BitMatrix, input_index: Int, output_index: Int
) raises -> Float32:
    matrix.validate()
    if input_index < 0 or input_index >= matrix.in_features:
        raise Error("gptq_8bit_weight: input index out of range")
    if output_index < 0 or output_index >= matrix.out_features:
        raise Error("gptq_8bit_weight: output index out of range")
    var group = matrix.group_for(input_index)
    if group < 0 or group >= matrix.group_count:
        raise Error("gptq_8bit_weight: g_idx contains an out-of-range group")
    return _gptq_8bit_weight_unchecked(matrix, input_index, output_index)


def dequantize_gptq_8bit_matrix(
    matrix: GPTQ8BitMatrix,
    output: Pointer[Float16, MutUntrackedOrigin],
    output_elements: Int,
) raises:
    if Int(output) <= 1:
        raise Error("dequantize_gptq_8bit_matrix: output pointer must be valid")
    matrix.validate()
    matrix.validate_group_indices()
    var expected_output = _checked_product(
        matrix.in_features, matrix.out_features, "GPTQ 8-bit output"
    )
    if output_elements != expected_output:
        raise Error("dequantize_gptq_8bit_matrix: output storage length mismatch")
    for output_index in range(matrix.out_features):
        for input_index in range(matrix.in_features):
            output.unsafe_store(
                output_index * matrix.in_features + input_index,
                _gptq_8bit_weight_unchecked(
                    matrix, input_index, output_index
                ).cast[DType.float16](),
            )


def gemm_gptq_8bit_matrix(
    input: Pointer[Float16, MutUntrackedOrigin],
    input_elements: Int,
    input_rows: Int,
    matrix: GPTQ8BitMatrix,
    output: Pointer[Float16, MutUntrackedOrigin],
    output_elements: Int,
) raises:
    if Int(input) <= 1 or Int(output) <= 1:
        raise Error("gemm_gptq_8bit_matrix: input and output pointers must be valid")
    matrix.validate()
    var expected_input = _checked_product(
        input_rows, matrix.in_features, "GPTQ 8-bit GEMM input"
    )
    var expected_output = _checked_product(
        input_rows, matrix.out_features, "GPTQ 8-bit GEMM output"
    )
    if input_elements != expected_input:
        raise Error("gemm_gptq_8bit_matrix: input storage length mismatch")
    if output_elements != expected_output:
        raise Error("gemm_gptq_8bit_matrix: output storage length mismatch")
    matrix.validate_group_indices()
    for row in range(input_rows):
        for output_index in range(matrix.out_features):
            var accumulator = Float32(0.0)
            for input_index in range(matrix.in_features):
                accumulator += input.unsafe_load(
                    row * matrix.in_features + input_index
                ).cast[DType.float32]() * _gptq_8bit_weight_unchecked(
                    matrix, input_index, output_index
                )
            output.unsafe_store(
                row * matrix.out_features + output_index,
                accumulator.cast[DType.float16](),
            )


struct AWQ4BitMatrix(Copyable, ImplicitlyCopyable):
    """AutoAWQ GEMM 4-bit matrix with exact tensor bounds."""

    var qweight: Pointer[UInt32, MutUntrackedOrigin]
    var qweight_elements: Int
    var qzeros: Pointer[UInt32, MutUntrackedOrigin]
    var qzero_elements: Int
    var scales: Pointer[Float16, MutUntrackedOrigin]
    var scale_elements: Int
    var in_features: Int
    var out_features: Int
    var group_size: Int
    var group_count: Int

    def __init__(
        out self,
        qweight: Pointer[UInt32, MutUntrackedOrigin],
        qweight_elements: Int,
        qzeros: Pointer[UInt32, MutUntrackedOrigin],
        qzero_elements: Int,
        scales: Pointer[Float16, MutUntrackedOrigin],
        scale_elements: Int,
        in_features: Int,
        out_features: Int,
        group_size: Int,
    ) raises:
        self.qweight = qweight
        self.qweight_elements = qweight_elements
        self.qzeros = qzeros
        self.qzero_elements = qzero_elements
        self.scales = scales
        self.scale_elements = scale_elements
        self.in_features = in_features
        self.out_features = out_features
        self.group_size = group_size
        self.group_count = 0
        if self.in_features <= 0 or self.out_features <= 0:
            raise Error("AWQ4BitMatrix: dimensions must be positive")
        if self.group_size <= 0:
            raise Error("AWQ4BitMatrix: group_size must be positive")
        if self.in_features % self.group_size != 0:
            raise Error("AWQ4BitMatrix: group_size must divide in_features")
        self.group_count = self.in_features // self.group_size
        self.validate()

    def __copyinit__(out self, existing: Self):
        self.qweight = existing.qweight
        self.qweight_elements = existing.qweight_elements
        self.qzeros = existing.qzeros
        self.qzero_elements = existing.qzero_elements
        self.scales = existing.scales
        self.scale_elements = existing.scale_elements
        self.in_features = existing.in_features
        self.out_features = existing.out_features
        self.group_size = existing.group_size
        self.group_count = existing.group_count

    def validate(self) raises:
        if self.in_features <= 0 or self.out_features <= 0:
            raise Error("AWQ4BitMatrix: dimensions must be positive")
        if self.group_size <= 0 or self.in_features % self.group_size != 0:
            raise Error("AWQ4BitMatrix: group_size must divide in_features")
        if self.out_features % 8 != 0:
            raise Error("AWQ4BitMatrix: out_features must be divisible by 8")
        if Int(self.qweight) <= 1 or Int(self.qzeros) <= 1 or Int(self.scales) <= 1:
            raise Error("AWQ4BitMatrix: packed storage pointers must be valid")
        var expected_groups = self.in_features // self.group_size
        if self.group_count != expected_groups:
            raise Error("AWQ4BitMatrix: group_count disagrees with matrix shape")
        var packed_outputs = self.out_features // 8
        var expected_qweights = _checked_product(
            self.in_features, packed_outputs, "AWQ qweight"
        )
        var expected_qzeros = _checked_product(
            self.group_count, packed_outputs, "AWQ qzeros"
        )
        var expected_scales = _checked_product(
            self.group_count, self.out_features, "AWQ scales"
        )
        if self.qweight_elements != expected_qweights:
            raise Error("AWQ4BitMatrix: qweight storage length mismatch")
        if self.qzero_elements != expected_qzeros:
            raise Error("AWQ4BitMatrix: qzero storage length mismatch")
        if self.scale_elements != expected_scales:
            raise Error("AWQ4BitMatrix: scale storage length mismatch")
        _ = _checked_product(
            self.in_features, self.out_features, "AWQ dequantized matrix"
        )


@always_inline
def _awq_nibble_position(logical_lane: Int) -> Int:
    # Inverse of AutoAWQ's [0,2,4,6,1,3,5,7] pack order.
    if logical_lane % 2 == 0:
        return logical_lane // 2
    return 4 + logical_lane // 2


@always_inline
def _awq_4bit_weight_unchecked(
    matrix: AWQ4BitMatrix, input_index: Int, output_index: Int
) -> Float32:
    var packed_outputs = matrix.out_features // 8
    var packed_column = output_index // 8
    var shift = UInt32(_awq_nibble_position(output_index % 8) * 4)
    var weight_word = matrix.qweight.unsafe_load(
        input_index * packed_outputs + packed_column
    )
    var quantized = Int((weight_word >> shift) & UInt32(0xF))
    var group = input_index // matrix.group_size
    var zero_word = matrix.qzeros.unsafe_load(
        group * packed_outputs + packed_column
    )
    var zero = Int((zero_word >> shift) & UInt32(0xF))
    var scale = matrix.scales.unsafe_load(
        group * matrix.out_features + output_index
    ).cast[DType.float32]()
    return (Float32(quantized) - Float32(zero)) * scale


def awq_4bit_weight(
    matrix: AWQ4BitMatrix, input_index: Int, output_index: Int
) raises -> Float32:
    matrix.validate()
    if input_index < 0 or input_index >= matrix.in_features:
        raise Error("awq_4bit_weight: input index out of range")
    if output_index < 0 or output_index >= matrix.out_features:
        raise Error("awq_4bit_weight: output index out of range")
    return _awq_4bit_weight_unchecked(matrix, input_index, output_index)


def dequantize_awq_4bit_matrix(
    matrix: AWQ4BitMatrix,
    output: Pointer[Float16, MutUntrackedOrigin],
    output_elements: Int,
) raises:
    if Int(output) <= 1:
        raise Error("dequantize_awq_4bit_matrix: output pointer must be valid")
    matrix.validate()
    var expected_output = _checked_product(
        matrix.in_features, matrix.out_features, "AWQ output"
    )
    if output_elements != expected_output:
        raise Error("dequantize_awq_4bit_matrix: output storage length mismatch")
    for output_index in range(matrix.out_features):
        for input_index in range(matrix.in_features):
            output.unsafe_store(
                output_index * matrix.in_features + input_index,
                _awq_4bit_weight_unchecked(
                    matrix, input_index, output_index
                ).cast[DType.float16](),
            )


def gemm_awq_4bit_matrix(
    input: Pointer[Float16, MutUntrackedOrigin],
    input_elements: Int,
    input_rows: Int,
    matrix: AWQ4BitMatrix,
    output: Pointer[Float16, MutUntrackedOrigin],
    output_elements: Int,
) raises:
    if Int(input) <= 1 or Int(output) <= 1:
        raise Error("gemm_awq_4bit_matrix: input and output pointers must be valid")
    matrix.validate()
    var expected_input = _checked_product(
        input_rows, matrix.in_features, "AWQ GEMM input"
    )
    var expected_output = _checked_product(
        input_rows, matrix.out_features, "AWQ GEMM output"
    )
    if input_elements != expected_input:
        raise Error("gemm_awq_4bit_matrix: input storage length mismatch")
    if output_elements != expected_output:
        raise Error("gemm_awq_4bit_matrix: output storage length mismatch")
    for row in range(input_rows):
        for output_index in range(matrix.out_features):
            var accumulator = Float32(0.0)
            for input_index in range(matrix.in_features):
                accumulator += input.unsafe_load(
                    row * matrix.in_features + input_index
                ).cast[DType.float32]() * _awq_4bit_weight_unchecked(
                    matrix, input_index, output_index
                )
            output.unsafe_store(
                row * matrix.out_features + output_index,
                accumulator.cast[DType.float16](),
            )


struct SmoothQuantW8A8Matrix(Copyable, ImplicitlyCopyable):
    """SmoothQuant/torch-int static per-tensor W8A8 linear metadata."""

    var weights: Pointer[Int8, MutUntrackedOrigin]
    var weight_elements: Int
    var weight_scale: Float32
    var input_scale: Float32
    var bias: Pointer[Float32, MutUntrackedOrigin]
    var bias_elements: Int
    var in_features: Int
    var out_features: Int
    var has_bias: Bool

    def __init__(
        out self,
        weights: Pointer[Int8, MutUntrackedOrigin],
        weight_elements: Int,
        weight_scale: Float32,
        input_scale: Float32,
        in_features: Int,
        out_features: Int,
        bias: Pointer[Float32, MutUntrackedOrigin] = Pointer[
            Float32, MutUntrackedOrigin
        ](unsafe_from_address=1),
        bias_elements: Int = 0,
        has_bias: Bool = False,
    ) raises:
        self.weights = weights
        self.weight_elements = weight_elements
        self.weight_scale = weight_scale
        self.input_scale = input_scale
        self.bias = bias
        self.bias_elements = bias_elements
        self.in_features = in_features
        self.out_features = out_features
        self.has_bias = has_bias
        self.validate()

    def __copyinit__(out self, existing: Self):
        self.weights = existing.weights
        self.weight_elements = existing.weight_elements
        self.weight_scale = existing.weight_scale
        self.input_scale = existing.input_scale
        self.bias = existing.bias
        self.bias_elements = existing.bias_elements
        self.in_features = existing.in_features
        self.out_features = existing.out_features
        self.has_bias = existing.has_bias

    def validate(self) raises:
        if self.in_features <= 0 or self.out_features <= 0:
            raise Error("SmoothQuantW8A8Matrix: dimensions must be positive")
        if Int(self.weights) <= 1:
            raise Error("SmoothQuantW8A8Matrix: weight pointer must be valid")
        if (
            self.weight_scale <= 0.0
            or isnan(self.weight_scale)
            or isinf(self.weight_scale)
        ):
            raise Error("SmoothQuantW8A8Matrix: weight_scale must be finite and positive")
        if (
            self.input_scale <= 0.0
            or isnan(self.input_scale)
            or isinf(self.input_scale)
        ):
            raise Error("SmoothQuantW8A8Matrix: input_scale must be finite and positive")
        var expected_weights = _checked_product(
            self.out_features, self.in_features, "SmoothQuant weights"
        )
        if self.weight_elements != expected_weights:
            raise Error("SmoothQuantW8A8Matrix: weight storage length mismatch")
        if self.has_bias:
            if Int(self.bias) <= 1 or self.bias_elements != self.out_features:
                raise Error("SmoothQuantW8A8Matrix: bias storage mismatch")
        elif self.bias_elements != 0:
            raise Error("SmoothQuantW8A8Matrix: bias length requires has_bias")


@always_inline
def quantize_smoothquant_int8(value: Float32, scale: Float32) raises -> Int8:
    """Symmetric static INT8 quantization with nearest rounding and saturation."""
    if scale <= 0.0 or isnan(scale) or isinf(scale):
        raise Error("quantize_smoothquant_int8: scale must be finite and positive")
    var scaled = value / scale
    var rounded: Int
    if scaled >= 0.0:
        rounded = Int(scaled + 0.5)
    else:
        rounded = Int(scaled - 0.5)
    if rounded > 127:
        rounded = 127
    elif rounded < -128:
        rounded = -128
    return Int8(rounded)


def dequantize_smoothquant_weights(
    matrix: SmoothQuantW8A8Matrix,
    output: Pointer[Float16, MutUntrackedOrigin],
    output_elements: Int,
) raises:
    if Int(output) <= 1:
        raise Error("dequantize_smoothquant_weights: output pointer must be valid")
    matrix.validate()
    if output_elements != matrix.weight_elements:
        raise Error("dequantize_smoothquant_weights: output storage length mismatch")
    for i in range(matrix.weight_elements):
        output.unsafe_store(
            i,
            (
                Float32(matrix.weights.unsafe_load(i)) * matrix.weight_scale
            ).cast[DType.float16](),
        )


def gemm_smoothquant_w8a8(
    input: Pointer[Float16, MutUntrackedOrigin],
    input_elements: Int,
    input_rows: Int,
    matrix: SmoothQuantW8A8Matrix,
    output: Pointer[Float16, MutUntrackedOrigin],
    output_elements: Int,
) raises:
    if Int(input) <= 1 or Int(output) <= 1:
        raise Error("gemm_smoothquant_w8a8: input and output pointers must be valid")
    matrix.validate()
    var expected_input = _checked_product(
        input_rows, matrix.in_features, "SmoothQuant GEMM input"
    )
    var expected_output = _checked_product(
        input_rows, matrix.out_features, "SmoothQuant GEMM output"
    )
    if input_elements != expected_input:
        raise Error("gemm_smoothquant_w8a8: input storage length mismatch")
    if output_elements != expected_output:
        raise Error("gemm_smoothquant_w8a8: output storage length mismatch")
    var combined_scale = matrix.input_scale * matrix.weight_scale
    if isnan(combined_scale) or isinf(combined_scale):
        raise Error("gemm_smoothquant_w8a8: combined scale is not finite")

    for row in range(input_rows):
        for output_index in range(matrix.out_features):
            var accumulator = Int32(0)
            for input_index in range(matrix.in_features):
                var activation = quantize_smoothquant_int8(
                    input.unsafe_load(
                        row * matrix.in_features + input_index
                    ).cast[DType.float32](),
                    matrix.input_scale,
                )
                var weight = matrix.weights.unsafe_load(
                    output_index * matrix.in_features + input_index
                )
                accumulator += Int32(activation) * Int32(weight)
            var result = Float32(accumulator) * combined_scale
            if matrix.has_bias:
                result += matrix.bias.unsafe_load(output_index)
            output.unsafe_store(
                row * matrix.out_features + output_index,
                result.cast[DType.float16](),
            )


struct EXL2Matrix(Copyable, ImplicitlyCopyable):
    """Canonical unshuffled EXL2 mixed-bit matrix from safetensors.

    `q_weight` is the converter-written `[packed_rows, stored_out_features]`
    Int32 tensor. `q_scale` is `[group_count, stored_out_features / 8]`
    packed UInt32, `q_scale_max` is the serialized (pre `/ 256`) Float16
    vector, and `q_groups` contains `(bits, first_packed_row)` UInt16 pairs.
    The loader-derived `q_perm = argsort(q_invperm)` and serialized
    `q_invperm[original_input]` map between packed and original input rows.

    The supported EXL2 bit widths are exactly 2, 3, 4, 5, 6, and 8. Output
    columns follow the upstream converter's padding to a multiple of 32 while
    `out_features` records the logical, unpadded width.
    """

    var qweight: Pointer[UInt32, MutUntrackedOrigin]
    var qweight_elements: Int
    var qweight_rows: Int
    var q_scale: Pointer[UInt32, MutUntrackedOrigin]
    var q_scale_elements: Int
    var q_scale_max: Pointer[Float16, MutUntrackedOrigin]
    var q_scale_max_elements: Int
    var q_groups: Pointer[UInt16, MutUntrackedOrigin]
    var q_group_elements: Int
    var q_perm: Pointer[Int32, MutUntrackedOrigin]
    var q_perm_elements: Int
    var q_invperm: Pointer[Int32, MutUntrackedOrigin]
    var q_invperm_elements: Int
    var in_features: Int
    var out_features: Int
    var stored_out_features: Int
    var group_count: Int

    def __init__(
        out self,
        qweight: Pointer[UInt32, MutUntrackedOrigin],
        qweight_elements: Int,
        qweight_rows: Int,
        q_scale: Pointer[UInt32, MutUntrackedOrigin],
        q_scale_elements: Int,
        q_scale_max: Pointer[Float16, MutUntrackedOrigin],
        q_scale_max_elements: Int,
        q_groups: Pointer[UInt16, MutUntrackedOrigin],
        q_group_elements: Int,
        q_perm: Pointer[Int32, MutUntrackedOrigin],
        q_perm_elements: Int,
        q_invperm: Pointer[Int32, MutUntrackedOrigin],
        q_invperm_elements: Int,
        in_features: Int,
        out_features: Int,
        stored_out_features: Int,
        group_count: Int,
    ) raises:
        self.qweight = qweight
        self.qweight_elements = qweight_elements
        self.qweight_rows = qweight_rows
        self.q_scale = q_scale
        self.q_scale_elements = q_scale_elements
        self.q_scale_max = q_scale_max
        self.q_scale_max_elements = q_scale_max_elements
        self.q_groups = q_groups
        self.q_group_elements = q_group_elements
        self.q_perm = q_perm
        self.q_perm_elements = q_perm_elements
        self.q_invperm = q_invperm
        self.q_invperm_elements = q_invperm_elements
        self.in_features = in_features
        self.out_features = out_features
        self.stored_out_features = stored_out_features
        self.group_count = group_count
        self.validate()

    def __copyinit__(out self, existing: Self):
        self.qweight = existing.qweight
        self.qweight_elements = existing.qweight_elements
        self.qweight_rows = existing.qweight_rows
        self.q_scale = existing.q_scale
        self.q_scale_elements = existing.q_scale_elements
        self.q_scale_max = existing.q_scale_max
        self.q_scale_max_elements = existing.q_scale_max_elements
        self.q_groups = existing.q_groups
        self.q_group_elements = existing.q_group_elements
        self.q_perm = existing.q_perm
        self.q_perm_elements = existing.q_perm_elements
        self.q_invperm = existing.q_invperm
        self.q_invperm_elements = existing.q_invperm_elements
        self.in_features = existing.in_features
        self.out_features = existing.out_features
        self.stored_out_features = existing.stored_out_features
        self.group_count = existing.group_count

    @always_inline
    def _bits_supported(self, bits: Int) -> Bool:
        return (
            bits == 2
            or bits == 3
            or bits == 4
            or bits == 5
            or bits == 6
            or bits == 8
        )

    def validate(self) raises:
        if self.in_features <= 0 or self.out_features <= 0:
            raise Error("EXL2Matrix: logical dimensions must be positive")
        if self.qweight_rows <= 0 or self.group_count <= 0:
            raise Error("EXL2Matrix: packed rows and group count must be positive")
        if self.stored_out_features < self.out_features:
            raise Error("EXL2Matrix: stored output width is shorter than logical width")
        if self.stored_out_features % 32 != 0:
            raise Error("EXL2Matrix: stored output width must use EXL2's 32-column padding")
        if (
            Int(self.qweight) <= 1
            or Int(self.q_scale) <= 1
            or Int(self.q_scale_max) <= 1
            or Int(self.q_groups) <= 1
            or Int(self.q_perm) <= 1
            or Int(self.q_invperm) <= 1
        ):
            raise Error("EXL2Matrix: all serialized tensor pointers must be valid")
        if self.qweight_elements != _checked_product(
            self.qweight_rows, self.stored_out_features, "EXL2 q_weight"
        ):
            raise Error("EXL2Matrix: q_weight storage length mismatch")
        if self.q_scale_elements != _checked_product(
            self.group_count,
            self.stored_out_features // 8,
            "EXL2 q_scale",
        ):
            raise Error("EXL2Matrix: q_scale storage length mismatch")
        if self.q_scale_max_elements != self.group_count:
            raise Error("EXL2Matrix: q_scale_max storage length mismatch")
        if self.q_group_elements != self.group_count * 2:
            raise Error("EXL2Matrix: q_groups storage length mismatch")
        if (
            self.q_perm_elements != self.in_features
            or self.q_invperm_elements != self.in_features
        ):
            raise Error("EXL2Matrix: permutation storage length mismatch")

        var logical_row = 0
        for group in range(self.group_count):
            var bits = Int(self.q_groups.unsafe_load(group * 2))
            if not self._bits_supported(bits):
                raise Error("EXL2Matrix: q_groups contains an unsupported bitrate")
            var packed_start = Int(self.q_groups.unsafe_load(group * 2 + 1))
            var packed_end = self.qweight_rows
            if group + 1 < self.group_count:
                packed_end = Int(self.q_groups.unsafe_load(group * 2 + 3))
            if group == 0 and packed_start != 0:
                raise Error("EXL2Matrix: first group must start at packed row zero")
            if packed_start < 0 or packed_end <= packed_start or packed_end > self.qweight_rows:
                raise Error("EXL2Matrix: q_groups packed row offsets are invalid")
            var packed_bits = (packed_end - packed_start) * 32
            if group + 1 < self.group_count:
                if packed_bits % bits != 0:
                    raise Error("EXL2Matrix: non-final group contains partial packed values")
                logical_row += packed_bits // bits
                if logical_row >= self.in_features:
                    raise Error("EXL2Matrix: non-final groups exhaust the logical rows")
            else:
                var remaining = self.in_features - logical_row
                if remaining <= 0:
                    raise Error("EXL2Matrix: final group has no logical rows")
                var required_packed_rows = (remaining * bits + 31) // 32
                if required_packed_rows != packed_end - packed_start:
                    raise Error("EXL2Matrix: final group packing does not cover logical rows exactly")
                logical_row += remaining
            var max_scale = self.q_scale_max.unsafe_load(group).cast[DType.float32]()
            if max_scale <= 0.0 or isnan(max_scale) or isinf(max_scale):
                raise Error("EXL2Matrix: q_scale_max values must be finite and positive")
        if logical_row != self.in_features:
            raise Error("EXL2Matrix: q_groups do not cover the input dimension")

        # ExLlama derives q_perm = argsort(q_invperm) while loading. Checking
        # both directions proves a bijection in linear time without scratch.
        for original_row in range(self.in_features):
            var packed_row = Int(self.q_invperm.unsafe_load(original_row))
            if packed_row < 0 or packed_row >= self.in_features:
                raise Error("EXL2Matrix: q_invperm contains an out-of-range row")
            if Int(self.q_perm.unsafe_load(packed_row)) != original_row:
                raise Error("EXL2Matrix: q_perm and q_invperm are not inverses")
        for packed_row in range(self.in_features):
            var original_row = Int(self.q_perm.unsafe_load(packed_row))
            if original_row < 0 or original_row >= self.in_features:
                raise Error("EXL2Matrix: q_perm contains an out-of-range row")
            if Int(self.q_invperm.unsafe_load(original_row)) != packed_row:
                raise Error("EXL2Matrix: q_invperm and q_perm are not inverses")


@always_inline
def _exl2_group_rows(matrix: EXL2Matrix, group: Int, logical_start: Int) -> Int:
    if group + 1 == matrix.group_count:
        return matrix.in_features - logical_start
    var bits = Int(matrix.q_groups.unsafe_load(group * 2))
    var packed_start = Int(matrix.q_groups.unsafe_load(group * 2 + 1))
    var packed_end = Int(matrix.q_groups.unsafe_load(group * 2 + 3))
    return (packed_end - packed_start) * 32 // bits


@always_inline
def _exl2_weight_unchecked(
    matrix: EXL2Matrix, input_index: Int, output_index: Int
) -> Float32:
    var packed_input = Int(matrix.q_invperm.unsafe_load(input_index))
    var logical_start = 0
    var selected_group = 0
    for group in range(matrix.group_count):
        var rows = _exl2_group_rows(matrix, group, logical_start)
        if packed_input < logical_start + rows:
            selected_group = group
            break
        logical_start += rows

    var bits = Int(matrix.q_groups.unsafe_load(selected_group * 2))
    var packed_start = Int(
        matrix.q_groups.unsafe_load(selected_group * 2 + 1)
    )
    var local_row = packed_input - logical_start
    var bit_index = local_row * bits
    var word_row = packed_start + bit_index // 32
    var shift = bit_index % 32
    var word = matrix.qweight.unsafe_load(
        word_row * matrix.stored_out_features + output_index
    )
    var quantized = word >> UInt32(shift)
    if shift + bits > 32:
        var next_word = matrix.qweight.unsafe_load(
            (word_row + 1) * matrix.stored_out_features + output_index
        )
        quantized |= next_word << UInt32(32 - shift)
    var mask = (UInt32(1) << UInt32(bits)) - UInt32(1)
    quantized &= mask

    var scale_word = matrix.q_scale.unsafe_load(
        selected_group * (matrix.stored_out_features // 8)
        + output_index // 8
    )
    var scale_code = Int(
        (scale_word >> UInt32((output_index % 8) * 4)) & UInt32(0xF)
    )
    var scale_level = Float32(scale_code + 1)
    var scale = (
        scale_level
        * scale_level
        * matrix.q_scale_max.unsafe_load(selected_group).cast[DType.float32]()
        / Float32(256.0)
    )
    var zero = UInt32(1) << UInt32(bits - 1)
    return (Float32(quantized) - Float32(zero)) * scale


def exl2_weight(
    matrix: EXL2Matrix, input_index: Int, output_index: Int
) raises -> Float32:
    matrix.validate()
    if input_index < 0 or input_index >= matrix.in_features:
        raise Error("exl2_weight: input index out of range")
    if output_index < 0 or output_index >= matrix.out_features:
        raise Error("exl2_weight: output index out of range")
    return _exl2_weight_unchecked(matrix, input_index, output_index)


def dequantize_exl2_matrix(
    matrix: EXL2Matrix,
    output: Pointer[Float16, MutUntrackedOrigin],
    output_elements: Int,
) raises:
    if Int(output) <= 1:
        raise Error("dequantize_exl2_matrix: output pointer must be valid")
    matrix.validate()
    var expected_output = _checked_product(
        matrix.in_features, matrix.out_features, "EXL2 output"
    )
    if output_elements != expected_output:
        raise Error("dequantize_exl2_matrix: output storage length mismatch")
    for output_index in range(matrix.out_features):
        for input_index in range(matrix.in_features):
            output.unsafe_store(
                output_index * matrix.in_features + input_index,
                _exl2_weight_unchecked(
                    matrix, input_index, output_index
                ).cast[DType.float16](),
            )


def gemm_exl2_matrix(
    input: Pointer[Float16, MutUntrackedOrigin],
    input_elements: Int,
    input_rows: Int,
    matrix: EXL2Matrix,
    output: Pointer[Float16, MutUntrackedOrigin],
    output_elements: Int,
) raises:
    if Int(input) <= 1 or Int(output) <= 1:
        raise Error("gemm_exl2_matrix: input and output pointers must be valid")
    matrix.validate()
    var expected_input = _checked_product(
        input_rows, matrix.in_features, "EXL2 GEMM input"
    )
    var expected_output = _checked_product(
        input_rows, matrix.out_features, "EXL2 GEMM output"
    )
    if input_elements != expected_input:
        raise Error("gemm_exl2_matrix: input storage length mismatch")
    if output_elements != expected_output:
        raise Error("gemm_exl2_matrix: output storage length mismatch")
    for row in range(input_rows):
        for output_index in range(matrix.out_features):
            var accumulator = Float32(0.0)
            for input_index in range(matrix.in_features):
                accumulator += input.unsafe_load(
                    row * matrix.in_features + input_index
                ).cast[DType.float32]() * _exl2_weight_unchecked(
                    matrix, input_index, output_index
                )
            output.unsafe_store(
                row * matrix.out_features + output_index,
                accumulator.cast[DType.float16](),
            )


struct HQQ4BitAxis1Matrix(Copyable, ImplicitlyCopyable):
    """Native HQQ 4-bit axis=1 packed matrix and floating metadata."""

    var packed_weights: Pointer[UInt8, MutUntrackedOrigin]
    var packed_elements: Int
    var scales: Pointer[Float16, MutUntrackedOrigin]
    var scale_elements: Int
    var zeros: Pointer[Float16, MutUntrackedOrigin]
    var zero_elements: Int
    var in_features: Int
    var out_features: Int
    var group_size: Int
    var group_count: Int

    def __init__(
        out self,
        packed_weights: Pointer[UInt8, MutUntrackedOrigin],
        packed_elements: Int,
        scales: Pointer[Float16, MutUntrackedOrigin],
        scale_elements: Int,
        zeros: Pointer[Float16, MutUntrackedOrigin],
        zero_elements: Int,
        in_features: Int,
        out_features: Int,
        group_size: Int,
    ) raises:
        self.packed_weights = packed_weights
        self.packed_elements = packed_elements
        self.scales = scales
        self.scale_elements = scale_elements
        self.zeros = zeros
        self.zero_elements = zero_elements
        self.in_features = in_features
        self.out_features = out_features
        self.group_size = group_size
        self.group_count = 0
        if self.in_features <= 0 or self.out_features <= 0:
            raise Error("HQQ4BitAxis1Matrix: dimensions must be positive")
        if self.group_size <= 0:
            raise Error("HQQ4BitAxis1Matrix: group_size must be positive")
        var total = _checked_product(
            self.in_features, self.out_features, "HQQ matrix"
        )
        if total % self.group_size != 0:
            raise Error("HQQ4BitAxis1Matrix: group_size must divide the matrix")
        self.group_count = total // self.group_size
        self.validate()

    def __copyinit__(out self, existing: Self):
        self.packed_weights = existing.packed_weights
        self.packed_elements = existing.packed_elements
        self.scales = existing.scales
        self.scale_elements = existing.scale_elements
        self.zeros = existing.zeros
        self.zero_elements = existing.zero_elements
        self.in_features = existing.in_features
        self.out_features = existing.out_features
        self.group_size = existing.group_size
        self.group_count = existing.group_count

    def validate(self) raises:
        if self.in_features <= 0 or self.out_features <= 0:
            raise Error("HQQ4BitAxis1Matrix: dimensions must be positive")
        if self.group_size <= 0:
            raise Error("HQQ4BitAxis1Matrix: group_size must be positive")
        if (
            Int(self.packed_weights) <= 1
            or Int(self.scales) <= 1
            or Int(self.zeros) <= 1
        ):
            raise Error("HQQ4BitAxis1Matrix: storage pointers must be valid")
        var total = _checked_product(
            self.in_features, self.out_features, "HQQ matrix"
        )
        if total % self.group_size != 0:
            raise Error("HQQ4BitAxis1Matrix: group_size must divide the matrix")
        var expected_groups = total // self.group_size
        if expected_groups % 2 != 0:
            raise Error("HQQ4BitAxis1Matrix: 4-bit packing requires an even group count")
        if self.group_count != expected_groups:
            raise Error("HQQ4BitAxis1Matrix: group_count disagrees with shape")
        if self.packed_elements != total // 2:
            raise Error("HQQ4BitAxis1Matrix: packed storage length mismatch")
        if self.scale_elements != expected_groups:
            raise Error("HQQ4BitAxis1Matrix: scale storage length mismatch")
        if self.zero_elements != expected_groups:
            raise Error("HQQ4BitAxis1Matrix: zero storage length mismatch")


@always_inline
def _hqq_4bit_axis1_weight_unchecked(
    matrix: HQQ4BitAxis1Matrix, input_index: Int, output_index: Int
) -> Float32:
    var linear_index = output_index * matrix.in_features + input_index
    var group = linear_index // matrix.group_size
    var lane = linear_index % matrix.group_size
    var half_groups = matrix.group_count // 2
    var packed_group = group if group < half_groups else group - half_groups
    var packed = matrix.packed_weights.unsafe_load(
        packed_group * matrix.group_size + lane
    )
    var quantized: Int
    if group < half_groups:
        quantized = Int((packed >> 4) & UInt8(0xF))
    else:
        quantized = Int(packed & UInt8(0xF))
    var scale = matrix.scales.unsafe_load(group).cast[DType.float32]()
    var zero = matrix.zeros.unsafe_load(group).cast[DType.float32]()
    return (Float32(quantized) - zero) * scale


def hqq_4bit_axis1_weight(
    matrix: HQQ4BitAxis1Matrix, input_index: Int, output_index: Int
) raises -> Float32:
    matrix.validate()
    if input_index < 0 or input_index >= matrix.in_features:
        raise Error("hqq_4bit_axis1_weight: input index out of range")
    if output_index < 0 or output_index >= matrix.out_features:
        raise Error("hqq_4bit_axis1_weight: output index out of range")
    return _hqq_4bit_axis1_weight_unchecked(
        matrix, input_index, output_index
    )


def dequantize_hqq_4bit_axis1(
    matrix: HQQ4BitAxis1Matrix,
    output: Pointer[Float16, MutUntrackedOrigin],
    output_elements: Int,
) raises:
    if Int(output) <= 1:
        raise Error("dequantize_hqq_4bit_axis1: output pointer must be valid")
    matrix.validate()
    var expected_output = _checked_product(
        matrix.in_features, matrix.out_features, "HQQ output"
    )
    if output_elements != expected_output:
        raise Error("dequantize_hqq_4bit_axis1: output storage length mismatch")
    for output_index in range(matrix.out_features):
        for input_index in range(matrix.in_features):
            output.unsafe_store(
                output_index * matrix.in_features + input_index,
                _hqq_4bit_axis1_weight_unchecked(
                    matrix, input_index, output_index
                ).cast[DType.float16](),
            )


def gemm_hqq_4bit_axis1(
    input: Pointer[Float16, MutUntrackedOrigin],
    input_elements: Int,
    input_rows: Int,
    matrix: HQQ4BitAxis1Matrix,
    output: Pointer[Float16, MutUntrackedOrigin],
    output_elements: Int,
) raises:
    if Int(input) <= 1 or Int(output) <= 1:
        raise Error("gemm_hqq_4bit_axis1: input and output pointers must be valid")
    matrix.validate()
    var expected_input = _checked_product(
        input_rows, matrix.in_features, "HQQ GEMM input"
    )
    var expected_output = _checked_product(
        input_rows, matrix.out_features, "HQQ GEMM output"
    )
    if input_elements != expected_input:
        raise Error("gemm_hqq_4bit_axis1: input storage length mismatch")
    if output_elements != expected_output:
        raise Error("gemm_hqq_4bit_axis1: output storage length mismatch")
    for row in range(input_rows):
        for output_index in range(matrix.out_features):
            var accumulator = Float32(0.0)
            for input_index in range(matrix.in_features):
                accumulator += input.unsafe_load(
                    row * matrix.in_features + input_index
                ).cast[DType.float32]() * _hqq_4bit_axis1_weight_unchecked(
                    matrix, input_index, output_index
                )
            output.unsafe_store(
                row * matrix.out_features + output_index,
                accumulator.cast[DType.float16](),
            )
