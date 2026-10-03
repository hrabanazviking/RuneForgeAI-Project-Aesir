"""Narrow16-column shared staging: exact three-owner primitive values and paired times."""
from std.sys import argv
from core.llama3_cuda import Llama3CUDASession
from tests.test_packed_matrix import synthetic, real_batch, span_guards


def collect[rows: Int](mut s: Llama3CUDASession) raises:
    print("MODE,turing_mma_staged_narrow_f16_f32,"+String(rows)+",16")
    span_guards()
    comptime for batch in [4,8,16,32]:
        synthetic[12,batch,staged_rows=64,narrow_rows=rows](s.context)
        synthetic[13,batch,staged_rows=64,narrow_rows=rows](s.context)
        synthetic[14,batch,staged_rows=64,narrow_rows=rows](s.context)
    print("SYNTHETIC,144,0")
    var count = 0
    var values = 0
    comptime for batch in [4,8,16,32]:
        real_batch[batch,staged_rows=64,narrow_rows=rows](s,count,values)
    print("PASS,matrix,"+String(count)+","+String(values)+","+String(count*30))


def main() raises:
    var args = argv()
    if len(args) != 3: raise Error("usage: test_turing_narrow_staging MODEL.gguf ROWS(64|128)")
    var rows = Int(args[2])
    if rows != 64 and rows != 128: raise Error("Unsupported narrow CTA rows")
    var s = Llama3CUDASession(args[1],512,prefix_cache=False,prefill_batch=4)
    if s.profile.hidden_size != 3072 or s.profile.layer_count != 28: raise Error("Row reuse probe requires strict3B")
    if rows == 64: collect[64](s)
    else: collect[128](s)
