from core.mimir_well import MimirWell, RuneTensor, f16
from core.compute import rmsnorm


def run_width(cols: Int) raises:
    var rows = 2
    var well = MimirWell((rows * cols + cols + 32) * 2)
    var values = RuneTensor[f16](rows, cols, well.allocate(rows * cols))
    var weights = RuneTensor[f16](1, cols, well.allocate(cols))
    for i in range(rows * cols):
        var numerator = (i % 13) - 6
        values.data.unsafe_store(
            i, Scalar[f16](Float32(numerator) / 3.0)
        )
    for c in range(cols):
        var numerator = (c % 7) - 3
        weights.data.unsafe_store(
            c, Scalar[f16](Float32(numerator) / 5.0)
        )
    print("WIDTH ", cols)
    print("WEIGHTS")
    for c in range(cols):
        print(Float32(weights.data.unsafe_load(c)))
    print("INPUT")
    for i in range(rows * cols):
        print(Float32(values.data.unsafe_load(i)))
    rmsnorm(values, weights, 1e-5)
    print("OUTPUT")
    for i in range(rows * cols):
        print(Float32(values.data.unsafe_load(i)))


def main() raises:
    run_width(3)
    run_width(15)
    run_width(16)
    run_width(17)
    run_width(33)
