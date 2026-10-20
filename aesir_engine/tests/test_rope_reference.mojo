"""Deterministic scalar-F32 oracle checks for CPU apply_rope."""

from std.math import cos, sin

from core.mimir_well import MimirWell, RuneTensor, Scalar, f16, f32
from core.compute import apply_rope


def check_layout(neox: Bool, start_pos: Int) raises:
    var q_rows = 3
    var q_cols = 8
    var k_rows = 2
    var k_cols = 4
    var head_dim = 4
    var well = MimirWell(4096)
    var Q = RuneTensor[f16](q_rows, q_cols, well.allocate(q_rows * q_cols))
    var K = RuneTensor[f16](k_rows, k_cols, well.allocate(k_rows * k_cols))
    for index in range(Q.size):
        Q.data.unsafe_store(index, Scalar[f16](Float32((index % 9) - 4) / 3.0))
    for index in range(K.size):
        K.data.unsafe_store(index, Scalar[f16](Float32((index % 7) - 3) / 2.0))

    var expected_q = List[Scalar[f16]]()
    var expected_k = List[Scalar[f16]]()
    for index in range(Q.size):
        expected_q.append(Q.data.unsafe_load(index))
    for index in range(K.size):
        expected_k.append(K.data.unsafe_load(index))

    var half = head_dim // 2
    for row in range(q_rows):
        for head in range(q_cols // head_dim):
            for i in range(half):
                var freq: Scalar[f32] = 1.0 / (Scalar[f32](10000.0) ** (Float32(2 * i) / Float32(head_dim)))
                var angle = Float32(start_pos + row) * freq
                var c = cos(angle).cast[f16]()
                var s = sin(angle).cast[f16]()
                var base = row * q_cols + head * head_dim
                var idx0 = base + (i if neox else 2 * i)
                var idx1 = idx0 + (half if neox else 1)
                var x0 = expected_q[idx0]
                var x1 = expected_q[idx1]
                expected_q[idx0] = x0 * c - x1 * s
                expected_q[idx1] = x0 * s + x1 * c
    for row in range(k_rows):
        for head in range(k_cols // head_dim):
            for i in range(half):
                var freq: Scalar[f32] = 1.0 / (Scalar[f32](10000.0) ** (Float32(2 * i) / Float32(head_dim)))
                var angle = Float32(start_pos + row) * freq
                var c = cos(angle).cast[f16]()
                var s = sin(angle).cast[f16]()
                var base = row * k_cols + head * head_dim
                var idx0 = base + (i if neox else 2 * i)
                var idx1 = idx0 + (half if neox else 1)
                var x0 = expected_k[idx0]
                var x1 = expected_k[idx1]
                expected_k[idx0] = x0 * c - x1 * s
                expected_k[idx1] = x0 * s + x1 * c

    apply_rope(Q, K, start_pos, head_dim, 10000.0, neox)
    for index in range(Q.size):
        if Q.data.unsafe_load(index) != expected_q[index]:
            raise Error("RoPE Q differs from scalar reference")
    for index in range(K.size):
        if K.data.unsafe_load(index) != expected_k[index]:
            raise Error("RoPE K differs from scalar reference")


def test_rope_reference() raises:
    check_layout(False, 0)
    check_layout(False, 7)
    check_layout(True, 0)
    check_layout(True, 7)
    print("PASS: RoPE scalar F32 reference across layouts, rows, heads, and positions")


def main() raises:
    test_rope_reference()
