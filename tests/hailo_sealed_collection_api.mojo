# Test-only lifetime/representation orchestration over tiny ordinary folders.
from std.sys import argv
from std.ffi import external_call
from hailbru.syscall import os_openat, os_close_descriptor, O_CLOEXEC, to_cstr
from smidr.sealed_source_collection import SealedIndexedSourceCollection, SealedUnindexedSourceCollection, SealedCollectionShard, read_sealed_collection_shard_bytes, read_sealed_collection_constants
from smidr.sealed_source_metadata import read_sealed_metadata_bytes
from smidr.tools.sealed_source_collection import _indexed, _unindexed, describe_indexed, describe_unindexed
from smidr.tools.hrpc_frame import _to_hex
from smidr.tools.source_inventory import _quote
from hailo_sealed_safetensors_api import _window


def _move_indexed(var owner: SealedIndexedSourceCollection) -> SealedIndexedSourceCollection:
    return owner^


def _move_unindexed(var owner: SealedUnindexedSourceCollection) -> SealedUnindexedSourceCollection:
    return owner^


def _mutate(path: String, mode: String) raises:
    if mode == "replace" or mode == "rename":
        var original = to_cstr(path)
        var rc: Int32
        if mode == "rename":
            var alternate = to_cstr(path + ".before")
            rc = external_call["rename", Int32](original, alternate)
            alternate.unsafe_free()
        else:
            rc = external_call["unlink", Int32](original)
        original.unsafe_free()
        if rc != 0:
            raise Error("test: original replacement/rename failed")
        var fd = os_openat("aarch64", path, 2 | 64 | O_CLOEXEC(), 384)
        if fd < 0:
            raise Error("test: replacement create failed")
        _ = os_close_descriptor(fd)
    elif mode == "truncate" or mode == "zero" or mode == "same_size":
        var fd = os_openat("aarch64", path, 2 | O_CLOEXEC(), 0)
        if fd < 0:
            raise Error("test: original mutation open failed")
        var rc = Int32(0)
        if mode == "same_size":
            var size = external_call["lseek", Int64](Int32(fd), Int64(0), Int32(2))
            var bytes = List[UInt8](length=1, fill=0)
            if size <= 0 or external_call["pread", Int64](Int32(fd), bytes.unsafe_ptr(), Int64(1), size-1) != 1:
                rc = -1
            else:
                bytes[0] ^= 64
                if external_call["pwrite", Int64](Int32(fd), bytes.unsafe_ptr(), Int64(1), size-1) != 1:
                    rc = -1
        else:
            rc = external_call["ftruncate", Int32](Int32(fd), Int64(1) if mode == "truncate" else Int64(0))
        _ = os_close_descriptor(fd)
        if rc != 0:
            raise Error("test: original mutation failed")


def _snapshot(shard: SealedCollectionShard) raises -> String:
    var bytes = read_sealed_collection_shard_bytes(shard, 1048576)
    var text = String("{\"label\":") + _quote(shard.label) + ",\"bytes_hex\":" + _quote(_to_hex(bytes)) + ",\"windows\":["
    for i in range(len(shard.storage.tensors)):
        if i != 0:
            text += ","
        ref tensor = shard.storage.tensors[i]
        var window = read_sealed_collection_constants(shard, tensor.original_name, 0, tensor.elements, 131072)
        text += _window(window)
    return text + "]}"


def _retained(mut shard: SealedCollectionShard) raises:
    var one = read_sealed_collection_shard_bytes(shard, 1048576)
    var two = read_sealed_collection_shard_bytes(shard, 1048576)
    var expected = _to_hex(two)
    if len(shard.storage.tensors) > 0:
        ref t = shard.storage.tensors[0]
        var a = read_sealed_collection_constants(shard, t.original_name, 0, t.elements, 131072)
        var b = read_sealed_collection_constants(shard, t.original_name, 0, t.elements, 131072)
        var before = _window(b)
        shard.owner.close()
        if len(a.raw_words) > 0:
            a.raw_words[0] ^= 1
            a.binary32_words[0] ^= 1
        if len(a.binding.shape) > 0:
            a.binding.shape[0] = -1
        if _window(b) != before:
            raise Error("test: retained constant windows alias")
    else:
        shard.owner.close()
    one[0] ^= 1
    if _to_hex(two) != expected:
        raise Error("test: retained byte lists alias")


def _closed(shard: SealedCollectionShard) raises:
    var refused = False
    try:
        _ = read_sealed_collection_shard_bytes(shard, 1048576)
    except:
        refused = True
    if not refused:
        raise Error("test: closed retained shard read accepted")
    if len(shard.storage.tensors) > 0:
        refused = False
        try:
            _ = read_sealed_collection_constants(shard, shard.storage.tensors[0].original_name, 0, 0, 1)
        except:
            refused = True
        if not refused:
            raise Error("test: closed retained constant read accepted")


def _bounds(mut shard: SealedCollectionShard, mode: String) raises:
    if mode == "byte_zero":
        _ = read_sealed_collection_shard_bytes(shard, 0)
    elif mode == "byte_short":
        _ = read_sealed_collection_shard_bytes(shard, Int(shard.owner.source_bytes)-1)
    elif mode == "owner_extent":
        shard.owner.source_bytes -= 1
        _ = read_sealed_collection_shard_bytes(shard, 1048576)
    elif mode == "window_first" or mode == "window_count" or mode == "window_bound":
        ref t = shard.storage.tensors[0]
        _ = read_sealed_collection_constants(shard, t.original_name,
            -1 if mode == "window_first" else 0,
            t.elements+1 if mode == "window_count" else t.elements,
            0 if mode == "window_bound" else 131072)


def main() raises:
    var args = List[String]()
    for arg in argv():
        args.append(String(arg))
    if (len(args) != 34 or args[2] != "indexed") and (len(args) != 29 or args[2] != "unindexed"):
        raise Error("usage: hailo_sealed_collection_api mode indexed|unindexed root labels policies")
    var mode = args[1]
    if mode == "recover":
        var bad = args.copy()
        bad[4] = String("invalid.index.json") if args[2] == "indexed" else String("invalid.safetensors")
        for _ in range(3):
            var refused = False
            try:
                if args[2] == "indexed":
                    _ = _indexed(bad, 3)
                else:
                    _ = _unindexed(bad, 3)
            except:
                refused = True
            if not refused:
                raise Error("test: recovery fixture accepted")
    if args[2] == "indexed":
        var owner = _indexed(args, 3)
        if len(owner.shards) > 0:
            _bounds(owner.shards[0], mode)
        if mode == "move":
            owner = _move_indexed(owner^)
        if mode == "cache":
            var other = _indexed(args, 3)
            var before = describe_indexed(owner)
            other.config.config.fields.clear()
            other.index.index.weight_map.clear()
            other.config.digest_hex = "forged"
            other.shards.clear()
            if describe_indexed(owner) != before:
                raise Error("test: independent collection caches alias")
        _mutate(owner.config.label, mode)
        _mutate(owner.index.label, mode)
        for i in range(len(owner.shards)):
            _mutate(owner.shards[i].owner.label, mode)
        var text = describe_indexed(owner)
        var data = String("{\"config_hex\":") + _quote(_to_hex(read_sealed_metadata_bytes(owner.config.source, 1048576)))
        data += ",\"index_hex\":" + _quote(_to_hex(read_sealed_metadata_bytes(owner.index.source, 1048576))) + ",\"shards\":["
        for i in range(len(owner.shards)):
            if i != 0:
                data += ","
            data += _snapshot(owner.shards[i])
        data += "]}"
        if mode == "retained":
            for i in range(len(owner.shards)):
                _retained(owner.shards[i])
        owner.close()
        owner.close()
        for i in range(len(owner.shards)):
            _closed(owner.shards[i])
        var refused = False
        try:
            _ = read_sealed_metadata_bytes(owner.config.source, 1048576)
        except:
            refused = True
        if not refused:
            raise Error("test: closed config read accepted")
        print(text)
        print(data)
    else:
        var owner = _unindexed(args, 3)
        _bounds(owner.shard, mode)
        if mode == "move":
            owner = _move_unindexed(owner^)
        if mode == "cache":
            var other = _unindexed(args, 3)
            var before = describe_unindexed(owner)
            other.config.config.fields.clear()
            other.shard.storage.tensors.clear()
            other.config.digest_hex = "forged"
            if describe_unindexed(owner) != before:
                raise Error("test: independent unindexed caches alias")
        _mutate(owner.config.label, mode)
        _mutate(owner.shard.owner.label, mode)
        var text = describe_unindexed(owner)
        var data = String("{\"config_hex\":") + _quote(_to_hex(read_sealed_metadata_bytes(owner.config.source, 1048576)))
        data += ",\"shards\":[" + _snapshot(owner.shard) + "]}"
        if mode == "retained":
            _retained(owner.shard)
        owner.close()
        owner.close()
        _closed(owner.shard)
        print(text)
        print(data)
