# tests/bench_teacher_forcing_a109.mojo
# A-109: Teacher-forcing harness v2 -- measured driver.
#
# Usage: bench_teacher_forcing_a109 <oracle.gguf> <candidate.gguf> <label> [mode]
#   mode = raw (default) | template
#
# Method: the A-045 standard sequence (RAW prompt "One day,
# Timmy went to", tokenizer add_bos=True, NO chat template, +
# the 32 pinned oracle greedy IDs) is graded through the v2
# harness (core/teacher_forcing_harness.tf_grade_rows) on CPU
# vs the pinned F16 CPU oracle. In template mode the prompt is
# deliberately ChatML-rendered first and the harness itself
# must reject it (TF109_REJECTED) before any grading -- the
# acceptance proof that template-rendered input never grades.

from std.sys import argv

from core.teacher_forcing_harness import (
    TF_OK,
    tf_grade_rows,
    tf_reject_name,
    tf_summary_digest,
    tf_summary_line,
    tf_validate_run,
)
from aesir import AesirEngine


def _oracle_ids() -> List[Int]:
    var e = List[Int]()
    e.append(265); e.append(282); e.append(295); e.append(433)
    e.append(335); e.append(345); e.append(357); e.append(426)
    e.append(342); e.append(394); e.append(261); e.append(370)
    e.append(268); e.append(414); e.append(444); e.append(335)
    e.append(261); e.append(370); e.append(268); e.append(414)
    e.append(444); e.append(426); e.append(291); e.append(268)
    e.append(414); e.append(444); e.append(286); e.append(399)
    e.append(262); e.append(423); e.append(388); e.append(269)
    return e^


def main() raises:
    var args = argv()
    if len(args) < 4 or len(args) > 5:
        raise Error("usage: bench_teacher_forcing_a109 <oracle.gguf> <candidate.gguf> <label> [raw|template]")
    var oracle_path = String(args[1])
    var cand_path = String(args[2])
    var label = String(args[3])
    var mode = String("raw")
    if len(args) == 5:
        mode = String(args[4])
    var raw_prompt = String("One day, Timmy went to")
    var prompt = raw_prompt
    if mode == String("template"):
        prompt = String("<|im_start|>user\n") + raw_prompt + String("<|im_end|>")
    var verdict = tf_validate_run(prompt, "cpu", "cpu")
    if verdict != TF_OK:
        print("TF109_REJECTED label=", label, " mode=", mode, " verdict=", tf_reject_name(verdict))
        print("TF109_BENCH_DONE label=", label)
        return
    var oracle_ids = _oracle_ids()
    var cand = AesirEngine(cand_path)
    var prompt_tokens = cand.tokenizer.encode(raw_prompt, True)
    if len(prompt_tokens) != 8:
        raise Error("A109: prompt token count != 8, got " + String(len(prompt_tokens)))
    var seq = prompt_tokens.copy()
    for i in range(len(oracle_ids)):
        seq.append(oracle_ids[i])
    var cand_rows = cand.teacher_forcing_logit_rows(seq)
    if len(cand_rows) != len(seq):
        raise Error("A109: logit row count != sequence length")
    var g = tf_grade_rows(cand_rows, seq, 8)
    print(tf_summary_line(label, "cpu", "cpu", g), " digest=", tf_summary_digest(label, "cpu", "cpu", g))
    print("TF109_BENCH_DONE label=", label)
