# loader/exl2.mojo
# EXL2ModelSeer: local descriptors and unsupported parser boundary

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
    if check_cuda_evidence:
        raise Error("EXL2 execution contract unverified: requires physical NVIDIA CUDA hardware evidence and custom EXL2 CUDA dequantization kernel")


struct EXL2ModelSeer:
    """
    ᛖᚲᛋᛚᛟ·ᛋᛖᛖᚱ — The Vision of the EXL2 Variable-Bit Matrix (EXL2ModelSeer)
    ════════════════════════════════════════════════════════════════════
    Preserves EXL2-shaped sub-block descriptors and the physical CUDA evidence
    boundary. EXL2 metadata parsing and execution are unsupported.
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
        Rejects synthetic parsing until an authoritative EXL2 decoder exists.
        """
        if size < 8:
            raise Error("EXL2 binary header span too small (< 8 bytes)")
        
        _ = bytes
        raise Error(
            "EXL2 metadata parsing is not implemented; "
            "fixed bitrate metadata is prohibited"
        )

    def add_sub_block(mut self, bit_rate: Float32, num_weights: Int = 256):
        """
        Registers an EXL2 variable-bit sub-block (e.g. 3.5 bpw, 4.0 bpw, 6.0 bpw).
        """
        var idx = len(self.sub_blocks)
        self.sub_blocks.append(EXL2SubBlockDescriptor(idx, bit_rate, num_weights))
        self.total_weights += Int64(num_weights)

    def map_to_well(self, mut well: MimirWell) -> Bool:
        """Returns false until EXL2 tensors are parsed and mapped."""
        _ = well
        return False
