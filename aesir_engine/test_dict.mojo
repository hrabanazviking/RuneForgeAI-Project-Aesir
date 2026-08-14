from std.collections import Dict
struct Foo:
    var x: Int
    def __init__(out self, x: Int):
        self.x = x

def main() raises:
    var d = Dict[String, Foo]()
    d["a"] = Foo(1)
    ref a = d["a"]
    print(a.x)
