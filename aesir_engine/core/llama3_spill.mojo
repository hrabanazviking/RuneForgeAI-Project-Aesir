"""Split execution for dense GQA (Llama 3 family): front layers on CUDA,
tail layers on the CPU path, the hidden state crossing once per token.

GPU-line spill build (platform/gpu-2060-verification), slice S2. The front
is a Llama3CUDASession built with an exec-layer cap: its device weights
are a compaction of exactly the front tensors (embedding + front layers)
with descriptor offsets remapped - real quant files scatter tensor data
in arbitrary order, so no file prefix exists - and its KV cache holds
only front layers. The tail reuses the CPU path itself: TransformerBlock
layers over a GGUFSeer, with the KV cache in host RAM beside the tail
layers. Selection is greedy argmax over the CPU final norm + output
projection, matching the native sampler temperature-0 rule. The split is
always reported by the constructor line; this session never silently
degenerates to all-CPU or all-GPU execution.
"""
from loader.gguf import GGUFSeer
from core.dense_residency import (
    DenseResidencyPlan,
    dense_front_resident_bytes,
    dense_layer_bytes,
    dense_tail_resident_bytes,
    describe_dense_spill,
)
from core.llama3_cuda import Llama3CUDASession
from core.inference import TransformerBlock
from core.mimir_well import MimirWell, KVCache, RuneTensor, f16, f32
from core.compute import rmsnorm, gemm_f16


struct Llama3SpillSession(Movable):
    var front: Llama3CUDASession
    var seer: GGUFSeer
    var well: MimirWell
    var kv_cache: KVCache
    var blocks: List[TransformerBlock]
    var exec_layers: Int
    var residency: DenseResidencyPlan
    var layer_count: Int
    var hidden: Int
    var context_length: Int
    var position: Int

    def __init__(out self, path: String, context_length: Int, exec_layers: Int,
                 device_index: Int = 0, well_bytes: Int = 1073741824) raises:
        self.front = Llama3CUDASession(path, context_length,
                                       device_index=device_index,
                                       exec_layers=exec_layers)
        if not self.front.spilled:
            raise Error("Spill session requires exec_layers < layer_count")
        self.seer = GGUFSeer(path)
        self.well = MimirWell(well_bytes)
        self.seer.mmap_and_load(self.well)
        self.layer_count = self.seer.config.block_count
        if exec_layers >= self.layer_count:
            raise Error("Spill session requires exec_layers < layer_count")
        self.exec_layers = exec_layers
        self.hidden = self.seer.tensors["token_embd.weight"].cols
        self.context_length = context_length
        self.kv_cache = KVCache(context_length, self.seer.config.kv_dim(),
                                self.well, self.layer_count)
        self.blocks = List[TransformerBlock]()
        var head_dim = self.hidden // self.seer.config.head_count
        for layer in range(exec_layers, self.layer_count):
            self.blocks.append(TransformerBlock(layer, head_dim,
                               self.seer.config.head_count, self.seer))
        self.position = 0
        print("[SPILL] gpu_layers=" + String(self.exec_layers) + "/" + String(self.layer_count) + " cpu_layers=" + String(self.layer_count - self.exec_layers) + " context=" + String(context_length))
        # J-021: the same split, stated through the Part II residency
        # machinery -- per-layer bytes summed from the front session's
        # tensor directory (its directory keeps true file sizes; the
        # compaction rewrote only descriptor copies), the always-
        # resident set derived from the same directory. Accounting
        # only: nothing on the execution path reads this plan.
        var layer_sizes = List[Int]()
        for layer in range(self.layer_count):
            layer_sizes.append(dense_layer_bytes(self.front.model, layer))
        self.residency = describe_dense_spill(
            layer_sizes,
            self.exec_layers,
            dense_front_resident_bytes(self.front.model),
            dense_tail_resident_bytes(self.front.model),
        )
        print("[RESIDENCY] " + self.residency.describe())

    def step(mut self, token: Int) raises -> Int:
        """Process one token at the current position across the split and
        return the greedily selected next token. The GPU front runs the
        embedding and front layers; the hidden vector crosses to host
        once; the CPU tail runs the remaining layers, the final norm, the
        output projection, and the argmax. Since J-021 the constructor also
reports the split through the Part II residency machinery
(core/dense_residency.mojo): the [RESIDENCY] line states the front
prefix as pinned device-resident layers and the tail as host-resident
layers, at directory-true byte sizes, in the J-018 statistics
vocabulary's terms."""
        if token < 0 or self.position >= self.context_length:
            raise Error("Spill session token/context bound exceeded")
        self.front.forward_front(token)
        var mark = self.well.offset
        var x_ptr = self.well.allocate(self.hidden)
        for i in range(self.hidden):
            x_ptr.unsafe_store(i, self.front.hidden_value(i).cast[DType.float16]())
        var x = RuneTensor[f16](1, self.hidden, x_ptr, False)
        for bi in range(len(self.blocks)):
            self.blocks[bi].forward(x, self.seer, self.well, 1, self.position,
                                    self.kv_cache)
        var epsilon: Scalar[f32] = 1e-5
        if self.seer.config.rms_epsilon > 0.0:
            epsilon = self.seer.config.rms_epsilon
        if "output_norm.weight" in self.seer.tensors:
            ref output_norm_weight = self.seer.tensors["output_norm.weight"]
            rmsnorm(x, output_norm_weight, epsilon)
        if "output.weight" not in self.seer.tensors:
            raise Error("Inference requires output.weight")
        ref output_weight = self.seer.tensors["output.weight"]
        var vocab_size = output_weight.rows
        var logits_ptr = self.well.allocate(vocab_size)
        var logits = RuneTensor[f16](1, vocab_size, logits_ptr, False)
        var output_weight_eff = output_weight.copy()
        gemm_f16(x, output_weight_eff, logits)
        var best = 0
        var best_value = logits.data.unsafe_load(0).cast[DType.float32]()
        for i in range(1, vocab_size):
            var value = logits.data.unsafe_load(i).cast[DType.float32]()
            if value > best_value:
                best_value = value
                best = i
        self.well.offset = mark
        self.position += 1
        return best
