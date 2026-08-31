"""Physical CUDA sampler probe. Validate output with test_cuda_sampling.py.

Synthetic logits are test inputs, not evidence of model inference support.
"""
from max.gpu.host import DeviceContext
from std.memory import bitcast
from core.cuda_sampling import NativeCUDASampler
from core.sampling_config import NativeSamplingConfig


def main() raises:
    var context = DeviceContext(0, api="cuda")
    if context.api() != "cuda" or not context.is_compatible():
        raise Error("Physical CUDA sampler test requires compatible NVIDIA GPU")
    for scenario in range(14):
        var vocab = 4099
        var config = NativeSamplingConfig(0.7, 17, 0.9, 0.04, 1.2, 7, 42)
        if scenario == 0:
            vocab = 257
            config = NativeSamplingConfig()
        elif scenario == 2:
            vocab = 19
            config = NativeSamplingConfig(1, 40, 1, 0, 1, 7, 0)
        elif scenario == 3:
            vocab = 257
            config = NativeSamplingConfig(0.00001, 256, 1, 0, 1, 7, 18446744073709551615)
        elif scenario == 4:
            config = NativeSamplingConfig(0, 17, 1, 0, 1.5, 7, 42)
        elif scenario == 5:
            config = NativeSamplingConfig(1, 1, 1, 0, 1, 7, 42)
        elif scenario == 6:
            vocab = 270
        elif scenario == 7:
            vocab = 8201
            config = NativeSamplingConfig(2, 256, 1, 0, 0.8, 7, 12345)
        elif scenario == 8:
            config.min_p = 1
        elif scenario == 13:
            config = NativeSamplingConfig()
        var host = context.enqueue_create_host_buffer[DType.float32](vocab + 3)
        for i in range(vocab):
            var value = Float32((i * 37 + 11) % 101 - 50) / 8
            if scenario == 2:
                value = 2
            elif scenario == 3:
                value = 3e38 if i % 2 else -3e38
            elif scenario == 9:
                value -= 100
            if i == 17 and scenario == 10:
                value = bitcast[DType.float32](UInt32(0x7fc00000))
            if i == 17 and (scenario == 11 or scenario == 13):
                value = bitcast[DType.float32](UInt32(0x7f800000))
            host[i + 3] = value
        var logits = context.enqueue_create_buffer[DType.float32](vocab + 3)
        var output = context.enqueue_create_buffer[DType.int32](1)
        var chosen = context.enqueue_create_host_buffer[DType.int32](1)
        context.enqueue_copy(logits, host)
        var sampler = NativeCUDASampler(context, vocab, config)
        for epoch in range(2):
            sampler.clear()
            # Overflow the seven-token ring and include repeated occurrences.
            for i in range(11):
                sampler.record((i * 7) % min(vocab, 19))
            var limit = 257 if scenario == 6 else (0 if scenario == 12 else vocab)
            for draw in range(32):
                sampler.select(logits.unsafe_ptr().unsafe_origin_cast[MutUntrackedOrigin](), 3,
                    output.unsafe_ptr().unsafe_origin_cast[MutUntrackedOrigin](), limit,
                    260 if scenario == 6 else -1, 269 if scenario == 6 else -1)
                context.enqueue_copy(chosen, output)
                context.synchronize()
                var token = Int(chosen[0])
                print("SAMPLE", scenario, epoch, draw, token)
                if token >= 0:
                    sampler.record(token)
        _ = sampler
        _ = logits
        _ = host
        _ = output
