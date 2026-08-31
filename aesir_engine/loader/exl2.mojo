# loader/exl2.mojo
# EXL2 metadata descriptors and explicit unavailable format/runtime boundary.

from std.math import isinf, isnan
from std.memory import Pointer
from core.mimir_well import MimirWell, f16

struct EXL2SubBlockDescriptor(Copyable):
    """Describes an EXL2 variable-bit quantized sub-block."""
    var sub_block_index: Int
    var bit_rate: Float32 # 2.0 to 8.0 bits per weight
    var num_weights: Int
    var scale_f16: Scalar[f16]

    def __init__(out self, sub_block_index: Int, bit_rate: Float32, num_weights: Int = 256, scale_f16: Scalar[f16] = Scalar[f16](1.0)):
        self.sub_block_index = sub_block_index
        self.bit_rate = bit_rate
        self.num_weights = num_weights
        self.scale_f16 = scale_f16

    def __copyinit__(out self, existing: Self):
        self.sub_block_index = existing.sub_block_index
        self.bit_rate = existing.bit_rate
        self.num_weights = existing.num_weights
        self.scale_f16 = existing.scale_f16


def validate_exl2_format_contract(check_cuda_evidence: Bool = True) raises:
    """
    Validates EXL2 execution contract.
    EXL2 requires physical NVIDIA CUDA hardware & custom EXL2 CUDA kernels.
    Raises explicit Error if physical CUDA hardware is absent or kernel uncompiled.
    """
    _ = check_cuda_evidence
    raise Error("EXL2 execution is not implemented: model parsing and custom CUDA kernels are unavailable")


struct EXL2ModelSeer:
    """
    ᛖᚲᛋᛚᛟ·ᛋᛖᛖᚱ — The Vision of the EXL2 Variable-Bit Matrix (EXL2ModelSeer)
    ════════════════════════════════════════════════════════════════════
    Holds caller-declared EXL2-like sub-block metadata. It does not parse an
    ExLlamaV2 model directory or safetensors files and cannot execute them.
    """
    var model_path: String
    var avg_bitrate: Float32
    var total_weights: Int64
    var sub_blocks: List[EXL2SubBlockDescriptor]

    def __init__(out self, model_path: String):
        self.model_path = model_path
        self.avg_bitrate = 0.0
        self.total_weights = 0
        self.sub_blocks = List[EXL2SubBlockDescriptor]()

    def parse_exl2_header_bytes(mut self, bytes: Pointer[Scalar[DType.uint8], MutUntrackedOrigin], size: Int) raises -> Bool:
        """
        Reserved byte-parser surface. EXL2 is not a standalone magic-header
        format, so accepting an invented `EXL2` prefix would be misleading.
        """
        _ = bytes
        _ = size
        raise Error("EXL2 byte parsing is not implemented; EXL2 models require validated config and safetensors artifacts")

    def add_sub_block(mut self, bit_rate: Float32, num_weights: Int = 256) raises:
        """
        Registers an EXL2 variable-bit sub-block (e.g. 3.5 bpw, 4.0 bpw, 6.0 bpw).
        """
        if isnan(bit_rate) or isinf(bit_rate) or bit_rate < 2.0 or bit_rate > 8.0:
            raise Error("EXL2 metadata bit rate must be finite and between 2 and 8")
        if num_weights <= 0:
            raise Error("EXL2 metadata weight count must be positive")
        if self.total_weights > Int64(0x7FFFFFFFFFFFFFFF) - Int64(num_weights):
            raise Error("EXL2 metadata total weight count overflow")
        var idx = len(self.sub_blocks)
        self.sub_blocks.append(EXL2SubBlockDescriptor(idx, bit_rate, num_weights))
        self.total_weights += Int64(num_weights)
        var weighted_sum = Float64(0.0)
        for block in self.sub_blocks:
            weighted_sum += Float64(block.bit_rate) * Float64(block.num_weights)
        self.avg_bitrate = Float32(weighted_sum / Float64(self.total_weights))

    def map_to_well(mut self, mut well: MimirWell) raises -> Bool:
        """Refuses mapping until real safetensors parsing and kernels exist."""
        _ = well
        raise Error("EXL2 tensor mapping and execution are not implemented")
