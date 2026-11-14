# Q35-3r footprint bench (not a suite test): one load (+ a short
# greedy forward for the engine modes) per invocation, so an outer
# /usr/bin/time -v measures the peak RSS of exactly one mode.
#
# Modes:
#  default     AesirEngine, default load.
#  resident    AesirEngine, Q8_0-resident opt-in.
#  materialize GGUFSeer load, then EXPLICITLY dequantize every large
#              Q8_0 tensor into its own heap F16 buffer and hold all
#              of them -- the F16-materialized load the gate prices,
#              performed deliberately so its peak is MEASURED, not
#              assumed. (Nothing in the engine does this; that is
#              the point of the resident path.)
# Usage: bench_qwen35_resident_footprint_q35_3r <gguf> <mode>

from std.memory.alloc import alloc, Layout
from std.sys import argv

from core.compute import BlockQ8_0, dequantize_q8_0
from core.mimir_well import MimirWell, KVCache
from qwen35_resident import qwen35_large_weight_names
from aesir import AesirEngine, GenerationConfig
from loader.gguf import GGUFSeer
from loader.tokenizer import RuneWeaver


def engine_mode(path: String, resident: Bool) raises:
    var engine = AesirEngine(path, knowledge_capacity=1, qwen35_resident=resident)
    var cfg = GenerationConfig(max_new_tokens=16, temperature=Float32(0.0), top_k=40, top_p=Float32(0.9), repetition_penalty=Float32(1.0), seed=UInt64(42))
    engine.pool.offset = engine.runtime_offset
    var kv = KVCache(64, engine.parser.config.kv_dim(), engine.pool, engine.parser.config.block_count)
    var tokens = List[Int]()
    tokens.append(1); tokens.append(3); tokens.append(17); tokens.append(42)
    var nxt = -1
    for pos in range(len(tokens)):
        nxt = engine._forward_position(tokens, kv, pos, cfg, False)
    var produced = String("")
    for _ in range(8):
        produced += String(nxt) + String(" ")
        tokens.append(nxt)
        nxt = engine._forward_position(tokens, kv, len(tokens) - 1, cfg, False)
    print("ENGINE MODE DONE resident=", resident, " generated:", produced)


def materialize_mode(path: String) raises:
    var pool = MimirWell(64 * 1024 * 1024)
    var tokenizer = RuneWeaver()
    var seer = GGUFSeer(path)
    seer.mmap_and_load(pool, tokenizer)
    var names = qwen35_large_weight_names(seer.config.block_count, seer.config.full_attention_interval)
    var total_elements = 0
    var checksum = Float32(0.0)
    var buffers = List[Int]()
    for i in range(len(names)):
        ref t = seer.tensors[names[i]]
        if not t.is_quantized:
            raise Error("materialize bench expects Q8_0 large tensors")
        var buf = alloc(Layout[Scalar[DType.float16]](count=t.size)).unsafe_leak()
        dequantize_q8_0(t.data.unsafe_bitcast[BlockQ8_0](), buf, t.size // 32)
        checksum += buf.unsafe_load(0).cast[DType.float32]() + buf.unsafe_load(t.size - 1).cast[DType.float32]()
        total_elements += t.size
        buffers.append(Int(buf))
    print("MATERIALIZE DONE large_tensors=", len(names), " f16_elements=", total_elements, " f16_bytes=", total_elements * 2, " checksum=", checksum, " buffers_held=", len(buffers))


def main() raises:
    var arguments = argv()
    if len(arguments) != 3:
        raise Error("usage: bench_qwen35_resident_footprint_q35_3r <gguf> <default|resident|materialize>")
    if arguments[2] == "default":
        engine_mode(arguments[1], False)
    elif arguments[2] == "resident":
        engine_mode(arguments[1], True)
    elif arguments[2] == "materialize":
        materialize_mode(arguments[1])
    else:
        raise Error("unknown mode " + arguments[2])
