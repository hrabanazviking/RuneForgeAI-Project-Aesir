"""Original packed block header reuse, full three-owner values and paired times."""
from std.sys import argv
from core.llama3_cuda import Llama3CUDASession
from tests.test_packed_matrix import synthetic, real_batch, span_guards


def main() raises:
    var args = argv()
    if len(args) != 2: raise Error("usage: test_turing_block_headers MODEL.gguf")
    var s = Llama3CUDASession(args[1],512,prefix_cache=False,prefill_batch=4)
    if s.profile.hidden_size != 3072 or s.profile.layer_count != 28:
        raise Error("Header cache probe requires strict3B")
    print("MODE,turing_mma_staged_header_cache_f16_f32,64,32")
    span_guards()
    comptime for batch in [4,8,16,32]:
        synthetic[12,batch,staged_rows=64,cache_headers=True](s.context)
        synthetic[13,batch,staged_rows=64,cache_headers=True](s.context)
        synthetic[14,batch,staged_rows=64,cache_headers=True](s.context)
    print("SYNTHETIC,144,0")
    var count = 0
    var values = 0
    comptime for batch in [4,8,16,32]:
        real_batch[batch,staged_rows=64,cache_headers=True](s,count,values)
    print("PASS,matrix,"+String(count)+","+String(values)+","+String(count*30))
