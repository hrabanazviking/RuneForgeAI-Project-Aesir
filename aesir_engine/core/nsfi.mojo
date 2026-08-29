# core/nsfi.mojo
# Experimental deterministic fractal-shaped tensor transform

from std.math import sin, cos
from .mimir_well import RuneTensor, f16

struct NSFIEngine:
    """
    Local mathematical experiment that writes deterministic values into a
    tensor. It does not reconstruct trained model weights or preserve accuracy.
    """
    var enabled: Bool
    var num_attractor_params: Int
    var compression_ratio: Float64

    def __init__(out self):
        self.enabled = False
        self.num_attractor_params = 16
        self.compression_ratio = 0.98

    def reconstruct_fractal_weights(self, seed_a: Float64, seed_b: Float64, mut target_weight: RuneTensor[f16]) raises:
        """
        Writes an experimental sinusoidal pattern into a caller-owned tensor.
        """
        if not self.enabled:
            return

        if target_weight.rows <= 0 or target_weight.cols <= 0:
            raise Error("NSFIEngine requires a non-empty target tensor")

        var rows = target_weight.rows
        var cols = target_weight.cols

        for r in range(rows):
            for c in range(cols):
                var x = (Float64(r) / Float64(rows)) * seed_a
                var y = (Float64(c) / Float64(cols)) * seed_b
                var fractal_val = sin(x * 12.5) * cos(y * 8.3) + sin(x + y)
                target_weight.set(r, c, Scalar[f16](fractal_val * 0.1))
