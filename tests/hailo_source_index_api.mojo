# Borrowed source bytes/owned results and exact file read checks only.
from std.sys import argv
from std.memory import Pointer
from std.origin import MutUntrackedOrigin
from armvegr.safetensors import JsonParser
from smidr.source_index import parse_source_index, read_source_index, SourceIndexPolicy
from smidr.source_metadata_file import read_source_metadata_bytes
from smidr.tools.source_index import describe_source_index
from smidr.tools.program_integrity import _hex, _integer, _signed
from smidr.tools.hrpc_frame import _to_hex


def main() raises:
    var args = argv()
    if len(args) == 4 and args[1] == "filehex":
        print(_to_hex(read_source_metadata_bytes(args[2], _signed(args[3]))))
        return
    if len(args) == 6 and args[1] == "span":
        var data = _hex(args[2])
        var parser = JsonParser(Pointer[UInt8, MutUntrackedOrigin](unsafe_from_address=Int(data.unsafe_ptr())), len(data), _integer(args[3]))
        var value = parser.copy_raw_span(_signed(args[4]), _signed(args[5]))
        _ = data
        var bytes = List[UInt8]()
        for byte in value.as_bytes():
            bytes.append(byte)
        _ = value
        print(_to_hex(bytes))
        return
    if len(args) == 6 and args[1] == "cursor":
        var data = _hex(args[2])
        var parser = JsonParser(Pointer[UInt8, MutUntrackedOrigin](unsafe_from_address=Int(data.unsafe_ptr())), len(data), _signed(args[3]))
        parser.pos = _signed(args[4])
        if args[5] == "peek":
            var byte = parser.peek()
            _ = data
            print(String(Int(byte)))
        elif args[5] == "raw":
            var value = parser.parse_raw_value()
            _ = data
            var bytes = List[UInt8]()
            for byte in value.as_bytes():
                bytes.append(byte)
            _ = value
            print(_to_hex(bytes))
        else:
            raise Error("SourceIndexApi: unknown cursor operation")
        return
    if len(args) == 4 and args[1] == "cleanup":
        var policy = SourceIndexPolicy(1048576, 10000, 20000, 10000000, 64)
        for _ in range(40):
            var refused = False
            try:
                _ = read_source_index(args[3], policy)
            except:
                refused = True
            if not refused:
                raise Error("SourceIndexApi: invalid source accepted")
            var result = read_source_index(args[2], policy)
            if len(result.weight_map) != 1:
                raise Error("SourceIndexApi: valid cleanup fixture differs")
        print("{\"cleanup_cycles\":40,\"execution_tested\":false}")
        return
    if len(args) != 8 or (args[1] != "bytes" and args[1] != "ownership"):
        raise Error("SourceIndexApi: expected bytes/ownership hex byte/tensor/field/work/depth")
    var data = _hex(args[2])
    var policy = SourceIndexPolicy(_signed(args[3]), _signed(args[4]), _signed(args[5]), _signed(args[6]), _signed(args[7]))
    var result = parse_source_index(data, policy)
    var snapshot = describe_source_index(result)
    if args[1] == "ownership":
        for i in range(len(data)):
            data[i] = 0
        data.clear()
        if describe_source_index(result) != snapshot:
            raise Error("SourceIndexApi: returned index borrows input bytes")
        var copied = result.weight_map.copy()
        for key in copied:
            var value = copied[key]
            result.weight_map[key] = "changed"
            if copied[key] != value:
                raise Error("SourceIndexApi: copied name mapping aliases")
        result.metadata.clear()
        result.unknown_fields.clear()
    print(snapshot)
