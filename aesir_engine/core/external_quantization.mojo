"""Validated execution primitives for metadata-bearing quantized matrices."""

from std.memory import Pointer


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
