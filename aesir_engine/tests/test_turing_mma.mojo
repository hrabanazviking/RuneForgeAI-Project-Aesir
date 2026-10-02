"""Actual public Turing MMA results, exact finite equations and borrowed guards.

Export through Float64 text to preserve every exact binary F32 operand result;
the default F32 formatter rounds some correct dyadic results too narrowly.
"""
from max.gpu.host import DeviceContext
from std.math import isfinite
from core.turing_mma_probe import launch_mma, admit_mma, matrix_a, matrix_b, matrix_c


def main() raises:
    var ctx = DeviceContext(0,api="cuda")
    var prefix = 17
    var count = 0
    var values = 0
    var guards = 0
    for invalid in range(9):
        var elements = 145
        var offset = 17
        var tiles = 1
        var steps = 1
        var case_index = 0
        var block_size = 32
        if invalid == 0: elements = 144
        elif invalid == 1: offset = -1
        elif invalid == 2: tiles = 0
        elif invalid == 3: tiles = 65
        elif invalid == 4: steps = 0
        elif invalid == 5: steps = 17
        elif invalid == 6: case_index = -1
        elif invalid == 7: case_index = 6
        else: block_size = 33
        var rejected = False
        try:
            admit_mma(elements,offset,tiles,steps,case_index,block_size)
        except:
            rejected = True
        if not rejected:
            raise Error("Invalid MMA metadata was admitted")
    print("META,1,cuda,m16n8k8,f16,f32,9")
    for case_index in range(6):
        for tiles in [1,3,7]:
            for block_size in [32,128]:
                for steps in [1,3,7]:
                    var size = prefix + tiles*128 + 33
                    var output = ctx.enqueue_create_buffer[DType.float32](size)
                    var host = ctx.enqueue_create_host_buffer[DType.float32](size)
                    output.enqueue_fill(12345)
                    launch_mma(ctx,output,prefix,tiles,steps,case_index,block_size)
                    ctx.enqueue_copy(host,output)
                    ctx.synchronize()
                    print("CASE,"+String(count)+","+String(case_index)+","+String(tiles)+","+String(block_size)+","+String(steps))
                    for i in range(size):
                        if i < prefix or i >= prefix+tiles*128:
                            if host[i] != 12345:
                                raise Error("MMA output changed unowned guard")
                            guards += 1
                    for tile in range(tiles):
                        var seed = case_index+tile*7
                        for row in range(16):
                            for column in range(8):
                                var expected = Float64(matrix_c(row,column,seed,case_index==0))
                                for step in range(steps):
                                    for k in range(8):
                                        expected += Float64(matrix_a(row,k,seed+step*11,case_index==0))*Float64(matrix_b(k,column,seed+step*11,case_index==0))
                                var actual = host[prefix+tile*128+row*8+column]
                                if not isfinite(actual) or Float64(actual) != expected:
                                    raise Error("Physical Turing MMA changed exact reference value")
                                print("VALUE,"+String(count)+","+String(tile)+","+String(row)+","+String(column)+","+String(Float64(actual)))
                                values += 1
                    print("GUARD,"+String(count)+",50,0")
                    count += 1
    print("PASS,mma,"+String(count)+","+String(values)+","+String(guards))
