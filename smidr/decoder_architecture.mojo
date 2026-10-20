# Original ordinary architecture intent. No model math or source alias guesses.
from std.collections import Dict
from std.math import isfinite
from smidr.decoder_layers import (
    SourceDecoderLayers, source_decoder_layers, validate_decoder_layers,
    _charge, _bytes, _cursor, _positive, _boolean, _text, _null,
    _same_fields, _same_strings,
)


@fieldwise_init
struct DecoderArchitecturePolicy(Copyable, Movable):
    var entries: Int
    var work: Int


@fieldwise_init
struct SourceDecoderArchitecture(Movable):
    var layers: SourceDecoderLayers
    var policy: DecoderArchitecturePolicy
    var dimensions: Dict[String, Int]
    var flags: Dict[String, Bool]
    var scalars: Dict[String, Float64]
    var activation: String
    var field_origins: Dict[String, String]
    var unresolved: List[String]
    var entry_count: Int
    var work_units: Int


def _admit_entry(mut entries: Int, mut work: Int, policy: DecoderArchitecturePolicy) raises:
    if entries >= policy.entries or work >= policy.work:
        raise Error("DecoderArchitecture: derived entry/work bound exceeded")
    entries += 1
    work += 1


def _origin(mut origins: Dict[String, String], key: String, value: String,
            mut entries: Int, mut work: Int, policy: DecoderArchitecturePolicy) raises:
    _admit_entry(entries, work, policy)
    origins[key] = value


def _note(mut notes: List[String], value: String, mut entries: Int,
          mut work: Int, policy: DecoderArchitecturePolicy) raises:
    _admit_entry(entries, work, policy)
    notes.append(value)


def _number(raw: String) raises -> Float64:
    # Full strict JSON validation is owned by the checked layer snapshot.
    var data = _bytes(raw)
    var parser = _cursor(data)
    parser.skip_ws()
    var first = parser.peek()
    _ = data
    if first != 45 and (first < 48 or first > 57):
        raise Error("DecoderArchitecture: JSON numerical scalar required")
    var value = atof(raw)
    if not isfinite(value) or value <= 0:
        raise Error("DecoderArchitecture: finite positive scalar required")
    return value


def source_decoder_architecture(layers: SourceDecoderLayers,
                                policy: DecoderArchitecturePolicy) raises -> SourceDecoderArchitecture:
    if policy.entries <= 0 or policy.work <= 0:
        raise Error("DecoderArchitecture: explicit positive policies required")
    var entries = _charge(0, len(layers.source.fields), policy.entries)
    var work = _charge(0, entries, policy.work)
    var raw_bytes = 0
    for key in layers.source.fields:
        var size = key.byte_length()
        if size > policy.work or layers.source.fields[key].byte_length() > policy.work - size:
            raise Error("DecoderArchitecture: raw field byte bound exceeded")
        size += layers.source.fields[key].byte_length()
        if size > (policy.work - work) // 4:
            raise Error("DecoderArchitecture: raw source work bound exceeded")
        work += size * 4
        raw_bytes = _charge(raw_bytes, size, layers.source.source_bytes)
    validate_decoder_layers(layers, layers.policy)
    var dimensions = Dict[String, Int]()
    var flags = Dict[String, Bool]()
    var scalars = Dict[String, Float64]()
    var origins = Dict[String, String]()
    var notes = List[String]()
    var integer_keys: List[String] = ["vocab_size", "hidden_size", "intermediate_size", "num_attention_heads", "max_position_embeddings"]
    var integer_defaults: List[Int] = [128256, 2048, 11008, 16, 32768]
    for i in range(len(integer_keys)):
        var key = integer_keys[i]
        var value = integer_defaults[i]
        var origin = String("documented_default:") + String(value)
        if key in layers.source.fields:
            value = _positive(layers.source.fields[key])
            origin = "source"
        _admit_entry(entries, work, policy)
        dimensions[key] = value
        _origin(origins, key, origin, entries, work, policy)
    _admit_entry(entries, work, policy)
    dimensions["num_hidden_layers"] = layers.layer_count
    _origin(origins, "num_hidden_layers", "source", entries, work, policy)
    var kv_key = String("num_key_value_heads")
    var kv_origin = String("absent_unresolved_public_default_conflict")
    var has_kv = kv_key in layers.source.fields
    if has_kv:
        if _null(layers.source.fields[kv_key]):
            has_kv = False
            kv_origin = "source:null_unresolved"
        else:
            var kv = _positive(layers.source.fields[kv_key])
            if dimensions["num_attention_heads"] % kv != 0:
                raise Error("DecoderArchitecture: KV heads must divide query heads")
            _admit_entry(entries, work, policy)
            dimensions[kv_key] = kv
            kv_origin = "source"
    _origin(origins, kv_key, kv_origin, entries, work, policy)
    if not has_kv:
        _note(notes, "kv_head_default_semantics_unresolved", entries, work, policy)
    if "head_dim" in layers.source.fields:
        _origin(origins, "head_dim", "source:unresolved_extension", entries, work, policy)
        _note(notes, "explicit_head_dim_extension_semantics", entries, work, policy)
    elif dimensions["hidden_size"] % dimensions["num_attention_heads"] == 0:
        _admit_entry(entries, work, policy)
        dimensions["head_dim_candidate"] = dimensions["hidden_size"] // dimensions["num_attention_heads"]
        _origin(origins, "head_dim_candidate", "arithmetic_only_requires_source_projection", entries, work, policy)
    else:
        _note(notes, "nonintegral_head_dimension_requires_source_projection", entries, work, policy)
    var flag_keys: List[String] = ["attention_bias", "mlp_bias", "use_cache"]
    for i in range(len(flag_keys)):
        var key = flag_keys[i]
        var value = i == 2
        var origin = String("documented_default:true") if value else String("documented_default:false")
        if key in layers.source.fields:
            value = _boolean(layers.source.fields[key])
            origin = "source"
        _admit_entry(entries, work, policy)
        flags[key] = value
        _origin(origins, key, origin, entries, work, policy)
        if value and i < 2:
            _note(notes, key + "_operation_lowering", entries, work, policy)
    if not flags["use_cache"]:
        _note(notes, "source_cache_disabled_semantics", entries, work, policy)
    var tie_key = String("tie_word_embeddings")
    var tie_origin = String("absent_unresolved")
    var has_tie = tie_key in layers.source.fields
    if has_tie:
        if _null(layers.source.fields[tie_key]):
            has_tie = False
            tie_origin = "source:null_unresolved"
        else:
            var value = _boolean(layers.source.fields[tie_key])
            _admit_entry(entries, work, policy)
            flags[tie_key] = value
            tie_origin = "source"
    _origin(origins, tie_key, tie_origin, entries, work, policy)
    if not has_tie:
        _note(notes, "output_tie_default_semantics_unresolved", entries, work, policy)
    var activation = String("silu")
    var activation_origin = String("documented_default:silu")
    if "hidden_act" in layers.source.fields:
        activation = _text(layers.source.fields["hidden_act"])
        activation_origin = "source"
    _admit_entry(entries, work, policy)
    _origin(origins, "hidden_act", activation_origin, entries, work, policy)
    if activation != "silu":
        _note(notes, "activation_operation_lowering", entries, work, policy)
    var scalar_keys: List[String] = ["rms_norm_eps", "rope_theta"]
    var scalar_defaults: List[Float64] = [0.000001, 2000000.0]
    var scalar_origins: List[String] = ["documented_default:1e-6", "documented_default:2000000"]
    for i in range(len(scalar_keys)):
        var key = scalar_keys[i]
        var value = scalar_defaults[i]
        var origin = scalar_origins[i]
        if key in layers.source.fields:
            value = _number(layers.source.fields[key])
            origin = "source"
        _admit_entry(entries, work, policy)
        scalars[key] = value
        _origin(origins, key, origin, entries, work, policy)
    var scaling_origin = String("absent")
    if "rope_scaling" in layers.source.fields:
        if _null(layers.source.fields["rope_scaling"]):
            scaling_origin = "source:null"
        else:
            var data = _bytes(layers.source.fields["rope_scaling"])
            var parser = _cursor(data)
            parser.skip_ws()
            var is_object = parser.peek() == 123
            _ = data
            if not is_object:
                raise Error("DecoderArchitecture: rotary scaling must be object or null")
            scaling_origin = "source:unresolved_object"
            _note(notes, "rotary_scaling_operation_lowering", entries, work, policy)
    _origin(origins, "rope_scaling", scaling_origin, entries, work, policy)
    if "pretraining_tp" in layers.source.fields:
        _note(notes, "pretraining_tp_semantics", entries, work, policy)
    for note in [String("source_aliases_and_projection_axes"), String("rotary_component_pairing"), String("architecture_modifier_integration"), String("numerical_hailo_execution")]:
        _note(notes, note, entries, work, policy)
    # This fresh owner is independent of every mutable input layer/config field.
    var snapshot = source_decoder_layers(layers.source, layers.policy)
    return SourceDecoderArchitecture(snapshot^, policy.copy(), dimensions^, flags^,
        scalars^, activation^, origins^, notes^, entries, work)


def validate_decoder_architecture(intent: SourceDecoderArchitecture,
                                  policy: DecoderArchitecturePolicy) raises:
    if policy.entries != intent.policy.entries or policy.work != intent.policy.work:
        raise Error("DecoderArchitecture: supplied and owned policy differ")
    var expected = source_decoder_architecture(intent.layers, policy)
    if intent.activation != expected.activation or intent.entry_count != expected.entry_count or intent.work_units != expected.work_units or len(intent.dimensions) != len(expected.dimensions) or len(intent.flags) != len(expected.flags) or len(intent.scalars) != len(expected.scalars):
        raise Error("DecoderArchitecture: derived architecture intent changed")
    for key in expected.dimensions:
        if key not in intent.dimensions or intent.dimensions[key] != expected.dimensions[key]:
            raise Error("DecoderArchitecture: derived dimensions changed")
    for key in expected.flags:
        if key not in intent.flags or intent.flags[key] != expected.flags[key]:
            raise Error("DecoderArchitecture: derived flags changed")
    for key in expected.scalars:
        if key not in intent.scalars or intent.scalars[key] != expected.scalars[key]:
            raise Error("DecoderArchitecture: derived scalar changed")
    _same_fields(intent.field_origins, expected.field_origins)
    _same_strings(intent.unresolved, expected.unresolved)
