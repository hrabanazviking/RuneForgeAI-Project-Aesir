# core/max_gate.mojo
# Legacy MAX graph gateway boundary. Real CUDA execution lives in
# cuda_resources.mojo and cuda_compute.mojo with selected device ownership.

from .mimir_well import RuneTensor, f16

struct MAXGate:
    """
    Reserved graph gateway without a graph/device runtime owner.
    """
    var is_initialized: Bool
    var num_devices: Int
    var device_name: String

    def __init__(out self):
        self.is_initialized = False
        self.num_devices = 0
        self.device_name = String("")

    def is_available(self) -> Bool:
        """Returns false; this class performs no runtime discovery."""
        return False

    def launch_gemm_max(self, A: RuneTensor[f16], B: RuneTensor[f16], mut C: RuneTensor[f16]) raises:
        """
        Validates tensor shapes, then rejects because no MAX graph executor is
        attached. It never substitutes a host scalar loop for acceleration.
        """
        if A.rows <= 0 or A.cols <= 0 or B.rows <= 0 or B.cols <= 0:
            raise Error("MAXGate: tensor dimensions must be positive")

        var M = A.rows
        var K = A.cols
        var N = B.cols

        if B.rows != K or C.rows != M or C.cols != N:
            raise Error("MAXGate: Incompatible GEMM shape dimensions")

        raise Error("MAXGate graph execution is not implemented; use an explicit CUDA executor")
