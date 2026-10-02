"""Control evidence fails closed on state/identity/mask/complete-vector drift."""
from array import array
import json
import hashlib
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
import check_turing_fixture_controls as check


def golden():
    return dict(input_ids=[1]*37,native=array("f",range(4)),logits=array("f",range(4)))


def fixture(delta=0):
    rows = ["[CUDA] synthetic api=cuda cpu_offload=0","META,1,fixture_controls,1536,32,4,4,1"]
    rows.extend(f"INPUT,{i},1" for i in range(37))
    for index in range(4):
        reason = "timeout" if index < 2 else ("cancelled" if index == 2 else "control_error")
        layers = (0,3,8,0)[index]; sampler = 32 if index in (1,2) else 0
        rows += [f"CONTROL,{index},{reason},{layers},0,0,{sampler},1,1",f"ABORT_GUARD,{index},1088,0",f"REFUSAL,{index},3,0"]
        if index == 2: rows.append("SIGINT_OWNER,2,1,0")
        rows.append(f"RESET,{index},0,0,0,1,0,1,1,1,0,0")
        rows.extend(f"LOGIT,{index},{token},{token},{token+delta}" for token in range(4))
        rows.append(f"GUARD,{index},1088,0")
    rows += ["POISON,1,0,0,32,0,4,0","POISON_GUARD,1088,0","MASK_RESTORED,1","COMPLETE,fixture_controls,4,16,1,9792,1"]
    return "\n".join(rows)+"\n"


class Contracts(unittest.TestCase):
    def parse(self,text,variant=None):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory)/"capture";path.write_text(text)
            with patch.object(check,"VOCABULARY",4): return check.parse(path,dict(golden(),attention_variant=variant))

    def test_complete_recovery_and_no_speed_claim(self):
        report = self.parse(fixture())
        self.assertTrue(report["passed"]);self.assertFalse(report["speed_claim"])
        self.assertEqual(report["recovered_values_per_mode"],16)
        self.assertTrue(all(c["byte_identical"] for c in report["cases"]))

    def test_complete_numeric_failure_retains_all_cases(self):
        report = self.parse(fixture(.125))
        self.assertFalse(report["passed"]);self.assertTrue(report["collection_complete"])
        self.assertEqual(len(report["cases"]),4)
        self.assertTrue(all(c["vector_mismatches"]["matrix"]==4 for c in report["cases"]))

    def test_signed_zero_requires_actual_bytes(self):
        report=self.parse(fixture().replace("LOGIT,0,0,0,0","LOGIT,0,0,0,-0.0"))
        self.assertFalse(report["passed"])
        self.assertFalse(report["cases"][0]["byte_identical"])
        self.assertEqual(report["cases"][0]["vector_mismatches"]["matrix"],0)

    def test_identity_inputs_and_layer_boundaries(self):
        for old,new in (("META,1,fixture_controls,1536,32,4,4,1","META,1,fixture_controls,4096,32,4,4,1"),
                        ("INPUT,1,1","INPUT,0,1"),("CONTROL,1,timeout,3","CONTROL,1,timeout,0"),
                        ("CONTROL,1,timeout,3","CONTROL,1,timeout,28"),("CONTROL,2,cancelled,8","CONTROL,2,cancelled,7")):
            with self.assertRaises(ValueError): self.parse(fixture().replace(old,new))

    def test_abort_commit_history_health_and_reset_requirement(self):
        old = "CONTROL,1,timeout,3,0,0,32,1,1"
        for new in ("CONTROL,1,timeout,3,32,32,32,1,1","CONTROL,1,timeout,3,0,0,0,1,1", "CONTROL,1,timeout,3,0,0,32,0,1","CONTROL,1,timeout,3,0,0,32,1,0"):
            with self.assertRaises(ValueError): self.parse(fixture().replace(old,new))

    def test_guards_refusal_descriptor_and_reset_ownership(self):
        for old,new in (("ABORT_GUARD,0,1088,0","ABORT_GUARD,0,1088,1"),("REFUSAL,0,3,0","REFUSAL,0,2,0"),
                        ("SIGINT_OWNER,2,1,0","SIGINT_OWNER,2,0,0"),("RESET,0,0,0,0,1,0,1,1,1,0,0","RESET,0,0,0,0,1,0,0,1,1,0,0"),
                        ("GUARD,0,1088,0","GUARD,0,1088,1"),("POISON,1,0,0,32,0,4,0","POISON,1,0,0,32,1,4,0"),("MASK_RESTORED,1","MASK_RESTORED,0")):
            with self.assertRaises(ValueError): self.parse(fixture().replace(old,new))

    def test_order_exact_f32_and_complete_evidence(self):
        for text in (fixture().replace("LOGIT,0,0,0,0","LOGIT,0,0,0,nan"),fixture().replace("LOGIT,0,0,0,0","LOGIT,0,0,0,1.1"),
                     fixture().replace("LOGIT,0,1,1,1","LOGIT,0,0,1,1"),fixture().replace("COMPLETE,fixture_controls,4,16,1,9792,1\n",""),fixture()+"extra\n"):
            with self.assertRaises((ValueError,StopIteration)): self.parse(text)

    def test_accepted_reference_binding(self):
        report = dict(schema=1,passed=True,speed_scored=True,collection_complete=True,csv_sha256="csv",model_sha256="model",full_model_values_per_mode=4*check.VOCABULARY,invalid_tiles=8,guards=4352,independent_reference=dict(passed=True,cases=[dict(native=dict(passed=True),matrix=dict(passed=True)) for _ in range(4)]),numerical_budget=dict(max_absolute_error=.05,max_rms_error=.005,same_full_vocabulary_argmax=True))
        data = dict(activation_precision=0,csv_sha256="csv",cases=[golden()]*4)
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory)/"report"
            capture=Path(directory)/"csv";capture.write_bytes(b"csv")
            data["csv_sha256"]=hashlib.sha256(b"csv").hexdigest();report["csv_sha256"]=data["csv_sha256"]
            with patch.object(check,"reference_parse",return_value=data):
                path.write_text(json.dumps(report));self.assertEqual(check.reference(capture,path,"model")[0]["input_ids"],[1]*37)
                for key,value in (("passed",False),("schema",True),("csv_sha256","wrong"),("model_sha256","wrong"),("independent_reference",dict(passed=False)),("guards",4351),("attention_variant",2)):
                    altered = dict(report);altered[key]=value;path.write_text(json.dumps(altered))
                    with self.assertRaises(ValueError): check.reference(capture,path,"model")
                path.write_text(json.dumps(report).replace('"schema": 1','"schema": 1, "schema": 1'))
                with self.assertRaises(ValueError):check.reference(capture,path,"model")

    def test_failed_cli_report_is_complete_and_exclusive(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory);capture=root/"capture";capture.write_text(fixture(.125));output=root/"result"
            args = ["check",str(capture),"--reference-csv","unused","--reference-report","unused","--model","unused","--model-sha256","a"*64,"--output",str(output)]
            with patch("sys.argv",args),patch.object(check,"VOCABULARY",4),patch.object(check,"digest",side_effect=lambda path:hashlib.sha256(capture.read_bytes()).hexdigest() if path==capture else "a"*64),patch.object(check,"reference",return_value=(golden(),dict(csv_sha256="a"*64,report_sha256="a"*64))):
                self.assertEqual(check.main(),1)
                report=json.loads(output.read_text());self.assertFalse(report["passed"]);self.assertTrue(report["collection_complete"])
                with self.assertRaises(FileExistsError): check.main()


    def test_variant_identity_duplicate_late_and_unknown_metadata(self):
        head,body=fixture().split("\n",1)
        for variant in (0,1,2):
            marker=f"ATTENTION,rope_cache_grid,{variant},32\n" if variant<2 else "ATTENTION,rope_cache_elementwise_grid,1,32\n"
            text=head+"\n"+marker+body
            self.assertTrue(self.parse(text,variant)["passed"])
            with self.assertRaises(ValueError):self.parse(text)
            for bad in (head+"\n"+marker+marker+body,fixture()+marker,text.replace(",32\n",",64\n",1),head+"\nATTENTION,rope_cache_grid,2,32\n"+body):
                with self.assertRaises(ValueError):self.parse(bad,variant)

    def test_source_mutation_interrupt_and_exclusive_failure_reporting(self):
        with tempfile.TemporaryDirectory() as directory:
            root=Path(directory);capture=root/"capture";capture.write_text(fixture());output=root/"result"
            args=["check",str(capture),"--reference-csv","source","--reference-report","source-report","--model","model","--model-sha256","a"*64,"--output",str(output)]
            proof=dict(csv_sha256="a"*64,report_sha256="a"*64)
            values=["a"*64,"a"*64,hashlib.sha256(capture.read_bytes()).hexdigest(),"changed"]
            with patch("sys.argv",args),patch.object(check,"VOCABULARY",4),patch.object(check,"digest",side_effect=values),patch.object(check,"reference",return_value=(golden(),proof)):
                self.assertEqual(check.main(),1)
            report=json.loads(output.read_text());self.assertTrue(report["collection_complete"]);self.assertFalse(report["passed"])
            self.assertIn("changed",report["error"]);self.assertFalse(report["speed_claim"])
            args[-1]=str(root/"interrupt")
            with patch("sys.argv",args),patch.object(check,"digest",return_value="a"*64),patch.object(check,"reference",side_effect=KeyboardInterrupt):
                self.assertEqual(check.main(),1)
            report=json.loads((root/"interrupt").read_text());self.assertFalse(report["collection_complete"]);self.assertIn("KeyboardInterrupt",report["error"])


if __name__ == "__main__": unittest.main()
