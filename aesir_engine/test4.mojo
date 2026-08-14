from std.ffi import external_call
from std.memory import Pointer
def main():
    var p_int = external_call["mmap", Int](Int(0), Int64(0), Int32(0), Int32(0), Int32(-1), Int64(0))
    if p_int == -1:
        print("mmap failed")
