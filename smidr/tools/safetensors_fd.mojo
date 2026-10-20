# Actual root -> same descriptor -> owned source inventory. Metadata only.
from std.sys import argv
from smidr.source_root import SourceRootPolicy, open_source_model_root
from smidr.safetensors_fd import SafetensorsFdPolicy, read_safetensors_owned_fd
from smidr.tools.safetensors_inventory import describe_safetensors_inventory
from smidr.tools.program_integrity import _integer


def main() raises:
    var args = argv()
    if len(args) != 13:
        raise Error("usage: safetensors_fd root label root-path/files/work/source-bytes header/tensors/rank/descriptor-work/depth/read-bytes")
    var root_policy = SourceRootPolicy(_integer(args[3]), _integer(args[4]), _integer(args[5]), _integer(args[6]))
    var policy = SafetensorsFdPolicy(_integer(args[7]), _integer(args[8]), _integer(args[9]), _integer(args[10]), _integer(args[11]), _integer(args[12]))
    var root = open_source_model_root(args[1], root_policy)
    var file = root.open_file(args[2])
    var result = read_safetensors_owned_fd(file.take_fd(), policy)
    root.close()
    print(describe_safetensors_inventory(result))
