# Ordinary shard-index inspection; file labels are not opened or resolved.
from std.sys import argv
from std.collections import Dict
from smidr.source_index import SourceShardIndex, SourceIndexPolicy, read_source_index
from smidr.tools.source_inventory import _quote
from smidr.tools.program_integrity import _integer


def _strings(values: Dict[String, String]) raises -> String:
    var text = String("{")
    var first = True
    for key in values:
        if not first:
            text += ","
        first = False
        text += _quote(key) + ":" + _quote(values[key])
    return text + "}"


def describe_source_index(result: SourceShardIndex) raises -> String:
    var text = String("{\"schema_version\":1,\"scope\":\"ordinary_shard_index\",\"source_path\":") + _quote(result.source_path)
    text += ",\"source_bytes\":" + String(result.source_bytes) + ",\"weight_map\":" + _strings(result.weight_map)
    text += ",\"metadata_raw\":" + _strings(result.metadata) + ",\"unknown_fields_raw\":" + _strings(result.unknown_fields)
    text += ",\"metadata_present\":" + String("true" if result.metadata_present else "false")
    text += ",\"declared_total_size\":" + String(result.declared_total_size) + ",\"schema_fields\":" + String(result.schema_fields) + ",\"work_units\":" + String(result.work_units)
    return text + ",\"shards_opened\":false,\"execution_tested\":false,\"source_fingerprint_verified\":false,\"hardware_fit_verified\":false}"


def main() raises:
    var args = argv()
    if len(args) != 7:
        raise Error("usage: source_index path byte/tensor/field/work/depth bounds")
    var policy = SourceIndexPolicy(_integer(args[2]), _integer(args[3]), _integer(args[4]), _integer(args[5]), _integer(args[6]))
    var result = read_source_index(args[1], policy)
    print(describe_source_index(result))
