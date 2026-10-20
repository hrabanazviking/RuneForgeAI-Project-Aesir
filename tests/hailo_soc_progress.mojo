# Host-only consumer of exact-count and directional-completion accounting.
from std.sys import argv
from hailbru.soc_progress import SocRpcProgress, rpc_descriptor_count
from smidr.tools.soc_abi import _uint64
from smidr.tools.hrpc_frame import _from_hex


def _json(value: Bool) -> String:
    return String("true") if value else String("false")


def main() raises:
    var args = argv()
    if len(args) == 5 and args[1] == "count":
        print(String(rpc_descriptor_count(_uint64(args[2]), _uint64(args[3]), _uint64(args[4]))))
        return
    if len(args) < 7 or args[1] != "progress":
        raise Error("usage: progress <input> <output> <input-count> <output-count> <irq> [irq...]")
    var input = _uint64(args[2])
    var output = _uint64(args[3])
    if input > 255 or output > 255:
        raise Error("invalid UInt8 channel")
    var progress = SocRpcProgress(UInt8(input), UInt8(output), 5)
    progress.launched(UInt8(output), Int64(_uint64(args[5])))
    progress.launched(UInt8(input), Int64(_uint64(args[4])))
    for index in range(6, len(args)):
        progress.consume(_from_hex(args[index]))
    print("{\"input_done\":" + _json(progress.input_done) + ",\"output_done\":" + _json(progress.output_done) + ",\"complete\":" + _json(progress.complete()) + "}")
