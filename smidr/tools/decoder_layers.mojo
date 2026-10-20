# Native layer-intent inspector; no source-model evaluation or device access.
from std.sys import argv
from std.collections import Dict
from smidr.source_config import SourceConfigPolicy, read_source_config
from smidr.decoder_layers import DecoderLayerPolicy, SourceDecoderLayers, source_decoder_layers, validate_decoder_layers, decoder_layer_uses_rope
from smidr.tools.source_config import describe_source_config
from smidr.tools.source_inventory import _quote
from smidr.tools.semantic_plan import _integers
from smidr.tools.program_integrity import _integer, _signed


def _fields(fields: Dict[String, String]) raises -> String:
    var text = String("{")
    var first = True
    for key in fields:
        if not first:
            text += ","
        first = False
        text += _quote(key) + ":" + _quote(fields[key])
    return text + "}"


def _strings(values: List[String]) -> String:
    var text = String("[")
    for i in range(len(values)):
        if i != 0:
            text += ","
        text += _quote(values[i])
    return text + "]"


def describe_decoder_layers(intent: SourceDecoderLayers) raises -> String:
    validate_decoder_layers(intent, intent.policy)
    var text = String("{\"schema_version\":1,\"scope\":\"ordinary_decoder_layer_intent\",\"execution_tested\":false,\"device_access\":false,\"complete_architecture_verified\":false,\"physical_layout_verified\":false,\"source_fingerprint_verified\":false")
    text += ",\"source\":" + describe_source_config(intent.source)
    text += ",\"model_type\":" + _quote(intent.model_type) + ",\"layer_count\":" + String(intent.layer_count)
    text += ",\"declared_rope_flags\":" + _integers(intent.declared_rope_flags) + ",\"rope_enabled\":" + _integers(intent.rope_enabled)
    text += ",\"layer_types\":" + _strings(intent.layer_types) + ",\"no_rope_layer_interval\":" + String(intent.no_rope_layer_interval)
    text += ",\"use_sliding_window\":" + String("true" if intent.use_sliding_window else "false")
    text += ",\"window_fields\":" + _fields(intent.window_fields) + ",\"field_origins\":" + _fields(intent.field_origins)
    text += ",\"unresolved\":" + _strings(intent.unresolved) + ",\"entry_count\":" + String(intent.entry_count) + ",\"work_units\":" + String(intent.work_units)
    return text + "}"


def main() raises:
    var args = argv()
    if len(args) != 9 and len(args) != 10:
        raise Error("usage: decoder_layers config config[bytes fields work depth] layer[layers entries work] [query_index]")
    var config_policy = SourceConfigPolicy(_integer(args[2]), _integer(args[3]), _integer(args[4]), _integer(args[5]))
    var policy = DecoderLayerPolicy(_integer(args[6]), _integer(args[7]), _integer(args[8]))
    var config = read_source_config(args[1], config_policy)
    var intent = source_decoder_layers(config, policy)
    var report = describe_decoder_layers(intent)
    if len(args) == 10:
        var index = _signed(args[9])
        var enabled = decoder_layer_uses_rope(intent, index)
        print("{\"intent\":" + report + ",\"query_index\":" + String(index) + ",\"uses_rope\":" + String("true" if enabled else "false") + "}")
    else:
        print(report)
