struct MyStruct:
    var x: Int

    def __init__(out self, x: Int):
        self.x = x

    def update(mut self, y: Int):
        self.x = y

def main():
    var s = MyStruct(5)
    s.update(10)
    print(s.x)
