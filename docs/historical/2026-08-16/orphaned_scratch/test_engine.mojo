from core.mimir_well import MimirWell
from loader.gguf import GGUFSeer
from loader.tokenizer import RuneWeaver

struct AesirEngine:
    var pool: MimirWell
    var parser: GGUFSeer
    var tokenizer: RuneWeaver

    def __init__(out self, model_path: String):
        var mimir_depth_bytes = 1024 * 1024 * 1024 * 5
        self.pool = MimirWell(mimir_depth_bytes)
        self.parser = GGUFSeer(model_path)
        self.parser.mmap_and_load(self.pool)
        self.tokenizer = RuneWeaver()

def main():
    var e = AesirEngine(String("model.gguf"))
