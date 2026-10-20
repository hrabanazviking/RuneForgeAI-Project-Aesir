#!/usr/bin/env python3
"Exact structural compatibility and direct typed inputs; no model forward."
import argparse
import hashlib
import itertools
import json
from pathlib import Path
import random
import subprocess
import sys
import tempfile
import unittest

from test_hailo_semantic_plan import dense_fixture, MAX
import test_hailo_semantic_plan as semantic_oracle

CONFIG = argparse.Namespace()


class TypedDecoder(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.bins = {name: str(Path(getattr(CONFIG, name)).resolve(strict=True))
                    for name in ("baseline", "binary", "typed", "api")}
        cls.temp = tempfile.TemporaryDirectory(prefix="aesir-typed-decoder-")
        cls.root = Path(cls.temp.name)
        cls.evidence = Path(CONFIG.evidence).resolve()
        cls.evidence.mkdir(parents=True, exist_ok=True)
        cls.records = []

    @classmethod
    def tearDownClass(cls):
        (cls.evidence/"fixture-runs.json").write_text(json.dumps(cls.records, indent=2)+"\n")
        cls.temp.cleanup()

    def run_child(self, kind, args, raw=None, trace=None):
        command = [self.bins[kind], *map(str, args)]
        if trace:
            command = [CONFIG.strace, "-y", "-o", str(self.evidence/trace),
                       "-e", "trace=openat,close,mmap,munmap,ioctl,write", *command]
        result = subprocess.run(command, capture_output=True, text=True, timeout=20,
                                stdin=subprocess.DEVNULL, check=False)
        self.records.append({"binary": kind, "arguments": [str(x) for x in args],
            "source_sha256": hashlib.sha256(raw).hexdigest() if raw is not None else None,
            "returncode": result.returncode, "stdout_sha256": hashlib.sha256(result.stdout.encode()).hexdigest(),
            "stdout_bytes": len(result.stdout.encode()), "stderr": result.stderr})
        return result

    def source(self, generated=None):
        raw, weights, offset = generated or dense_fixture()
        source = self.root/f"fixture-{len(self.records)}.gguf"
        source.write_bytes(raw)
        return source, raw, weights

    def accept(self, result):
        self.assertEqual(result.returncode, 0, result.stdout+result.stderr)
        return json.loads(result.stdout)

    def refuse(self, result):
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(result.stdout, "")

    def compare(self, generated=None, session=(3, 0, 16), trace=False):
        source, raw, weights = self.source(generated)
        plans = []
        for kind in ("baseline", "binary", "typed"):
            args = [source, *session] if kind != "typed" else ["typed", source, *session]
            plans.append(self.accept(self.run_child(kind, args, raw,
                "typed-source.strace" if trace and kind == "typed" else None)))
        self.assertEqual(plans[0], plans[1])
        self.assertEqual(plans[0], plans[2])
        self.assertEqual(plans[2]["weights"], weights)
        semantic_oracle.SemanticPlan.check_graph(self, plans[2])
        self.assertEqual(hashlib.sha256(source.read_bytes()).digest(), hashlib.sha256(raw).digest())
        for flag in ("execution_tested", "executable_program", "source_fingerprint_verified", "hardware_fit_verified"):
            self.assertIs(plans[2][flag], False)
        return plans[2]

    def test_complete_graph_baseline_compatibility(self):
        for session in ((3,0,16),(1,7,16),(4,5,16),(16,0,16),(1,63,64)):
            self.compare(session=session)
        for layers, tied, value in itertools.product((1,2,4), (False,True), (2,3)):
            self.compare(dense_fixture(layers=layers,tied=tied,value=value))
        self.compare(dense_fixture(hidden=10,key=2,value=3))
        self.compare(dense_fixture(kv_heads=4, explicit_dims=False, drop=("llama.attention.head_count_kv",)))
        for kind in (0,1,12,13,14,30):
            self.compare(dense_fixture(hidden=256,key=64,value=64,ff=512,matrix_kind=kind))
        for base, epsilon in ((0.125,0.03125),(3.1415927,1e-9),(1.17549435e-38,3.4028234e38)):
            self.compare(dense_fixture(overrides={"llama.rope.freq_base":(6,base),
                "llama.attention.layer_norm_rms_epsilon":(6,epsilon)}))
        layout = "unresolved \"layout\" / Æsir\nprovenance"
        self.assertEqual(self.compare(dense_fixture(overrides={"llama.tensor_data_layout":(8,layout)}))
                         ["parameters"]["source_layout"], layout)

    def test_adapter_semantic_refusals_are_preserved(self):
        cases = [dense_fixture(architecture="qwen3"), dense_fixture(hidden=10, explicit_dims=False),
                 dense_fixture(overrides={"llama.extra_semantic":(4,1)}),
                 dense_fixture(overrides={"llama.rope.scaling.type":(8,"linear")}),
                 dense_fixture(overrides={"llama.embedding_length":(8,"8")}),
                 dense_fixture(overrides={"llama.rope.freq_base":(6,float("nan"))}),
                 dense_fixture(overrides={"llama.vocab_size":(4,11)}),
                 dense_fixture(omit=("blk.0.attn_q.weight",)),
                 dense_fixture(extra_tensors=(("unused.weight",8,1,0),)),
                 dense_fixture(drop=("llama.context_length",))]
        for generated in cases:
            source, raw, _ = self.source(generated)
            for kind in ("baseline","binary","typed"):
                args = [source,3,0,16] if kind != "typed" else ["typed",source,3,0,16]
                self.refuse(self.run_child(kind,args,raw))

    def test_direct_typed_dimension_and_shape_refusals(self):
        source, raw, _ = self.source()
        cases = {"layers":(0,-1,2,MAX), "hidden":(0,-1,9,MAX), "feed_forward":(0,-1,13,MAX),
                 "heads":(0,-1,3,MAX), "kv_heads":(0,-1,3,8,MAX),
                 "key_dim":(0,-1,3,MAX), "value_dim":(0,-1,3,MAX),
                 "rope_dim":(0,-1,1,3,4,MAX), "vocabulary":(0,-1,11,MAX),
                 "source_context":(0,-1,15)}
        for field, values in cases.items():
            for value in values:
                self.refuse(self.run_child("typed",["parameter",source,3,0,16,field,value],raw))
        for session in ((0,0,16),(1,-1,16),(1,0,0),(2,15,16),(1,17,16),(1,0,65),
                        (MAX,MAX,MAX),(1,MAX,16)):
            self.refuse(self.run_child("typed",["typed",source,*session],raw))
        for field, value in (("source_context",MAX),("source_layout","a \"layout\"\nÆsir")):
            report=self.accept(self.run_child("typed",["parameter",source,3,0,16,field,value],raw))
            semantic_oracle.SemanticPlan.check_graph(self,report)

    def test_exact_float_parameters_and_invalid_words(self):
        source, raw, _ = self.source()
        # Native API checks twenty parameter words exactly, not decimal formatting.
        report=self.accept(self.run_child("api",[source],raw))
        self.assertEqual(report["float32_bits_checked"],20)
        self.assertTrue(report["ownership_checked"])
        self.assertFalse(report["device_access"])
        self.assertFalse(report["execution_tested"])
        for field in ("rope_base_bits","rms_epsilon_bits"):
            for word in (0,0x80000000,0x80000001,0xBF800000,0x7F800000,0xFF800000,
                         0x7F800001,0x7FC00000,0x7FFFFFFF,0xFFC00001):
                self.refuse(self.run_child("typed",["parameter",source,3,0,16,field,word],raw))

    def test_direct_inventory_refusals(self):
        source, raw, _ = self.source()
        for mode in ("architecture","empty","source_bytes","data_offset","data_after_source","aggregate",
                     "offset_before","offset_after","offset_overflow","columns","rows","rows_overflow",
                     "kind","byte_count","overlap","extra","missing"):
            self.refuse(self.run_child("typed",["inventory",source,3,0,16,mode],raw))

    def test_pair_sort_and_overlap_oracle(self):
        cases=[[],[(0,1)],[(MAX-1,MAX)],[(0,1),(1,2)],[(0,4),(1,2)],[(1,2),(0,4)],
               [(1,2),(1,3)],[(0,MAX),(MAX-1,MAX)]]
        for n in range(2,7):
            spans=[(i*3,i*3+2) for i in range(n)]
            cases.extend(list(itertools.permutations(spans))[:40])
        rng=random.Random(20261020)
        for _ in range(160):
            spans=[(start:=rng.randrange(0,500),start+rng.randrange(1,20)) for _ in range(rng.randrange(0,40))]
            rng.shuffle(spans)
            cases.append(spans)
        # Larger reversed disjoint/overlapping metadata probes, no tensor allocation.
        cases += [list(reversed([(i*3,i*3+2) for i in range(2000)])),
                  [(i*3,i*3+4) for i in range(2000)]]
        for spans in cases:
            ordered=sorted(spans)
            overlap=any(b[0]<a[1] for a,b in zip(ordered,ordered[1:]))
            result=self.run_child("api",["spans",*(v for pair in spans for v in pair)])
            if overlap:
                self.refuse(result)
                self.assertIn("overlapping descriptive source bindings",result.stderr)
            else:
                report=self.accept(result)
                self.assertEqual(report,{"starts":[a for a,b in ordered],"ends":[b for a,b in ordered]})

    def test_synthetic_and_read_only_syscalls(self):
        report=self.accept(self.run_child("typed",["synthetic"],trace="typed-synthetic.strace"))
        semantic_oracle.SemanticPlan.check_graph(self,report)
        self.compare(trace=True)
        source_trace=(self.evidence/"typed-source.strace").read_text()
        self.assertIn("O_RDONLY",source_trace)
        self.assertIn("PROT_READ, MAP_PRIVATE",source_trace)
        source_unmap=source_trace.index("munmap(",source_trace.index("fixture-"))
        self.assertLess(source_unmap, source_trace.index("write(1"))
        for name in ("typed-source.strace","typed-synthetic.strace"):
            trace=(self.evidence/name).read_text()
            for forbidden in ("/dev/h1x-","libcuda","libhailort","libggml","ioctl("):
                self.assertNotIn(forbidden,trace)
        self.assertNotIn(".gguf", (self.evidence/"typed-synthetic.strace").read_text())


if __name__=="__main__":
    parser=argparse.ArgumentParser()
    for name in ("baseline","binary","typed","api","strace","evidence"):
        parser.add_argument("--"+name,required=True)
    CONFIG,remaining=parser.parse_known_args()
    unittest.main(argv=[sys.argv[0],*remaining])
