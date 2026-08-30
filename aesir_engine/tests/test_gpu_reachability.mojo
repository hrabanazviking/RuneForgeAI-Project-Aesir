# aesir_engine/tests/test_gpu_reachability.mojo
#
# GPU-0 hardware-only proof for the locked Mojo 1.0.0 / MAX 26.5.0 toolchain.
# This file is intentionally excluded from tests/run_all.mojo because it requires
# a physical NVIDIA GPU and a compatible ptxas installation.

from max.gpu.host import DeviceContext, HostBuffer
from std.gpu import global_idx
from std.memory import Pointer
from std.sys import argv


comptime ELEMENT_COUNT = 257
comptime BLOCK_SIZE = 128
comptime EXECUTION_ROUNDS = 3


def affine_kernel[
    input_origin: Origin[mut=False], output_origin: MutOrigin
](
    input: Pointer[Float32, input_origin],
    output: Pointer[Float32, output_origin],
    count: Int32,
):
    """Apply a deterministic affine transform on the selected GPU."""
    var index = Int(global_idx.x)
    if index < Int(count):
        output.unsafe_store(index, input.unsafe_load(index) * 2.0 + 3.0)


def expected_input(index: Int, execution_round: Int) -> Float32:
    """Return a binary-exact host test value independent of GPU output."""
    return Float32(index - 128) * 0.25 + Float32(execution_round)


def validate_identity(
    host_input: HostBuffer[DType.float32],
    host_roundtrip: HostBuffer[DType.float32],
    execution_round: Int,
) raises:
    """Reject any host-to-device-to-host transfer mismatch."""
    for index in range(ELEMENT_COUNT):
        var expected = expected_input(index, execution_round)
        if host_input[index] != expected or host_roundtrip[index] != expected:
            raise Error(
                "GPU-0 copy mismatch at index "
                + String(index)
                + " during round "
                + String(execution_round)
            )


def validate_kernel_output(
    host_output: HostBuffer[DType.float32],
    execution_round: Int,
    inject_mismatch: Bool,
) raises:
    """Reject any GPU result that differs from the independent host formula."""
    for index in range(ELEMENT_COUNT):
        var expected = expected_input(index, execution_round) * 2.0 + 3.0
        if (
            inject_mismatch
            and execution_round == EXECUTION_ROUNDS - 1
            and index == 0
        ):
            expected += 1.0
        if host_output[index] != expected:
            raise Error(
                "GPU-0 kernel mismatch at index "
                + String(index)
                + " during round "
                + String(execution_round)
            )


def main() raises:
    var inject_mismatch = False
    var arguments = argv()
    if len(arguments) == 2 and arguments[1] == "--negative-control":
        inject_mismatch = True
    elif len(arguments) != 1:
        raise Error("usage: test_gpu_reachability.mojo [--negative-control]")

    with DeviceContext() as context:
        var device_name = context.name()
        var device_api = context.api()
        if device_name.byte_length() == 0:
            raise Error("GPU-0 context returned an empty device name")
        if device_api != "cuda":
            raise Error("GPU-0 requires CUDA, got device API: " + device_api)

        print("[GPU0] device:", device_name)
        print("[GPU0] api:", device_api)
        print("[GPU0] context: created")

        var host_input = context.enqueue_create_host_buffer[DType.float32](
            ELEMENT_COUNT
        )
        var host_roundtrip = context.enqueue_create_host_buffer[DType.float32](
            ELEMENT_COUNT
        )
        var host_output = context.enqueue_create_host_buffer[DType.float32](
            ELEMENT_COUNT
        )
        var device_input = context.enqueue_create_buffer[DType.float32](
            ELEMENT_COUNT
        )
        var device_output = context.enqueue_create_buffer[DType.float32](
            ELEMENT_COUNT
        )
        print("[GPU0] buffers: host-and-device-created")

        for execution_round in range(EXECUTION_ROUNDS):
            for index in range(ELEMENT_COUNT):
                host_input[index] = expected_input(index, execution_round)
                host_roundtrip[index] = -1.0
                host_output[index] = -1.0

            context.enqueue_copy(device_input, host_input)
            context.enqueue_copy(host_roundtrip, device_input)
            context.synchronize()
            validate_identity(host_input, host_roundtrip, execution_round)

            context.enqueue_function[
                affine_kernel[origin_of(device_input), origin_of(device_output)]
            ](
                device_input.unsafe_ptr(),
                device_output.unsafe_ptr(),
                Int32(ELEMENT_COUNT),
                grid_dim=(ELEMENT_COUNT + BLOCK_SIZE - 1) // BLOCK_SIZE,
                block_dim=BLOCK_SIZE,
            )
            context.enqueue_copy(host_output, device_output)
            context.synchronize()
            validate_kernel_output(
                host_output, execution_round, inject_mismatch
            )

        print("[GPU0] copy-roundtrip: pass")
        print("[GPU0] kernel-affine-parity: pass")
        print("[GPU0] synchronized-rounds:", EXECUTION_ROUNDS)
        print("[GPU0] result: PASS")
