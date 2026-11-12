"""Mojo-native GPU kernels on gfx1151 (A-029).

The A-029 determination (docs/AESIR_Z13_MOJO_GPU_DECISION.md):
Mojo/MAX 26.x (Mojo 1.0.0) compiles Mojo kernels for gfx1151 that
execute on the Radeon 8060S through DeviceContext(api="hip") -
proven by compiled probes with triangulated device-execution
evidence (arch-specific code object, gfx942 build rejected at
launch with hipErrorNoBinaryForGpu, hidden-device runs fail with
hipErrorNoDevice, gpu_busy_percent 99% median under a spin kernel;
hidden_files/a029/). These cases pin the capability in-suite:
vec_add and the engine-shaped GEMM run through core/mojo_gpu_
target.mojo and verify byte-exact against the CPU oracle.

Present/absent discipline matches A-011/A-019: on purpleraider the
HIP device must be real and every case verifies real execution;
on a host without it the cases assert fail-closed behaviour and
pass as honest-absent.
"""
from core.mojo_gpu_target import MojoNative


def _fa(i: Int) -> Float32:
    return Float32((i * 37 + 11) % 997) * Float32(0.5) - Float32(100.0)


def _fb(i: Int) -> Float32:
    return Float32((i * 91 + 7) % 613) * Float32(0.25) + Float32(3.0)


def test_mojo_native_vec_add_oracle() raises:
    print("--- Testing Mojo-native vec_add oracle (A-029) ---")
    if not MojoNative.available():
        print("HIP UNAVAILABLE: vec_add case not run (honest-absent)")
        return
    # 65537 lanes: not a multiple of the 256-wide block, so the
    # kernel bounds guard is exercised, not just the fast path.
    comptime N = 65537
    var a = List[Float32](capacity=N)
    var b = List[Float32](capacity=N)
    for i in range(N):
        a.append(_fa(i))
        b.append(_fb(i))
    var out = MojoNative.vec_add(a, b)
    if len(out) != N:
        raise Error("MojoNative.vec_add: output size mismatch")
    for i in range(N):
        var oracle = _fa(i) + _fb(i)
        if out[i] != oracle:
            raise Error(
                "MojoNative.vec_add mismatch at "
                + String(i)
                + ": got "
                + String(out[i])
                + " want "
                + String(oracle)
            )


def test_mojo_native_gemm_oracle() raises:
    print("--- Testing Mojo-native GEMM oracle (A-029) ---")
    if not MojoNative.available():
        print("HIP UNAVAILABLE: GEMM case not run (honest-absent)")
        return
    comptime M = 64
    comptime N = 64
    comptime K = 64
    var a = List[Float32](capacity=M * K)
    var b = List[Float32](capacity=N * K)
    for i in range(M * K):
        a.append(Float32((i * 7) % 13) * Float32(0.25) - Float32(1.5))
    for i in range(N * K):
        b.append(Float32((i * 5) % 11) * Float32(0.125) - Float32(0.5))
    var c = MojoNative.gemm(a, b, M, N, K)
    if len(c) != M * N:
        raise Error("MojoNative.gemm: output size mismatch")
    for row in range(M):
        for col in range(N):
            var oracle: Float32 = 0.0
            for inner in range(K):
                oracle += a[row * K + inner] * b[col * K + inner]
            if c[row * N + col] != oracle:
                raise Error(
                    "MojoNative.gemm mismatch at row "
                    + String(row)
                    + " col "
                    + String(col)
                )


def test_mojo_native_rejection() raises:
    print("--- Testing Mojo-native rejection (A-029) ---")
    # Shape errors raise before any device work, on every host.
    var a = List[Float32](capacity=4)
    var b = List[Float32](capacity=3)
    for i in range(4):
        a.append(Float32(i))
    for i in range(3):
        b.append(Float32(i))
    var raised = False
    try:
        _ = MojoNative.vec_add(a, b)
    except:
        raised = True
    if not raised:
        raise Error("MojoNative.vec_add accepted mismatched inputs")
    raised = False
    try:
        _ = MojoNative.gemm(a, b, 2, 2, 2)
    except:
        raised = True
    if not raised:
        raise Error("MojoNative.gemm accepted wrong element counts")
    # A device index that does not exist never yields a context:
    # fail-closed on hosts with and without a HIP device alike.
    if MojoNative.probe_device(99):
        raise Error("MojoNative.probe_device(99) reported a device")
    if MojoNative.available():
        if not MojoNative.probe_device(0):
            raise Error("MojoNative.probe_device(0) failed on live device")
        var name = MojoNative.device_name()
        if name.byte_length() == 0:
            raise Error("MojoNative.device_name empty on live device")
