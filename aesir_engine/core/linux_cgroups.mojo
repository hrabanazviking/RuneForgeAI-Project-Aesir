"""Read-only Linux cgroup v2 memory admission through visible mount ancestry.

Namespace-hidden ancestors cannot be observed. Their limits are not guessed.
Known v1 memory control or unreadable/malformed observations fail closed.
"""
from std.ffi import external_call
from std.memory import Pointer
from core.observation_integer import bounded_decimal


def read_kernel_observation(path: String, required: Bool = True) raises -> String:
    var name = List[Int8]()
    for byte in path.as_bytes():
        if byte == 0:
            raise Error("Kernel observation path contains NUL")
        name.append(Int8(byte))
    name.append(0)
    var fd = external_call["open64", Int32](name.unsafe_ptr(), Int32(524288), Int32(0))
    _ = name
    if fd < 0:
        var error = external_call["__errno_location", Pointer[Int32, MutUntrackedOrigin]]().unsafe_load()
        if not required and error == 2:
            return ""
        raise Error("Cannot read kernel memory observation: " + path)
    var output = List[Int8]()
    var chunk = List[Int8]()
    for _ in range(4096):
        chunk.append(0)
    try:
        while True:
            var count = external_call["read", Int](Int(fd), chunk.unsafe_ptr(), Int(4096))
            if count < 0:
                var error = external_call["__errno_location", Pointer[Int32, MutUntrackedOrigin]]().unsafe_load()
                if error == 4:
                    continue
                raise Error("Kernel memory observation read failed")
            if count == 0:
                break
            if count > 1048576 - len(output):
                raise Error("Kernel memory observation exceeds 1 MiB")
            for i in range(count):
                if chunk[i] == 0:
                    raise Error("Kernel memory observation contains NUL")
                output.append(chunk[i])
    except:
        _ = external_call["close", Int32](fd)
        raise
    _ = external_call["close", Int32](fd)
    if len(output) == 0:
        raise Error("Empty kernel memory observation")
    output.append(0)
    return String(unsafe_from_utf8_ptr=output.unsafe_ptr())


def checked_cgroup_path(path: String) raises -> String:
    if not path.startswith("/") or path.byte_length() > 4096:
        raise Error("Invalid cgroup absolute path")
    if path != "/":
        for component in String(path[byte=1:]).split("/"):
            if String(component) == "" or String(component) == "." or String(component) == "..":
                raise Error("Ambiguous cgroup path or hidden namespace ancestry")
    for byte in path.as_bytes():
        if byte == 0:
            raise Error("NUL in cgroup path")
    return path


def decode_mount_path(encoded: String) raises -> String:
    var output = List[Int8]()
    var bytes = encoded.as_bytes()
    var i = 0
    while i < len(bytes):
        if bytes[i] != 92:
            output.append(Int8(bytes[i]))
            i += 1
            continue
        if i + 3 >= len(bytes):
            raise Error("Truncated mountinfo escape")
        var escape = String(encoded[byte=i:i + 4])
        if escape == "\\040":
            output.append(32)
        elif escape == "\\011":
            output.append(9)
        elif escape == "\\012":
            output.append(10)
        elif escape == "\\134":
            output.append(92)
        else:
            raise Error("Unknown mountinfo path escape")
        i += 4
    output.append(0)
    return checked_cgroup_path(String(unsafe_from_utf8_ptr=output.unsafe_ptr()))


def unified_membership(text: String) raises -> String:
    var result = String("")
    for line in text.split("\n"):
        if String(line) == "":
            continue
        var parts = line.split(":", 2)
        if len(parts) != 3:
            raise Error("Malformed cgroup membership")
        var hierarchy = bounded_decimal(String(parts[0]))
        if (hierarchy == 0) != (String(parts[1]) == ""):
            raise Error("Malformed cgroup hierarchy/controller pairing")
        for controller in parts[1].split(","):
            if String(controller) == "memory":
                raise Error("cgroup v1 memory admission is not implemented; refusing host-only budget")
        if String(parts[0]) == "0" and String(parts[1]) == "":
            if result != "":
                raise Error("Duplicate unified cgroup membership")
            result = checked_cgroup_path(String(parts[2]))
    return result


def cgroup_directories(membership: String, mountinfo: String) raises -> List[String]:
    var group = unified_membership(membership)
    var result = List[String]()
    if group == "":
        return result^
    var root = String("")
    var mount = String("")
    for line in mountinfo.split("\n"):
        var halves = line.split(" - ")
        if len(halves) != 2:
            continue
        var right = halves[1].split()
        if len(right) < 3 or String(right[0]) != "cgroup2":
            continue
        var left = halves[0].split()
        if len(left) < 6:
            raise Error("Malformed cgroup mountinfo")
        var candidate = decode_mount_path(String(left[3]))
        if candidate != "/" and group != candidate and not group.startswith(candidate + "/"):
            continue
        if root == "" or candidate.byte_length() < root.byte_length():
            root = candidate
            mount = decode_mount_path(String(left[4]))
    if mount == "":
        raise Error("Cannot resolve visible cgroup2 memory hierarchy")
    var suffix = group if root == "/" else String(group[byte=root.byte_length():])
    var path = mount
    if suffix != "" and suffix != "/":
        path = (String("") if mount == "/" else mount) + suffix
    while True:
        result.append(path)
        if path == mount:
            return result^
        if len(result) >= 512:
            raise Error("Cgroup ancestry exceeds 512 levels")
        var last = 0
        for i in range(path.byte_length()):
            if path.as_bytes()[i] == 47:
                last = i
        path = String("/") if last == 0 else String(path[byte=0:last])


struct CgroupMemoryBudget(Copyable, ImplicitlyCopyable):
    var limit_bytes: Int
    var available_bytes: Int
    var observed_levels: Int
    var active: Bool

    def __init__(out self):
        self.limit_bytes = 9223372036854775807
        self.available_bytes = 9223372036854775807
        self.observed_levels = 0
        self.active = False

    def include(mut self, limit_text: String, current_text: String) raises:
        var limit_value = String(limit_text.strip())
        var current = bounded_decimal(String(current_text.strip()))
        if limit_value != "max":
            var limit = bounded_decimal(limit_value)
            self.limit_bytes = min(self.limit_bytes, limit)
            self.available_bytes = min(self.available_bytes, max(0, limit - current))
        self.observed_levels += 1


def observe_cgroup_memory() raises -> CgroupMemoryBudget:
    var membership = read_kernel_observation("/proc/self/cgroup")
    var directories = cgroup_directories(membership, read_kernel_observation("/proc/self/mountinfo"))
    var result = CgroupMemoryBudget()
    result.active = len(directories) != 0
    for directory in directories:
        var prefix = (String("") if directory == "/" else directory) + "/memory."
        var limit = read_kernel_observation(prefix + "max", False)
        var current = read_kernel_observation(prefix + "current", False)
        if limit == "" and current == "":
            continue  # Root or controller not enabled here; still inspect ancestors.
        if limit == "" or current == "":
            raise Error("Incomplete cgroup memory observation")
        result.include(limit, current)
    if read_kernel_observation("/proc/self/cgroup") != membership:
        raise Error("Cgroup membership changed during memory observation; retry")
    return result
