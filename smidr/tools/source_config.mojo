# Configuration metadata inspector. Never evaluates model code or parameters.
from std.sys import argv
from smidr.source_config import SourceConfiguration, SourceConfigPolicy, read_source_config
from smidr.tools.source_inventory import _quote
from smidr.tools.program_integrity import _integer


def describe_source_config(result: SourceConfiguration) raises -> String:
    var text = String("{\"schema_version\":1,\"scope\":\"ordinary_source_configuration\",\"source_path\":") + _quote(result.source_path)
    text += ",\"source_bytes\":" + String(result.source_bytes) + ",\"fields_raw\":{"
    var first = True
    for key in result.fields:
        if not first:
            text += ","
        first = False
        text += _quote(key) + ":" + _quote(result.fields[key])
    text += "},\"root_fields\":" + String(len(result.fields)) + ",\"work_units\":" + String(result.work_units)
    return text + ",\"tensors_loaded\":false,\"shards_opened\":false,\"semantic_adapter_verified\":false,\"source_fingerprint_verified\":false,\"hardware_fit_verified\":false,\"execution_tested\":false}"


def main() raises:
    var args = argv()
    if len(args) != 6:
        raise Error("usage: source_config path byte/field/work/depth bounds")
    var policy = SourceConfigPolicy(_integer(args[2]), _integer(args[3]), _integer(args[4]), _integer(args[5]))
    var result = read_source_config(args[1], policy)
    print(describe_source_config(result))
