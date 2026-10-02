"""Explicit wider shared-input Turing choices, identical complete precision gates."""
from std.sys import argv
from core.llama3_cuda import Llama3CUDASession
from tests.test_packed_matrix import synthetic, real_batch, span_guards


def run[rows: Int,columns: Int](path: String) raises:
    var s = Llama3CUDASession(path,512,prefix_cache=False,prefill_batch=4)
    if s.profile.hidden_size != 3072 or s.profile.layer_count != 28:
        raise Error("Wide Turing probe requires strict 3B fixture")
    print("MODE,turing_mma_staged_wide_f16_f32,"+String(rows)+","+String(columns))
    span_guards()
    comptime for batch in [4,8,16,32]:
        synthetic[12,batch,staged_rows=rows,staged_columns=columns](s.context)
        synthetic[13,batch,staged_rows=rows,staged_columns=columns](s.context)
        synthetic[14,batch,staged_rows=rows,staged_columns=columns](s.context)
    print("SYNTHETIC,144,0")
    var count = 0
    var values = 0
    comptime for batch in [4,8,16,32]:
        real_batch[batch,staged_rows=rows,staged_columns=columns](s,count,values)
    print("PASS,matrix,"+String(count)+","+String(values)+","+String(count*20))


def main() raises:
    var args = argv()
    if len(args) != 4:
        raise Error("usage: test_turing_wide_staging MODEL.gguf ROW_TILE INPUT_COLUMNS")
    var rows = Int(args[2])
    var columns = Int(args[3])
    if rows == 32 and columns == 64: run[32,64](args[1])
    elif rows == 32 and columns == 128: run[32,128](args[1])
    elif rows == 64 and columns == 64: run[64,64](args[1])
    elif rows == 64 and columns == 128: run[64,128](args[1])
    else: raise Error("Wide staged Turing choice is not declared")
