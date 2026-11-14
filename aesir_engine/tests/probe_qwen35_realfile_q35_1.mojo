# Q35-1 real-file validation probe (not a suite test).
#
# Seam (precedent: aesir_engine/tests/inject_mmproj.mojo): stage the
# loader exactly as mmap_and_load does -- _open_and_map, _parse_header,
# _parse_metadata, _parse_tensors -- then call _validate_required_tensors
# directly. This does NOT materialize the F16 weight pool: _map_tensor
# maps F16/Q8_0 tensors as zero-copy views into the mmap, and only the
# file's F32 tensors are converted into the pool (real file census:
# 2,645,504 F32 elements = ~5.3 MB as f16). No AesirEngine, no Seer
# dequantization (~57 GB) is involved. MemAvailable must be checked
# before running; the driver is run fenced (24G/32G) regardless.
# Usage: probe_qwen35_realfile_q35_1 <real.gguf>

from std.sys import argv

from core.mimir_well import MimirWell
from loader.gguf import GGMLType, GGUFSeer
from loader.tokenizer import RuneWeaver


def main() raises:
    var arguments = argv()
    if len(arguments) != 2:
        raise Error("usage: probe_qwen35_realfile_q35_1 <real.gguf>")
    var pool = MimirWell(64 * 1024 * 1024)
    var tokenizer = RuneWeaver()
    var seer = GGUFSeer(arguments[1])
    seer._open_and_map()
    seer._parse_header()
    var table_offset = seer._parse_metadata(tokenizer)
    print("arch:", seer.config.architecture, "blocks:", seer.config.block_count, "hidden:", seer.config.embedding_length, "tensors:", seer.tensor_count)
    print("ssm: groups", seer.config.ssm_group_count, "state", seer.config.ssm_state_size, "dt_rank", seer.config.ssm_time_step_rank, "inner", seer.config.ssm_inner_size, "kernel", seer.config.ssm_conv_kernel, "interval", seer.config.full_attention_interval)
    seer._parse_tensors(table_offset, pool)
    print("tensor directory parsed; pool F32-converted elements:", pool.offset)
    seer._validate_required_tensors()
    print("REALFILE VALIDATION: PASS - _validate_qwen35_tensors accepted the real 27B tensor directory")
    ref qkv = seer.tensors["blk.0.attn_qkv.weight"]
    print("blk.0.attn_qkv:", qkv.rows, "x", qkv.cols, "type", seer.tensor_types.get("blk.0.attn_qkv.weight", UInt32(99)))
    ref conv = seer.tensors["blk.0.ssm_conv1d.weight"]
    print("blk.0.ssm_conv1d:", conv.rows, "x", conv.cols, "type", seer.tensor_types.get("blk.0.ssm_conv1d.weight", UInt32(99)))
    _ = GGMLType.Q8_0
