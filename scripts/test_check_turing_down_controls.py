"""Explicit down128 cooperative recovery evidence; no synthetic hardware claims."""
from pathlib import Path
import hashlib
import json
import sys
import tempfile
import unittest
from unittest.mock import patch

import check_turing_fixture_controls as check
import check_turing_down_source as source
import check_turing_model_prefill as model
import check_llama3_logits as logits
from test_check_turing_fixture_controls import fixture as base, golden as baseline
from test_check_turing_down_model import fixture as model_base, MARKER


def golden(): return dict(baseline(), attention_variant=3, control_capable=True)


def fixture(delta=0):
    text=base(delta).replace("META,1,fixture_controls", MARKER+"\nMETA,1,fixture_controls")
    for index,layers in enumerate((0,3,8,0)):
        text=text.replace(f"ABORT_GUARD,{index},",f"ABORT_DOWN_ROWS128,{index},{layers}\nABORT_GUARD,{index},")
        text=text.replace(f"\nGUARD,{index},1088",f"\nRECOVERED_DOWN_ROWS128,{index},28\nGUARD,{index},1088")
    return text.replace("POISON_GUARD,", "POISON_DOWN_ROWS128,1\nPOISON_GUARD,")


class Contracts(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory();self.addCleanup(self.temp.cleanup);self.root=Path(self.temp.name)
        self.csv=self.root/"capture";self.csv.write_text(fixture())
        for obj in (check,source,model,logits):
            p=patch.object(obj,"VOCABULARY",4);p.start();self.addCleanup(p.stop)

    def parse(self,text=None):
        if text is not None:self.csv.write_text(text)
        return check.parse(self.csv,golden(),allow_down=True)

    def accepted(self,capable=True):
        csv=self.root/"model.csv";text=model_base()
        if capable:text=text.replace("ADMISSION,3,2,0\n","ADMISSION,3,2,0\nCONTROL_CAPABLE,3,1\n")
        csv.write_text(text);data=model.parse(csv);r=model.summarize(data)
        r.update(passed=True,speed_scored=True,model_sha256="a"*64,
            independent_reference=dict(passed=True,requested_gpu_layers=0,context=4096,kv="f16",batch=128,threads=4,
                weight_mode="dequantized_f32",numpy="2.4.4",llama_cpp_python="0.3.23",library_sha256="b"*64,
                cases=[dict(native=c["native_comparison"],matrix=c["native_comparison"]) for c in data["cases"]]),
            fixture_reference=dict(passed=True,attention_variant=2,csv_sha256="c"*64,report_sha256="d"*64,
                cases=[dict(input_ids_equal=True,native_f32_bytes_equal=True,matrix_f32_bytes_equal=True,
                    guarded_cache_identity_passed=True,passed=True) for _ in range(4)]))
        report=self.root/"model.json";report.write_text(json.dumps(r));return csv,report,r

    def test_default_refuses_explicit_capable_source_and_recovery(self):
        with self.assertRaises(ValueError):check.parse(self.csv,golden())
        r=self.parse();self.assertTrue(r["passed"]);self.assertFalse(r["speed_claim"])
        self.assertTrue(r["control_capable"]);self.assertEqual([c["abort_down128_host_enqueues"] for c in r["cases"]],[0,3,8,0])
        self.assertTrue(all(c["recovered_down128_host_enqueues"]==28 for c in r["cases"]))
        with self.assertRaises(ValueError):check.parse(self.csv,dict(golden(),control_capable=False),allow_down=True)

    def test_actual_counts_marker_newline_and_poison_are_mandatory(self):
        for old,new in (("ABORT_DOWN_ROWS128,1,3","ABORT_DOWN_ROWS128,1,4"),
            ("RECOVERED_DOWN_ROWS128,0,28","RECOVERED_DOWN_ROWS128,0,27"),
            ("POISON_DOWN_ROWS128,1","POISON_DOWN_ROWS128,0"),
            ("ABORT_DOWN_ROWS128,0,0\n",""),(MARKER,"ATTENTION,rope_cache_elementwise_grid,1,32"),
            ("CONTROL,1,timeout,3,0,0,32,1,1","CONTROL,1,timeout,3,32,0,32,1,1"),
            ("MASK_RESTORED,1","MASK_RESTORED,0")):
            with self.subTest(old=old),self.assertRaises((ValueError,StopIteration)):self.parse(fixture().replace(old,new))
        with self.assertRaises(ValueError):self.parse(fixture().rstrip("\n"))

    def test_signed_zero_and_complete_numeric_failures_retained(self):
        for text in (fixture(.125),fixture().replace("LOGIT,0,0,0,0","LOGIT,0,0,0,-0.0")):
            r=self.parse(text);self.assertFalse(r["passed"]);self.assertTrue(r["collection_complete"])
            self.assertEqual(len(r["cases"]),4);self.assertFalse(r["speed_claim"])

    def test_control_capable_metadata_and_accepted_source_boolean_match(self):
        csv,report,r=self.accepted()
        self.assertTrue(check.reference(csv,report,"a"*64,allow_down=True)[1]["control_capable"])
        for value in (False,1):
            r["control_capable"]=value;report.write_text(json.dumps(r))
            with self.assertRaises(ValueError):source.accepted_model(csv,report,"a"*64)
        csv,report,_=self.accepted(False)
        with self.assertRaises(ValueError):check.reference(csv,report,"a"*64,allow_down=True)
        self.assertFalse(model.parse(csv)["control_capable"])
        text=model_base().replace("ADMISSION,3,2,0\n","ADMISSION,3,2,0\nCONTROL_CAPABLE,3,1\n")
        for changed in (text.replace("CONTROL_CAPABLE,3,1","CONTROL_CAPABLE,3,0"),
            text.replace("CONTROL_CAPABLE,3,1","CONTROL_CAPABLE,3,1\nCONTROL_CAPABLE,3,1")):
            csv.write_text(changed)
            with self.assertRaises(ValueError):model.parse(csv)

    def main(self,suffix,*,mutate=None,interrupt=False):
        self.csv.write_text(fixture());output=self.root/suffix
        paths=[self.root/n for n in ("model","source","source-report")]
        args=["checker",str(self.csv),"--down128","--model",str(paths[0]),"--model-sha256","a"*64,
            "--reference-csv",str(paths[1]),"--reference-report",str(paths[2]),"--output",str(output)]
        proof=dict(passed=True,control_capable=True,attention_variant=3,csv_sha256="b"*64,report_sha256="c"*64)
        hashes={paths[0]:"a"*64,paths[1]:"b"*64,paths[2]:"c"*64,self.csv:hashlib.sha256(self.csv.read_bytes()).hexdigest()}
        counts={}
        def digest(p):
            counts[p]=counts.get(p,0)+1
            if p==mutate and counts[p]>=(2 if p==paths[0] else 1):return "e"*64
            return hashes[p]
        with patch.object(sys,"argv",args),patch.object(check,"digest",side_effect=digest), \
            patch.object(check,"reference",side_effect=KeyboardInterrupt if interrupt else None,return_value=(golden(),proof)):
            status=check.main()
        return status,json.loads(output.read_text()),args,paths+[self.csv]

    def test_all_after_validation_artifact_mutations_preserve_complete_failure(self):
        _,_,_,paths=self.main("paths")
        for index,p in enumerate(paths):
            status,r,_,_=self.main("changed"+str(index),mutate=p)
            self.assertEqual(status,1);self.assertFalse(r["passed"]);self.assertTrue(r["collection_complete"])
            self.assertEqual(len(r["cases"]),4);self.assertFalse(r["speed_claim"])

    def test_interrupt_and_exclusive_reports_fail_closed(self):
        for label in ("success","interrupt"):
            status,r,args,_=self.main(label,interrupt=label=="interrupt")
            self.assertEqual(status,1 if label=="interrupt" else 0)
            self.assertEqual(r["collection_complete"],label=="success")
            if label=="interrupt":self.assertIn("KeyboardInterrupt",r["error"])
            saved=Path(args[-1]).read_bytes()
            with patch.object(sys,"argv",args),self.assertRaises(FileExistsError):check.main()
            self.assertEqual(Path(args[-1]).read_bytes(),saved)


if __name__=="__main__":unittest.main()
