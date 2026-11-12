# tests/bench_oversized_streaming_a049.mojo
# A-049 standalone proof on the oversized fixture (not part of
# run_all: it takes a fixture path and runs for ~a minute over
# 40 GiB). Standalone-harness choice follows the A-046/A-048 pattern
# (bench + docs/bench doc, +0 E-MASTER cases): the proof needs a
# 43 GB fixture and OS residency sampling over minutes, which the
# in-suite harness (no fixture path, seconds-scale) cannot host.
#
# Fixture: hidden_files/fixtures/oversized_a049.gguf -- the pinned
# stories260K F16 GGUF (sha256 57a81ed1...e69e3, the A-004 pin) with
# its 48 real tensors byte-identical, plus 160 pad tensors of
# 256 MiB each built by repeating the real token_embd.weight bytes
# (builder: hidden_files/build_a049_fixture.py). File sha256 is
# pinned by run_a049_bench.sh before and after the run.
#
# Three legs, all numbers printed from live measurement:
# 1. Generation: the ordinary engine (AesirEngine) generates 32
#    greedy tokens from the canonical prompt over the oversized
#    file's mmap. The embedded model is bit-identical to the pinned
#    fixture, so the token IDs must equal the pinned A-004/A-020
#    oracle exactly -- coherent generation, from the oversized file.
# 2. Sweep: OversizedStreaming.sweep_region walks the 40 GiB pad
#    region in 256 MiB windows with drop-behind. Gate: every byte
#    streamed, >= 99% of the region handed back, and the mapping's
#    peak resident bytes bounded by a small fraction of the region
#    (gate: <= region/16), not by the region size.
# 3. Control: touch_region repeats the identical checksum walk with
#    no dropping. Gate: identical checksum (same bytes read) and the
#    mapping's resident bytes grow to >= 90% of the region -- full
#    residency, the behaviour the sweep avoids. The bench then drops
#    the pad region again so the host is left as it was found.

from std.sys import argv

from aesir import AesirEngine
from core.mimir_well import MimirWell
from core.oversized_streaming import OversizedStreaming
from core.weight_residency import WeightResidency
from loader.gguf import GGUFSeer
from loader.tokenizer import RuneWeaver

comptime WINDOW_BYTES = 256 * 1024 * 1024
comptime PAD_TENSOR_BYTES = 16384 * 8192 * 2
comptime PAD_COUNT = 160


def main() raises:
    var arguments = argv()
    if len(arguments) != 2:
        raise Error("usage: bench_oversized_streaming_a049 <oversized.gguf>")

    var rss_start = WeightResidency.process_rss_bytes()
    print("RSS at start (bytes):", rss_start)

    var pool = MimirWell(2 * 1024 * 1024)
    var tokenizer = RuneWeaver()
    var seer = GGUFSeer(arguments[1])
    seer.mmap_and_load(pool, tokenizer)
    if seer.version != 3:
        raise Error("A049: fixture is not GGUF v3")
    if seer.tensor_count != 48 + PAD_COUNT:
        raise Error("A049: fixture tensor count is not 48 real + 160 pad")
    print("file_bytes:", Int(seer.file_size))
    print("tensor_count:", seer.tensor_count)

    var acct = WeightResidency.account(seer)
    print("tensor_payload_bytes:", acct.tensor_payload_bytes)
    print("zero_copy_bytes:", acct.zero_copy_bytes)
    print("converted_source_bytes:", acct.converted_source_bytes)
    print("duplicate_resident_bytes:", acct.duplicate_resident_bytes())
    if not acct.bulk_single_residency():
        raise Error("A049: residency accounting split is incomplete")

    var pad_start = seer.tensor_file_offsets["stream.pad.0000.weight"]
    var pad_end = seer.tensor_file_offsets["stream.pad.0159.weight"] + PAD_TENSOR_BYTES
    var region_bytes = pad_end - pad_start
    print("pad_region_start:", pad_start)
    print("pad_region_bytes:", region_bytes)
    if region_bytes != PAD_COUNT * PAD_TENSOR_BYTES:
        raise Error("A049: pad region is not 160 x 256 MiB")

    var base = seer.mmap_ptr.unsafe_bitcast[UInt8]()
    var baseline = WeightResidency.mapping_accounting(base)
    print("mapping_resident_baseline (bytes):", baseline.resident_bytes)

    # Leg 1 -- coherent generation over the oversized file.
    var engine = AesirEngine(arguments[1], knowledge_capacity=1)
    var result = engine.generate_tokens("One day, Timmy went to", 32)
    var expected = List[Int]()
    expected.append(265)
    expected.append(282)
    expected.append(295)
    expected.append(433)
    expected.append(335)
    expected.append(345)
    expected.append(357)
    expected.append(426)
    expected.append(342)
    expected.append(394)
    expected.append(261)
    expected.append(370)
    expected.append(268)
    expected.append(414)
    expected.append(444)
    expected.append(335)
    expected.append(261)
    expected.append(370)
    expected.append(268)
    expected.append(414)
    expected.append(444)
    expected.append(426)
    expected.append(291)
    expected.append(268)
    expected.append(414)
    expected.append(444)
    expected.append(286)
    expected.append(399)
    expected.append(262)
    expected.append(423)
    expected.append(388)
    expected.append(269)
    if result.generated_token_count() != 32:
        raise Error("A049: generation did not return 32 tokens")
    var gen_line = String("A049_GEN:")
    for index in range(len(expected)):
        if result.token_ids[index] != expected[index]:
            raise Error("A049: generated token differs from pinned oracle")
        gen_line += String(" ") + String(result.token_ids[index])
    print(gen_line)
    print("A049 generation vs pinned oracle: EXACT (32 tokens)")

    # Leg 2 -- streaming sweep over the pad region.
    var sweep = OversizedStreaming.sweep_region(base, pad_start, region_bytes, WINDOW_BYTES)
    print("SWEEP windows:", sweep.windows)
    print("SWEEP bytes_streamed:", sweep.bytes_streamed)
    print("SWEEP bytes_dropped:", sweep.bytes_dropped)
    print("SWEEP dropped_coverage_bp:", sweep.dropped_coverage_bp())
    print("SWEEP checksum:", sweep.checksum)
    print("SWEEP peak_rss_bytes:", sweep.peak_rss_bytes)
    print("SWEEP final_rss_bytes:", sweep.final_rss_bytes)
    print("SWEEP peak_mapping_resident_bytes:", sweep.peak_mapping_resident_bytes)
    print("SWEEP final_mapping_resident_bytes:", sweep.final_mapping_resident_bytes)
    if not sweep.fully_streamed():
        raise Error("A049: sweep did not touch every byte of the region")
    if sweep.dropped_coverage_bp() < 9900:
        raise Error("A049: sweep handed back less than 99% of the region")
    if sweep.peak_mapping_resident_bytes > region_bytes // 16:
        raise Error("A049: sweep peak residency not bounded (exceeds region/16)")
    print("A049 sweep: STREAMING (peak resident bounded, region handed back)")

    # Leg 3 -- control: same walk, no dropping -> full residency.
    var touch = OversizedStreaming.touch_region(base, pad_start, region_bytes, WINDOW_BYTES)
    print("TOUCH windows:", touch.windows)
    print("TOUCH bytes_streamed:", touch.bytes_streamed)
    print("TOUCH bytes_dropped:", touch.bytes_dropped)
    print("TOUCH checksum:", touch.checksum)
    print("TOUCH peak_rss_bytes:", touch.peak_rss_bytes)
    print("TOUCH final_rss_bytes:", touch.final_rss_bytes)
    print("TOUCH peak_mapping_resident_bytes:", touch.peak_mapping_resident_bytes)
    print("TOUCH final_mapping_resident_bytes:", touch.final_mapping_resident_bytes)
    if touch.checksum != sweep.checksum:
        raise Error("A049: control checksum differs -- legs read different bytes")
    if touch.final_mapping_resident_bytes < region_bytes * 9 // 10:
        raise Error("A049: control did not reach full residency")
    print("A049 control: FULL RESIDENCY (same bytes, nothing handed back)")

    # Leave the host as found: hand the pad region back.
    var dropped = OversizedStreaming.drop_region(base, pad_start, region_bytes)
    var after = WeightResidency.mapping_accounting(base)
    print("cleanup_dropped_bytes:", dropped)
    print("mapping_resident_after_cleanup (bytes):", after.resident_bytes)
    print("RSS at end (bytes):", WeightResidency.process_rss_bytes())
    # Lifetime anchor (load-bearing, not decoration): Mojo destroys a
    # variable at its last use, and GGUFSeer.__deinit__ munmaps the
    # file. Every accounting call above reads the mapping through the
    # raw base pointer, which does NOT count as a use of seer -- so
    # without a seer use after the final accounting call, the compiler
    # may deinit seer early and unmap the file mid-proof (observed:
    # mapping_accounting reporting "address not in any readable
    # mapping" on a live seer; strace showed the full-extent munmap
    # landing at the last seer use). This print keeps seer alive
    # across every leg.
    print("seer_alive_at_end: tensors=", seer.tensor_count, " file_bytes=", Int(seer.file_size))
    print("A049_OVERSIZED_STREAMING: PASS")
