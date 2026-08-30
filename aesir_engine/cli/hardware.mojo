"""CLI presentation of observed resources and executable native model plans."""
from aesir import NativeModelPlan, choose_native_cuda, observe_host_memory, observe_cpu_name, CUDAGate, bounded_decimal


def parse_device_index(value: String) raises -> Int:
    if value == "auto":
        return -1
    var index = bounded_decimal(value)
    if index > 2147483647:
        raise Error("Device index exceeds runtime range")
    return index


def parse_reserve_bytes(value: String) raises -> Int:
    var mib = bounded_decimal(value)
    if mib > 9223372036854775807 // 1048576:
        raise Error("Memory reserve byte count overflow")
    return mib * 1048576


def dispatch_hardware(args: List[String]) raises:
    if len(args) != 2 or args[1] != "list":
        raise Error("usage: aesir hardware list")
    print("Aesir observed hardware (snapshot, not a reservation)")
    var host = observe_host_memory()
    print("cpu:0 name=" + observe_cpu_name() + " backend=cpu memory_domain=system")
    print("  total_bytes=" + String(host.total_bytes) + " available_bytes=" + String(host.available_bytes))
    print("  execution=Linux native CPU Llama F16; other CPU profiles require separate admission")
    var cuda = CUDAGate.discover_physical_devices()
    cuda.validate()
    print("cuda status=" + cuda.status.name() + " detail=" + cuda.message)
    for device in cuda.devices:
        print("cuda:" + String(device.backend_index) + " name=" + device.name)
        print("  runtime_id=" + device.stable_id + " compatible=" + String(device.capabilities.is_compatible))
        print("  source=MAX.DeviceContext.get_memory_info total_bytes=" + String(device.capabilities.total_memory_bytes)
              + " free_bytes=" + String(device.capabilities.free_memory_bytes))
        print("  compute_capability=" + String(device.capabilities.compute_capability_major)
              + "." + String(device.capabilities.compute_capability_minor)
              + " api_version=" + String(device.capabilities.api_version))
        print("  memory_domain=unknown; shared/unified/peer access not probed")
        print("  execution=native Gemma4 E4B and Llama3 8B profiles after model admission")
    print("hip/vulkan/metal/oneapi/npu: execution not implemented; not probed by this command")


def dispatch_compute(args: List[String]) raises:
    if len(args) < 3 or (args[1] != "plan" and args[1] != "explain"):
        raise Error("usage: aesir compute plan|explain <model.gguf> [--profile auto|gemma4|llama3] [--context N] [--device auto|N] [--reserve-mib N]")
    var profile = String("auto")
    var context = 0
    var device = -1
    var reserve = 268435456
    var seen = List[String]()
    var i = 3
    while i < len(args):
        var flag = args[i]
        if i + 1 == len(args) or flag in seen:
            raise Error("Missing or duplicate compute option: " + flag)
        seen.append(flag)
        var value = args[i + 1]
        if flag == "--profile":
            profile = value
        elif flag == "--context":
            context = bounded_decimal(value)
            if context < 2 or context > 32768:
                raise Error("Context must be within 2..32768")
        elif flag == "--device":
            device = parse_device_index(value)
        elif flag == "--reserve-mib":
            reserve = parse_reserve_bytes(value)
        else:
            raise Error("Unknown compute option: " + flag)
        i += 2
    var plan = NativeModelPlan(args[2], profile, context)
    print("profile=" + plan.profile + " context=" + String(plan.context_length))
    print("weights_bytes=" + String(plan.memory.weights_bytes)
          + " kv_bytes=" + String(plan.memory.kv_bytes)
          + " activation_bytes=" + String(plan.memory.activation_bytes))
    print("explicit_device_bytes=" + String(plan.memory.device_bytes)
          + " host_mapping_and_upload_bytes=" + String(plan.memory.host_upload_bytes)
          + " reserve_bytes=" + String(reserve))
    var selected = choose_native_cuda(plan.memory, device, reserve)
    var host = observe_host_memory()
    if reserve > host.available_bytes or plan.memory.host_upload_bytes > host.available_bytes - reserve:
        raise Error("Plan rejected: insufficient host upload memory")
    print("selected=cuda:" + String(selected) + " cpu_offload=0")
    print("reason=compatible device with sufficient observed memory"
          + ("; highest free memory among fitting devices" if device < 0 else "; explicit device selection"))
    print("This validates tensor profile and explicit buffers, not tokenizer compatibility or allocation success.")
    print("No weights uploaded. Driver/tokenizer overhead uses reserve; memory is rechecked at session creation.")
