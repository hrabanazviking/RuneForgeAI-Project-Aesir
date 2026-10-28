"""Opt-in PTX bisect probe: launch each Gemma 4 session kernel in
isolation on the attached CUDA device and report which ones the driver
JIT accepts. Built to isolate CUDA_ERROR_INVALID_PTX on sm_75: the
session admits and uploads, then dies at first forward inside MAX module
loading, while MAX basics and the Turing MMA kernels pass on the card."""
from max.gpu.host import DeviceContext
from core.gemma4_kernels import (
    Floats, Integers, embedding_kernel, matvec_kernel, packed_matvec_kernel,
    norm_kernel, element_kernel, rope_kernel, cache_kernel, scores_kernel,
    softmax_kernel, attention_kernel, argmax_kernel,
)
from core.packed_quantization import Bytes
from std.gpu import global_idx


def control_kernel(a: Floats, count_arg: Int64):
    var i = Int(global_idx.x)
    if i < Int(count_arg):
        a.unsafe_store(i, a.unsafe_load(i) + Float32(1))


def main() raises:
    var ctx = DeviceContext(0, api="cuda")
    var wbuf = ctx.enqueue_create_buffer[DType.uint8](1 << 20)
    var abuf = ctx.enqueue_create_buffer[DType.float32](65536)
    var kvbuf = ctx.enqueue_create_buffer[DType.float32](65536)
    var obuf = ctx.enqueue_create_buffer[DType.int32](16)
    ctx.synchronize()
    try:
        ctx.enqueue_function[control_kernel](abuf.unsafe_ptr(), Int64(128), grid_dim=1, block_dim=128)
        ctx.synchronize()
        print("OK control_kernel")
    except e:
        print("FAIL control_kernel", e)
    try:
        ctx.enqueue_function[embedding_kernel](wbuf.unsafe_ptr(), abuf.unsafe_ptr(), Int64(0), Int64(0), Int64(128), Int64(0), Int64(0), Float32(1), grid_dim=1, block_dim=128)
        ctx.synchronize()
        print("OK embedding_kernel")
    except e:
        print("FAIL embedding_kernel", e)
    try:
        ctx.enqueue_function[matvec_kernel](wbuf.unsafe_ptr(), abuf.unsafe_ptr(), Int64(0), Int64(0), Int64(64), Int64(2), Int64(0), Int64(1024), grid_dim=1, block_dim=128)
        ctx.synchronize()
        print("OK matvec_kernel")
    except e:
        print("FAIL matvec_kernel", e)
    try:
        ctx.enqueue_function[packed_matvec_kernel[12]](wbuf.unsafe_ptr(), abuf.unsafe_ptr(), Int64(0), Int64(256), Int64(2), Int64(0), Int64(2048), grid_dim=1, block_dim=128)
        ctx.synchronize()
        print("OK packed_matvec_kernel[12]")
    except e:
        print("FAIL packed_matvec_kernel[12]", e)
    try:
        ctx.enqueue_function[packed_matvec_kernel[14]](wbuf.unsafe_ptr(), abuf.unsafe_ptr(), Int64(0), Int64(256), Int64(2), Int64(0), Int64(3072), grid_dim=1, block_dim=128)
        ctx.synchronize()
        print("OK packed_matvec_kernel[14]")
    except e:
        print("FAIL packed_matvec_kernel[14]", e)
    try:
        ctx.enqueue_function[norm_kernel](wbuf.unsafe_ptr(), abuf.unsafe_ptr(), Int64(-1), Int64(0), Int64(4096), Int64(64), Int64(2), Float32(1e-6), Float32(1), grid_dim=1, block_dim=128)
        ctx.synchronize()
        print("OK norm_kernel")
    except e:
        print("FAIL norm_kernel", e)
    try:
        ctx.enqueue_function[element_kernel](wbuf.unsafe_ptr(), abuf.unsafe_ptr(), Int64(1), Int64(0), Int64(8192), Int64(5120), Int64(128), Float32(1), grid_dim=1, block_dim=128)
        ctx.synchronize()
        print("OK element_kernel")
    except e:
        print("FAIL element_kernel", e)
    try:
        ctx.enqueue_function[rope_kernel](wbuf.unsafe_ptr(), abuf.unsafe_ptr(), Int64(0), Int64(64), Int64(2), Int64(1), Float32(10000), Int64(-1), grid_dim=1, block_dim=128)
        ctx.synchronize()
        print("OK rope_kernel")
    except e:
        print("FAIL rope_kernel", e)
    try:
        ctx.enqueue_function[cache_kernel](abuf.unsafe_ptr(), kvbuf.unsafe_ptr(), Int64(0), Int64(8192), Int64(0), Int64(16), Int64(64), Int64(0), grid_dim=1, block_dim=128)
        ctx.synchronize()
        print("OK cache_kernel")
    except e:
        print("FAIL cache_kernel", e)
    try:
        ctx.enqueue_function[scores_kernel](abuf.unsafe_ptr(), kvbuf.unsafe_ptr(), Int64(0), Int64(16384), Int64(0), Int64(16), Int64(64), Int64(2), Int64(1), Int64(0), Int64(4), grid_dim=2, block_dim=128)
        ctx.synchronize()
        print("OK scores_kernel")
    except e:
        print("FAIL scores_kernel", e)
    try:
        ctx.enqueue_function[softmax_kernel](abuf.unsafe_ptr(), Int64(16384), Int64(4), Int64(2), grid_dim=1, block_dim=128)
        ctx.synchronize()
        print("OK softmax_kernel")
    except e:
        print("FAIL softmax_kernel", e)
    try:
        ctx.enqueue_function[attention_kernel](abuf.unsafe_ptr(), kvbuf.unsafe_ptr(), Int64(16384), Int64(20480), Int64(0), Int64(16), Int64(64), Int64(2), Int64(1), Int64(0), Int64(4), grid_dim=1, block_dim=128)
        ctx.synchronize()
        print("OK attention_kernel")
    except e:
        print("FAIL attention_kernel", e)
    try:
        ctx.enqueue_function[argmax_kernel](abuf.unsafe_ptr(), obuf.unsafe_ptr(), Int64(0), Int64(128), grid_dim=1, block_dim=32)
        ctx.synchronize()
        print("OK argmax_kernel")
    except e:
        print("FAIL argmax_kernel", e)
    print("PTX-PROBE-DONE")
