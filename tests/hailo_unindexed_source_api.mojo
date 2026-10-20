# Owned single-file metadata snapshots and repeated late failures.
from std.sys import argv
from smidr.source_root import SourceRootPolicy
from smidr.source_config import SourceConfigPolicy
from smidr.safetensors_fd import SafetensorsFdPolicy
from smidr.shard_collection import ShardCollectionPolicy, read_unindexed_source_collection
from smidr.tools.unindexed_source import describe_unindexed_source


def main() raises:
    var args = argv()
    if len(args) != 5:
        raise Error("UnindexedSourceApi: expected ownership/cleanup root weights config")
    var root = SourceRootPolicy(4095, 100, 1000000, 9223372036854775807)
    var config = SourceConfigPolicy(1048576, 5000, 10000000, 64)
    var fd = SafetensorsFdPolicy(1048576, 1000, 64, 10000000, 64, 1048584)
    var policy = ShardCollectionPolicy(100, 1000, 10000000, 9223372036854775807, 100000000)
    if args[1] == "cleanup":
        for _ in range(20):
            var refused = False
            try:
                _ = read_unindexed_source_collection(args[2], "invalid.safetensors", args[4], root, config, fd, policy)
            except:
                refused = True
            if not refused:
                raise Error("UnindexedSourceApi: malformed source accepted")
            var result = read_unindexed_source_collection(args[2], args[3], args[4], root, config, fd, policy)
            if result.tensor_count == 0:
                raise Error("UnindexedSourceApi: cleanup fixture is empty")
        print("{\"cleanup_cycles\":20,\"execution_tested\":false}")
        return
    var first = read_unindexed_source_collection(args[2], args[3], args[4], root, config, fd, policy)
    var second = read_unindexed_source_collection(args[2], args[3], args[4], root, config, fd, policy)
    var snapshot = describe_unindexed_source(second)
    first.config.fields.clear()
    first.shard.storage.metadata.clear()
    for i in range(len(first.shard.storage.tensors)):
        first.shard.storage.tensors[i].source_shape.clear()
        first.shard.storage.tensors[i].original_name = "changed"
    first.shard.storage.tensors.clear()
    if describe_unindexed_source(second) != snapshot:
        raise Error("UnindexedSourceApi: copied source records alias")
    print(snapshot)
