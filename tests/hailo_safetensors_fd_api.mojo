# Direct copied-header/fd ownership checks only. No tensor values/model math.
from std.sys import argv
from std.ffi import external_call
from armvegr.safetensors import decode_safetensors_header, safetensors_header_length
from hailbru.syscall import os_host_architecture, os_openat, O_RDONLY, O_CLOEXEC, to_cstr, os_close_descriptor
from smidr.source_root import SourceRootPolicy, open_source_model_root
from smidr.safetensors_fd import SafetensorsFdPolicy, read_safetensors_owned_fd
from smidr.safetensors_inventory import safetensors_inventory_from_header
from smidr.tools.safetensors_inventory import describe_safetensors_inventory
from smidr.tools.program_integrity import _hex, _signed


def main() raises:
    var args = argv()
    if len(args) == 5 and args[1] == "length":
        print(String(safetensors_header_length(_hex(args[2]), Int64(_signed(args[3])), _signed(args[4]))))
        return
    if len(args) == 9 and (args[1] == "decode" or args[1] == "ownership"):
        var data = _hex(args[2])
        var header = decode_safetensors_header(data, Int64(_signed(args[3])),
            _signed(args[4]), _signed(args[5]), _signed(args[6]), _signed(args[7]), _signed(args[8]))
        var result = safetensors_inventory_from_header(header)
        var snapshot = describe_safetensors_inventory(result)
        if args[1] == "ownership":
            for i in range(len(data)):
                data[i] = 0
            data.clear()
            header.descs.clear()
            header.metadata.clear()
            if describe_safetensors_inventory(result) != snapshot:
                raise Error("SafetensorsFdApi: metadata borrows header or byte storage")
        print(snapshot)
        return
    var policy = SafetensorsFdPolicy(65536, 64, 32, 16384, 32, 65544)
    if len(args) == 3 and args[1] == "invalidfd":
        _ = read_safetensors_owned_fd(Int64(_signed(args[2])), policy)
        raise Error("SafetensorsFdApi: invalid fd unexpectedly accepted")
    if len(args) == 4 and args[1] == "closeinteger":
        print(String(os_close_descriptor(Int64(_signed(args[2])))))
        print(String(os_close_descriptor(Int64(_signed(args[3])))))
        return
    if len(args) < 4:
        raise Error("SafetensorsFdApi: expected operation root/path label")
    var mode = args[1]
    if len(args) == 10:
        policy = SafetensorsFdPolicy(_signed(args[4]), _signed(args[5]), _signed(args[6]), _signed(args[7]), _signed(args[8]), _signed(args[9]))
    if mode == "direct":
        var arch = os_host_architecture()
        var fd = os_openat(arch, args[2], O_RDONLY() | O_CLOEXEC() | 0x800, 0)
        var result = read_safetensors_owned_fd(fd, policy)
        print(describe_safetensors_inventory(result))
        return
    var root = open_source_model_root(args[2], SourceRootPolicy(4095, 100, 100000, 9223372036854775807))
    if mode == "cleanup":
        for _ in range(40):
            var invalid = root.open_file("invalid.safetensors")
            var refused = False
            try:
                _ = read_safetensors_owned_fd(invalid.take_fd(), policy)
            except:
                refused = True
            if not refused:
                raise Error("SafetensorsFdApi: malformed header accepted")
            var valid = root.open_file(args[3])
            var result = read_safetensors_owned_fd(valid.take_fd(), policy)
            if len(result.tensors) != 1:
                raise Error("SafetensorsFdApi: cleanup fixture count differs")
        root.close()
        print("{\"cleanup_cycles\":40,\"execution_tested\":false}")
        return
    var file = root.open_file(args[3])
    if mode == "replace":
        if len(args) != 5:
            raise Error("SafetensorsFdApi: replacement fixture path required")
        var from_path = to_cstr(args[4])
        var to_path = to_cstr(file.source_path)
        var rc = external_call["rename", Int32](from_path, to_path)
        from_path.unsafe_free()
        to_path.unsafe_free()
        if rc != 0:
            raise Error("SafetensorsFdApi: replacement rename failed")
    if mode == "offset":
        if external_call["lseek", Int64](Int32(file.fd), Int64(0), Int32(2)) != file.source_bytes:
            raise Error("SafetensorsFdApi: fixture seek failed")
    var result = read_safetensors_owned_fd(file.take_fd(), policy)
    root.close()
    print(describe_safetensors_inventory(result))
