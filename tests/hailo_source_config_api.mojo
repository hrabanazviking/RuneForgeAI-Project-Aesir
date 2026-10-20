# Borrowed-byte ownership and file cleanup; metadata only.
from std.sys import argv
from smidr.source_config import parse_source_config, read_source_config, SourceConfigPolicy
from smidr.tools.source_config import describe_source_config
from smidr.tools.program_integrity import _hex, _signed


def main() raises:
    var args = argv()
    if len(args) == 4 and args[1] == "cleanup":
        var policy = SourceConfigPolicy(1048576, 10000, 10000000, 64)
        for _ in range(40):
            var refused = False
            try:
                _ = read_source_config(args[3], policy)
            except:
                refused = True
            if not refused:
                raise Error("SourceConfigApi: malformed configuration accepted")
            var result = read_source_config(args[2], policy)
            if len(result.fields) != 1:
                raise Error("SourceConfigApi: cleanup fixture differs")
        print("{\"cleanup_cycles\":40,\"execution_tested\":false}")
        return
    if len(args) != 7 or (args[1] != "bytes" and args[1] != "ownership"):
        raise Error("SourceConfigApi: expected bytes/ownership hex byte/field/work/depth")
    var data = _hex(args[2])
    var policy = SourceConfigPolicy(_signed(args[3]), _signed(args[4]), _signed(args[5]), _signed(args[6]))
    var result = parse_source_config(data, policy)
    var snapshot = describe_source_config(result)
    if args[1] == "ownership":
        for i in range(len(data)):
            data[i] = 0
        data.clear()
        if describe_source_config(result) != snapshot:
            raise Error("SourceConfigApi: configuration borrows input bytes")
        var copied = result.fields.copy()
        for key in copied:
            var original = copied[key]
            result.fields[key] = "changed"
            if copied[key] != original:
                raise Error("SourceConfigApi: copied raw values alias")
        result.fields.clear()
    print(snapshot)
