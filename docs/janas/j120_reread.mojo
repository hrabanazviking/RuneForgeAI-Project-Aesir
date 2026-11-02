# J-120 re-read driver: the converted file judged
# by the tree's own GGUF loader machinery, at the
# three levels the J-120 protocol (doc section 0.6)
# pre-registered:
#   1. PackedGGUF census (names, shapes, types,
#      byte counts, non-overlap is enforced by the
#      packed loader itself) agrees with the
#      conversion's emitted census exactly;
#   2. GGUFSeer.inspect_metadata: header + metadata
#      parse and tokenizer vocabulary validation;
#   3. GGUFSeer.mmap_and_load on the tiny complete
#      synthetic llama: state VALIDATED.
# The expected census below is the fixture's
# (j120_fixtures.py): GGUF dims are [ne0, ne1] =
# [in, out] for 2-D tensors, [n] for 1-D; types
# 30 = BF16 (2-D), 0 = F32 (1-D).
# No inference runs in this driver: the loader
# validates and maps, nothing is generated.

from core.mimir_well import MimirWell
from loader.gguf import GGUFSeer, GGUFState
from loader.packed_gguf import PackedGGUF
from loader.tokenizer import RuneWeaver

comptime GGUF_PATH = "/tmp/j120/work/merged.gguf"


def expect(cond: Bool, what: String) raises:
    if not cond:
        raise Error("J120 reread: " + what)


def main() raises:
    var names = List[String]()
    var cols = List[Int]()
    var rows = List[Int]()
    var kinds = List[Int]()
    var sizes = List[Int]()
    # (name, ne0/cols, rows, ggml type, byte count)
    names.append("token_embd.weight"); cols.append(8); rows.append(8); kinds.append(30); sizes.append(128)
    names.append("output_norm.weight"); cols.append(8); rows.append(1); kinds.append(0); sizes.append(32)
    names.append("output.weight"); cols.append(8); rows.append(8); kinds.append(30); sizes.append(128)
    names.append("blk.0.attn_norm.weight"); cols.append(8); rows.append(1); kinds.append(0); sizes.append(32)
    names.append("blk.0.attn_q.weight"); cols.append(8); rows.append(8); kinds.append(30); sizes.append(128)
    names.append("blk.0.attn_k.weight"); cols.append(8); rows.append(4); kinds.append(30); sizes.append(64)
    names.append("blk.0.attn_v.weight"); cols.append(8); rows.append(4); kinds.append(30); sizes.append(64)
    names.append("blk.0.attn_output.weight"); cols.append(8); rows.append(8); kinds.append(30); sizes.append(128)
    names.append("blk.0.ffn_norm.weight"); cols.append(8); rows.append(1); kinds.append(0); sizes.append(32)
    names.append("blk.0.ffn_gate.weight"); cols.append(8); rows.append(16); kinds.append(30); sizes.append(256)
    names.append("blk.0.ffn_up.weight"); cols.append(8); rows.append(16); kinds.append(30); sizes.append(256)
    names.append("blk.0.ffn_down.weight"); cols.append(16); rows.append(8); kinds.append(30); sizes.append(256)

    # Level 1: PackedGGUF census.
    var packed = PackedGGUF(GGUF_PATH)
    expect(len(packed.tensors) == 12, "packed census count is 12")
    expect(packed.text("general.architecture") == "llama", "packed arch is llama")
    expect(packed.integer("general.alignment", -1) == 32, "packed alignment is 32")
    expect(packed.integer("llama.embedding_length", -1) == 8, "packed hidden is 8")
    expect(packed.integer("llama.block_count", -1) == 1, "packed blocks is 1")
    for i in range(len(names)):
        expect(names[i] in packed.tensors, "packed census has " + names[i])
        var t = packed.tensors[names[i]]
        expect(t.columns == cols[i], "packed cols for " + names[i])
        expect(t.rows == rows[i], "packed rows for " + names[i])
        expect(t.kind == kinds[i], "packed type for " + names[i])
        expect(t.byte_count == sizes[i], "packed bytes for " + names[i])
        var shape = packed.tensor_shape(names[i])
        expect(shape[0] == cols[i], "packed shape[0] for " + names[i])
        if rows[i] > 1:
            expect(len(shape) == 2 and shape[1] == rows[i], "packed shape[1] for " + names[i])
    print("PASS: level 1 PackedGGUF census (12 tensors, shapes/types/bytes agree)")

    # Level 2: GGUFSeer metadata + tokenizer validation.
    var seer = GGUFSeer(GGUF_PATH)
    var tokenizer = RuneWeaver()
    seer.inspect_metadata(tokenizer)
    expect(seer.state == GGUFState.HEADER_PARSED, "metadata parse state")
    expect(seer.tensor_count == 12, "seer tensor count is 12")
    expect(seer.kv_count == 19, "seer kv count is 19")
    expect(seer.config.architecture == "llama", "seer arch is llama")
    expect(seer.config.embedding_length == 8, "seer hidden is 8")
    expect(seer.config.block_count == 1, "seer blocks is 1")
    expect(tokenizer.vocab_size == 8, "tokenizer vocab is 8")
    seer.close()
    print("PASS: level 2 GGUFSeer.inspect_metadata (header, metadata, vocab validated)")

    # Level 3: full mmap_and_load validation.
    var seer2 = GGUFSeer(GGUF_PATH)
    var tokenizer2 = RuneWeaver()
    var well = MimirWell(1024 * 1024)
    seer2.mmap_and_load(well, tokenizer2)
    expect(seer2.state == GGUFState.VALIDATED, "full load reaches VALIDATED")
    expect(len(seer2.tensors) == 12, "validated tensor map holds 12 tensors")
    seer2.close()
    print("PASS: level 3 GGUFSeer.mmap_and_load (state VALIDATED, 12 tensors)")
    print("REREAD DRIVER: ALL PASS")
