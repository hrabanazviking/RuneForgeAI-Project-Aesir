"""Owned exact original three-owner token-partition experiment."""
from std.sys import argv
from core.llama3_cuda import Llama3CUDASession
from tests.test_packed_matrix import synthetic, real_batch, span_guards


def collect[rows: Int,tokens: Int](mut s: Llama3CUDASession) raises:
    print("MODE,turing_mma_token_partition_f16_f32,"+String(rows)+","+String(tokens)+",32")
    span_guards()
    comptime for batch in [4,8,16,32]:
        synthetic[12,batch,partition_rows=rows,token_tile=tokens](s.context)
        synthetic[13,batch,partition_rows=rows,token_tile=tokens](s.context)
        synthetic[14,batch,partition_rows=rows,token_tile=tokens](s.context)
    print("SYNTHETIC,144,0")
    var count = 0
    var values = 0
    comptime for batch in [4,8,16,32]:
        real_batch[batch,partition_rows=rows,token_tile=tokens](s,count,values)
    print("PASS,matrix,"+String(count)+","+String(values)+","+String(count*30))


def main() raises:
    var args = argv()
    if len(args) != 4: raise Error("usage: test_turing_token_partition MODEL.gguf ROWS[64|128] TOKENS[8|16]")
    var rows = Int(args[2])
    var tokens = Int(args[3])
    if (rows != 64 and rows != 128) or (tokens != 8 and tokens != 16): raise Error("Unsupported token partition geometry")
    var s = Llama3CUDASession(args[1],512,prefix_cache=False,prefill_batch=4)
    if s.profile.hidden_size != 3072 or s.profile.layer_count != 28: raise Error("Token partition requires strict3B")
    if rows == 64:
        if tokens == 8: collect[64,8](s)
        else: collect[64,16](s)
    else:
        if tokens == 8: collect[128,8](s)
        else: collect[128,16](s)
