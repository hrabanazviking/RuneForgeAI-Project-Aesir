# Original source-layer interpretation. Metadata only, never a model forward.
from std.collections import Dict
from std.memory import Pointer
from std.origin import MutUntrackedOrigin
from armvegr.safetensors import JsonParser
from smidr.source_config import SourceConfiguration


@fieldwise_init
struct DecoderLayerPolicy(Copyable, Movable):
    var layers: Int
    var entries: Int
    var work: Int


@fieldwise_init
struct SourceDecoderLayers(Movable):
    var source: SourceConfiguration
    var policy: DecoderLayerPolicy
    var model_type: String
    var layer_count: Int
    var declared_rope_flags: List[Int]
    var rope_enabled: List[Int]
    var layer_types: List[String]
    var no_rope_layer_interval: Int
    var use_sliding_window: Bool
    var window_fields: Dict[String, String]
    var field_origins: Dict[String, String]
    var unresolved: List[String]
    var entry_count: Int
    var work_units: Int


def _charge(used: Int, amount: Int, bound: Int) raises -> Int:
    if used < 0 or amount < 0 or used > bound or amount > bound - used:
        raise Error("DecoderLayers: metadata entry/work bound exceeded")
    return used + amount


def _bytes(raw: String) -> List[UInt8]:
    var data = List[UInt8]()
    data.reserve(raw.byte_length())
    for byte in raw.as_bytes():
        data.append(byte)
    return data^


def _cursor(data: List[UInt8]) -> JsonParser:
    return JsonParser(Pointer[UInt8, MutUntrackedOrigin](unsafe_from_address=Int(data.unsafe_ptr())), len(data), 64)


def _end(mut parser: JsonParser) raises:
    parser.skip_ws()
    if parser.pos != parser.n:
        raise Error("DecoderLayers: trailing raw field data")


def _raw_value(raw: String) raises:
    var data = _bytes(raw)
    var parser = _cursor(data)
    parser.skip_value()
    _end(parser)
    _ = data


def _null(raw: String) raises -> Bool:
    var data = _bytes(raw)
    var parser = _cursor(data)
    parser.skip_ws()
    var result = parser.peek() == 110
    if result:
        parser.expect_word("null")
        _end(parser)
    _ = data
    return result


def _text(raw: String) raises -> String:
    var data = _bytes(raw)
    var parser = _cursor(data)
    var result = parser.parse_string()
    _end(parser)
    _ = data
    return result^


def _positive(raw: String) raises -> Int:
    var data = _bytes(raw)
    var parser = _cursor(data)
    var result = parser.parse_int()
    _end(parser)
    if result <= 0:
        raise Error("DecoderLayers: positive integer source field required")
    _ = data
    return Int(result)


def _boolean(raw: String) raises -> Bool:
    var data = _bytes(raw)
    var parser = _cursor(data)
    parser.skip_ws()
    var result = parser.peek() == 116
    parser.expect_word("true" if result else "false")
    _end(parser)
    _ = data
    return result


def _flags(raw: String, bound: Int) raises -> List[Int]:
    var data = _bytes(raw)
    var parser = _cursor(data)
    parser.expect(91)
    var result = List[Int]()
    parser.skip_ws()
    if parser.peek() != 93:
        while True:
            if len(result) >= bound:
                raise Error("DecoderLayers: declared mask entry bound exceeded")
            var value = parser.parse_int()
            if value != 0 and value != 1:
                raise Error("DecoderLayers: integer0/1 mask required")
            result.append(Int(value))
            parser.skip_ws()
            if parser.peek() == 93:
                break
            parser.expect(44)
    parser.expect(93)
    _end(parser)
    _ = data
    return result^


def _types(raw: String, bound: Int) raises -> List[String]:
    var data = _bytes(raw)
    var parser = _cursor(data)
    parser.expect(91)
    var result = List[String]()
    parser.skip_ws()
    if parser.peek() != 93:
        while True:
            if len(result) >= bound:
                raise Error("DecoderLayers: source layer-type entry bound exceeded")
            result.append(parser.parse_string())
            parser.skip_ws()
            if parser.peek() == 93:
                break
            parser.expect(44)
    parser.expect(93)
    _end(parser)
    _ = data
    return result^


def source_decoder_layers(source: SourceConfiguration,
                          policy: DecoderLayerPolicy) raises -> SourceDecoderLayers:
    if policy.layers <= 0 or policy.entries <= 0 or policy.work <= 0:
        raise Error("DecoderLayers: explicit positive policies required")
    var entries = _charge(0, len(source.fields), policy.entries)
    var work = _charge(0, entries, policy.work)
    if source.source_bytes < 2 or source.source_bytes > (9223372036854775807 - len(source.fields)) // 4 or source.work_units != source.source_bytes * 4 + len(source.fields):
        raise Error("DecoderLayers: inconsistent original config accounting")
    var raw_bytes = 0
    # Charge all retained raw/key bytes before copying or parsing them.
    for key in source.fields:
        var size = key.byte_length()
        if source.fields[key].byte_length() > policy.work - size:
            raise Error("DecoderLayers: source field byte bound exceeded")
        size += source.fields[key].byte_length()
        if size > (policy.work - work) // 4:
            raise Error("DecoderLayers: raw source work bound exceeded")
        work += size * 4
        raw_bytes = _charge(raw_bytes, size, source.source_bytes)
    for key in source.fields:
        _raw_value(source.fields[key])
    if "model_type" not in source.fields:
        raise Error("DecoderLayers: explicit model type required")
    var model = _text(source.fields["model_type"])
    if model != "smollm3":
        raise Error("DecoderLayers: source layer semantics implementation unresolved: " + model)
    var layers = 36
    var layer_origin = String("documented_default:36")
    if "num_hidden_layers" in source.fields:
        layers = _positive(source.fields["num_hidden_layers"])
        layer_origin = "source"
    if layers > policy.layers:
        raise Error("DecoderLayers: source layer count exceeds policy")
    entries = _charge(entries, layers, policy.entries)
    work = _charge(work, layers, policy.work)
    work = _charge(work, layers, policy.work)
    var origins = Dict[String, String]()
    origins["model_type"] = "source"
    origins["num_hidden_layers"] = layer_origin
    var interval = 4
    origins["no_rope_layer_interval"] = "documented_default:4"
    if "no_rope_layer_interval" in source.fields:
        interval = _positive(source.fields["no_rope_layer_interval"])
        origins["no_rope_layer_interval"] = "source"
    var declared = List[Int]()
    var generated = True
    origins["no_rope_layers"] = "absent_then_documented_interval"
    if "no_rope_layers" in source.fields:
        if _null(source.fields["no_rope_layers"]):
            origins["no_rope_layers"] = "source:null_then_documented_interval"
        else:
            declared = _flags(source.fields["no_rope_layers"], min(policy.entries - entries, policy.work - work))
            entries = _charge(entries, len(declared), policy.entries)
            work = _charge(work, len(declared), policy.work)
            if len(declared) < layers:
                raise Error("DecoderLayers: declared mask is shorter than actual layers")
            generated = False
            origins["no_rope_layers"] = "source"
    var effective = List[Int]()
    effective.reserve(layers)
    for i in range(layers):
        effective.append((0 if (i + 1) % interval == 0 else 1) if generated else declared[i])
    var types = List[String]()
    var unresolved = List[String]()
    origins["layer_types"] = "absent"
    if "layer_types" in source.fields:
        if _null(source.fields["layer_types"]):
            origins["layer_types"] = "source:null"
        else:
            types = _types(source.fields["layer_types"], min(policy.entries - entries, policy.work - work))
            entries = _charge(entries, len(types), policy.entries)
            work = _charge(work, len(types), policy.work)
            if len(types) != layers:
                raise Error("DecoderLayers: source layer types must match actual layer count")
            origins["layer_types"] = "source"
    if len(types) == 0:
        unresolved.append("attention_layer_types_not_declared")
    for i in range(len(types)):
        if types[i] != "full_attention":
            unresolved.append("attention_layer_type_semantics:" + String(i))
    var window = False
    origins["use_sliding_window"] = "documented_default:false"
    if "use_sliding_window" in source.fields:
        window = _boolean(source.fields["use_sliding_window"])
        origins["use_sliding_window"] = "source"
    if window:
        unresolved.append("window_architecture_and_mask_lowering")
    var windows = Dict[String, String]()
    for key in [String("sliding_window"), String("max_window_layers")]:
        origins[key] = "absent"
        if key in source.fields:
            windows[key] = source.fields[key]
            if _null(source.fields[key]):
                origins[key] = "source:null"
            else:
                _ = _positive(source.fields[key])
                origins[key] = "source"
    var snapshot = SourceConfiguration(source.source_path, source.source_bytes,
        source.fields.copy(), source.work_units)
    return SourceDecoderLayers(snapshot^, policy.copy(), model^, layers, declared^,
        effective^, types^, interval, window, windows^, origins^, unresolved^, entries, work)


def _same_ints(a: List[Int], b: List[Int]) raises:
    if len(a) != len(b):
        raise Error("DecoderLayers: derived integer array length changed")
    for i in range(len(a)):
        if a[i] != b[i]:
            raise Error("DecoderLayers: derived integer array changed")


def _same_strings(a: List[String], b: List[String]) raises:
    if len(a) != len(b):
        raise Error("DecoderLayers: derived string array length changed")
    for i in range(len(a)):
        if a[i] != b[i]:
            raise Error("DecoderLayers: derived string array changed")


def _same_fields(a: Dict[String, String], b: Dict[String, String]) raises:
    if len(a) != len(b):
        raise Error("DecoderLayers: derived field count changed")
    for key in a:
        if key not in b or a[key] != b[key]:
            raise Error("DecoderLayers: derived source/default provenance changed")


def validate_decoder_layers(intent: SourceDecoderLayers,
                            policy: DecoderLayerPolicy) raises:
    if policy.layers != intent.policy.layers or policy.entries != intent.policy.entries or policy.work != intent.policy.work:
        raise Error("DecoderLayers: supplied and owned policy differ")
    var expected = source_decoder_layers(intent.source, policy)
    if intent.model_type != expected.model_type or intent.layer_count != expected.layer_count or intent.no_rope_layer_interval != expected.no_rope_layer_interval or intent.use_sliding_window != expected.use_sliding_window or intent.entry_count != expected.entry_count or intent.work_units != expected.work_units:
        raise Error("DecoderLayers: derived source intent changed")
    _same_ints(intent.declared_rope_flags, expected.declared_rope_flags)
    _same_ints(intent.rope_enabled, expected.rope_enabled)
    _same_strings(intent.layer_types, expected.layer_types)
    _same_strings(intent.unresolved, expected.unresolved)
    _same_fields(intent.window_fields, expected.window_fields)
    _same_fields(intent.field_origins, expected.field_origins)


def decoder_layer_uses_rope(intent: SourceDecoderLayers, layer: Int) raises -> Bool:
    validate_decoder_layers(intent, intent.policy)
    if layer < 0 or layer >= intent.layer_count:
        raise Error("DecoderLayers: layer index outside declared source intent")
    return intent.rope_enabled[layer] == 1
