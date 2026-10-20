# Owned collection snapshots / repeated late-error cleanup over tiny files.
from std.sys import argv
from std.ffi import external_call
from hailbru.syscall import to_cstr
from smidr.source_metadata_file import read_source_metadata_owned_fd
from smidr.tools.hrpc_frame import _to_hex
from smidr.source_root import SourceRootPolicy, open_source_model_root
from smidr.source_index import SourceIndexPolicy
from smidr.source_config import SourceConfigPolicy
from smidr.safetensors_fd import SafetensorsFdPolicy
from smidr.shard_collection import ShardCollectionPolicy, read_indexed_shard_collection
from smidr.tools.shard_collection import describe_shard_collection
from smidr.tools.program_integrity import _signed


def main() raises:
    var args = argv()
    if len(args) == 4 and args[1] == "invalidmetadatafd":
        _ = read_source_metadata_owned_fd(Int64(_signed(args[2])), _signed(args[3]))
        raise Error("ShardCollectionApi: invalid metadata fd accepted")
    if len(args) == 5 and (args[1] == "metadata" or args[1] == "metadata_offset"):
        var directory = open_source_model_root(args[2], SourceRootPolicy(4095, 100, 1000000, 9223372036854775807))
        var file = directory.open_file(args[3])
        if args[1] == "metadata_offset":
            if external_call["lseek", Int64](Int32(file.fd), Int64(0), Int32(2)) != file.source_bytes:
                raise Error("ShardCollectionApi: metadata seek failed")
        var data = read_source_metadata_owned_fd(file.take_fd(), _signed(args[4]))
        directory.close()
        print(_to_hex(data))
        return
    if len(args) != 5:
        raise Error("ShardCollectionApi: expected ownership/cleanup root index config")
    var root = SourceRootPolicy(4095, 100, 1000000, 9223372036854775807)
    var index = SourceIndexPolicy(1048576, 1000, 5000, 10000000, 64)
    var config = SourceConfigPolicy(1048576, 5000, 10000000, 64)
    var fd = SafetensorsFdPolicy(1048576, 1000, 64, 10000000, 64, 1048584)
    var policy = ShardCollectionPolicy(100, 1000, 10000000, 9223372036854775807, 100000000)
    if args[1] == "cleanup":
        for _ in range(20):
            var refused = False
            try:
                _ = read_indexed_shard_collection(args[2], "invalid.index.json", args[4], root, index, config, fd, policy)
            except:
                refused = True
            if not refused:
                raise Error("ShardCollectionApi: inconsistent collection accepted")
            var result = read_indexed_shard_collection(args[2], args[3], args[4], root, index, config, fd, policy)
            if result.tensor_count == 0:
                raise Error("ShardCollectionApi: cleanup fixture empty")
        print("{\"cleanup_cycles\":20,\"execution_tested\":false}")
        return
    var first = read_indexed_shard_collection(args[2], args[3], args[4], root, index, config, fd, policy)
    var second = read_indexed_shard_collection(args[2], args[3], args[4], root, index, config, fd, policy)
    var snapshot = describe_shard_collection(second)
    first.index.weight_map.clear()
    first.index.metadata.clear()
    first.config.fields.clear()
    for i in range(len(first.shards)):
        first.shards[i].storage.metadata.clear()
        for j in range(len(first.shards[i].storage.tensors)):
            first.shards[i].storage.tensors[j].source_shape.clear()
            first.shards[i].storage.tensors[j].original_name = "changed"
    first.shards.clear()
    if describe_shard_collection(second) != snapshot:
        raise Error("ShardCollectionApi: returned collections share mutable metadata")
    print(snapshot)
