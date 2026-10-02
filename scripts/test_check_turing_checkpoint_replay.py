"""Portable malformed checkpoint/source contracts; no physical inference claim."""
import hashlib
import json
import os
from pathlib import Path
import struct
import sys
import tempfile
import unittest
from unittest.mock import patch
import check_turing_checkpoint_replay as check
import check_llama3_logits as logits
from test_check_turing_decode_quality import fixture as decode_fixture

HASH = hashlib.sha256(struct.pack("<II", 1, 2)).hexdigest()


def source():
    cases = []
    for index in range(4):
        frames = 16 if index % 2 else 32
        cases.append(dict(index=index, policy=index % 2, cap=frames, finish_reason="length", input_ids=[1, 2],
            frames=[dict(native_choice=2, matrix_choice=2, sample_equal=True, greedy_argmax_passed=True, native_comparison=dict(passed=True), independent=dict(native=dict(passed=True), matrix=dict(passed=True))) for _ in range(frames)], replay=[dict(passed=True) for _ in range(frames)]))
    return dict(schema=1,model_sha256="a" * 64,activation_precision=0,evaluated_frames=96,full_model_values_per_mode=384,
        passed=True,collection_complete=True,native_quality_passed=True,replay_passed=True,independent_reference_passed=True,speed_scored=False,
        numerical_budget=dict(max_absolute_error=.05,max_rms_error=.005,same_full_vocabulary_argmax=True),csv_sha256="f" * 64,cases=cases)


def fixture(delta=0, bit_error=False):
    rows = ["[CUDA] native Mojo synthetic api=cuda cpu_offload=0", "META,1,turing_checkpoint,1536,4,2,4"] + decode_fixture().splitlines()[2:4]
    for index in range(2):
        rows.append(f"CASE,{index},2,10,4")
        for ordinal, token in enumerate([1, 2] + [2] * 8): rows.append(f"INPUT,{index},{ordinal},{token}")
        for mode in range(2):
            for ordinal in range(10): rows.append(f"TILE,{index},{mode},{ordinal},{ordinal},1")
        draws = 9 if index else 0
        rows.extend([f"CHECKPOINT,{index},8,2,2,10,10,10,10,{draws},{draws}", f"REFUSAL,{index},6,10,10,1"])
        for step in range(4):
            pos = 11 + step; draw = step + 10 if index else 0
            rows.append(f"BASE,{index},{step},2,2,{pos},{pos},{pos},{pos},{draw},{draw}")
        rows.extend([f"GUARD,{index},0,1088,0", f"RESTORED,{index},10,10,10,10,{draws},{draws},2,1"])
        for step in range(4):
            pos = 11 + step; draw = step + 10 if index else 0
            rows.append(f"REPLAY,{index},{step},2,2,{pos},{pos},{pos},{pos},{draw},{draw}")
            rows.append(f"BITS,{index},{step},{int(bit_error)},0")
            for token, value in enumerate([0, 1, 5, 0]):
                restored = -0.0 if bit_error and token == 0 else value
                rows.append(f"LOGIT,{index},{step},{token},{value},{value + delta},{restored},{value + delta}")
        rows.append(f"GUARD,{index},1,1088,0")
    rows.append("COMPLETE,turing_checkpoint,2,8,32,4352,12")
    return "\n".join(rows) + "\n"


class Oracle:
    identity = {"synthetic_test_only": True}
    def __init__(self): self.begins = []; self.advances = []; self.closed = False
    def begin(self, ids): self.begins.append(ids)
    def advance(self, token): self.advances.append(token)
    def expected(self, position): return [0, 1, 5, 0]
    def close(self): self.closed = True


class Contracts(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(); self.addCleanup(self.temp.cleanup)
        self.path = Path(self.temp.name) / "capture"; self.path.write_text(fixture())
        for obj,name,value in ((check,"VOCABULARY",4),(logits,"VOCABULARY",4),(check,"PREFIX",2),(check,"CHECKPOINT",10),(check,"EOS",(3,)),(check,"INPUT_HASHES",(HASH,HASH))):
            p = patch.object(obj,name,value);p.start();self.addCleanup(p.stop)
        self.accepted = dict(sha256="c" * 64,csv_sha256="f" * 64,cases=source()["cases"][:2])

    def parse(self,text=None,oracle=None):
        if text is not None:self.path.write_text(text)
        return check.parse(self.path,self.accepted,oracle)

    def test_complete_requires_independent_and_exact_causal_evaluation(self):
        self.assertFalse(self.parse()["passed"])
        oracle = Oracle()
        with patch.object(Path,"read_text",side_effect=AssertionError("whole stream read")):
            report = self.parse(oracle=oracle)
        self.assertTrue(report["passed"]);self.assertFalse(report["speed_scored"])
        self.assertEqual(oracle.begins,[[1,2]+[2]*8]*2);self.assertEqual(oracle.advances,[2]*8)
        self.assertEqual(report["full_model_values_per_mode"],32)

    def test_complete_numeric_failure_preserves_every_frame(self):
        report = self.parse(fixture(.125),Oracle())
        self.assertFalse(report["passed"]);self.assertTrue(report["collection_complete"])
        self.assertEqual(sum(len(c["frames"]) for c in report["cases"]),8)
        self.assertTrue(all(not f["independent"]["matrix"]["passed"] for c in report["cases"] for f in c["frames"]))

    def test_signed_zero_exact_replay_and_truthful_bit_counts(self):
        report = self.parse(fixture(bit_error=True),Oracle())
        self.assertFalse(report["passed"]);self.assertTrue(report["native_quality_passed"])
        self.assertTrue(all(f["bit_mismatches"] == [1,0] for c in report["cases"] for f in c["frames"]))
        with self.assertRaises(ValueError):self.parse(fixture(bit_error=True).replace("BITS,0,0,1,0","BITS,0,0,0,0"))

    def test_checkpoint_tiles_ids_owner_refusal_and_restore_states(self):
        for old,new in (("TILE,0,0,0,0,1","TILE,0,0,0,0,4"),("INPUT,0,0,1","INPUT,0,0,0"),
                        ("REFUSAL,0,6,10,10,1","REFUSAL,0,5,10,10,1"),("CHECKPOINT,1,8,2,2,10,10,10,10,9,9","CHECKPOINT,1,8,2,2,10,10,10,10,8,9"),
                        ("RESTORED,0,10,10,10,10,0,0,2,1","RESTORED,0,10,10,10,10,1,0,2,1"),("GUARD,0,0,1088,0","GUARD,0,0,1088,1")):
            with self.assertRaises(ValueError):self.parse(fixture().replace(old,new))

    def test_sample_source_drift_retained_as_complete_failure(self):
        for old,new in (("INPUT,0,9,2","INPUT,0,9,1"),("BASE,1,0,2,2","BASE,1,0,2,1"),("REPLAY,1,0,2,2","REPLAY,1,0,2,1")):
            report = self.parse(fixture().replace(old,new),Oracle())
            self.assertFalse(report["passed"]);self.assertTrue(report["collection_complete"])

    def test_full_vector_bounds_order_policy_terminal_and_totals(self):
        for old,new in (("LOGIT,0,0,0,0,0,0,0","LOGIT,0,0,0,nan,0,0,0"),("LOGIT,0,0,0,0,0,0,0","LOGIT,0,0,0,1.1,0,0,0"),
                        ("LOGIT,0,0,1,1,1,1,1","LOGIT,0,0,0,1,1,1,1"),("POLICY,1,","POLICY,2,"),("BASE,0,0,2,2","BASE,0,0,3,2"),
                        ("COMPLETE,turing_checkpoint,2,8,32,4352,12","COMPLETE,turing_checkpoint,2,8,31,4352,12")):
            with self.assertRaises(ValueError):self.parse(fixture().replace(old,new))
        with self.assertRaises(ValueError):self.parse(fixture()+"late\n")
        with self.assertRaises(ValueError):self.parse(fixture().rstrip("\n"))

    def test_regular_nofollow_byte_and_line_bounds(self):
        link = self.path.with_name("link");link.symlink_to(self.path)
        with self.assertRaises(OSError):check.parse(link,self.accepted)
        fifo = self.path.with_name("fifo");os.mkfifo(fifo)
        with self.assertRaises(ValueError):check.parse(fifo,self.accepted)
        with patch.object(check,"MAX_BYTES",8):
            with self.assertRaises(ValueError):self.parse()
        with self.assertRaises(ValueError):self.parse("x"*1025+"\n")

    def test_accepted_reference_hash_quality_budget_and_duplicates(self):
        reference = self.path.with_name("accepted")
        value = source();text = json.dumps(value);reference.write_text(text)
        result = check.accepted(reference,hashlib.sha256(text.encode()).hexdigest(),"a"*64)
        self.assertEqual(len(result["cases"]),2)
        with self.assertRaises(ValueError):check.accepted(reference,"d"*64,"a"*64)
        for change in ("passed","independent_reference_passed"):
            value = source();value[change] = False;text = json.dumps(value);reference.write_text(text)
            with self.assertRaises(ValueError):check.accepted(reference,hashlib.sha256(text.encode()).hexdigest(),"a"*64)
        text = json.dumps(source()).replace('"schema": 1','"schema": 1, "schema": 1');reference.write_text(text)
        with self.assertRaises(ValueError):check.accepted(reference,hashlib.sha256(text.encode()).hexdigest(),"a"*64)

    def test_exclusive_complete_failure_and_reference_cleanup(self):
        model=self.path.with_name("model");model.write_bytes(b"m")
        ref=self.path.with_name("ref");ref.write_bytes(b"r")
        out=self.path.with_name("report");self.path.write_text(fixture(.125));oracle=Oracle()
        args=["check",str(self.path),"--model",str(model),"--model-sha256","a"*64,"--reference-model",str(ref),"--reference-sha256","b"*64,"--reference-provenance",str(ref),"--accepted-report",str(ref),"--accepted-report-sha256","c"*64,"--output",str(out)]
        with patch.object(sys,"argv",args),patch.object(check,"digest",side_effect=["a"*64,"b"*64]*2),patch.object(check,"provenance",return_value=dict(derived_bytes=1)),patch.object(check,"accepted",return_value=self.accepted),patch.object(check,"CPUReference",return_value=oracle):
            self.assertEqual(check.main(),1)
        report=json.loads(out.read_text());self.assertTrue(report["collection_complete"]);self.assertFalse(report["passed"])
        self.assertEqual(len(report["cases"]),2);self.assertTrue(oracle.closed)
        with patch.object(sys,"argv",args):
            with self.assertRaises(FileExistsError):check.main()


if __name__ == "__main__":unittest.main()
