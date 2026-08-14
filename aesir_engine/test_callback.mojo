alias GenerateCallback = fn(String) -> String

struct Server:
    var callback: GenerateCallback
    
    def __init__(out self, cb: GenerateCallback):
        self.callback = cb

    def process(self):
        print(self.callback(String("test")))

def my_cb(prompt: String) -> String:
    return prompt + " completed"

def main():
    var s = Server(my_cb)
    s.process()
