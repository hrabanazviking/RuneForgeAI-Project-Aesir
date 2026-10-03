"""Explicit fused4 cooperative recovery evidence; no synthetic hardware claims."""
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
from test_check_fused_attention_model import fixture as model_base, MARKER


def golden(): return dict(baseline(), attention_variant=4, control_capable=True)


def fixture(delta=0):
    text=base(delta).replace("META,1,fixture_controls", MARKER+"\nMETA,1,fixture_controls")
    for index,layers in enumerate((0,3,8,0)):
        text=text.replace(f"ABORT_GUARD,{index},",f"ABORT_DOWN_ROWS128,{index},{layers}\nABORT_GUARD,{index},")
        text=text.replace(f"\nGUARD,{index},1088",f"\nRECOVERED_DOWN_ROWS128,{index},28\nGUARD,{index},1088")
        text=text.replace(f"ABORT_DOWN_ROWS128,{index},{layers}\n",f"ABORT_DOWN_ROWS128,{index},{layers}\nABORT_FUSED_ATTENTION,{index},{layers},0\n")
        text=text.replace(f"RECOVERED_DOWN_ROWS128,{index},28\n",f"RECOVERED_DOWN_ROWS128,{index},28\nRECOVERED_FUSED_ATTENTION,{index},56,28\n")
    return text.replace("POISON_GUARD,", "POISON_DOWN_ROWS128,1\nPOISON_FUSED_ATTENTION,1,0\nPOISON_GUARD,")


class Contracts(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory();self.addCleanup(self.temp.cleanup);self.root=Path(self.temp.name)
        self.binary=self.root/"model-binary";self.binary.write_bytes(b"capable4")
        self.csv=self.root/"capture";self.csv.write_text(fixture())
        for obj in (check,source,model,logits):
            p=patch.object(obj,"VOCABULARY",4);p.start();self.addCleanup(p.stop)

    def parse(self,text=None):
        if text is not None:self.csv.write_text(text)
        return check.parse(self.csv,golden(),allow_fused=True)

    def accepted(self,capable=True):
        csv=self.root/"model.csv";text=model_base()
        if capable:text=text.replace("ADMISSION,4,3,0\n","ADMISSION,4,3,0\nCONTROL_CAPABLE,4,1\n")
        csv.write_text(text);data=model.parse(csv,allow_fused=True,allow_fused_controls=capable);r=model.summarize(data)
        r.update(passed=True,speed_scored=True,model_sha256="a"*64,binary_sha256=hashlib.sha256(self.binary.read_bytes()).hexdigest(),
            independent_reference=dict(passed=True,requested_gpu_layers=0,context=4096,kv="f16",batch=128,threads=4,
                weight_mode="dequantized_f32",numpy="2.4.4",llama_cpp_python="0.3.23",library_sha256="b"*64,
                cases=[dict(native=c["native_comparison"],matrix=c["native_comparison"]) for c in data["cases"]]),
            fixture_reference=dict(passed=True,attention_variant=4,control_capable=False,binary_sha256="e"*64,csv_sha256="c"*64,report_sha256="d"*64,
                cases=[dict(input_ids_equal=True,native_f32_bytes_equal=True,matrix_f32_bytes_equal=True,
                    guarded_cache_identity_passed=True,passed=True) for _ in range(4)]))
        report=self.root/"model.json";report.write_text(json.dumps(r));return csv,report,r

    def test_default_refuses_explicit_capable_source_and_recovery(self):
        with self.assertRaises(ValueError):check.parse(self.csv,golden())
        r=self.parse();self.assertTrue(r["passed"]);self.assertFalse(r["speed_claim"])
        self.assertTrue(r["control_capable"]);self.assertEqual([c["abort_down128_host_enqueues"] for c in r["cases"]],[0,3,8,0])
        self.assertTrue(all(c["recovered_down128_host_enqueues"]==28 for c in r["cases"]))
        with self.assertRaises(ValueError):check.parse(self.csv,dict(golden(),control_capable=False),allow_fused=True)

    def test_actual_counts_marker_newline_and_poison_are_mandatory(self):
        for old,new in (("ABORT_DOWN_ROWS128,1,3","ABORT_DOWN_ROWS128,1,4"),
            ("RECOVERED_DOWN_ROWS128,0,28","RECOVERED_DOWN_ROWS128,0,27"),
            ("POISON_DOWN_ROWS128,1","POISON_DOWN_ROWS128,0"),
            ("ABORT_DOWN_ROWS128,0,0\n",""),(MARKER,"ATTENTION,rope_cache_elementwise_grid,1,32"),
            ("CONTROL,1,timeout,3,0,0,32,1,1","CONTROL,1,timeout,3,32,0,32,1,1"),
            ("MASK_RESTORED,1","MASK_RESTORED,0")):
            with self.subTest(old=old),self.assertRaises((ValueError,StopIteration)):self.parse(fixture().replace(old,new))
        for old,new in (("ABORT_FUSED_ATTENTION,1,3,0","ABORT_FUSED_ATTENTION,1,3,1"),
            ("RECOVERED_FUSED_ATTENTION,0,56,28","RECOVERED_FUSED_ATTENTION,0,55,28"),
            ("POISON_FUSED_ATTENTION,1,0","POISON_FUSED_ATTENTION,0,0")):
            with self.assertRaises(ValueError):self.parse(fixture().replace(old,new))
        with self.assertRaises(ValueError):self.parse(fixture().rstrip("\n"))

    def test_signed_zero_and_complete_numeric_failures_retained(self):
        for text in (fixture(.125),fixture().replace("LOGIT,0,0,0,0","LOGIT,0,0,0,-0.0")):
            r=self.parse(text);self.assertFalse(r["passed"]);self.assertTrue(r["collection_complete"])
            self.assertEqual(len(r["cases"]),4);self.assertFalse(r["speed_claim"])

    def test_control_capable_metadata_and_accepted_source_boolean_match(self):
        csv,report,r=self.accepted()
        self.assertTrue(check.reference(csv,report,"a"*64,allow_fused=True,binary=self.binary)[1]["control_capable"])
        for value in (False,1):
            r["control_capable"]=value;report.write_text(json.dumps(r))
            with self.assertRaises(ValueError):source.accepted_model(csv,report,"a"*64,fused=True,binary=self.binary,fused_controls=True)
        csv,report,_=self.accepted(False)
        with self.assertRaises(ValueError):check.reference(csv,report,"a"*64,allow_fused=True,binary=self.binary)
        self.assertFalse(model.parse(csv,allow_fused=True)["control_capable"])
        text=model_base().replace("ADMISSION,4,3,0\n","ADMISSION,4,3,0\nCONTROL_CAPABLE,4,1\n")
        for changed in (text.replace("CONTROL_CAPABLE,4,1","CONTROL_CAPABLE,4,0"),
            text.replace("CONTROL_CAPABLE,4,1","CONTROL_CAPABLE,4,1\nCONTROL_CAPABLE,4,1")):
            csv.write_text(changed)
            with self.assertRaises(ValueError):model.parse(csv,allow_fused=True,allow_fused_controls=True)

    def main(self,suffix,*,mutate=None,interrupt=False):
        self.csv.write_text(fixture());output=self.root/suffix
        paths=[self.root/n for n in ("model","source","source-report")]
        current=self.root/"control-binary";current.write_bytes(b"control4");current_sha=hashlib.sha256(current.read_bytes()).hexdigest()
        args=["checker",str(self.csv),"--fused-attention","--reference-binary",str(self.binary),"--binary",str(current),"--binary-sha256",current_sha,"--model",str(paths[0]),"--model-sha256","a"*64,
            "--reference-csv",str(paths[1]),"--reference-report",str(paths[2]),"--output",str(output)]
        proof=dict(passed=True,control_capable=True,attention_variant=4,csv_sha256="b"*64,report_sha256="c"*64,binary_sha256=hashlib.sha256(self.binary.read_bytes()).hexdigest())
        hashes={paths[0]:"a"*64,paths[1]:"b"*64,paths[2]:"c"*64,self.csv:hashlib.sha256(self.csv.read_bytes()).hexdigest(),current:current_sha,self.binary:proof["binary_sha256"]}
        counts={}
        def digest(p):
            counts[p]=counts.get(p,0)+1
            if p==mutate and counts[p]>=(2 if p in (paths[0],current) else 1):return "e"*64
            return hashes[p]
        with patch.object(sys,"argv",args),patch.object(check,"digest",side_effect=digest), \
            patch.object(check,"reference",side_effect=KeyboardInterrupt if interrupt else None,return_value=(golden(),proof)):
            status=check.main()
        return status,json.loads(output.read_text()),args,paths+[self.csv,current,self.binary]

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

    def test_fused_source_default_closed_binary_predecessor_and_cpu_scope(self):
        csv,report,original=self.accepted()
        with self.assertRaises(ValueError):source.accepted_model(csv,report,"a"*64,fused=True,binary=self.binary)
        with self.assertRaises(ValueError):source.accepted_model(csv,report,"a"*64,fused=True,fused_controls=True)
        for mutate in (lambda r:r.update(binary_sha256="e"*64),lambda r:r["fixture_reference"].update(attention_variant=3),
            lambda r:r["fixture_reference"].update(control_capable=True),lambda r:r["cases"][0].update(fused_attention_host_enqueues=1),
            lambda r:r["independent_reference"]["cases"][3]["matrix"].update(rms_error=.006)):
            value=__import__('json').loads(__import__('json').dumps(original));mutate(value);report.write_text(__import__('json').dumps(value))
            with self.assertRaises(ValueError):check.reference(csv,report,"a"*64,allow_fused=True,binary=self.binary)

    def test_binaries_cli_required_and_strategies_exclusive(self):
        _,_,args,_=self.main("cli")
        for name in ("--reference-binary","--binary","--binary-sha256"):
            changed=args.copy();i=changed.index(name);del changed[i:i+2]
            with patch.object(sys,"argv",changed),self.assertRaises(SystemExit) as error:check.main()
            self.assertEqual(error.exception.code,2)
        with patch.object(sys,"argv",args+["--down128"]),self.assertRaises(SystemExit):check.main()
        with self.assertRaises(ValueError):check.parse(self.csv,golden(),allow_down=True,allow_fused=True)

if __name__=="__main__":unittest.main()
