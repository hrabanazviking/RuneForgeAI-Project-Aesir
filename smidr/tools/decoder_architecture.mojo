# Owned ordinary parameter intent inspector. No inference or source alias guess.
from std.sys import argv
from std.memory import bitcast
from smidr.source_config import SourceConfigPolicy, read_source_config
from smidr.decoder_layers import DecoderLayerPolicy, source_decoder_layers
from smidr.decoder_architecture import DecoderArchitecturePolicy, SourceDecoderArchitecture, source_decoder_architecture, validate_decoder_architecture
from smidr.tools.decoder_layers import describe_decoder_layers
from smidr.tools.source_inventory import _quote


def describe_decoder_architecture(intent: SourceDecoderArchitecture) raises -> String:
    validate_decoder_architecture(intent, intent.policy)
    var text = String("{\"schema_version\":1,\"architecture_adapter_verified\":false,\"source_projection_axes_verified\":false,\"execution_tested\":false,\"device_access\":false,\"dimensions\":{")
    var first = True
    for key in intent.dimensions:
        if not first:
            text += ","
        first = False
        text += _quote(key) + ":" + String(intent.dimensions[key])
    text += "},\"flags\":{"
    first = True
    for key in intent.flags:
        if not first:
            text += ","
        first = False
        text += _quote(key) + ":" + String("true" if intent.flags[key] else "false")
    text += "},\"scalars\":{"
    first = True
    for key in intent.scalars:
        if not first:
            text += ","
        first = False
        text += _quote(key) + ":" + String(intent.scalars[key])
    text += "},\"scalar_bits\":{"
    first = True
    for key in intent.scalars:
        if not first:
            text += ","
        first = False
        text += _quote(key) + ":" + String(bitcast[DType.uint64](intent.scalars[key]))
    text += "},\"activation\":" + _quote(intent.activation) + ",\"field_origins\":{"
    first = True
    for key in intent.field_origins:
        if not first:
            text += ","
        first = False
        text += _quote(key) + ":" + _quote(intent.field_origins[key])
    text += "},\"unresolved\":["
    for i in range(len(intent.unresolved)):
        if i != 0:
            text += ","
        text += _quote(intent.unresolved[i])
    text += "],\"entry_count\":" + String(intent.entry_count) + ",\"work_units\":" + String(intent.work_units)
    text += ",\"policy\":{\"entries\":" + String(intent.policy.entries) + ",\"work\":" + String(intent.policy.work) + "},\"layers\":" + describe_decoder_layers(intent.layers) + "}"
    return text


def main() raises:
    var args = argv()
    if len(args) != 11:
        raise Error("expected config path config[bytes fields work depth] layer[layers entries work] architecture[entries work]")
    var source = read_source_config(args[1], SourceConfigPolicy(Int(args[2]), Int(args[3]), Int(args[4]), Int(args[5])))
    var layers = source_decoder_layers(source, DecoderLayerPolicy(Int(args[6]), Int(args[7]), Int(args[8])))
    var intent = source_decoder_architecture(layers, DecoderArchitecturePolicy(Int(args[9]), Int(args[10])))
    print(describe_decoder_architecture(intent))
