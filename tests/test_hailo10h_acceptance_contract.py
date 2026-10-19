#!/usr/bin/env python3
"""Synthetic validator regressions only; these never prove Hailo execution."""

from copy import deepcopy
import json
from pathlib import Path
import unittest

from test_hailo10h_hardware import records, validate_chat, validate_response


PROFILE = json.loads((Path(__file__).parent / "fixtures" /
                      "hailo10h_qwen25_1_5b.json").read_text())


def identity(usage=0, completion="none"):
    return {**{key: PROFILE[key] for key in (
        "architecture", "backend", "runtime_version", "firmware_version",
        "model_sha256", "model_size_bytes", "context_capacity", "template_token_reserve",
    )}, "device_id": "synthetic-validator-device", "context_usage": usage,
        "last_completion": completion, "needs_reset": False, "needs_reopen": False}


def response(text, usage):
    return {"response": text, "provenance": identity(usage, "end_of_generation")}


def conversation():
    return [identity(), response("Remembered.", 40), response("ember\nOK.", 75),
            {"error": "ContextCapacityExceeded: request rejected"},
            identity(75, "end_of_generation"), response("ember", 105),
            {"event": "context_cleared", "provenance": identity(0, "context_cleared")},
            identity(0, "context_cleared"), response("5.", 46)]


class AcceptanceContractTests(unittest.TestCase):
    def test_formatting_observation_is_separate_from_recall(self):
        result = validate_chat(conversation(), PROFILE, "synthetic-validator-device")
        self.assertFalse(result["recall_word_only"])
        self.assertTrue(result["recall_after_rejection_word_only"])

    def test_wrong_or_missing_provenance_cannot_pass(self):
        for field, value in [("backend", "cpu"), ("architecture", "HAILO8"),
                             ("device_id", "other"), ("model_sha256", "0" * 64),
                             ("model_size_bytes", 1), ("runtime_version", "unknown"),
                             ("firmware_version", "unknown"), ("context_usage", True),
                             ("needs_reset", True), ("needs_reopen", True)]:
            with self.subTest(field=field):
                row = response("5.", 46)
                row["provenance"][field] = value
                with self.assertRaises(ValueError):
                    validate_response(row, PROFILE, "synthetic-validator-device", arithmetic=True)
        row = response("5.", 46)
        row["provenance"] = {"diagnostics_error": "device unavailable"}
        with self.assertRaises(ValueError):
            validate_response(row, PROFILE, "synthetic-validator-device")

    def test_failed_empty_aborted_and_wrong_answer_reject(self):
        for row in ({"error": "failure"}, response("", 46), response("6", 46),
                    response("5.", 0)):
            with self.subTest(row=row), self.assertRaises(ValueError):
                validate_response(row, PROFILE, "synthetic-validator-device", arithmetic=True)
        row = response("5.", 46)
        row["provenance"]["last_completion"] = "aborted"
        with self.assertRaises(ValueError):
            validate_response(row, PROFILE, "synthetic-validator-device")

    def test_context_loss_and_false_reset_reject(self):
        for position, usage in ((0, 1), (2, 40), (4, 76), (6, 1), (7, 1)):
            with self.subTest(position=position):
                rows = deepcopy(conversation())
                target = rows[position].get("provenance", rows[position])
                target["context_usage"] = usage
                with self.assertRaises(ValueError):
                    validate_chat(rows, PROFILE, "synthetic-validator-device")

    def test_missing_records_and_hidden_error_reject(self):
        for rows in (conversation()[:-1], conversation() + [identity()]):
            with self.assertRaises(ValueError):
                validate_chat(rows, PROFILE, "synthetic-validator-device")
        rows = conversation()
        rows[3] = response("pretend overflow succeeded", 76)
        with self.assertRaises(ValueError):
            validate_chat(rows, PROFILE, "synthetic-validator-device")

    def test_incorrect_recall_cannot_pass(self):
        rows = conversation()
        rows[5]["response"] = "I do not remember."
        with self.assertRaises(ValueError):
            validate_chat(rows, PROFILE, "synthetic-validator-device")

    def test_json_output_is_strict(self):
        self.assertEqual(records('{"response":"5."}\n'), [{"response": "5."}])
        for text in ("", "null", "[]", 'banner\n{"response":"5."}', "{broken"):
            with self.subTest(text=text), self.assertRaises(ValueError):
                records(text)


if __name__ == "__main__":
    unittest.main()
