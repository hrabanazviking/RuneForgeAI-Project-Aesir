# Actual ordinary indexed file collection inspector; metadata only.
from std.sys import argv
from smidr.source_root import SourceRootPolicy
from smidr.source_index import SourceIndexPolicy
from smidr.source_config import SourceConfigPolicy
from smidr.safetensors_fd import SafetensorsFdPolicy
from smidr.shard_collection import SourceShardCollection, ShardCollectionPolicy, read_indexed_shard_collection
from smidr.tools.source_index import describe_source_index
from smidr.tools.source_config import describe_source_config
from smidr.tools.source_storage import describe_source_storage
from smidr.tools.source_inventory import _quote
from smidr.tools.program_integrity import _integer


def describe_shard_collection(result: SourceShardCollection) raises -> String:
    var text = String("{\"schema_version\":1,\"scope\":\"indexed_source_collection\",\"root_path\":") + _quote(result.root_path)
    text += ",\"index\":" + describe_source_index(result.index) + ",\"config\":" + describe_source_config(result.config) + ",\"shards\":["
    for i in range(len(result.shards)):
        if i != 0:
            text += ","
        ref shard = result.shards[i]
        text += "{\"label\":" + _quote(shard.label) + ",\"storage\":" + describe_source_storage(shard.storage) + "}"
    text += "],\"tensor_count\":" + String(result.tensor_count) + ",\"metadata_bytes\":" + String(result.metadata_bytes)
    text += ",\"payload_bytes\":" + String(result.payload_bytes) + ",\"work_units\":" + String(result.work_units)
    return text + ",\"index_tensor_binding_verified\":true,\"tensor_values_loaded\":false,\"semantic_adapter_verified\":false,\"source_fingerprint_verified\":false,\"hardware_fit_verified\":false,\"execution_tested\":false}"


def main() raises:
    var args = argv()
    if len(args) != 28:
        raise Error("usage: shard_collection root index-label config-label root[4] index[5] config[4] fd[6] collection[5] positive policies")
    var root = SourceRootPolicy(_integer(args[4]), _integer(args[5]), _integer(args[6]), _integer(args[7]))
    var index = SourceIndexPolicy(_integer(args[8]), _integer(args[9]), _integer(args[10]), _integer(args[11]), _integer(args[12]))
    var config = SourceConfigPolicy(_integer(args[13]), _integer(args[14]), _integer(args[15]), _integer(args[16]))
    var fd = SafetensorsFdPolicy(_integer(args[17]), _integer(args[18]), _integer(args[19]), _integer(args[20]), _integer(args[21]), _integer(args[22]))
    var policy = ShardCollectionPolicy(_integer(args[23]), _integer(args[24]), _integer(args[25]), _integer(args[26]), _integer(args[27]))
    var result = read_indexed_shard_collection(args[1], args[2], args[3], root, index, config, fd, policy)
    print(describe_shard_collection(result))
