from std.memory import Pointer
def main():
    var p = Pointer[Int8, MutUntrackedOrigin](unsafe_from_address=-1)
    if Int(p.unsafe_bitcast[Int]()) == -1:
        print("is -1")
