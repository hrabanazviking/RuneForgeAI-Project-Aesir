# aesir_engine/tests/test_gpu_discovery.mojo
#
# GPU-1 opt-in physical discovery proof. This file is intentionally excluded
# from tests/run_all.mojo because a successful result requires a CUDA device.

from core.cuda_gate import CUDAGate
from core.mimir_well import (
    DeviceTopology,
    DiscoveryStatus,
    GPURealmType,
)


def main() raises:
    var reported_count = CUDAGate.get_device_count()
    var result = CUDAGate.discover_physical_devices()
    result.validate()

    if result.status.value != DiscoveryStatus.SUCCESS:
        raise Error(
            "GPU-1 discovery did not succeed: "
            + result.status.name()
            + ": "
            + result.message
        )
    if reported_count <= 0:
        raise Error("GPU-1 MAX device count was not positive")
    if len(result.devices) != reported_count:
        raise Error(
            "GPU-1 enumerated record count differs from MAX device count"
        )

    var topology = DeviceTopology(1)
    topology.apply_gpu_discovery(result.copy())
    if len(topology.physical_devices) != reported_count:
        raise Error("GPU-1 topology did not retain every observed CUDA device")
    if len(topology.gpu_realms) != 1:
        raise Error("GPU-1 topology did not deduplicate the CUDA realm")

    print("[GPU1] status:", result.status.name())
    print("[GPU1] cuda-device-count:", reported_count)
    for index in range(len(result.devices)):
        var device = result.devices[index].copy()
        device.validate()
        if device.realm.value != GPURealmType.NVIDIA_CUDA:
            raise Error("GPU-1 observed a CUDA device with the wrong realm")
        if device.backend_index != index:
            raise Error("GPU-1 backend-local indices are not ordered")
        if device.api != "cuda":
            raise Error("GPU-1 CUDA device reported a non-CUDA API")
        if not device.capabilities.is_compatible:
            raise Error("GPU-1 observed device is not compatible with MAX")

        var by_index = topology.select_gpu_by_index(
            GPURealmType(GPURealmType.NVIDIA_CUDA), index
        )
        var by_stable_id = topology.select_gpu_by_stable_id(device.stable_id)
        if (
            by_index.stable_id != device.stable_id
            or by_stable_id.backend_index != index
        ):
            raise Error(
                "GPU-1 stable selection did not return the observed device"
            )

        print("[GPU1] device-index:", device.backend_index)
        print("[GPU1] runtime-id:", device.runtime_id)
        print("[GPU1] stable-id:", device.stable_id)
        print("[GPU1] name:", device.name)
        print("[GPU1] api:", device.api)
        print("[GPU1] api-version:", device.capabilities.api_version)
        print(
            "[GPU1] free-memory-bytes:", device.capabilities.free_memory_bytes
        )
        print(
            "[GPU1] total-memory-bytes:", device.capabilities.total_memory_bytes
        )
        print(
            "[GPU1] compute-capability:",
            device.capabilities.compute_capability_major,
            ".",
            device.capabilities.compute_capability_minor,
            sep="",
        )
        print(
            "[GPU1] multiprocessor-count:",
            device.capabilities.multiprocessor_count,
        )
        print(
            "[GPU1] max-threads-per-block:",
            device.capabilities.max_threads_per_block,
        )

    print("[GPU1] topology-selection: pass")
    print("[GPU1] result: PASS")
