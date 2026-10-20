from core.mimir_well import MimirWell, RuneTensor, Scalar, f16
from core.compute import flash_attention_2


def main() raises:
    var seq_len = 3
    var cols = 4
    var head_dim = 2
    var well = MimirWell(4096)
    var Q = RuneTensor[f16](seq_len, cols, well.allocate(seq_len * cols))
    var K = RuneTensor[f16](seq_len, cols, well.allocate(seq_len * cols))
    var V = RuneTensor[f16](seq_len, cols, well.allocate(seq_len * cols))
    var Out = RuneTensor[f16](seq_len, cols, well.allocate(seq_len * cols))
    for index in range(seq_len * cols):
        var row = index // cols
        var col = index % cols
        Q.data.unsafe_store(index, Scalar[f16](Float32((row + 1) * (col + 1)) / 4.0))
        K.data.unsafe_store(index, Scalar[f16](Float32((row + 2) - col) / 3.0))
        V.data.unsafe_store(index, Scalar[f16](Float32((row + 1) * 10 + col)))
    print("SEQ_LEN 3 COLS 4 HEAD_DIM 2")
    print("Q")
    for index in range(Q.size): print(Float32(Q.data.unsafe_load(index)))
    print("K")
    for index in range(K.size): print(Float32(K.data.unsafe_load(index)))
    print("V")
    for index in range(V.size): print(Float32(V.data.unsafe_load(index)))
    flash_attention_2(Q, K, V, Out, seq_len, head_dim)
    print("OUT")
    for index in range(Out.size): print(Float32(Out.data.unsafe_load(index)))
