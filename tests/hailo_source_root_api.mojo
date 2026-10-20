# Direct owner/ABI probes over synthetic files only.
from std.sys import argv
from std.ffi import external_call
from hailbru.syscall import os_beneath_open_how, os_fd_regular_size, os_close, to_cstr
from smidr.source_root import SourceRootPolicy, open_source_model_root
from smidr.tools.program_integrity import _signed
from smidr.tools.hrpc_frame import _to_hex


def implicit(root_path: String, label: String) raises:
    var root = open_source_model_root(root_path, SourceRootPolicy(4095, 10, 100000, 1048576))
    var file = root.open_file(label)
    _ = file
    _ = root


def main() raises:
    var args = argv()
    if len(args) == 3 and args[1] == "abi":
        print(_to_hex(os_beneath_open_how(args[2])))
        return
    if len(args) < 4:
        raise Error("SourceRootApi: expected mode root label")
    var mode = args[1]
    if mode == "implicit":
        implicit(args[2], args[3])
        print("{\"implicit_cleanup\":true}")
        return
    var policy = SourceRootPolicy(4095, 100, 100000, 1048576)
    if len(args) == 8:
        policy = SourceRootPolicy(_signed(args[4]), _signed(args[5]), _signed(args[6]), _signed(args[7]))
    var root_path = String(args[2])
    if mode == "nulroot":
        root_path += "\0tail"
    var root = open_source_model_root(root_path, policy)
    var label = String(args[3])
    if mode == "nullabel":
        label += "\0tail"
    if mode == "rename":
        if len(args) != 5:
            raise Error("SourceRootApi: rename requires new fixture path")
        var old = to_cstr(args[2])
        var new = to_cstr(args[4])
        var rc = external_call["rename", Int32](old, new)
        old.unsafe_free()
        new.unsafe_free()
        if rc != 0:
            raise Error("SourceRootApi: fixture rename failed")
    if mode == "cycles":
        for _ in range(40):
            var refused = False
            try:
                _ = root.open_file("missing.json")
            except:
                refused = True
            if not refused:
                raise Error("SourceRootApi: missing fixture accepted")
            var file = root.open_file(label)
            file.close()
        root.close()
        print("{\"cleanup_cycles\":40}")
        return
    if mode == "closedroot":
        root.close()
        _ = root.open_file(label)
        raise Error("SourceRootApi: closed root unexpectedly admitted")
    if mode == "mutate":
        if len(args) != 6:
            raise Error("SourceRootApi: mutate requires field and value")
        var value = _signed(args[5])
        if args[4] == "path":
            root.policy.path_bytes = value
        elif args[4] == "files":
            root.policy.files = value
        elif args[4] == "work":
            root.policy.work = value
        elif args[4] == "source":
            root.policy.source_bytes = value
        elif args[4] == "attempts":
            root.attempts = value
        elif args[4] == "used":
            root.work_units = value
        else:
            raise Error("SourceRootApi: unknown mutation field")
    var file = root.open_file(label)
    if mode == "unwind":
        raise Error("SourceRootApi: deliberate owner unwind")
    if mode == "repeat":
        file.close()
        _ = root.open_file(label)
    elif mode == "transfer":
        var moved = file^
        root.close()
        var fd = moved.take_fd()
        try:
            if os_fd_regular_size(moved.arch, fd) != moved.source_bytes:
                raise Error("SourceRootApi: transferred fd extent differs")
        except e:
            _ = os_close(moved.arch, fd)
            raise e
        var twice = False
        try:
            _ = moved.take_fd()
        except:
            twice = True
        if os_close(moved.arch, fd) != 0 or not twice:
            raise Error("SourceRootApi: transfer cleanup/double-take guard failed")
        moved.close()
        print("{\"transferred_once\":true,\"root_closed_first\":true}")
        return
    file.close()
    file.close()
    root.close()
    root.close()
    print("{\"explicit_cleanup\":true,\"attempts\":" + String(root.attempts) + ",\"work_units\":" + String(root.work_units) + "}")
