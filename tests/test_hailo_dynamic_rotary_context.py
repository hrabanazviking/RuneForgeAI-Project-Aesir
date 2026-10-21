#!/usr/bin/env python3
"""Independent integer/rational acceptance; never evaluates a model or attention."""
import argparse
from fractions import Fraction
import hashlib
import itertools
import json
from pathlib import Path
import subprocess
import unittest

CONFIG = None
CALLS = []

class DynamicRotaryContextTest(unittest.TestCase):
    def child(self, mode, values=(), refuse=False):
        args = [str(CONFIG.binary), mode, *map(str, values)]
        result = subprocess.run(args, text=True, capture_output=True, timeout=10)
        CALLS.append(dict(mode=mode, args=list(map(str, values)), returncode=result.returncode,
                          stdout=result.stdout, stderr=result.stderr, expected_refusal=refuse))
        if refuse:
            self.assertNotEqual(result.returncode, 0)
            self.assertNotIn("INVALID: mutation accepted", result.stderr)
            self.assertIn("DynamicRotary", result.stderr)
            return
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stderr, "")
        return [list(map(int, line.split())) for line in result.stdout.splitlines()]

    def batch(self, mode, rows, expected):
        for start in range(0, len(rows), 32):
            batch = rows[start:start+32]
            got = self.child(mode, itertools.chain.from_iterable(batch))
            self.assertEqual(got, expected[start:start+32])

    def test_context_domains_and_limits(self):
        rows, expected = [], []
        for limit in range(1, 10):
            for reference in range(1, limit+1):
                for retained in range(reference, limit+1):
                    for position in range(limit):
                        # Independent partition by observed-index interval.
                        intervals = [(0, reference-2, reference),
                                     (reference-1, retained-1, retained),
                                     (retained, limit-1, position+1)]
                        matches = [selected for lo,hi,selected in intervals if lo <= position <= hi]
                        self.assertEqual(len(matches), 1)
                        rows.append([reference, retained, limit, position])
                        expected.append([reference, matches[0], limit])
        high = (1 << 63)-1
        for row in [[1,1,high,high-1],[high,high,high,high-1],
                    [high-1,high,high,high-2],[high-1,high,high,high-3]]:
            reference, retained, limit, position = row
            selected = reference if position+1 < reference else max(retained,position+1)
            rows.append(row); expected.append([reference, selected, limit])
        self.batch("select", rows, expected)
        for reference, limit in [(1,1),(8,64),(high,high)]:
            self.assertEqual(self.child("initial", [reference,limit]), [[reference,reference,limit]])
        self.context_cases = len(rows)

    def test_all_public_state_observations(self):
        oracle = json.loads(CONFIG.oracle.read_text())
        rows, expected = [], []
        for scenario in oracle["scenarios"]:
            reference = scenario["configured_context"]
            retained = reference
            for step in scenario["steps"]:
                rows.append([reference, retained, 64, max(step["positions"])])
                expected.append([reference, step["observed_context"], 64])
                retained = step["observed_context"]
        self.assertEqual(len(rows), 576)
        self.batch("select", rows, expected)

    def test_exact_rational_schedule(self):
        rows, expected = [], []
        contexts = [(1,1,1),(8,8,64),(8,17,64),(16,32,64),
                    (1,(1<<63)-1,(1<<63)-1)]
        widths = list(range(2,34,2)) + [(1<<63)-2]
        for reference, selected, limit in contexts:
            for width in widths:
                indices = list(range(width//2)) if width < 100 else [0,1,width//2-1]
                for pair in indices:
                    theta = Fraction(-pair, width//2)
                    gain = Fraction(0) if pair == 0 else Fraction(-pair, width//2-1)
                    actual_theta = [0,1] if pair == 0 else [-2*pair,width]
                    actual_gain = [0,1] if pair == 0 else [-2*pair,width-2]
                    self.assertEqual(Fraction(*actual_theta), theta)
                    self.assertEqual(Fraction(*actual_gain), gain)
                    self.assertEqual(Fraction(selected-reference, reference), Fraction(selected,reference)-1)
                    rows.append([reference,selected,limit,width,pair])
                    expected.append([reference,selected,limit,width,pair,*actual_theta,*actual_gain,selected-reference,reference])
        self.batch("coefficients", rows, expected)

    def test_refusals_mutation_ownership_and_recovery(self):
        high = (1<<63)-1
        for row in [[0,1,8,0],[-1,1,8,0],[8,7,8,0],[1,9,8,0],
                    [1,1,0,0],[1,1,8,-1],[1,1,8,8],[1,1,high,high]]:
            self.child("select", row, refuse=True)
        for row in [[0,8],[-1,8],[9,8],[1,0]]:
            self.child("initial", row, refuse=True)
        for width,pair in [(0,0),(1,0),(3,0),(-2,0),(2,-1),(2,1),(8,4),(high,0)]:
            self.child("coefficients", [8,17,64,width,pair], refuse=True)
        for field in range(11):
            self.child("mutate", [field], refuse=True)
            self.assertEqual(self.child("isolation"), [[8,17,64,2,0,0,1,0,1,9,8]])

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--binary", type=Path, required=True)
    parser.add_argument("--oracle", type=Path, default=Path("docs/evidence/dynamic-basis-2026-10-21/states.json"))
    parser.add_argument("--result", type=Path, required=True)
    CONFIG = parser.parse_args()
    suite = unittest.defaultTestLoader.loadTestsFromTestCase(DynamicRotaryContextTest)
    result = unittest.TextTestRunner(verbosity=2).run(suite)
    report = dict(methods=result.testsRun, failures=len(result.failures), errors=len(result.errors),
                  native_child_calls=len(CALLS), expected_refusals=sum(row["expected_refusal"] for row in CALLS),
                  accepted_calls=sum(not row["expected_refusal"] for row in CALLS),
                  public_state_observations=576, model_layer_attention_or_device_execution=False,
                  inputs={str(p):hashlib.sha256(p.read_bytes()).hexdigest() for p in [CONFIG.binary,CONFIG.oracle,Path(__file__)]},calls=CALLS)
    CONFIG.result.write_text(json.dumps(report,indent=2)+"\n")
    raise SystemExit(not result.wasSuccessful())
