"""Observed Linux host resources; never substitutes configured memory for facts."""


def bounded_decimal(text: String) raises -> Int:
    var value = 0
    if text.byte_length() == 0:
        raise Error("Expected an unsigned decimal integer")
    for byte in text.as_bytes():
        if byte < 48 or byte > 57:
            raise Error("Expected an unsigned decimal integer")
        var digit = Int(byte - 48)
        if value > (9223372036854775807 - digit) // 10:
            raise Error("Integer overflow")
        value = value * 10 + digit
    return value


struct HostMemory(Copyable, ImplicitlyCopyable):
    var total_bytes: Int
    var available_bytes: Int

    def __init__(out self, total_bytes: Int, available_bytes: Int) raises:
        if total_bytes <= 0 or available_bytes < 0 or available_bytes > total_bytes:
            raise Error("Invalid observed host memory")
        self.total_bytes = total_bytes
        self.available_bytes = available_bytes


def parse_linux_memory(text: String) raises -> HostMemory:
    var total = -1
    var available = -1
    for line in text.split("\n"):
        var parts = line.split()
        if len(parts) == 0:
            continue
        if String(parts[0]) != "MemTotal:" and String(parts[0]) != "MemAvailable:":
            continue
        if len(parts) != 3 or String(parts[2]) != "kB":
            raise Error("Malformed Linux memory observation")
        var kib = bounded_decimal(String(parts[1]))
        if kib > 9223372036854775807 // 1024:
            raise Error("Linux memory byte count overflow")
        if String(parts[0]) == "MemTotal:":
            if total >= 0:
                raise Error("Duplicate MemTotal observation")
            total = kib * 1024
        else:
            if available >= 0:
                raise Error("Duplicate MemAvailable observation")
            available = kib * 1024
    return HostMemory(total, available)


def observe_host_memory() raises -> HostMemory:
    # procfs is the Linux kernel interface, not a machine-specific data path.
    with open("/proc/meminfo", "r") as source:
        return parse_linux_memory(source.read())


def observe_cpu_name() raises -> String:
    var text = String("")
    with open("/proc/cpuinfo", "r") as source:
        text = source.read()
    for line in text.split("\n"):
        var pair = line.split(":", 1)
        if len(pair) == 2 and (String(pair[0].strip()) == "model name" or String(pair[0].strip()) == "Hardware"):
            return String(pair[1].strip())
    return "unknown (kernel did not report a CPU model)"
