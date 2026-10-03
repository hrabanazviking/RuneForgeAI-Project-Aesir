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
from check_turing_model_prefill import provenance, attention_variant, fused_attention_calls

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


def accepted(path, identity, model_sha, *, allow_down=False, allow_fused=False, binary=None):
    if allow_down and allow_fused: raise ValueError("Checkpoint source strategies are exclusive")
    binary_sha = digest(binary) if allow_fused and binary is not None else None
    if allow_fused and binary_sha is None: raise ValueError("Fused checkpoint requires actual accepted decode binary")
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
    if allow_down or allow_fused:
        variant = 4 if allow_fused else 3
        from check_turing_down_source import fixed_comparison
        cpu = value.get("independent_reference", {})
        proof = value.get("accepted_fused_model" if allow_fused else "accepted_down_model", {})
        if (type(value.get("schema")) is not int or type(value.get("activation_precision")) is not int or
            type(value.get("attention_variant")) is not int or value["attention_variant"] != variant or value.get("model_source_passed") is not True or
            proof.get("passed") is not True or proof.get("attention_variant") != variant or proof.get("model_sha256") != model_sha or
            any(not re.fullmatch(r"[0-9a-f]{64}", proof.get(k, "")) for k in ("csv_sha256", "report_sha256")) or
            type(cpu.get("requested_gpu_layers")) is not int or cpu["requested_gpu_layers"] != 0 or
            cpu.get("context") != 4096 or cpu.get("kv") != "f16" or cpu.get("batch") != 128 or cpu.get("threads") != 4 or
            cpu.get("weight_mode") != "dequantized_f32" or cpu.get("numpy") != "2.4.4" or cpu.get("llama_cpp_python") != "0.3.23" or
            not re.fullmatch(r"[0-9a-f]{64}", cpu.get("library_sha256", "")) or value.get("guards") != 4352):
            raise ValueError("Checkpoint requires exact explicit source/model and zero-GPU F32 identity")
        if allow_fused and (type(proof.get("attention_variant")) is not int or proof.get("control_capable") is not False or
            value.get("binary_sha256") != binary_sha or not re.fullmatch(r"[0-9a-f]{64}", proof.get("binary_sha256", ""))):
            raise ValueError("Fused accepted decode/model binary identity mismatch")
    elif value.get("attention_variant") in (3, 4):
        raise ValueError("Strategy3/4 checkpoint source requires explicit opt-in")
    for index, case in enumerate(value["cases"]):
        frames = 16 if index % 2 else 32
        if case["index"] != index or case["policy"] != index % 2 or case["cap"] != frames or len(case["frames"]) != frames or len(case["replay"]) != frames or case["finish_reason"] != "length": raise ValueError("Accepted source policy/frame mismatch")
        for f in case["frames"]:
            if not f["sample_equal"] or not f["greedy_argmax_passed"] or not f["native_comparison"]["passed"] or not all(v["passed"] for v in f["independent"].values()): raise ValueError("Failed source frame")
        if not all(f["passed"] for f in case["replay"]): raise ValueError("Failed source replay")
        if allow_down or allow_fused:
            ids = case["input_ids"]
            if any(type(token) is not int or not 0 <= token < VOCABULARY for token in ids):
                raise ValueError("Checkpoint source input IDs invalid")
            identity_hash = hashlib.sha256(b"".join(struct.pack("<I", token) for token in ids)).hexdigest()
            if identity_hash != INPUT_HASHES[index//2] or case.get("input_sha256") != identity_hash:
                raise ValueError("Checkpoint source public input identity changed")
            count = len(ids); calls = ((count-1)//32)*28
            if (case.get("model_source_vectors_passed") is not True or case.get("down128_host_enqueues") != calls or
                case.get("replay_down128_host_enqueues") != calls or type(case.get("down128_host_enqueues")) is not int or
                type(case.get("replay_down128_host_enqueues")) is not int or case.get("evaluated_frames") != frames or
                any(not fixed_comparison(f["native_comparison"]) or set(f["independent"]) != {"native", "matrix"} or
                    any(not fixed_comparison(c) for c in f["independent"].values()) for f in case["frames"])):
                raise ValueError("Checkpoint source numerical/counter coverage mismatch")
            if allow_fused:
                fused, original = fused_attention_calls(count)
                required = dict(fused_attention_host_enqueues=fused, original_attention_queries=original,
                    replay_fused_attention_host_enqueues=fused, replay_original_attention_queries=original+(frames-1)*28)
                if any(type(case.get(k)) is not int or case[k] != v for k,v in required.items()):
                    raise ValueError("Fused accepted source attention counter mismatch")
            for step, (frame, replay) in enumerate(zip(case["frames"], case["replay"], strict=True)):
                draws = step+1 if index%2 else 0
                if (any(frame.get(k) is not True for k in ("sample_equal", "greedy_argmax_passed")) or
                    replay.get("passed") is not True or any(frame.get(k) != count+step or replay.get(k) != count+step for k in ("position", "history")) or
                    frame.get("draws") != draws or replay.get("draws") != draws or
                    any(replay.get(k) != frame.get(k) for k in ("native_choice", "matrix_choice")) or
                    any(replay.get(k) != 0 for k in ("native_replay_bit_mismatches", "matrix_replay_bit_mismatches"))):
                    raise ValueError("Checkpoint source causal/sample/replay state mismatch")

    if allow_fused and digest(binary) != binary_sha: raise ValueError("Accepted decode binary changed during admission")
    return dict(sha256=identity, csv_sha256=value["csv_sha256"], cases=value["cases"][:2],
        **({"attention_variant": 4 if allow_fused else 3} if allow_down or allow_fused else {}),
        **({"binary_sha256": binary_sha} if allow_fused else {}))


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
    fused = report.get("attention_variant") == 4
    down = report.get("attention_variant") in (3, 4)
    calls = ((PREFIX-1)//32)*28
    if down:
        records.expect(["DOWN_ROWS128", str(index), str(calls)])
        result["down128_host_enqueues"] = calls
    if fused:
        fused_calls, original = fused_attention_calls(PREFIX)
        original += (CHECKPOINT-PREFIX)*28
        records.expect(["FUSED_ATTENTION", str(index), str(fused_calls), str(original)])
        result.update(fused_attention_host_enqueues=fused_calls, original_attention_queries=original)
    cp = state(records.next(), "CHECKPOINT", index, 8, CHECKPOINT)
    result["checkpoint"] = cp
    result["checkpoint_choices_match_source"] = all(cp[k] == source["frames"][8][k] for k in ("native_choice", "matrix_choice"))
    records.expect(["REFUSAL", str(index), "14" if fused else "9" if down else "6", str(CHECKPOINT), str(CHECKPOINT), "1"])
    for step in range(4): result["baseline"].append(state(records.next(), "BASE", index, step, CHECKPOINT + 1 + step))
    records.expect(["GUARD", str(index), "0", "1088", "0"])
    draws = "9" if index else "0"
    records.expect(["RESTORED", str(index), str(CHECKPOINT), str(CHECKPOINT), str(CHECKPOINT), str(CHECKPOINT), draws, draws, str(cp["native_choice"]), "1"])
    if down:
        records.expect(["RESTORED_DOWN_ROWS128", str(index), str(calls)])
        result["restored_down128_host_enqueues"] = calls
    if fused:
        records.expect(["RESTORED_FUSED_ATTENTION", str(index), str(fused_calls), str(original)])
        result.update(restored_fused_attention_host_enqueues=fused_calls, restored_original_attention_queries=original)
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
    if fused:
        records.expect(["REPLAY_FUSED_ATTENTION", str(index), str(fused_calls), str(original+4*28)])
        result.update(replay_fused_attention_host_enqueues=fused_calls, replay_original_attention_queries=original+4*28)
    records.expect(["GUARD", str(index), "1", "1088", "0"])


def initial_report():
    return dict(schema=1, passed=False, collection_complete=False, speed_scored=False, cases=[],
                numerical_budget=dict(max_absolute_error=MAX_ABSOLUTE_ERROR, max_rms_error=MAX_RMS_ERROR, same_full_vocabulary_argmax=True),
                limits="Same-process owning-context mode0 reset/replay only, strict3B/context1536/F16KV, public37 plus eight scalar IDs and four continuation frames/policy. Native-forced original boundaries and seeds. No persisted format/crash recovery/context recreation/production32/concurrency/provider score.")


def parse(path, source, oracle=None, report=None, *, allow_down=False, allow_fused=False):
    if allow_down and allow_fused: raise ValueError("Checkpoint strategies are exclusive")
    report = initial_report() if report is None else report
    records = Records(path, MAX_BYTES)
    try:
        cuda = records.next()
        if len(cuda) != 1 or not cuda[0].startswith("[CUDA] native Mojo ") or "api=cuda" not in cuda[0] or "cpu_offload=0" not in cuda[0]: raise ValueError("Missing actual native CUDA identity")
        report["native_banner"] = cuda[0]
        row = records.next(); report["attention_variant"] = attention_variant(row, allow_down=allow_down, allow_fused=allow_fused)
        if allow_down and (report["attention_variant"] != 3 or source.get("attention_variant") != 3):
            raise ValueError("Down checkpoint strategy differs from accepted source")
        if allow_fused and (report["attention_variant"] != 4 or source.get("attention_variant") != 4):
            raise ValueError("Fused checkpoint strategy differs from accepted source")
        if report["attention_variant"] is not None: row = records.next()
        if row != ["META", "1", "turing_checkpoint", "1536", str(VOCABULARY), "2", "4"]: raise ValueError("Wrong checkpoint metadata")
        policy_rows(records)
        for index in range(2): case(records, report, index, source["cases"][index], oracle)
        records.expect(["COMPLETE", "turing_checkpoint", "2", "8", str(8 * VOCABULARY), "4352", "28" if allow_fused else "18" if allow_down else "12"])
        report.update(csv_sha256=records.finish(), csv_bytes=records.bytes, collection_complete=True, accepted_source=dict(sha256=source["sha256"], csv_sha256=source["csv_sha256"], **({"binary_sha256": source["binary_sha256"]} if allow_fused else {})), full_model_values_per_mode=8 * VOCABULARY, guards=4352, invalid_plan_refusals=28 if allow_fused else 18 if allow_down else 12)
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
    options.add_argument("--down128", action="store_true", help="Explicit accepted strategy3 owning-context replay")
    options.add_argument("--fused-attention", action="store_true", help="Explicit source-bound strategy4 replay")
    for name in ("accepted-binary", "binary"): options.add_argument("--"+name, type=Path)
    options.add_argument("--binary-sha256")
    args = options.parse_args()
    if args.down128 and args.fused_attention: options.error("Down/fused strategies are exclusive")
    if args.fused_attention and (args.accepted_binary is None or args.binary is None or args.binary_sha256 is None or not re.fullmatch(r"[0-9a-f]{64}", args.binary_sha256)):
        options.error("Fused checkpoint requires actual accepted/current binaries and current SHA256")
    if any(not re.fullmatch(r"[0-9a-f]{64}", v) for v in (args.model_sha256, args.reference_sha256, args.accepted_report_sha256)): options.error("Explicit lowercase SHA-256 identities required")
    with args.output.open("x", encoding="utf-8") as output:
        report = initial_report(); oracle = None
        try:
            if digest(args.model) != args.model_sha256 or digest(args.reference_model) != args.reference_sha256: raise ValueError("Original/derived reference checksum mismatch")
            derived = provenance(args.reference_provenance, args.model_sha256, args.reference_sha256)
            if args.reference_model.stat().st_size != derived["derived_bytes"]: raise ValueError("Derived reference size mismatch")
            if args.fused_attention:
                if digest(args.binary) != args.binary_sha256: raise ValueError("Current fused checkpoint binary checksum mismatch")
                report["binary_sha256"] = args.binary_sha256
            source = accepted(args.accepted_report, args.accepted_report_sha256, args.model_sha256, allow_down=args.down128, allow_fused=args.fused_attention, binary=args.accepted_binary)
            report.update(model_sha256=args.model_sha256, reference_derivation=derived)
            oracle = CPUReference(args.reference_model); report["independent_reference"] = oracle.identity
            parse(args.csv, source, oracle, report, allow_down=args.down128, allow_fused=args.fused_attention)
            if digest(args.model) != args.model_sha256 or digest(args.reference_model) != args.reference_sha256: raise ValueError("Original/derived model changed during oracle")
            if args.down128 and (digest(args.csv) != report["csv_sha256"] or digest(args.reference_provenance) != derived["snapshot_sha256"]):
                raise ValueError("Down checkpoint capture/derivation changed during oracle")
            if args.fused_attention and any(digest(p) != h for p,h in ((args.csv, report["csv_sha256"]),
                (args.reference_provenance, derived["snapshot_sha256"]), (args.binary, args.binary_sha256),
                (args.accepted_binary, source["binary_sha256"]))):
                raise ValueError("Fused checkpoint capture/derivation/binaries changed during oracle")
            accepted(args.accepted_report, args.accepted_report_sha256, args.model_sha256, allow_down=args.down128,
                allow_fused=args.fused_attention, binary=args.accepted_binary)
        except (Exception, KeyboardInterrupt) as error: report.update(passed=False, error=f"{type(error).__name__}: {error}")
        finally:
            if oracle is not None:
                try: oracle.close()
                except (Exception, KeyboardInterrupt) as error: report.update(passed=False, error=f"Reference cleanup failed: {type(error).__name__}: {error}")
        json.dump(report, output, indent=2, allow_nan=False); output.write("\n")
    print("PASS: exact checkpoint continuation replay" if report["passed"] else "FAIL: " + report["error"])
    return 0 if report["passed"] else 1


if __name__ == "__main__": raise SystemExit(main())
