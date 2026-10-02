#!/usr/bin/env python3
"""Bounded control/state proof and exact recovered vectors; no speed scoring."""
import argparse
from array import array
import csv
import hashlib
import io
import json
from pathlib import Path
import re

from launch import digest
from profile_native_cuda import read_text
from check_turing_activations import f32
from check_turing_model_prefill import parse as reference_parse, attention_variant, reference_fields
from check_llama3_logits import VOCABULARY


def reference(path,report_path,model_sha):
    data = reference_parse(path)
    text = read_text(report_path,5*1024*1024)
    report = json.loads(text,object_pairs_hook=reference_fields,parse_constant=lambda _: (_ for _ in ()).throw(ValueError("Nonfinite control source")))
    if (type(report.get("schema")) is not int or report["schema"] != 1 or
        report.get("passed") is not True or report.get("speed_scored") is not True or
        report.get("collection_complete") is not True or data["activation_precision"] != 0 or
        report.get("csv_sha256") != data["csv_sha256"] or report.get("model_sha256") != model_sha or
        report.get("independent_reference",{}).get("passed") is not True or
        report.get("numerical_budget") != dict(max_absolute_error=.05,max_rms_error=.005,same_full_vocabulary_argmax=True)):
        raise ValueError("Control reference is not bound to accepted original-mode0 independent evidence")
    if report.get("attention_variant") != data.get("attention_variant") or report.get("full_model_values_per_mode") != 4*VOCABULARY or report.get("invalid_tiles") != 8 or report.get("guards") != 4352:
        raise ValueError("Control source variant/scope/totals mismatch")
    cases = report["independent_reference"].get("cases",[])
    if len(cases) != 4 or any(c.get(mode,{}).get("passed") is not True for c in cases for mode in ("native","matrix")):
        raise ValueError("Control source lacks every independent owner/case")
    proof = dict(csv_sha256=data["csv_sha256"],report_sha256=hashlib.sha256(text.encode()).hexdigest(),attention_variant=data.get("attention_variant"))
    if digest(path) != proof["csv_sha256"] or digest(report_path) != proof["report_sha256"]:
        raise ValueError("Control reference changed during admission")
    return dict(data["cases"][1],attention_variant=data.get("attention_variant")),proof


def parse(path,golden):
    text = read_text(path,64*1024*1024)
    if len(text.encode()) > 64*1024*1024: raise ValueError("Control CSV grew beyond admission")
    reader = iter(csv.reader(io.StringIO(text)))
    row = next(reader)
    if not row or not row[0].startswith("[CUDA]") or "api=cuda" not in row[0] or "cpu_offload=0" not in row[0]:
        raise ValueError("Missing native CUDA control identity")
    row = next(reader); variant = attention_variant(row)
    if variant is not None: row = next(reader)
    if variant != golden.get("attention_variant"): raise ValueError("Control strategy differs from accepted source")
    if row != ["META","1","fixture_controls","1536","32",str(VOCABULARY),"4","1"]:
        raise ValueError("Wrong control fixture metadata")
    if len(golden["input_ids"]) != 37: raise ValueError("Wrong accepted public recovery case")
    for ordinal,token in enumerate(golden["input_ids"]):
        if next(reader) != ["INPUT",str(ordinal),str(token)]:
            raise ValueError("Recovery input identity/order changed")
    cases = []
    for index in range(4):
        row = next(reader); reason = "timeout" if index < 2 else ("cancelled" if index == 2 else "control_error")
        sampler = "32" if index in (1,2) else "0"
        if len(row) != 9 or row[:3] != ["CONTROL",str(index),reason] or row[4:] != ["0","0",sampler,"1","1"]:
            raise ValueError("Control abort committed state or lost reset requirement")
        layers = int(row[3])
        if str(layers) != row[3] or (index == 1 and not 0 < layers < 28) or (index == 2 and layers != 8) or (index in (0,3) and layers != 0):
            raise ValueError("Wrong actual control layer boundary")
        if next(reader) != ["ABORT_GUARD",str(index),"1088","0"] or next(reader) != ["REFUSAL",str(index),"3","0"]:
            raise ValueError("Abort guard or reset-required refusal failed")
        if index == 2 and next(reader) != ["SIGINT_OWNER","2","1","0"]:
            raise ValueError("Caller did not own and consume exactly one SIGINT")
        if next(reader) != ["RESET",str(index),"0","0","0","1","0","1","1","1","0","0"]:
            raise ValueError("Reset retained state or replaced weight/buffer ownership")
        native = array("f"); matrix = array("f")
        for token in range(VOCABULARY):
            row = next(reader)
            if len(row) != 5 or row[:3] != ["LOGIT",str(index),str(token)]:
                raise ValueError("Incomplete/duplicate/out-of-order recovered vectors")
            native.append(f32(row[3])); matrix.append(f32(row[4]))
        if next(reader) != ["GUARD",str(index),"1088","0"]:
            raise ValueError("Recovered fixture guards failed")
        differences = dict(native=sum(a != b for a,b in zip(native,golden["native"],strict=True)),
                           matrix=sum(a != b for a,b in zip(matrix,golden["logits"],strict=True)))
        cases.append(dict(reason=reason,completed_layers=layers,position_before_reset=0,
                          uncommitted_sampler_position=int(sampler),reset_required=True,
                          vector_mismatches=differences,byte_identical=native.tobytes()==golden["native"].tobytes() and matrix.tobytes()==golden["logits"].tobytes(),
                          native_sha256=hashlib.sha256(native.tobytes()).hexdigest(),matrix_sha256=hashlib.sha256(matrix.tobytes()).hexdigest()))
    if next(reader) != ["POISON","1","0","0","32","0","4","0"] or next(reader) != ["POISON_GUARD","1088","0"]:
        raise ValueError("Unexpected exception did not poison fixture and refuse reuse/reset")
    if next(reader) != ["MASK_RESTORED","1"] or next(reader) != ["COMPLETE","fixture_controls","4",str(4*VOCABULARY),"1","9792","1"]:
        raise ValueError("Control mask restoration or complete totals failed")
    if next(reader,None) is not None: raise ValueError("Trailing control evidence")
    return dict(schema=1,passed=all(c["byte_identical"] for c in cases),collection_complete=True,speed_claim=False,attention_variant=variant,
                csv_sha256=hashlib.sha256(text.encode()).hexdigest(),recovered_values_per_mode=4*VOCABULARY,
                guards=9792,poisoned_exception_cases=1,owner_mask_restored=True,cases=cases,
                limits="Test-only strict3B/context1536 original precision0 with explicit execution strategy binding and cooperative layer boundaries. 10ms deadline is not hard real time. SIGINT delivered to the owning test thread after8 synced layers. Exact accepted case1 vectors after explicit reset, with preserved allocations. Unexpected observer exception proves poison policy, not an actual GPU-fault repair. No production/concurrency/provider or speed claim.")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("csv",type=Path); parser.add_argument("--reference-csv",type=Path,required=True)
    parser.add_argument("--reference-report",type=Path,required=True); parser.add_argument("--model",type=Path,required=True)
    parser.add_argument("--model-sha256",required=True); parser.add_argument("--output",type=Path,required=True)
    args = parser.parse_args()
    if not re.fullmatch(r"[0-9a-f]{64}",args.model_sha256): parser.error("Lowercase model SHA-256 required")
    with args.output.open("x",encoding="utf-8") as stream:
        report = dict(schema=1,passed=False,collection_complete=False,speed_claim=False)
        try:
            if digest(args.model) != args.model_sha256: raise ValueError("Control model checksum mismatch")
            golden,proof = reference(args.reference_csv,args.reference_report,args.model_sha256)
            report = parse(args.csv,golden)
            report.update(model_sha256=args.model_sha256,accepted_reference=proof)
            if digest(args.model) != args.model_sha256: raise ValueError("Control model changed during read")
            if digest(args.csv) != report["csv_sha256"] or digest(args.reference_csv) != proof["csv_sha256"] or digest(args.reference_report) != proof["report_sha256"]:
                raise ValueError("Control capture or accepted reference changed during validation")
            if not report["passed"]: report["error"] = "Recovered complete vectors differ; control acceptance withheld"
        except (Exception,KeyboardInterrupt) as error:
            report.update(passed=False,error=f"{type(error).__name__}: {error}")
        json.dump(report,stream,indent=2,allow_nan=False);stream.write("\n")
    print("PASS: cooperative fixture control/recovery" if report["passed"] else "FAIL: "+report["error"])
    return 0 if report["passed"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
