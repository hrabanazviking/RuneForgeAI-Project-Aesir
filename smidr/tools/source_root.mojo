# Real beneath-root regular-file admission inspector; no tensor/model reads.
from std.sys import argv
from smidr.source_root import SourceRootPolicy, open_source_model_root
from smidr.tools.source_inventory import _quote
from smidr.tools.program_integrity import _integer


def main() raises:
    var args = argv()
    if len(args) != 7:
        raise Error("usage: source_root root label path/file/work/source-byte bounds")
    var policy = SourceRootPolicy(_integer(args[3]), _integer(args[4]), _integer(args[5]), _integer(args[6]))
    var root = open_source_model_root(args[1], policy)
    var file = root.open_file(args[2])
    var text = String("{\"schema_version\":1,\"scope\":\"beneath_root_regular_file\",\"label\":") + _quote(file.label)
    text += ",\"source_path\":" + _quote(file.source_path) + ",\"source_bytes\":" + String(file.source_bytes)
    text += ",\"attempts\":" + String(root.attempts) + ",\"work_units\":" + String(root.work_units)
    file.close()
    root.close()
    print(text + ",\"file_admitted\":true,\"tensor_header_parsed\":false,\"source_fingerprint_verified\":false,\"hardware_fit_verified\":false,\"execution_tested\":false}")
