trait Engine:
    def generate(self, prompt: String) -> String:
        ...

struct MyEngine:
    def __init__(out self):
        pass
    def generate(self, prompt: String) -> String:
        return prompt + " completed"

struct Server[E: Engine]:
    var engine: E
    
    def __init__(out self, engine: E):
        self.engine = engine

    def process(self):
        print(self.engine.generate(String("test")))

def main():
    var e = MyEngine()
    var s = Server(e)
    s.process()
