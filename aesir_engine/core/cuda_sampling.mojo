"""Native CUDA top-k/nucleus/min-p sampling with device repetition history.

The first kernel selects sorted candidates independently in 128 disjoint
vocabulary partitions. A second warp merges their exact global top-k. Only the
chosen token leaves the device. This favors auditable correctness over sorting
or throughput optimizations. No external inference/sampling runtime is used.
"""
from max.gpu.host import DeviceContext, DeviceBuffer
from std.gpu import global_idx
from std.gpu.primitives import warp
from std.math import exp, isfinite
from std.memory import bitcast
from core.gemma4_kernels import Floats, Integers, argmax_kernel
from core.sampling_config import NativeSamplingConfig, sampling_device_bytes


def sampling_record(counts: Integers, history: Integers, token: Int32,
                    position: Int64, window: Int64):
    var slot = Int(position % window)
    if position >= window:
        var old = Int(history.unsafe_load(slot))
        counts.unsafe_store(old, counts.unsafe_load(old) - 1)
    counts.unsafe_store(Int(token), counts.unsafe_load(Int(token)) + 1)
    history.unsafe_store(slot, token)


def sampling_partitions(logits: Floats, counts: Integers, values: Floats,
                        ids: Integers, bad_flags: Integers, offset: Int64,
                        vocab: Int64, k: Int64, penalty: Float32,
                        ordinary_limit: Int64, eos1: Int64, eos2: Int64):
    var lane = Int(global_idx.x) % 32
    var group = Int(global_idx.x) // 32
    var previous = bitcast[DType.float32](UInt32(0x7f800000))
    var previous_id = Int32(-1)
    var bad = Int32(0)
    for rank in range(Int(k)):
        var best = -bitcast[DType.float32](UInt32(0x7f800000))
        var best_id = Int32(2147483647)
        for token in range(group * 32 + lane, Int(vocab), 128 * 32):
            var value = logits.unsafe_load(Int(offset) + token)
            if counts.unsafe_load(token) > 0:
                value = value * penalty if value < 0 else value / penalty
            if not isfinite(value):
                bad = 1
                continue
            if token >= Int(ordinary_limit) and token != Int(eos1) and token != Int(eos2):
                continue
            if value > previous or (value == previous and token <= Int(previous_id)):
                continue
            if value > best or (value == best and token < Int(best_id)):
                best = value
                best_id = Int32(token)
        previous = warp.max(best)
        previous_id = warp.min(best_id if best == previous else Int32(2147483647))
        if lane == 0:
            values.unsafe_store(group * Int(k) + rank, previous)
            ids.unsafe_store(group * Int(k) + rank, previous_id)
    bad = warp.max(bad)
    if lane == 0:
        bad_flags.unsafe_store(group, bad)


def sampling_merge(values: Floats, ids: Integers, bad_flags: Integers,
                   output: Integers, k: Int64, temperature: Float32,
                   top_p: Float32, min_p: Float32, seed: UInt64, draw: UInt64):
    var lane = Int(global_idx.x)
    var bad = Int32(0)
    for group in range(lane, 128, 32):
        bad = max(bad, bad_flags.unsafe_load(group))
    if warp.max(bad) != 0:
        if lane == 0:
            output.unsafe_store(0, Int32(-1))
        return
    var previous = bitcast[DType.float32](UInt32(0x7f800000))
    var previous_id = Int32(-1)
    var final_base = 128 * Int(k)
    for rank in range(Int(k)):
        var best = -bitcast[DType.float32](UInt32(0x7f800000))
        var best_id = Int32(2147483647)
        for slot in range(lane, final_base, 32):
            var value = values.unsafe_load(slot)
            var token = ids.unsafe_load(slot)
            if token == 2147483647 or value > previous or (value == previous and token <= previous_id):
                continue
            if value > best or (value == best and token < best_id):
                best = value
                best_id = token
        previous = warp.max(best)
        previous_id = warp.min(best_id if best == previous else Int32(2147483647))
        if lane == 0:
            values.unsafe_store(final_base + rank, previous)
            ids.unsafe_store(final_base + rank, previous_id)
    if lane != 0:
        return
    if ids.unsafe_load(final_base) == 2147483647:
        output.unsafe_store(0, Int32(-1))
        return
    if temperature == 0:
        output.unsafe_store(0, ids.unsafe_load(final_base))
        return
    # Relative probabilities avoid overflow even at very low temperatures.
    var maximum = values.unsafe_load(final_base)
    var total: Float32 = 0
    var kept = 0
    for rank in range(Int(k)):
        if ids.unsafe_load(final_base + rank) == 2147483647:
            break
        var delta = Float32((Float64(values.unsafe_load(final_base + rank)) - Float64(maximum)) / Float64(temperature))
        var probability = exp(delta)
        if probability < min_p:
            break
        values.unsafe_store(final_base + rank, probability)
        total += probability
        kept += 1
    var nucleus: Float32 = 0
    var count = 0
    for rank in range(kept):
        nucleus += values.unsafe_load(final_base + rank)
        count += 1
        if nucleus >= top_p * total:
            break
    # SplitMix64 keyed by seed and sample index. Zero is a valid seed.
    var random = seed + (draw + 1) * UInt64(0x9E3779B97F4A7C15)
    random = (random ^ (random >> 30)) * UInt64(0xBF58476D1CE4E5B9)
    random = (random ^ (random >> 27)) * UInt64(0x94D049BB133111EB)
    random ^= random >> 31
    var target = Float32(random >> 40) / Float32(16777216) * nucleus
    var cumulative: Float32 = 0
    for rank in range(count):
        cumulative += values.unsafe_load(final_base + rank)
        if target < cumulative or rank == count - 1:
            output.unsafe_store(0, ids.unsafe_load(final_base + rank))
            return


struct NativeCUDASampler:
    var context: DeviceContext
    var counts: DeviceBuffer[DType.int32]
    var history: DeviceBuffer[DType.int32]
    var values: DeviceBuffer[DType.float32]
    var ids: DeviceBuffer[DType.int32]
    var flags: DeviceBuffer[DType.int32]
    var config: NativeSamplingConfig
    var vocab_size: Int
    var position: Int
    var draws: UInt64

    def __init__(out self, context: DeviceContext, vocab_size: Int,
                 config: NativeSamplingConfig = NativeSamplingConfig()) raises:
        config.validate()
        _ = sampling_device_bytes(vocab_size)
        self.context = context
        self.config = config
        self.vocab_size = vocab_size
        self.position = 0
        self.draws = 0
        self.counts = context.enqueue_create_buffer[DType.int32](vocab_size)
        self.history = context.enqueue_create_buffer[DType.int32](8192)
        self.values = context.enqueue_create_buffer[DType.float32](128 * 256 + 256)
        self.ids = context.enqueue_create_buffer[DType.int32](128 * 256 + 256)
        self.flags = context.enqueue_create_buffer[DType.int32](128)
        self.counts.enqueue_fill(0)

    def clear(mut self) raises:
        self.counts.enqueue_fill(0)
        self.position = 0
        self.draws = 0

    def configure(mut self, config: NativeSamplingConfig) raises:
        config.validate()
        if config.repeat_last_n != self.config.repeat_last_n:
            raise Error("Changing repetition window requires a new session")
        if config.seed != self.config.seed:
            self.draws = 0
        self.config = config

    def record(mut self, token: Int) raises:
        if token < 0 or token >= self.vocab_size:
            raise Error("Sampling history token outside vocabulary")
        self.context.enqueue_function[sampling_record](
            self.counts.unsafe_ptr().unsafe_origin_cast[MutUntrackedOrigin](),
            self.history.unsafe_ptr().unsafe_origin_cast[MutUntrackedOrigin](),
            Int32(token), Int64(self.position), Int64(self.config.repeat_last_n),
            grid_dim=1, block_dim=1)
        self.position += 1

    def select(mut self, logits: Floats, offset: Int, output: Integers,
               ordinary_limit: Int, eos1: Int, eos2: Int) raises:
        if self.config.plain_greedy():
            self.context.enqueue_function[argmax_kernel](logits, output, Int64(offset), Int64(self.vocab_size), grid_dim=1, block_dim=32)
            return
        var k = 1 if self.config.temperature == 0 else self.config.top_k
        self.context.enqueue_function[sampling_partitions](logits,
            self.counts.unsafe_ptr().unsafe_origin_cast[MutUntrackedOrigin](),
            self.values.unsafe_ptr().unsafe_origin_cast[MutUntrackedOrigin](),
            self.ids.unsafe_ptr().unsafe_origin_cast[MutUntrackedOrigin](),
            self.flags.unsafe_ptr().unsafe_origin_cast[MutUntrackedOrigin](),
            Int64(offset), Int64(self.vocab_size), Int64(k), self.config.repetition_penalty,
            Int64(ordinary_limit), Int64(eos1), Int64(eos2), grid_dim=32, block_dim=128)
        self.context.enqueue_function[sampling_merge](
            self.values.unsafe_ptr().unsafe_origin_cast[MutUntrackedOrigin](),
            self.ids.unsafe_ptr().unsafe_origin_cast[MutUntrackedOrigin](),
            self.flags.unsafe_ptr().unsafe_origin_cast[MutUntrackedOrigin](), output,
            Int64(k), self.config.temperature, self.config.top_p, self.config.min_p,
            self.config.seed, self.draws, grid_dim=1, block_dim=32)
        # A deterministic penalized argmax does not consume an RNG draw.
        if self.config.temperature > 0:
            self.draws += 1
