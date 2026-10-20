# Ordinary single-file/config source inspector. No index is generated or required.
from std.sys import argv
from smidr.source_root import SourceRootPolicy
from smidr.source_config import SourceConfigPolicy
from smidr.safetensors_fd import SafetensorsFdPolicy
from smidr.shard_collection import SourceUnindexedCollection, ShardCollectionPolicy, read_unindexed_source_collection
from smidr.tools.source_config import describe_source_config
from smidr.tools.source_storage import describe_source_storage
from smidr.tools.source_inventory import _quote
from smidr.tools.program_integrity import _integer


def describe_unindexed_source(result: SourceUnindexedCollection) raises -> String:
    var text = String("{\"schema_version\":1,\"scope\":\"unindexed_source_collection\",\"root_path\":") + _quote(result.root_path)
    text += ",\"config\":" + describe_source_config(result.config) + ",\"source\":{\"label\":" + _quote(result.shard.label)
    text += ",\"storage\":" + describe_source_storage(result.shard.storage) + "}"
    text += ",\"tensor_count\":" + String(result.tensor_count) + ",\"metadata_bytes\":" + String(result.metadata_bytes)
    text += ",\"payload_bytes\":" + String(result.payload_bytes) + ",\"work_units\":" + String(result.work_units)
    return text + ",\"index_present\":false,\"index_tensor_binding_verified\":false,\"tensor_values_loaded\":false,\"semantic_adapter_verified\":false,\"source_fingerprint_verified\":false,\"hardware_fit_verified\":false,\"execution_tested\":false}"


def main() raises:
    var args = argv()
    if len(args) != 23:
        raise Error("usage: unindexed_source root weights config root[4] config[4] fd[6] collection[5] positive policies")
    var root = SourceRootPolicy(_integer(args[4]), _integer(args[5]), _integer(args[6]), _integer(args[7]))
    var config = SourceConfigPolicy(_integer(args[8]), _integer(args[9]), _integer(args[10]), _integer(args[11]))
    var fd = SafetensorsFdPolicy(_integer(args[12]), _integer(args[13]), _integer(args[14]), _integer(args[15]), _integer(args[16]), _integer(args[17]))
    var policy = ShardCollectionPolicy(_integer(args[18]), _integer(args[19]), _integer(args[20]), _integer(args[21]), _integer(args[22]))
    var result = read_unindexed_source_collection(args[1], args[2], args[3], root, config, fd, policy)
    print(describe_unindexed_source(result))
