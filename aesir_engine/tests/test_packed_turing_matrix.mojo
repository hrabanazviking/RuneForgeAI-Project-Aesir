"""Opt-in physical original packed weights through the public Turing MMA API."""
from std.sys import argv
from core.llama3_cuda import Llama3CUDASession
from tests.test_packed_matrix import synthetic, real_batch, span_guards


def main() raises:
    var args = argv()
    if len(args) != 2:
        raise Error("usage: test_packed_turing_matrix MODEL.gguf")
    var s = Llama3CUDASession(args[1],512,prefix_cache=False,prefill_batch=4)
    if s.profile.hidden_size != 3072 or s.profile.layer_count != 28:
        raise Error("Packed MMA probe requires strict 3B fixture")
    print("MODE,turing_mma_split_weight_f16_f32")
    span_guards()
    comptime for batch in [4,8,16,32]:
        synthetic[12,batch,turing=True](s.context)
        synthetic[13,batch,turing=True](s.context)
        synthetic[14,batch,turing=True](s.context)
    print("SYNTHETIC,144,0")
    var count = 0
    var values = 0
    comptime for batch in [4,8,16,32]:
        real_batch[batch,turing=True](s,count,values)
    print("PASS,matrix,"+String(count)+","+String(values)+","+String(count*20))
