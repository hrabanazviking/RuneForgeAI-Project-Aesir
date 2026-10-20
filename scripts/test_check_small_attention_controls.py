"""Portable strategy5 control checks reject altered execution evidence."""
from array import array
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

import check_turing_fixture_controls as check
from test_check_turing_fixture_controls import fixture as base, golden as base_golden


def golden():
    return dict(base_golden(), attention_variant=5, control_capable=True)


def fixture(delta=0):
    text = base(delta).replace(
        "META,1,fixture_controls",
        "ATTENTION,rope_cache_elementwise_down128_small_controls,1,32\n"
        "META,1,fixture_controls",
    )
    for index, layers in enumerate((0, 3, 8, 0)):
        text = text.replace(
            f"ABORT_GUARD,{index},",
            f"ABORT_SMALL_ATTENTION,{index},{layers},0,0\n"
            f"ABORT_DOWN_ROWS128,{index},{layers}\n"
            f"ABORT_FUSED_ATTENTION,{index},0,0\nABORT_GUARD,{index},",
        )
        text = text.replace(
            f"\nGUARD,{index},1088",
            f"\nRECOVERED_SMALL_ATTENTION,{index},56,0,28\n"
            f"RECOVERED_DOWN_ROWS128,{index},28\n"
            f"RECOVERED_FUSED_ATTENTION,{index},0,28\nGUARD,{index},1088",
        )
    text = text.replace(
        "POISON_GUARD,",
        "POISON_SMALL_ATTENTION,1,0,0\nPOISON_DOWN_ROWS128,1\n"
        "POISON_FUSED_ATTENTION,0,0\nPOISON_GUARD,",
    )
    return text


class SmallAttentionControls(unittest.TestCase):
    def parse(self, text=None):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "capture.csv"
            path.write_text(fixture() if text is None else text)
            with patch.object(check, "VOCABULARY", 4):
                return check.parse(path, golden(), allow_small=True)

    def test_complete_strategy5_recovery_is_unscored(self):
        report = self.parse()
        self.assertTrue(report["passed"])
        self.assertFalse(report["speed_claim"])
        self.assertEqual(report["attention_variant"], 5)
        self.assertTrue(all(c["byte_identical"] for c in report["cases"]))

    def test_small_dispatch_and_closed_fused_counts_are_mandatory(self):
        for old, new in (
            ("ABORT_SMALL_ATTENTION,1,3,0,0", "ABORT_SMALL_ATTENTION,1,7,0,0"),
            ("RECOVERED_SMALL_ATTENTION,0,56,0,28", "RECOVERED_SMALL_ATTENTION,0,55,0,28"),
            ("POISON_SMALL_ATTENTION,1,0,0", "POISON_SMALL_ATTENTION,2,0,0"),
            ("ABORT_FUSED_ATTENTION,0,0,0", "ABORT_FUSED_ATTENTION,0,1,0"),
            ("RECOVERED_FUSED_ATTENTION,0,0,28", "RECOVERED_FUSED_ATTENTION,0,0,27"),
            ("POISON_FUSED_ATTENTION,0,0", "POISON_FUSED_ATTENTION,1,0"),
        ):
            with self.subTest(old=old), self.assertRaises(ValueError):
                self.parse(fixture().replace(old, new))

    def test_strategy_marker_and_complete_state_are_required(self):
        text = fixture()
        for old, new in (
            ("rope_cache_elementwise_down128_small_controls", "rope_cache_elementwise_down128_small"),
            ("CONTROL,1,timeout,3,0,0,32,1,1", "CONTROL,1,timeout,3,32,0,32,1,1"),
            ("RESET,0,0,0,0,1,0,1,1,1,0,0", "RESET,0,0,0,0,1,0,0,1,1,0,0"),
            ("MASK_RESTORED,1", "MASK_RESTORED,0"),
        ):
            with self.subTest(old=old), self.assertRaises((ValueError, StopIteration)):
                self.parse(text.replace(old, new))


if __name__ == "__main__":
    unittest.main()
