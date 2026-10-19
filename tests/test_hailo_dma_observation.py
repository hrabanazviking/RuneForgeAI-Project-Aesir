#!/usr/bin/env python3
"""Adversarial checker tests against an explicit real observation file.

Mutations are test-only damaged records, never generated device responses.
"""
import argparse
import copy
import sys
import unittest
from check_hailo_dma_observation import check, load

CONFIG = argparse.Namespace()


class ObservationChecks(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.original = load(CONFIG.trace)

    def setUp(self):
        self.rows = copy.deepcopy(self.original)

    def entry(self, operation):
        return next(r for r in self.rows if r.get("operation") == operation)

    def reply(self, entry):
        return next(r for r in self.rows if r["kind"] == "return" and r["id"] == entry["id"])

    def test_actual_paired_observation(self):
        summary = check(self.rows)
        self.assertEqual(summary["paired_ioctls"], 548)
        self.assertEqual(summary["mapped_buffers"], 258)
        self.assertFalse(summary["independent_mojo_exchange"])
        self.assertFalse(summary["model_inference"])

    def test_missing_and_duplicate_call_records_reject(self):
        self.rows.pop()
        with self.assertRaisesRegex(ValueError, "unpaired"):
            check(self.rows)
        self.rows = copy.deepcopy(self.original)
        self.rows.append(copy.deepcopy(self.rows[1]))
        with self.assertRaisesRegex(ValueError, "duplicate"):
            check(self.rows)

    def test_guessed_padding_and_zero_success_return_reject(self):
        transfer = self.entry("transfer")
        transfer["buffers"][0]["bytes"] = 2072
        with self.assertRaisesRegex(ValueError, "physical message length"):
            check(self.rows)
        transfer["buffers"][0]["bytes"] = 2068
        self.reply(transfer)["result"] = 0
        with self.assertRaisesRegex(ValueError, "descriptor count"):
            check(self.rows)

    def test_unassigned_descriptor_or_channels_reject(self):
        transfer = self.entry("transfer")
        transfer["handle"] += 1
        with self.assertRaisesRegex(ValueError, "descriptor/channel"):
            check(self.rows)

    def test_wrong_unmap_tuple_rejects(self):
        unmap = self.entry("buffer-unmap")
        unmap["address_or_fd"] += 1
        with self.assertRaisesRegex(ValueError, "unmatched buffer unmap"):
            check(self.rows)

    def test_invented_zero_request_status_rejects(self):
        transfer = next(r for r in self.rows if r.get("operation") == "transfer"
                        and "header_hex" in r["buffers"][0])
        header = bytearray.fromhex(transfer["buffers"][0]["header_hex"])
        header[16:20] = bytes(4)
        transfer["buffers"][0]["header_hex"] = header.hex()
        with self.assertRaisesRegex(ValueError, "request envelope"):
            check(self.rows)

    def test_interrupt_error_does_not_become_completion(self):
        irq = next(r for r in self.rows if r.get("interrupts"))
        irq["interrupts"][0]["data"] = 254
        with self.assertRaisesRegex(ValueError, "interrupt status"):
            check(self.rows)

    def test_failed_ioctl_is_not_reported_as_reference_success(self):
        reply = self.reply(self.entry("connect"))
        reply["result"], reply["errno"] = -1, 5
        with self.assertRaisesRegex(ValueError, "failed reference ioctl"):
            check(self.rows)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--trace", required=True)
    CONFIG, remaining = parser.parse_known_args()
    unittest.main(argv=[sys.argv[0], *remaining])
