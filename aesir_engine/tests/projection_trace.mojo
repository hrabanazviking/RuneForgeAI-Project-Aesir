"""Enabled-only diagnostic NVTX calls; direct probe owns globally loaded library."""
from std.ffi import OwnedDLHandle
from loader.packed_gguf import PackedTensor


def same_projection_tensor(a: PackedTensor,b: PackedTensor) -> Bool:
    return a.offset == b.offset and a.kind == b.kind and a.rows == b.rows and a.columns == b.columns


def projection_push(stage: String,count: Int) raises:
    var process = OwnedDLHandle()
    var push = process.get_function[Int32]("nvtxRangePushA")
    var label = String("aesir.project.")+stage+".b"+String(count)
    var text = label.as_c_string_slice()
    _ = push(text.unsafe_ptr())


def projection_pop() raises:
    var process = OwnedDLHandle()
    var pop = process.get_function[Int32]("nvtxRangePop")
    _ = pop()
