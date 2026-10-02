"""Explicit physical matrix staging choices; same fixed primitive gates."""
from std.sys import argv
from core.llama3_cuda import Llama3CUDASession
from tests.test_packed_matrix import synthetic, real_batch, span_guards


def run_tile[rows: Int, columns: Int](path: String) raises:
    var s = Llama3CUDASession(path,512,prefix_cache=False,prefill_batch=4)
    if s.profile.hidden_size != 3072 or s.profile.layer_count != 28:
        raise Error("Matrix tuning requires strict 3B fixture")
    print("TILE," + String(rows) + "," + String(columns))
    span_guards[rows,columns]()
    comptime for batch in [4,8,16,32]:
        synthetic[12,batch,rows,columns](s.context)
        synthetic[13,batch,rows,columns](s.context)
        synthetic[14,batch,rows,columns](s.context)
    print("SYNTHETIC,144,0")
    var count = 0
    var values = 0
    comptime for batch in [4,8,16,32]:
        real_batch[batch,rows,columns](s,count,values)
    print("PASS,matrix," + String(count) + "," + String(values) + "," + String(count * 20))


def main() raises:
    var args = argv()
    if len(args) != 4:
        raise Error("usage: test_matrix_tile_tuning MODEL.gguf TILE_ROWS TILE_COLUMNS")
    var rows = Int(args[2])
    var columns = Int(args[3])
    if rows == 8 and columns == 128:
        run_tile[8,128](args[1])
    elif rows == 16 and columns == 64:
        run_tile[16,64](args[1])
    elif rows == 16 and columns == 128:
        run_tile[16,128](args[1])
    elif rows == 32 and columns == 64:
        run_tile[32,64](args[1])
    elif rows == 32 and columns == 128:
        run_tile[32,128](args[1])
    else:
        raise Error("Matrix tuning choice is not declared")
