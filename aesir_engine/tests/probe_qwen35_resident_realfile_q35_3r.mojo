# Q35-3r real-file resident probe (not a suite test).
#
# Same no-materialization seam as the Q35-1 probe: stage the loader
# exactly as mmap_and_load does, validate the tensor directory, then
# enforce the Q8_0-resident contract over the real file's directory
# and price its large weights both ways. Q8_0 tensors stay zero-copy
# packed views into the mmap; only the file's F32 tensors convert
# into the pool (27B census: 2,645,504 elements). NO forward path is
# touched and no AesirEngine is constructed. Run fenced; check
# MemAvailable first.
# Usage: probe_qwen35_resident_realfile_q35_3r <real.gguf>

from std.sys import argv

from core.mimir_well import MimirWell
from qwen35_resident import validate_qwen35_resident
from loader.gguf import GGUFSeer
from loader.tokenizer import RuneWeaver


def main() raises:
    var arguments = argv()
    if len(arguments) != 2:
        raise Error("usage: probe_qwen35_resident_realfile_q35_3r <real.gguf>")
    var pool = MimirWell(64 * 1024 * 1024)
    var tokenizer = RuneWeaver()
    var seer = GGUFSeer(arguments[1])
    seer._open_and_map()
    seer._parse_header()
    var table_offset = seer._parse_metadata(tokenizer)
    print("arch:", seer.config.architecture, "blocks:", seer.config.block_count, "hidden:", seer.config.embedding_length, "tensors:", seer.tensor_count)
    seer._parse_tensors(table_offset, pool)
    print("tensor directory parsed; pool F32-converted elements:", pool.offset)
    seer._validate_required_tensors()
    print("DIRECTORY VALIDATION: PASS")
    var report = validate_qwen35_resident(seer)
    print("RESIDENT CENSUS: large_tensors=", report.large_count, " large_elements=", report.large_elements, " q8_0_bytes=", report.q8_bytes, " f16_materialized_bytes=", report.f16_bytes, " mode=", report.load_mode())
    print("RESIDENT VALIDATION: PASS - every large weight of the real file is stored Q8_0 and admitted resident")
