#!/usr/bin/env python3
"""Streaming owning-context checkpoint continuation and exact-bit replay gate."""
import argparse
from array import array
import hashlib
import json
from pathlib import Path
import re
import struct

from launch import digest
from profile_native_cuda import read_text
from check_turing_activations import f32
from check_llama3_logits import compare_case, VOCABULARY, MAX_ABSOLUTE_ERROR, MAX_RMS_ERROR
from check_turing_decode_quality import Records, integer, CPUReference, INPUT_HASHES, policy_rows
from check_turing_model_prefill import provenance, attention_variant

MAX_BYTES = 256 * 1024**2
PREFIX = 37
CHECKPOINT = 45
EOS = (128001, 128009)


def unique(pairs):
    result = {}
    for key, value in pairs:
        if key in result: raise ValueError("Duplicate accepted-report JSON key")
        result[key] = value
    return result


def accepted(path, identity, model_sha):
    text = read_text(path, 1024**2)
    if hashlib.sha256(text.encode()).hexdigest() != identity: raise ValueError("Accepted decode report identity changed")
    value = json.loads(text, object_pairs_hook=unique, parse_constant=lambda _: (_ for _ in ()).throw(ValueError("Nonfinite accepted report")))
    if value["schema"] != 1 or value["model_sha256"] != model_sha or value["activation_precision"] != 0 or value["evaluated_frames"] != 96 or value["full_model_values_per_mode"] != 96 * VOCABULARY:
        raise ValueError("Wrong accepted decode model/mode/counts")
    if not all(value[k] is True for k in ("passed", "collection_complete", "native_quality_passed", "replay_passed", "independent_reference_passed")) or value["speed_scored"] is not False:
        raise ValueError("Decode source lacks complete independent acceptance")
    if value["numerical_budget"] != dict(max_absolute_error=MAX_ABSOLUTE_ERROR, max_rms_error=MAX_RMS_ERROR, same_full_vocabulary_argmax=True):
        raise ValueError("Accepted source changed numerical budgets")
    if len(value["cases"]) != 4 or not re.fullmatch(r"[0-9a-f]{64}", value["csv_sha256"]): raise ValueError("Incomplete accepted source identity")
    for index, case in enumerate(value["cases"]):
        frames = 16 if index % 2 else 32
        if case["index"] != index or case["policy"] != index % 2 or case["cap"] != frames or len(case["frames"]) != frames or len(case["replay"]) != frames or case["finish_reason"] != "length": raise ValueError("Accepted source policy/frame mismatch")
        for f in case["frames"]:
            if not f["sample_equal"] or not f["greedy_argmax_passed"] or not f["native_comparison"]["passed"] or not all(v["passed"] for v in f["independent"].values()): raise ValueError("Failed source frame")
        if not all(f["passed"] for f in case["replay"]): raise ValueError("Failed source replay")
    return dict(sha256=identity, csv_sha256=value["csv_sha256"], cases=value["cases"][:2])


def counts(mode):
    tiles = []; left = PREFIX - 1
    while left:
        count = 32 if mode == 1 and left >= 32 else 4 if left >= 4 else 1
        tiles.append(count); left -= count
    return tiles + [1] * 9


def state(row, label, index, step, position):
    if len(row) != 11 or row[:3] != [label, str(index), str(step)]: raise ValueError("Wrong checkpoint state order/identity")
    values = [integer(v, 0, max(VOCABULARY, 1536)) for v in row[3:]]
    native, matrix, np, mp, nh, mh, nd, md = values
    draws = step + 1 if label == "CHECKPOINT" else step + 10
    if not index: draws = 0
    if (np, mp, nh, mh, nd, md) != (position, position, position, position, draws, draws) or native >= VOCABULARY or matrix >= VOCABULARY:
        raise ValueError("Checkpoint causal position/history/draw/ID mismatch")
    if native in EOS: raise ValueError("Unexpected terminal checkpoint/continuation")
    if index and any(v >= 128000 and v not in EOS for v in (native, matrix)): raise ValueError("Reserved seeded checkpoint choice")
    return dict(native_choice=native, matrix_choice=matrix, position=position, history=position, draws=draws)


def vectors(records, index, step):
    result = [array("f") for _ in range(4)]
    for token in range(VOCABULARY):
        row = records.next()
        if len(row) != 8 or row[:4] != ["LOGIT", str(index), str(step), str(token)]: raise ValueError("Incomplete/duplicate/out-of-order checkpoint vectors")
        for mode in range(4): result[mode].append(f32(row[4 + mode]))
    return result


def bit_mismatches(a, b):
    return sum(x != y for x, y in zip(array("I", a.tobytes()), array("I", b.tobytes())))


def case(records, report, index, source, oracle):
    records.expect(["CASE", str(index), str(PREFIX), str(CHECKPOINT), "4"])
    ids = []
    for ordinal in range(CHECKPOINT):
        row = records.next()
        if len(row) != 4 or row[:3] != ["INPUT", str(index), str(ordinal)]: raise ValueError("Checkpoint ID order changed")
        ids.append(integer(row[3], 0, VOCABULARY - 1))
    prefix_hash = hashlib.sha256(b"".join(struct.pack("<I", v) for v in ids[:PREFIX])).hexdigest()
    if prefix_hash != INPUT_HASHES[0] or ids[:PREFIX] != source["input_ids"]: raise ValueError("Public checkpoint prefix changed")
    expected_ids = source["input_ids"] + [f["native_choice"] for f in source["frames"][:8]]
    result = dict(index=index, input_ids=ids, checkpoint_ids_match_source=ids == expected_ids, baseline=[], frames=[])
    report["cases"].append(result)
    for mode in range(2):
        offset = 0
        for ordinal, count in enumerate(counts(mode)):
            records.expect(["TILE", str(index), str(mode), str(ordinal), str(offset), str(count)])
            offset += count
        if offset != CHECKPOINT: raise ValueError("Checkpoint plan total changed")
    cp = state(records.next(), "CHECKPOINT", index, 8, CHECKPOINT)
    result["checkpoint"] = cp
    result["checkpoint_choices_match_source"] = all(cp[k] == source["frames"][8][k] for k in ("native_choice", "matrix_choice"))
    records.expect(["REFUSAL", str(index), "6", str(CHECKPOINT), str(CHECKPOINT), "1"])
    for step in range(4): result["baseline"].append(state(records.next(), "BASE", index, step, CHECKPOINT + 1 + step))
    records.expect(["GUARD", str(index), "0", "1088", "0"])
    draws = "9" if index else "0"
    records.expect(["RESTORED", str(index), str(CHECKPOINT), str(CHECKPOINT), str(CHECKPOINT), str(CHECKPOINT), draws, draws, str(cp["native_choice"]), "1"])
    if oracle is not None: oracle.begin(ids); oracle.advance(cp["native_choice"])
    for step, baseline in enumerate(result["baseline"]):
        again = state(records.next(), "REPLAY", index, step, CHECKPOINT + 1 + step)
        bits = records.next()
        if len(bits) != 5 or bits[:3] != ["BITS", str(index), str(step)]: raise ValueError("Missing checkpoint bit result")
        declared = [integer(v, 0, VOCABULARY) for v in bits[3:]]
        nv, mv, nr, mr = vectors(records, index, step)
        actual = [bit_mismatches(nv, nr), bit_mismatches(mv, mr)]
        if declared != actual: raise ValueError("Reported checkpoint bit count differs from actual bytes")
        metric = dict(baseline=baseline, replay=again, bit_mismatches=actual, own_replay_passed=actual == [0, 0] and baseline == again,
                      baseline_source_choices_match=all(baseline[k] == source["frames"][step + 9][k] for k in ("native_choice", "matrix_choice")),
                      sample_equal=baseline["native_choice"] == baseline["matrix_choice"] and again["native_choice"] == again["matrix_choice"],
                      native_comparison=compare_case(mv, nv), replay_native_comparison=compare_case(mr, nr))
        metric["greedy_argmax_passed"] = bool(index) or (baseline["native_choice"] == metric["native_comparison"]["reference_argmax"] and baseline["matrix_choice"] == metric["native_comparison"]["native_argmax"] and again["native_choice"] == metric["replay_native_comparison"]["reference_argmax"] and again["matrix_choice"] == metric["replay_native_comparison"]["native_argmax"])
        if oracle is not None:
            expected = oracle.expected(CHECKPOINT + step + 1)
            metric["independent"] = {name: compare_case(values, expected) for name, values in zip(("native", "matrix", "restored_native", "restored_matrix"), (nv, mv, nr, mr))}
        result["frames"].append(metric)
        del nv, mv, nr, mr
        if oracle is not None and step < 3: oracle.advance(baseline["native_choice"])
    records.expect(["GUARD", str(index), "1", "1088", "0"])


def initial_report():
    return dict(schema=1, passed=False, collection_complete=False, speed_scored=False, cases=[],
                numerical_budget=dict(max_absolute_error=MAX_ABSOLUTE_ERROR, max_rms_error=MAX_RMS_ERROR, same_full_vocabulary_argmax=True),
                limits="Same-process owning-context mode0 reset/replay only, strict3B/context1536/F16KV, public37 plus eight scalar IDs and four continuation frames/policy. Native-forced original boundaries and seeds. No persisted format/crash recovery/context recreation/production32/concurrency/provider score.")


def parse(path, source, oracle=None, report=None):
    report = initial_report() if report is None else report
    records = Records(path, MAX_BYTES)
    try:
        cuda = records.next()
        if len(cuda) != 1 or not cuda[0].startswith("[CUDA] native Mojo ") or "api=cuda" not in cuda[0] or "cpu_offload=0" not in cuda[0]: raise ValueError("Missing actual native CUDA identity")
        report["native_banner"] = cuda[0]
        row = records.next(); report["attention_variant"] = attention_variant(row)
        if report["attention_variant"] is not None: row = records.next()
        if row != ["META", "1", "turing_checkpoint", "1536", str(VOCABULARY), "2", "4"]: raise ValueError("Wrong checkpoint metadata")
        policy_rows(records)
        for index in range(2): case(records, report, index, source["cases"][index], oracle)
        records.expect(["COMPLETE", "turing_checkpoint", "2", "8", str(8 * VOCABULARY), "4352", "12"])
        report.update(csv_sha256=records.finish(), csv_bytes=records.bytes, collection_complete=True, accepted_source=dict(sha256=source["sha256"], csv_sha256=source["csv_sha256"]), full_model_values_per_mode=8 * VOCABULARY, guards=4352, invalid_plan_refusals=12)
        score(report)
        return report
    finally: records.close()


def score(report):
    frames = [f for c in report["cases"] for f in c["frames"]]
    report["native_quality_passed"] = bool(frames) and all(f["sample_equal"] and f["greedy_argmax_passed"] and f["native_comparison"]["passed"] and f["replay_native_comparison"]["passed"] for f in frames)
    report["replay_passed"] = bool(frames) and all(f["own_replay_passed"] for f in frames)
    report["source_binding_passed"] = bool(frames) and all(c["checkpoint_ids_match_source"] and c["checkpoint_choices_match_source"] for c in report["cases"]) and all(f["baseline_source_choices_match"] for f in frames)
    report["independent_reference_passed"] = bool(frames) and all("independent" in f and all(v["passed"] for v in f["independent"].values()) for f in frames)
    report["passed"] = report["collection_complete"] and all(report[k] for k in ("native_quality_passed", "replay_passed", "source_binding_passed", "independent_reference_passed"))
    if not report["passed"]: report["error"] = "Complete checkpoint quality/bit-replay/source/independent gate failed"
    else: report.pop("error", None)


def main():
    options = argparse.ArgumentParser(description=__doc__)
    options.add_argument("csv", type=Path)
    for name in ("model", "reference-model", "reference-provenance", "accepted-report", "output"): options.add_argument("--" + name, type=Path, required=True)
    for name in ("model-sha256", "reference-sha256", "accepted-report-sha256"): options.add_argument("--" + name, required=True)
    args = options.parse_args()
    if any(not re.fullmatch(r"[0-9a-f]{64}", v) for v in (args.model_sha256, args.reference_sha256, args.accepted_report_sha256)): options.error("Explicit lowercase SHA-256 identities required")
    with args.output.open("x", encoding="utf-8") as output:
        report = initial_report(); oracle = None
        try:
            if digest(args.model) != args.model_sha256 or digest(args.reference_model) != args.reference_sha256: raise ValueError("Original/derived reference checksum mismatch")
            derived = provenance(args.reference_provenance, args.model_sha256, args.reference_sha256)
            if args.reference_model.stat().st_size != derived["derived_bytes"]: raise ValueError("Derived reference size mismatch")
            source = accepted(args.accepted_report, args.accepted_report_sha256, args.model_sha256)
            report.update(model_sha256=args.model_sha256, reference_derivation=derived)
            oracle = CPUReference(args.reference_model); report["independent_reference"] = oracle.identity
            parse(args.csv, source, oracle, report)
            if digest(args.model) != args.model_sha256 or digest(args.reference_model) != args.reference_sha256: raise ValueError("Original/derived model changed during oracle")
            accepted(args.accepted_report, args.accepted_report_sha256, args.model_sha256)
        except (Exception, KeyboardInterrupt) as error: report.update(passed=False, error=f"{type(error).__name__}: {error}")
        finally:
            if oracle is not None:
                try: oracle.close()
                except Exception as error: report.update(passed=False, error=f"Reference cleanup failed: {type(error).__name__}: {error}")
        json.dump(report, output, indent=2, allow_nan=False); output.write("\n")
    print("PASS: exact checkpoint continuation replay" if report["passed"] else "FAIL: " + report["error"])
    return 0 if report["passed"] else 1


if __name__ == "__main__": raise SystemExit(main())
