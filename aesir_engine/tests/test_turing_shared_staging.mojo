"""Explicit row-staged packed Turing MMA choices under identical physical gates."""
from std.sys import argv
from core.llama3_cuda import Llama3CUDASession
from tests.test_packed_matrix import synthetic, real_batch, span_guards


def run[rows: Int](path: String) raises:
    var s = Llama3CUDASession(path,512,prefix_cache=False,prefill_batch=4)
    if s.profile.hidden_size != 3072 or s.profile.layer_count != 28:
        raise Error("Staged Turing probe requires strict 3B fixture")
    print("MODE,turing_mma_staged_f16_f32,"+String(rows))
    span_guards()
    comptime for batch in [4,8,16,32]:
        synthetic[12,batch,staged_rows=rows](s.context)
        synthetic[13,batch,staged_rows=rows](s.context)
        synthetic[14,batch,staged_rows=rows](s.context)
    print("SYNTHETIC,144,0")
    var count = 0
    var values = 0
    comptime for batch in [4,8,16,32]:
        real_batch[batch,staged_rows=rows](s,count,values)
    print("PASS,matrix,"+String(count)+","+String(values)+","+String(count*20))


def main() raises:
    var args = argv()
    if len(args) != 3:
        raise Error("usage: test_turing_shared_staging MODEL.gguf ROW_TILE")
    var rows = Int(args[2])
    if rows == 16: run[16](args[1])
    elif rows == 32: run[32](args[1])
    elif rows == 64: run[64](args[1])
    else: raise Error("Staged Turing row tile is not declared")
