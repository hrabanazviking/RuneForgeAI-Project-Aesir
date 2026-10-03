"""Opt-in actual SIMT matrix rows/guards, real weights and paired primitive times.

Native reference parity is bounded-error, not an independent numerical oracle.
The complete CSV is admitted by optional check_packed_matrix.py using gguf/NumPy.
No runtime dispatch or larger prefill-control policy is changed by this probe.
"""
from std.sys import argv
from std.ffi import external_call
from std.memory import Pointer
from std.math import abs, sqrt, isfinite
from max.gpu.host import DeviceContext, DeviceBuffer
from core.packed_matrix import project_matrix, admit_matrix
from core.packed_turing_matrix import project_turing, project_turing_staged, project_turing_large_rows, project_turing_narrow
from core.packed_turing_loop import project_turing_loop
from core.packed_turing_partition import project_turing_partition
from core.packed_projection import four_matvec_kernel, block_matvec_kernel, ProjectionFloats
from core.packed_quantization import Bytes
from core.llama3_cuda import Llama3CUDASession


def candidate[kind: Int,batch: Int,tile_rows: Int,tile_columns: Int,turing: Bool,staged_rows: Int,staged_columns: Int,cache_headers: Bool = False,large_rows: Int = 0,narrow_rows: Int = 0,loop_rows: Int = 0,partition_rows: Int = 0,token_tile: Int = 0](
    ctx: DeviceContext,w: DeviceBuffer[DType.uint8],a: DeviceBuffer[DType.float32],
    base: Int,columns: Int,rows: Int,src: Int,dst: Int,stride: Int,tokens: Int) raises:
    """Explicit opt-in dispatch; existing SIMT harness defaults stay unchanged."""
    comptime assert not (turing and staged_rows != 0)
    comptime assert staged_rows != 0 or staged_columns == 32
    comptime assert not (cache_headers and large_rows != 0)
    comptime assert narrow_rows == 0 or (not cache_headers and large_rows == 0 and not turing)
    comptime assert loop_rows == 0 or (not cache_headers and large_rows == 0 and narrow_rows == 0 and not turing)
    comptime assert partition_rows == 0 or ((partition_rows == 64 or partition_rows == 128) and (token_tile == 8 or token_tile == 16) and staged_rows == 0 and staged_columns == 32 and not cache_headers and large_rows == 0 and narrow_rows == 0 and loop_rows == 0 and not turing)
    comptime assert partition_rows != 0 or token_tile == 0
    comptime if partition_rows != 0:
        project_turing_partition[kind,batch,partition_rows,token_tile](ctx,w,a,base,columns,rows,src,dst,stride,tokens)
    elif loop_rows != 0:
        project_turing_loop[kind,batch,loop_rows](ctx,w,a,base,columns,rows,src,dst,stride,tokens)
    elif narrow_rows != 0:
        project_turing_narrow[kind,batch,narrow_rows](ctx,w,a,base,columns,rows,src,dst,stride,tokens)
    elif large_rows != 0:
        project_turing_large_rows[kind,batch,large_rows](ctx,w,a,base,columns,rows,src,dst,stride,tokens)
    elif staged_rows != 0:
        project_turing_staged[kind,batch,staged_rows,staged_columns,0,cache_headers](ctx,w,a,base,columns,rows,src,dst,stride,tokens)
    elif turing:
        project_turing[kind,batch](ctx,w,a,base,columns,rows,src,dst,stride,tokens)
    else:
        project_matrix[kind,batch,tile_rows,tile_columns](ctx,w,a,base,columns,rows,src,dst,stride,tokens)


def seconds() raises -> Float64:
    var stamp = InlineArray[Int64, 2](fill=0)
    if external_call["clock_gettime", Int32](Int32(1), stamp.unsafe_ptr()) != 0:
        raise Error("Matrix timing clock failed")
    return Float64(stamp[0]) + Float64(stamp[1]) / 1000000000.0


def reference[kind: Int, batch: Int](ctx: DeviceContext, w: DeviceBuffer[DType.uint8],
    a: DeviceBuffer[DType.float32], base: Int, columns: Int, rows: Int, dst: Int, stride: Int, tokens: Int) raises:
    var wp = Bytes(unsafe_from_address=Int(w.unsafe_ptr()))
    var ap = ProjectionFloats(unsafe_from_address=Int(a.unsafe_ptr()))
    if tokens == batch:
        for start in range(0, batch, 4):
            ctx.enqueue_function[four_matvec_kernel[kind]](wp, ap, Int64(base), Int64(columns),
                Int64(rows), Int64(start * stride), Int64(start * stride + dst), Int64(stride),
                grid_dim=(rows + 3) // 4, block_dim=128)
    else:
        for token in range(tokens):
            ctx.enqueue_function[block_matvec_kernel[kind]](wp, ap, Int64(base), Int64(columns),
                Int64(rows), Int64(token * stride), Int64(token * stride + dst),
                grid_dim=(rows + 3) // 4, block_dim=128)


def selected_original[kind: Int,batch: Int](ctx: DeviceContext,w: DeviceBuffer[DType.uint8],a: DeviceBuffer[DType.float32],
    base: Int,columns: Int,rows: Int,src: Int,dst: Int,stride: Int,tokens: Int) raises:
    """Source-selected original: down128 only at canonical down batch32."""
    if batch == 32 and columns == 8192 and rows == 3072:
        project_turing_large_rows[kind,batch,128](ctx,w,a,base,columns,rows,src,dst,stride,tokens)
    else:
        project_turing_staged[kind,batch,64,32](ctx,w,a,base,columns,rows,src,dst,stride,tokens)


def exercise[kind: Int, batch: Int, tile_rows: Int = 32, tile_columns: Int = 32, turing: Bool = False,staged_rows: Int = 0,staged_columns: Int = 32,cache_headers: Bool = False,large_rows: Int = 0,narrow_rows: Int = 0,loop_rows: Int = 0,partition_rows: Int = 0,token_tile: Int = 0](ctx: DeviceContext, w: DeviceBuffer[DType.uint8],
    base: Int, columns: Int, rows: Int, tokens: Int, case_index: Int, name: String, real: Bool) raises -> Int:
    var span = ((rows + 31) // 32) * 32
    var src = 17
    var dst = src + columns + 13
    var reference_offset = dst + span + 13
    var stride = reference_offset + span + 17
    var a = ctx.enqueue_create_buffer[DType.float32](batch * stride)
    var h = ctx.enqueue_create_host_buffer[DType.float32](batch * stride)
    for i in range(batch * stride):
        h[i] = -9876
    for token in range(tokens):
        for col in range(columns):
            h[token * stride + src + col] = Float32((col * 7 + token * 13) % 29 - 14) / 16.0
    ctx.enqueue_copy(a, h)
    # References borrow a pointer at src; output stays in the same token stride.
    var shifted = ProjectionFloats(unsafe_from_address=Int(a.unsafe_ptr())).unsafe_offset(src)
    var wp = Bytes(unsafe_from_address=Int(w.unsafe_ptr()))
    for token in range(tokens):
        ctx.enqueue_function[block_matvec_kernel[kind]](wp, shifted, Int64(base), Int64(columns),
            Int64(rows), Int64(token * stride), Int64(token * stride + reference_offset - src),
            grid_dim=(rows + 3) // 4, block_dim=128)
    var native_snapshot = List[Float32]()
    comptime if cache_headers or large_rows != 0 or narrow_rows != 0 or loop_rows != 0 or partition_rows != 0:
        ctx.enqueue_copy(h,a)
        ctx.synchronize()
        for token in range(tokens):
            for row in range(rows): native_snapshot.append(h[token*stride+reference_offset+row])
        comptime if partition_rows != 0:
            selected_original[kind,batch](ctx,w,a,base,columns,rows,src,reference_offset,stride,tokens)
        else:
            project_turing_staged[kind,batch,64,32](ctx,w,a,base,columns,rows,src,reference_offset,stride,tokens)
    candidate[kind,batch,tile_rows,tile_columns,turing,staged_rows,staged_columns,cache_headers,large_rows,narrow_rows,loop_rows,partition_rows,token_tile](ctx,w,a,base,columns,rows,src,dst,stride,tokens)
    ctx.enqueue_copy(h,a)
    ctx.synchronize()
    var normalized_sum: Float64 = 0
    var guards = 0
    if real:
        print("CASE," + String(case_index) + "," + name + "," + String(kind) + "," + String(columns) + "," + String(rows) + "," + String(batch) + "," + String(base))
        comptime if partition_rows != 0:
            var original_rows = 128 if batch == 32 and columns == 8192 and rows == 3072 else 64
            print("PARTITION,"+String(case_index)+","+String(partition_rows)+","+String(token_tile)+","+String((rows+partition_rows-1)//partition_rows)+","+String((tokens+token_tile-1)//token_tile)+","+String(partition_rows//16*32)+",1")
            print("SELECTED,"+String(case_index)+","+String(original_rows)+",32")
    for token in range(batch):
        for i in range(stride):
            var in_src = i >= src and i < src + columns and token < tokens
            var in_dst = token < tokens and i >= dst and i < dst + rows
            var in_ref = token < tokens and i >= reference_offset and i < reference_offset + rows
            if not in_dst and not in_ref:
                var expected: Float32 = -9876
                if in_src:
                    expected = Float32(((i - src) * 7 + token * 13) % 29 - 14) / 16.0
                if h[token * stride + i] != expected:
                    raise Error("Matrix candidate mutated a guard/input/unowned token")
                guards += 1
        if token < tokens:
            for row in range(rows):
                var actual = h[token * stride + dst + row]
                var expected = h[token * stride + reference_offset + row]
                var staged = expected
                comptime if cache_headers or large_rows != 0 or narrow_rows != 0 or loop_rows != 0 or partition_rows != 0:
                    expected = native_snapshot[token*rows+row]
                    if Pointer(to=actual).unsafe_bitcast[UInt32]()[] != Pointer(to=staged).unsafe_bitcast[UInt32]()[]:
                        raise Error("Paired candidate changed original staged F32 bits")
                var error = Float64(abs(actual - expected)) / (1.0 + Float64(abs(expected)))
                if not isfinite(actual) or not isfinite(expected) or error > 0.002:
                    raise Error("Matrix primitive exceeded predeclared per-output error: kind="+String(kind)+", columns="+String(columns)+", rows="+String(rows)+", batch="+String(batch)+", token="+String(token)+", row="+String(row)+", reference="+String(Float64(expected))+", actual="+String(Float64(actual)))
                normalized_sum += error * error
                if real:
                    comptime if cache_headers or large_rows != 0 or narrow_rows != 0 or loop_rows != 0 or partition_rows != 0:
                        print("VALUE,"+String(case_index)+","+String(token)+","+String(row)+","+String(Float64(expected))+","+String(Float64(actual))+","+String(Float64(staged)))
                    else:
                        print("VALUE," + String(case_index) + "," + String(token) + "," + String(row) + "," + String(expected) + "," + String(actual))
    if sqrt(normalized_sum / Float64(rows * tokens)) > 0.0002:
        raise Error("Matrix primitive exceeded predeclared normalized RMS")
    if real:
        print("GUARD," + String(case_index) + "," + String(guards) + ",0")
        # Timed input starts at zero with independently admitted disjoint outputs.
        # Whole buffer reset is outside the timed loops.
        for token in range(batch):
            for col in range(columns):
                h[token * stride + col] = Float32((col * 7 + token * 13) % 29 - 14) / 16.0
        ctx.enqueue_copy(a,h)
        for _ in range(2):
            candidate[kind,batch,tile_rows,tile_columns,turing,staged_rows,staged_columns,cache_headers,large_rows,narrow_rows,loop_rows,partition_rows,token_tile](ctx,w,a,base,columns,rows,0,dst,stride,batch)
            reference[kind,batch](ctx,w,a,base,columns,rows,reference_offset,stride,batch)
            comptime if cache_headers or large_rows != 0 or narrow_rows != 0 or loop_rows != 0 or partition_rows != 0:
                comptime if partition_rows != 0:
                    selected_original[kind,batch](ctx,w,a,base,columns,rows,0,reference_offset,stride,batch)
                else:
                    project_turing_staged[kind,batch,64,32](ctx,w,a,base,columns,rows,0,reference_offset,stride,batch)
        ctx.synchronize()
        for sample in range(10):
            for step in range(3 if cache_headers or large_rows != 0 or narrow_rows != 0 or loop_rows != 0 or partition_rows != 0 else 2):
                var mode = (sample + step) % (3 if cache_headers or large_rows != 0 or narrow_rows != 0 or loop_rows != 0 or partition_rows != 0 else 2)
                var started = seconds()
                for _ in range(3):
                    if mode == 0:
                        reference[kind,batch](ctx,w,a,base,columns,rows,reference_offset,stride,batch)
                    elif mode == 1:
                        candidate[kind,batch,tile_rows,tile_columns,turing,staged_rows,staged_columns,cache_headers,large_rows,narrow_rows,loop_rows,partition_rows,token_tile](ctx,w,a,base,columns,rows,0,dst,stride,batch)
                    else:
                        comptime if cache_headers or large_rows != 0 or narrow_rows != 0 or loop_rows != 0 or partition_rows != 0:
                            comptime if partition_rows != 0:
                                selected_original[kind,batch](ctx,w,a,base,columns,rows,0,reference_offset,stride,batch)
                            else:
                                project_turing_staged[kind,batch,64,32](ctx,w,a,base,columns,rows,0,reference_offset,stride,batch)
                        else:
                            raise Error("Unexpected matrix timing owner")
                ctx.synchronize()
                var elapsed = seconds() - started
                if elapsed <= 0 or not isfinite(elapsed):
                    raise Error("Matrix timing is invalid")
                print("TIME," + String(case_index) + "," + String(mode) + "," + String(sample) + ",3," + String(elapsed))
    return rows * tokens


def synthetic[kind: Int,batch: Int, tile_rows: Int = 32, tile_columns: Int = 32, turing: Bool = False,staged_rows: Int = 0,staged_columns: Int = 32,cache_headers: Bool = False,large_rows: Int = 0,narrow_rows: Int = 0,loop_rows: Int = 0,partition_rows: Int = 0,token_tile: Int = 0](ctx: DeviceContext) raises:
    comptime bytes = 144 if kind == 12 else (176 if kind == 13 else 210)
    for columns in [256,512,3072,8192]:
        for rows in [1,7,33]:
            var size = 32 + rows * columns // 256 * bytes + 32
            var w = ctx.enqueue_create_buffer[DType.uint8](size)
            var h = ctx.enqueue_create_host_buffer[DType.uint8](size)
            for i in range(size):
                h[i] = UInt8((i * 37 + i // 7) % 256)
            for block in range(rows * columns // 256):
                var p = 32 + block * bytes
                var d = p + (208 if kind == 14 else 0)
                h[d] = 0
                h[d+1] = UInt8(44 if block % 2 == 0 else 172)
                comptime if kind != 14:
                    h[p+2] = 0
                    h[p+3] = 40
            ctx.enqueue_copy(w,h)
            _ = exercise[kind,batch,tile_rows,tile_columns,turing,staged_rows,staged_columns,cache_headers,large_rows,narrow_rows,loop_rows,partition_rows,token_tile](ctx,w,32,columns,rows,batch-1,0,"synthetic",False)


def real_batch[batch: Int, tile_rows: Int = 32, tile_columns: Int = 32, turing: Bool = False,staged_rows: Int = 0,staged_columns: Int = 32,cache_headers: Bool = False,large_rows: Int = 0,narrow_rows: Int = 0,loop_rows: Int = 0,partition_rows: Int = 0,token_tile: Int = 0](mut s: Llama3CUDASession, mut case_index: Int, mut values: Int) raises:
    for name in ["blk.0.attn_q.weight", "blk.0.attn_k.weight", "blk.0.attn_v.weight",
                 "blk.0.attn_output.weight", "blk.0.ffn_gate.weight", "blk.0.ffn_up.weight", "blk.0.ffn_down.weight"]:
        var t = s.model.tensors[name]
        if t.kind == 12:
            values += exercise[12,batch,tile_rows,tile_columns,turing,staged_rows,staged_columns,cache_headers,large_rows,narrow_rows,loop_rows,partition_rows,token_tile](s.context,s.weights,t.offset,t.columns,t.rows,batch,case_index,name,True)
        elif t.kind == 14:
            values += exercise[14,batch,tile_rows,tile_columns,turing,staged_rows,staged_columns,cache_headers,large_rows,narrow_rows,loop_rows,partition_rows,token_tile](s.context,s.weights,t.offset,t.columns,t.rows,batch,case_index,name,True)
        else:
            raise Error("Unexpected real tensor quantization")
        case_index += 1



def span_guards[tile_rows: Int = 32, tile_columns: Int = 32]() raises:
    for invalid in range(12):
        var base = 0
        var columns = 256
        var rows = 1
        var src = 0
        var dst = 300
        var stride = 512
        var tokens = 4
        var weight_bytes = 144
        var elements = 2048
        if invalid == 0: dst = 128
        elif invalid == 1: base = -1
        elif invalid == 2: columns = 257
        elif invalid == 3: rows = 0
        elif invalid == 4: rows = 128257
        elif invalid == 5: src = -1
        elif invalid == 6: stride = 0
        elif invalid == 7: tokens = 0
        elif invalid == 8: tokens = 5
        elif invalid == 9: weight_bytes = 143
        elif invalid == 10: elements = 2047
        else: dst = 512
        var rejected = False
        try:
            admit_matrix[12,4,tile_rows,tile_columns](weight_bytes,elements,base,columns,rows,src,dst,stride,tokens)
        except:
            rejected = True
        if not rejected:
            raise Error("Invalid matrix span was admitted")

def main() raises:
    var args = argv()
    if len(args) != 2:
        raise Error("usage: test_packed_matrix MODEL.gguf")
    var s = Llama3CUDASession(args[1],512,prefix_cache=False,prefill_batch=4)
    if s.profile.hidden_size != 3072 or s.profile.layer_count != 28:
        raise Error("Matrix candidate requires strict 3B fixture")
    span_guards()
    comptime for batch in [4,8,16,32]:
        synthetic[12,batch](s.context)
        synthetic[13,batch](s.context)
        synthetic[14,batch](s.context)
    print("SYNTHETIC,144,0")
    var count = 0
    var values = 0
    comptime for batch in [4,8,16,32]:
        real_batch[batch](s,count,values)
    print("PASS,matrix," + String(count) + "," + String(values) + "," + String(count * 20))
