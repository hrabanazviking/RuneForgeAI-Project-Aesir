"""Explicit strategy3 sealed replay contracts; synthetic evidence is not GPU proof."""
from pathlib import Path
import hashlib
import json
import sys
import tempfile
import unittest
from unittest.mock import patch

import check_turing_checkpoint_replay as check
import check_turing_down_source as down
import check_llama3_logits as logits
from test_check_turing_checkpoint_replay import source as base_source, fixture as base, Oracle, HASH
from test_check_turing_down_model import MARKER


def source():
    r = base_source()
    r.update(attention_variant=3, model_source_passed=True, guards=4352,
        accepted_down_model=dict(passed=True, attention_variant=3, model_sha256="a" * 64,
            csv_sha256="c" * 64, report_sha256="d" * 64),
        independent_reference=dict(requested_gpu_layers=0, context=4096, kv="f16", batch=128, threads=4,
            weight_mode="dequantized_f32", numpy="2.4.4", llama_cpp_python="0.3.23", library_sha256="b" * 64))
    metric = logits.compare_case([0, 1, 5, 0], [0, 1, 5, 0])
    for case in r["cases"]:
        case.update(model_source_vectors_passed=True, input_sha256=HASH, down128_host_enqueues=0,
            replay_down128_host_enqueues=0, evaluated_frames=case["cap"])
        for step, (f, replay) in enumerate(zip(case["frames"], case["replay"])):
            f.update(native_comparison=dict(metric), independent=dict(native=dict(metric), matrix=dict(metric)),
                position=2+step, history=2+step, draws=step+1 if case["policy"] else 0)
            replay.update(native_choice=2, matrix_choice=2, position=2+step, history=2+step,
                draws=f["draws"], native_replay_bit_mismatches=0, matrix_replay_bit_mismatches=0)
    return r


def fixture(**kwargs):
    text = base(**kwargs).replace("META,1,turing_checkpoint", MARKER + "\nMETA,1,turing_checkpoint")
    for index in range(2):
        text = text.replace(f"CHECKPOINT,{index},", f"DOWN_ROWS128,{index},0\nCHECKPOINT,{index},")
        text = text.replace(f"REFUSAL,{index},6,", f"REFUSAL,{index},9,")
        text = text.replace(f"REPLAY,{index},0,", f"RESTORED_DOWN_ROWS128,{index},0\nREPLAY,{index},0,")
    return text.replace("4352,12", "4352,18")


class Contracts(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(); self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name); self.csv = self.root / "capture"; self.csv.write_text(fixture())
        for obj, name, value in ((check,"VOCABULARY",4),(down,"VOCABULARY",4),(logits,"VOCABULARY",4),
            (check,"PREFIX",2),(check,"CHECKPOINT",10),(check,"EOS",(3,)),(check,"INPUT_HASHES",(HASH,HASH))):
            p = patch.object(obj,name,value); p.start(); self.addCleanup(p.stop)

    def accepted(self, value=None):
        p = self.root / "source"; p.write_text(json.dumps(source() if value is None else value))
        return p, hashlib.sha256(p.read_bytes()).hexdigest()

    def parse(self, text=None, *, independent=True):
        if text is not None: self.csv.write_text(text)
        p, sha = self.accepted(); src = check.accepted(p, sha, "a" * 64, allow_down=True)
        return check.parse(self.csv, src, Oracle() if independent else None, allow_down=True)

    def test_explicit_source_strategy_only_and_complete_frames(self):
        p, sha = self.accepted()
        with self.assertRaises(ValueError): check.accepted(p, sha, "a" * 64)
        src = check.accepted(p, sha, "a" * 64, allow_down=True)
        with self.assertRaises(ValueError): check.parse(self.csv, src, Oracle())
        r = self.parse(); self.assertTrue(r["passed"]); self.assertFalse(r["speed_scored"])
        self.assertEqual(r["invalid_plan_refusals"],18); self.assertEqual(r["full_model_values_per_mode"],32)
        self.assertFalse(self.parse(independent=False)["passed"])
        src.pop("attention_variant")
        with self.assertRaises(ValueError): check.parse(self.csv, src, Oracle(), allow_down=True)

    def test_counters_refusals_totals_and_actual_signed_zero_replay(self):
        for old, new in (("DOWN_ROWS128,0,0", "DOWN_ROWS128,0,1"), ("RESTORED_DOWN_ROWS128,0,0", "RESTORED_DOWN_ROWS128,0,1"),
            ("REFUSAL,0,9,10,10,1", "REFUSAL,0,6,10,10,1"), ("4352,18", "4352,12"),
            (MARKER, "ATTENTION,rope_cache_elementwise_grid,1,32")):
            with self.subTest(old=old),self.assertRaises(ValueError): self.parse(fixture().replace(old,new))
        r = self.parse(fixture(bit_error=True)); self.assertFalse(r["passed"]); self.assertTrue(r["collection_complete"])
        self.assertEqual(sum(len(c["frames"]) for c in r["cases"]),8)
        self.assertTrue(all(f["bit_mismatches"]==[1,0] for c in r["cases"] for f in c["frames"]))

    def test_source_boolean_cannot_hide_numeric_or_causal_failures(self):
        for mutate in (lambda r: r["cases"][3]["frames"][15]["independent"]["matrix"].update(rms_error=.0051),
            lambda r: r["cases"][2]["frames"][31]["native_comparison"].update(values=True),
            lambda r: r["cases"][1]["replay"][3].update(matrix_replay_bit_mismatches=1),
            lambda r: r["cases"][0]["frames"][0].update(history=3),
            lambda r: r["cases"][1]["frames"][0].update(draws=0),
            lambda r: r["cases"][3]["replay"][0].update(matrix_choice=1),
            lambda r: r["cases"][0].update(input_sha256="b" * 64),
            lambda r: r["cases"][0].update(down128_host_enqueues=False)):
            r = source(); mutate(r); p, sha = self.accepted(r)
            with self.assertRaises(ValueError): check.accepted(p,sha,"a"*64,allow_down=True)

    def test_source_scope_model_and_independent_identity_refuse(self):
        for mutate in (lambda r: r.update(attention_variant=2), lambda r: r.update(activation_precision=False),
            lambda r: r.update(model_source_passed=False), lambda r: r["accepted_down_model"].update(model_sha256="b"*64),
            lambda r: r["independent_reference"].update(requested_gpu_layers=1),
            lambda r: r["independent_reference"].update(weight_mode="packed"),
            lambda r: r["cases"][3].update(model_source_vectors_passed=False),
            lambda r: r["cases"][2].update(replay_down128_host_enqueues=1)):
            r = source(); mutate(r); p, sha = self.accepted(r)
            with self.assertRaises(ValueError): check.accepted(p,sha,"a"*64,allow_down=True)
        p, sha = self.accepted()
        with self.assertRaises(ValueError): check.accepted(p,"e"*64,"a"*64,allow_down=True)
        p.write_text(json.dumps(source()).replace('"schema": 1','"schema": 1,"schema": 1'))
        with self.assertRaises(ValueError): check.accepted(p,hashlib.sha256(p.read_bytes()).hexdigest(),"a"*64,allow_down=True)

    def main(self,suffix,*,mutate=None,interrupt=False,cleanup=False):
        p, sha = self.accepted(); model = self.root/"model"; model.write_bytes(b"m")
        ref = self.root/"reference"; ref.write_bytes(b"r"); receipt=self.root/"derivation"; receipt.write_bytes(b"d")
        self.csv.write_text(fixture()); out=self.root/suffix
        args=["checker",str(self.csv),"--down128","--model",str(model),"--model-sha256","a"*64,
            "--reference-model",str(ref),"--reference-sha256","b"*64,"--reference-provenance",str(receipt),
            "--accepted-report",str(p),"--accepted-report-sha256",sha,"--output",str(out)]
        hashes={model:"a"*64,ref:"b"*64,self.csv:hashlib.sha256(self.csv.read_bytes()).hexdigest(),receipt:"d"*64}
        counts={}; oracle=Oracle()
        def digest(path):
            counts[path]=counts.get(path,0)+1
            if path==mutate and counts[path]>=(2 if path in (model,ref) else 1): return "e"*64
            return hashes[path]
        def expected(position):
            if interrupt: raise KeyboardInterrupt()
            if mutate==p: p.write_text("changed")
            return [0,1,5,0]
        def close():
            oracle.closed=True
            if cleanup: raise KeyboardInterrupt()
        with patch.object(sys,"argv",args),patch.object(check,"digest",side_effect=digest), \
            patch.object(check,"provenance",return_value=dict(derived_bytes=1,snapshot_sha256="d"*64)), \
            patch.object(check,"CPUReference",return_value=oracle),patch.object(oracle,"expected",side_effect=expected), \
            patch.object(oracle,"close",side_effect=close): status=check.main()
        return status,json.loads(out.read_text()),args,oracle,(model,ref,self.csv,receipt,p)

    def test_after_oracle_weights_capture_derivation_and_source_mutations_fail(self):
        _,_,_,_,paths=self.main("paths")
        for index,path in enumerate(paths):
            status,r,_,oracle,_=self.main("changed"+str(index),mutate=path)
            self.assertEqual(status,1);self.assertFalse(r["passed"]);self.assertFalse(r["speed_scored"])
            self.assertTrue(r["collection_complete"]);self.assertEqual(sum(len(c["frames"]) for c in r["cases"]),8)
            self.assertTrue(oracle.closed)

    def test_interrupt_and_cleanup_preserve_failed_evidence(self):
        for mode in ("interrupt","cleanup"):
            status,r,_,oracle,_=self.main(mode,interrupt=mode=="interrupt",cleanup=mode=="cleanup")
            self.assertEqual(status,1);self.assertFalse(r["passed"]);self.assertTrue(oracle.closed)
            self.assertIn("KeyboardInterrupt",r["error"]);self.assertEqual(r["collection_complete"],mode=="cleanup")

    def test_successful_report_and_failures_are_exclusive(self):
        for mode in ("successful","interrupted"):
            status,r,args,_,_=self.main(mode,interrupt=mode=="interrupted")
            self.assertEqual(status,0 if mode=="successful" else 1)
            saved=Path(args[-1]).read_bytes()
            with patch.object(sys,"argv",args),self.assertRaises(FileExistsError):check.main()
            self.assertEqual(Path(args[-1]).read_bytes(),saved)


if __name__=="__main__":unittest.main()
