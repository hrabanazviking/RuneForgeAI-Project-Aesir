from core.mimir_well import MimirWell, RuneTensor, Scalar, f16
from core.compute import apply_rope


def capture_layout(neox: Bool) raises:
    var well = MimirWell(1024 * 1024)
    var q = RuneTensor[f16](2, 8, well.allocate(16))
    var k = RuneTensor[f16](3, 4, well.allocate(12))
    for index in range(q.size):
        var numerator = (index % 11) - 5
        q.data.unsafe_store(index, Scalar[f16](Float32(numerator) / 4.0))
    for index in range(k.size):
        var numerator = (index % 7) - 3
        k.data.unsafe_store(index, Scalar[f16](Float32(numerator) / 3.0))

    print("LAYOUT ", "neox" if neox else "interleaved")
    print("Q_SHAPE 2 8")
    print("Q_INPUT")
    for index in range(q.size):
        print(Float32(q.data.unsafe_load(index)))
    print("K_SHAPE 3 4")
    print("K_INPUT")
    for index in range(k.size):
        print(Float32(k.data.unsafe_load(index)))

    apply_rope(q, k, 5, 4, 10000.0, neox)

    print("Q_OUTPUT")
    for index in range(q.size):
        print(Float32(q.data.unsafe_load(index)))
    print("K_OUTPUT")
    for index in range(k.size):
        print(Float32(k.data.unsafe_load(index)))


def main() raises:
    capture_layout(False)
    capture_layout(True)
