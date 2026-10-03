#!/usr/bin/env python3
"""Bind owned inference-only trace to complete explicit accepted strategy2/3/4 bytes; unscored."""
import argparse
from array import array
import csv
import hashlib
import io
import json
from pathlib import Path
import re
import sqlite3

from launch import digest
from profile_native_cuda import read_text
from check_cuda_trace import analyze
from check_turing_down_source import accepted_model
from check_turing_activations import f32
from check_turing_fixture_controls import reference
from check_turing_model_prefill import parse as source_parse, rope_cache_calls, elementwise_calls
from check_llama3_logits import VOCABULARY

RANGE = "aesir.fixture.prefill"


def parse(path, golden, case, projection_ranges=False, *, allow_down=False, allow_fused=False):
    if type(allow_down) is not bool or type(allow_fused) is not bool or (allow_down and allow_fused) or ((allow_down or allow_fused) and not projection_ranges):
        raise ValueError("Down trace requires explicit projection ranges")
    strategy = 4 if allow_fused else 3 if allow_down else 2
    text = read_text(path, 16 * 1024**2)
    if len(text.encode()) > 16 * 1024**2 or not text.endswith("\n"):
        raise ValueError("Trace CSV exceeds byte limit or lacks complete final line")
    if any(len(line) > 1024 for line in text.splitlines()):
        raise ValueError("Trace CSV line exceeds admission")
    reader = iter(csv.reader(io.StringIO(text), strict=True))
    row = next(reader)
    if not row or not row[0].startswith("[CUDA]") or "api=cuda" not in row[0] or "cpu_offload=0" not in row[0]:
        raise ValueError("Missing native CUDA trace identity")
    row = next(reader)
    if (len(row) != 6 or row[:4] != ["TRACE", "1", str(strategy), str(case)] or
            not re.fullmatch(r"[1-9][0-9]{0,9}", row[4]) or row[5] != RANGE):
        raise ValueError("Wrong trace strategy/case/PID/range")
    pid = int(row[4]); count = len(golden["input_ids"])
    if projection_ranges and next(reader) != ["STAGES","1"]:
        raise ValueError("Missing explicit projection diagnostic marker")
    if next(reader) != ["STATE", *([str(count)] * 4)]:
        raise ValueError("Trace lost exact committed positions")
    for index, token in enumerate(golden["input_ids"]):
        if next(reader) != ["INPUT", str(index), str(token)]:
            raise ValueError("Trace input identity/order mismatch")
    values = array("f")
    for index in range(VOCABULARY):
        row = next(reader)
        if len(row) != 3 or row[:2] != ["LOGIT", str(index)]:
            raise ValueError("Incomplete/duplicate/out-of-order trace logits")
        values.append(f32(row[2]))
    if next(reader) != ["ENQUEUE", str(rope_cache_calls(count, 2)), str(elementwise_calls(count, 2))]:
        raise ValueError("Trace host enqueue counts changed")
    if allow_down or allow_fused:
        if next(reader) != ["DOWN_ROWS128", str((count-1)//32*28)] or next(reader) != ["DOWN_TILE", "128", "32"]:
            raise ValueError("Down trace dispatch counts/selected tile changed")
    fused_calls = None
    original_queries = None
    if allow_fused:
        remaining = count-1
        fused_calls = (remaining//32+(remaining%32)//4)*28
        original_queries = (remaining%4+1)*28
        if next(reader) != ["FUSED_ATTENTION", str(fused_calls), str(original_queries)]:
            raise ValueError("Fused attention actual enqueue/query counts changed")
    row = next(reader)
    if len(row) != 3 or row[:2] != ["CACHE", "176160832"] or not re.fullmatch(r"[0-9a-f]{64}", row[2]):
        raise ValueError("Trace cache record incomplete")
    cache = row[2] == golden["guarded_cache_sha256"]
    if next(reader) != ["GUARD", "1088", "0"] or next(reader) != ["COMPLETE", "prefill_trace", str(VOCABULARY)]:
        raise ValueError("Trace guard/totals incomplete")
    if next(reader, None) is not None:
        raise ValueError("Trailing trace evidence")
    identical = values.tobytes() == golden["logits"].tobytes()
    extra = dict(fused_attention_host_enqueues=fused_calls, original_attention_queries=original_queries) if allow_fused else {}
    return dict(passed=identical and cache, case=case, pid=pid, values=VOCABULARY, projection_ranges=projection_ranges,
                attention_variant=strategy, down128_host_enqueues=(count-1)//32*28 if allow_down or allow_fused else None,
                **extra,
                input_tokens=count, f32_bytes_equal=identical, guarded_cache_equal=cache,
                guards=1088, csv_sha256=hashlib.sha256(text.encode()).hexdigest(),
                f32_sha256=hashlib.sha256(values.tobytes()).hexdigest())


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--unprofiled", type=Path, required=True)
    parser.add_argument("--profiled", type=Path, required=True)
    parser.add_argument("--sqlite", type=Path, required=True)
    parser.add_argument("--binary", type=Path, required=True)
    parser.add_argument("--binary-sha256", required=True)
    parser.add_argument("--model", type=Path, required=True)
    parser.add_argument("--model-sha256", required=True)
    parser.add_argument("--reference-csv", type=Path, required=True)
    parser.add_argument("--reference-report", type=Path, required=True)
    parser.add_argument("--case", type=int, choices=(1, 3), required=True)
    parser.add_argument("--projection-ranges", action="store_true")
    parser.add_argument("--down128", action="store_true")
    parser.add_argument("--fused-attention", action="store_true")
    parser.add_argument("--reference-binary", type=Path)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    report = dict(schema=1, passed=False, collection_complete=False, speed_scored=False)
    with args.output.open("x", encoding="utf-8") as stream:
        try:
            if not all(re.fullmatch(r"[0-9a-f]{64}", s) for s in (args.model_sha256, args.binary_sha256)):
                raise ValueError("Expected exact model/binary SHA256")
            if digest(args.model) != args.model_sha256 or digest(args.binary) != args.binary_sha256:
                raise ValueError("Model/binary identity mismatch")
            if args.fused_attention:
                if args.down128 or not args.projection_ranges or args.reference_binary is None:
                    raise ValueError("Fused trace requires exclusive explicit ranges and actual default4 source binary")
                source, proof = accepted_model(args.reference_csv, args.reference_report, args.model_sha256,
                    fused=True, binary=args.reference_binary)
            elif args.reference_binary is not None:
                raise ValueError("Reference binary belongs only to explicit fused trace")
            elif args.down128:
                if not args.projection_ranges: raise ValueError("Down trace requires explicit projection ranges")
                source, proof = accepted_model(args.reference_csv, args.reference_report, args.model_sha256)
            else:
                _, proof = reference(args.reference_csv, args.reference_report, args.model_sha256)
                if proof["attention_variant"] != 2:
                    raise ValueError("Trace requires accepted strategy2")
                source = source_parse(args.reference_csv)
            if source["csv_sha256"] != proof["csv_sha256"]:
                raise ValueError("Trace source changed during admission")
            golden = source["cases"][args.case]
            unprofiled = parse(args.unprofiled, golden, args.case,args.projection_ranges,allow_down=args.down128,allow_fused=args.fused_attention)
            profiled = parse(args.profiled, golden, args.case,args.projection_ranges,allow_down=args.down128,allow_fused=args.fused_attention)
            report.update(probe_collection_complete=True, unprofiled=unprofiled, profiled=profiled,
                          model_sha256=args.model_sha256, binary_sha256=args.binary_sha256,
                          accepted_reference=proof)
            sqlite_sha = digest(args.sqlite)
            tiles = None
            if args.projection_ranges:
                tiles = {1:1,4:0,32:0};remaining=len(golden["input_ids"])-1
                while remaining:
                    size = 32 if remaining >= 32 else (4 if remaining >= 4 else 1)
                    tiles[size] += 1;remaining -= size
            extra = dict(fused_attention=True) if args.fused_attention else {}
            trace = analyze(args.sqlite, args.binary.name,
                            expected_pid=profiled["pid"], nvtx_range=RANGE,projection_tiles=tiles,down128=args.down128 or args.fused_attention,record_resources=args.down128 or args.fused_attention,**extra)
            if trace["gpu"]["compute"] != "7.5":
                raise ValueError("Trace differs from admitted physical capability7.5")
            report.update(collection_complete=True, unprofiled=unprofiled, profiled=profiled,
                          trace=trace, model_sha256=args.model_sha256, binary_sha256=args.binary_sha256,
                          sqlite_sha256=sqlite_sha, accepted_reference=proof)
            expected = [(args.model, args.model_sha256), (args.binary, args.binary_sha256),
                        (args.reference_csv, proof["csv_sha256"]), (args.reference_report, proof["report_sha256"]),
                        (args.unprofiled, unprofiled["csv_sha256"]), (args.profiled, profiled["csv_sha256"]),
                        (args.sqlite, sqlite_sha)]
            if args.fused_attention: expected.append((args.reference_binary, proof["binary_sha256"]))
            if any(digest(path) != sha for path, sha in expected):
                raise ValueError("Trace artifact changed during validation")
            report["passed"] = unprofiled["passed"] and profiled["passed"]
            report["limits"] = ("One inference-only same-thread synchronized NVTX range, original strict3B/"
                                "context1536/F16KV/sm75 explicit strategy2/3/4. All source F32/cache bytes retained. "
                                "Explicit stage attribution uses successful launch correlations and owned tensors. Recorded resource fields do not infer occupancy/spills or a failure cause. "
                                "API/GPU durations overlap; uncovered time has no inferred cause. No speed score, "
                                "production32, broader context/device/concurrency/soak or provider lead.")
        except (ValueError, OSError, KeyError, StopIteration, csv.Error, sqlite3.Error, KeyboardInterrupt) as error:
            report.update(passed=False, error=f"{type(error).__name__}: {error}")
        json.dump(report, stream, indent=2); stream.write("\n")
    return 0 if report["passed"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
