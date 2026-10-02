"""Test-owned grid-y wrappers; original x/lane arithmetic and F16 casts stay."""
from std.gpu import block_idx, global_idx
from core.gemma4_kernels import Floats
from core.packed_quantization import Bytes
from core.llama3_kernels import Halves, llama_rope_transform, llama_cache_cell


def batched_rope(a: Floats,src: Int64,width: Int64,heads: Int64,position: Int64,
    frequency: Float32,neox: Int64,stride: Int64):
    var token = Int64(block_idx.y)
    llama_rope_transform(a,src+token*stride,width,heads,position+token,frequency,neox,Float32(1))


def batched_scaled_rope(w: Bytes,a: Floats,src: Int64,width: Int64,heads: Int64,
    position: Int64,frequency: Float32,neox: Int64,factors: Int64,stride: Int64):
    var token = Int64(block_idx.y)
    var half = Int(width)//2
    var i = Int(global_idx.x)
    if i < Int(heads)*half:
        var factor = w.unsafe_offset(Int(factors)).unsafe_bitcast[Float32]().unsafe_load(i%half)
        llama_rope_transform(a,src+token*stride,width,heads,position+token,frequency,neox,factor)


def batched_cache(a: Floats,kv: Halves,key: Int64,value: Int64,offset: Int64,
    capacity: Int64,width: Int64,position: Int64,stride: Int64):
    var token = Int64(block_idx.y)
    llama_cache_cell(a,kv,key+token*stride,value+token*stride,offset,capacity,width,position+token)
