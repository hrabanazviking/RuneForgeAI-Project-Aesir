from loader.gguf import GGUFSeer
from loader.tokenizer import RuneWeaver
from core.mimir_well import MimirWell

def main() raises:
    var seer = GGUFSeer("qwen2.5-0.5b-instruct-q4_0.gguf")
    var well = MimirWell(10 * 1024 * 1024)
    var weaver = RuneWeaver()
    seer.mmap_and_load(well, weaver)
    
    print("Total Tensors:", len(seer.tensors))
    for name in seer.tensors.keys():
        var t = seer.tensors[name].copy()
        print("Tensor:", name, "shape=(", t.rows, ",", t.cols, ") quant=", t.is_quantized, "fmt=", t.quant_format.name())
