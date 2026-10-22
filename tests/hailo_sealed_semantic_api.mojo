# Test-only borrowing of sealed GGUF metadata into the existing structural graph.
# No tensor, layer or attention evaluation and no device admission.
from std.sys import argv
from loader.packed_gguf import PackedGGUF
from loader.tokenizer import RuneWeaver
from smidr.sealed_gguf_source import load_sealed_packed_gguf
from smidr.source_inventory import inventory_from_source
from smidr.semantic_plan import gguf_dense_decoder_parameters, build_dense_semantic_plan
from smidr.tools.semantic_plan import describe_semantic_plan


def main() raises:
    var args = argv()
    if len(args) != 5:
        raise Error("usage: hailo_sealed_semantic_api source query past capacity")
    if args[2] == "path_capacity":
        var source = PackedGGUF(args[1])
        var extent = source.source.file_size
        source.source.file_size = 9223372036854775807
        var refused = False
        try:
            _ = source.source._read_u32(Int(extent))
        except:
            refused = True
        if not refused:
            raise Error("test: old path capacity bound bypassed")
        source.source.file_size = 1
        source.source.close()
        source.source.close()
        print("bounded")
        return
    var owned = load_sealed_packed_gguf(args[1], 1048576, 4096, 4096, 4096)
    if args[2] == "sealed_reentry":
        var original_fd = owned.source.source.fd
        owned.source.source._open_and_map()
        owned.source.source._open_and_map()
        if owned.source.source.fd != original_fd:
            raise Error("test: live sealed descriptor replaced")
        owned.source.source.close()
        var tokenizer = RuneWeaver()
        var refused = False
        try:
            owned.source.source.inspect_metadata(tokenizer)
        except:
            refused = True
        if not refused:
            raise Error("test: closed sealed metadata source reopened")
        refused = False
        try:
            owned.source.source._open_and_map()
        except:
            refused = True
        if not refused:
            raise Error("test: failed metadata source reopened")
        print("bounded")
        return
    var parameters = gguf_dense_decoder_parameters(owned.source)
    var inventory = inventory_from_source(owned.source)
    var plan = build_dense_semantic_plan(inventory^, parameters, Int(args[2]), Int(args[3]), Int(args[4]))
    var text = describe_semantic_plan(plan)
    owned.source.source.close()
    print(text)
