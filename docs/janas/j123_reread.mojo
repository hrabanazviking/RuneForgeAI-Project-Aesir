# J-123 re-read driver: a synthetic qwen3next GGUF judged by the
# tree's own GGUF loader machinery, at the three levels the
# J-120 protocol (doc section 0.6) pre-registered:
#   1. PackedGGUF census agrees with the fixture's stated census
#      (tensor count, arch, geometry metadata);
#   2. GGUFSeer.inspect_metadata: header + metadata parse and
#      tokenizer validation, incl. the J-123 config field
#      expert_shared_feed_forward_length;
#   3. GGUFSeer.mmap_and_load: state VALIDATED, with the full
#      hybrid tensor map held.
# Usage: j123_reread <file.gguf> <expected_tensor_count>
# No inference runs in this driver: the loader validates and
# maps, nothing is generated. Admission here is loader-level
# only (J-123 doc section 0.1(c)); no session steps this arch.

from std.sys import argv

from core.mimir_well import MimirWell
from loader.gguf import GGUFSeer, GGUFState
from loader.packed_gguf import PackedGGUF
from loader.tokenizer import RuneWeaver
from cli.modelfile import parse_int


def expect(cond: Bool, what: String) raises:
    if not cond:
        raise Error("J123 reread: " + what)


def main() raises:
    var args = argv()
    if len(args) != 3:
        raise Error("usage: j123_reread <file.gguf> <expected_tensor_count>")
    var path = args[1]
    var want = parse_int(args[2])

    # Level 1: PackedGGUF census.
    var packed = PackedGGUF(path)
    expect(len(packed.tensors) == want, "packed census count")
    expect(packed.text("general.architecture") == "qwen3next", "packed arch")
    expect(packed.integer("qwen3next.block_count", -1) == 4, "packed blocks")
    expect(packed.integer("qwen3next.expert_count", -1) == 4, "packed experts")
    expect(
        packed.integer("qwen3next.expert_shared_feed_forward_length", -1) == 8,
        "packed shared width",
    )
    expect("blk.0.ssm_out.weight" in packed.tensors, "packed has blk.0 SSM out")
    expect("blk.3.attn_q.weight" in packed.tensors, "packed has blk.3 attn_q")
    expect(
        "blk.0.attn_q.weight" not in packed.tensors,
        "packed blk.0 carries no attn_q (SSM block)",
    )
    print("PASS: level 1 PackedGGUF census (count, arch, geometry, hybrid directory)")

    # Level 2: GGUFSeer metadata + tokenizer validation.
    var seer = GGUFSeer(path)
    var tokenizer = RuneWeaver()
    seer.inspect_metadata(tokenizer)
    expect(seer.state == GGUFState.HEADER_PARSED, "metadata parse state")
    expect(seer.tensor_count == want, "seer tensor count")
    expect(seer.config.architecture == "qwen3next", "seer arch")
    expect(seer.config.embedding_length == 16, "seer hidden")
    expect(seer.config.block_count == 4, "seer blocks")
    expect(seer.config.expert_count == 4, "seer experts")
    expect(seer.config.expert_used_count == 2, "seer experts used")
    expect(
        seer.config.expert_shared_feed_forward_length == 8, "seer shared width"
    )
    expect(seer.config.ssm_inner_size == 16, "seer SSM inner")
    expect(seer.config.full_attention_interval == 4, "seer interval")
    expect(tokenizer.vocab_size == 16, "tokenizer vocab")
    seer.close()
    print("PASS: level 2 GGUFSeer.inspect_metadata (header, metadata, vocab validated)")

    # Level 3: full mmap_and_load validation.
    var seer2 = GGUFSeer(path)
    var tokenizer2 = RuneWeaver()
    var well = MimirWell(4 * 1024 * 1024)
    seer2.mmap_and_load(well, tokenizer2)
    expect(seer2.state == GGUFState.VALIDATED, "full load reaches VALIDATED")
    expect(len(seer2.tensors) == want, "validated tensor map count")
    seer2.close()
    print("PASS: level 3 GGUFSeer.mmap_and_load (state VALIDATED)")
    print("REREAD DRIVER: ALL PASS")
