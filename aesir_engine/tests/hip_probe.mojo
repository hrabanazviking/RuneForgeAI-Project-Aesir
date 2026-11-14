from core.amd_gate import AMDGate

def main():
    print("gate_status:", AMDGate.gate_status())
    print("device_count:", AMDGate.get_device_count())
    var d = AMDGate.discover_physical_devices()
    print("discovery status:", d.status.name(), "|", d.message)
    print("devices:", len(d.devices))
    for dev in d.devices:
        print("dev", dev.backend_index, dev.name, "api=" + dev.api, "free=", dev.capabilities.free_memory_bytes, "compat=", dev.capabilities.is_compatible)
