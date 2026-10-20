# Ordinary configuration metadata; architecture semantics remain a separate owner.
from std.collections import Dict
from std.memory import Pointer
from std.origin import MutUntrackedOrigin
from armvegr.safetensors import JsonParser
from smidr.source_metadata_file import read_source_metadata_bytes


@fieldwise_init
struct SourceConfigPolicy(Copyable, Movable):
    var bytes: Int
    var fields: Int
    var work: Int
    var depth: Int


@fieldwise_init
struct SourceConfiguration(Movable):
    var source_path: String
    var source_bytes: Int
    var fields: Dict[String, String]
    var work_units: Int


def _admit(policy: SourceConfigPolicy, size: Int) raises -> Int:
    if policy.bytes <= 0 or policy.fields <= 0 or policy.work <= 0 or policy.depth <= 0 or policy.depth > 64:
        raise Error("SourceConfig: positive policies and depth at most64 required")
    if size < 0 or size > policy.bytes or size > policy.work // 4:
        raise Error("SourceConfig: input byte/work bound exceeded")
    return size * 4


def parse_source_config(data: List[UInt8], policy: SourceConfigPolicy) raises -> SourceConfiguration:
    var work = _admit(policy, len(data))
    var pointer = Pointer[UInt8, MutUntrackedOrigin](unsafe_from_address=Int(data.unsafe_ptr()))
    # A whole-document pass supplies global duplicate/depth/UTF-8/EOF checks;
    # the second pass retains exact raw values without interpreting modifiers.
    var complete = JsonParser(pointer, len(data), policy.depth)
    complete.skip_value()
    complete.skip_ws()
    if complete.pos != len(data):
        raise Error("SourceConfig: trailing data after JSON value")
    var result = SourceConfiguration("", len(data), Dict[String, String](), work)
    var parser = JsonParser(pointer, len(data), policy.depth)
    parser.expect(123)
    parser.skip_ws()
    if parser.peek() == 125:
        parser.pos += 1
    else:
        while True:
            if len(result.fields) >= policy.fields or result.work_units >= policy.work:
                raise Error("SourceConfig: root field/work bound exceeded")
            var key = parser.parse_string()
            if key in result.fields:
                raise Error("SourceConfig: duplicate decoded root field")
            parser.expect(58)
            result.fields[key] = parser.parse_raw_value()
            result.work_units += 1
            parser.skip_ws()
            if parser.peek() == 125:
                parser.pos += 1
                break
            parser.expect(44)
    parser.skip_ws()
    if parser.pos != len(data):
        raise Error("SourceConfig: trailing configuration data")
    _ = data  # Keep the borrowed byte owner alive through every cursor use.
    return result^


def read_source_config(path: String, policy: SourceConfigPolicy) raises -> SourceConfiguration:
    _ = _admit(policy, 0)
    var data = read_source_metadata_bytes(path, policy.bytes)
    var result = parse_source_config(data, policy)
    result.source_path = path
    return result^
