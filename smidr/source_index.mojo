# Ordinary shard-index metadata only. No shard opens or numerical/model work.
from std.collections import Dict
from std.memory import Pointer
from std.origin import MutUntrackedOrigin
from armvegr.safetensors import JsonParser
from smidr.source_metadata_file import read_source_metadata_bytes


@fieldwise_init
struct SourceIndexPolicy(Copyable, Movable):
    var bytes: Int
    var tensors: Int
    var fields: Int
    var work: Int
    var depth: Int


@fieldwise_init
struct SourceShardIndex(Movable):
    var source_path: String
    var source_bytes: Int
    var weight_map: Dict[String, String]
    var metadata: Dict[String, String]
    var unknown_fields: Dict[String, String]
    var metadata_present: Bool
    var declared_total_size: Int
    var schema_fields: Int
    var work_units: Int


def _policy(policy: SourceIndexPolicy, size: Int) raises -> Int:
    if policy.bytes <= 0 or policy.tensors <= 0 or policy.fields <= 0 or policy.work <= 0 or policy.depth <= 0 or policy.depth > 64:
        raise Error("SourceIndex: positive policies and depth at most64 required")
    if size < 0 or size > policy.bytes or size > policy.work // 4:
        raise Error("SourceIndex: input byte/work bound exceeded")
    return size * 4


def _member(mut result: SourceShardIndex, policy: SourceIndexPolicy) raises:
    if result.schema_fields >= policy.fields or result.work_units >= policy.work:
        raise Error("SourceIndex: schema member/work bound exceeded")
    result.schema_fields += 1
    result.work_units += 1


def _next(mut parser: JsonParser) raises -> Bool:
    parser.skip_ws()
    if parser.peek() == 125:
        parser.pos += 1
        return False
    if parser.peek() != 44:
        raise Error("SourceIndex: malformed object delimiter")
    parser.pos += 1
    parser.skip_ws()
    # A following parse_string rejects trailing commas.
    return True


def _weight_map(mut parser: JsonParser, mut result: SourceShardIndex,
                policy: SourceIndexPolicy) raises:
    parser.expect(123)
    parser.skip_ws()
    if parser.peek() == 125:
        parser.pos += 1
        return
    while True:
        _member(result, policy)
        if len(result.weight_map) >= policy.tensors:
            raise Error("SourceIndex: tensor entry bound exceeded")
        var name = parser.parse_string()
        if name in result.weight_map:
            raise Error("SourceIndex: duplicate decoded tensor name")
        parser.expect(58)
        var label = parser.parse_string()
        result.weight_map[name] = label
        if not _next(parser):
            break


def _metadata(mut parser: JsonParser, mut result: SourceShardIndex,
              policy: SourceIndexPolicy) raises:
    parser.expect(123)
    result.metadata_present = True
    parser.skip_ws()
    if parser.peek() == 125:
        parser.pos += 1
        return
    while True:
        _member(result, policy)
        var key = parser.parse_string()
        if key in result.metadata:
            raise Error("SourceIndex: duplicate decoded metadata key")
        parser.expect(58)
        var raw: String
        if key == "total_size":
            parser.skip_ws()
            var first = parser.pos
            var size = parser.parse_int()
            if size < 0:
                raise Error("SourceIndex: negative declared total size")
            result.declared_total_size = Int(size)
            raw = parser.copy_raw_span(first, parser.pos)
        else:
            raw = parser.parse_raw_value()
        result.metadata[key] = raw
        if not _next(parser):
            break


def parse_source_index(data: List[UInt8], policy: SourceIndexPolicy) raises -> SourceShardIndex:
    var work = _policy(policy, len(data))
    var pointer = Pointer[UInt8, MutUntrackedOrigin](unsafe_from_address=Int(data.unsafe_ptr()))
    # Complete JSON/UTF-8/duplicate/nesting/EOF validation is independent of
    # schema count limits. The borrowed List remains alive through both passes.
    var complete = JsonParser(pointer, len(data), policy.depth)
    complete.skip_value()
    complete.skip_ws()
    if complete.pos != len(data):
        raise Error("SourceIndex: trailing data after JSON value")
    var result = SourceShardIndex("", len(data), Dict[String, String](),
        Dict[String, String](), Dict[String, String](), False, -1, 0, work)
    var parser = JsonParser(pointer, len(data), policy.depth)
    parser.expect(123)
    parser.skip_ws()
    var seen = Dict[String, Bool]()
    if parser.peek() == 125:
        parser.pos += 1
    else:
        while True:
            _member(result, policy)
            var key = parser.parse_string()
            if key in seen:
                raise Error("SourceIndex: duplicate decoded root key")
            seen[key] = True
            parser.expect(58)
            if key == "weight_map":
                _weight_map(parser, result, policy)
            elif key == "metadata":
                _metadata(parser, result, policy)
            else:
                result.unknown_fields[key] = parser.parse_raw_value()
            if not _next(parser):
                break
    parser.skip_ws()
    if parser.pos != len(data):
        raise Error("SourceIndex: trailing data after index")
    if "weight_map" not in seen:
        raise Error("SourceIndex: missing weight_map")
    _ = data  # Extend the borrowed List through every untracked cursor use.
    return result^


def read_source_index(path: String, policy: SourceIndexPolicy) raises -> SourceShardIndex:
    _ = _policy(policy, 0)
    var data = read_source_metadata_bytes(path, policy.bytes)
    var result = parse_source_index(data, policy)
    result.source_path = path
    return result^
