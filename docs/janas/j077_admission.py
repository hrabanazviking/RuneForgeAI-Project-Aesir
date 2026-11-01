#!/usr/bin/env python3
"""J-077 admission over J-076's filed census rows.

Applies core/mtp_head_support.mojo's admission mapping --
the Python mirror of its rules, in the J-076 pattern (the
census script mirrored the classifier the same way) -- to
every row of docs/janas/j076_census_output.txt (PROVEN
inputs: full directories read and sha-pinned by J-076), and
to the roadmap's named cases J-076 section 3 graded
ABSENT-FILE / NOT PROVEN (directory_read False by record).

Mapping (mtp_head_support.mojo, rules 2-3): a censused
WITH_MTP row admits; NO_MTP refuses REFUSE_NO_MTP;
VOCAB_ONLY refuses REFUSE_VOCAB_ONLY; an uncensused file
refuses REFUSE_NOT_PROVEN. Output: one refusal/admission
line per file, in mtp_refusal_line's form (file, verdict,
reason), plus the summary counts. Run from the repo root.
Deterministic: the same census rows always file the same
lines.
"""
import json
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]

# The roadmap's named cases with no directory read tonight
# (J-076 section 3): filed here exactly as uncensused --
# name as recorded, directory_read False.
NAMED_UNREAD = [
    "Qwen3-Next-80B-A3B-Instruct-Q4_K_M.gguf",
    "Qwen3.5-2B-Claude-4.6-OS-Auto-Variable-HERETIC-UNCENSORED-THINKING.i1-Q4_K_M.gguf",
    "qwen35moe (no file, no pin in any Aesir record)",
    "qwen4exp / Qwen3.8-Flash-Next (no file, unpinned)",
    "Gemma 4 assistant file (absent at ledger level)",
]


def refusal_line(file_name, verdict_word, reason):
    return (
        f"REFUSED file={file_name} verdict={verdict_word} "
        f"reason={reason} -- MTP requested; not run plain"
    )


def main():
    census = json.loads(
        (ROOT / "docs/janas/j076_census_output.txt").read_text()
    )
    lines = []
    counts = {"ADMITTED": 0, "REFUSE_NO_MTP": 0,
              "REFUSE_VOCAB_ONLY": 0, "REFUSE_NOT_PROVEN": 0}
    for row in census:
        name = pathlib.Path(row["path"]).name
        verdict = row["verdict"]
        if verdict == "WITH_MTP":
            counts["ADMITTED"] += 1
            lines.append(
                f"ADMITTED file={name} verdict=WITH_MTP "
                f"heads={row['mtp_hit_count']}"
            )
        elif verdict == "NO_MTP":
            counts["REFUSE_NO_MTP"] += 1
            lines.append(refusal_line(name, "NO_MTP", "REFUSE_NO_MTP"))
        elif verdict == "VOCAB_ONLY":
            counts["REFUSE_VOCAB_ONLY"] += 1
            lines.append(
                refusal_line(name, "VOCAB_ONLY", "REFUSE_VOCAB_ONLY")
            )
        else:
            raise SystemExit(f"unknown census verdict: {verdict}")
    for name in NAMED_UNREAD:
        counts["REFUSE_NOT_PROVEN"] += 1
        lines.append(refusal_line(name, "NOT_PROVEN", "REFUSE_NOT_PROVEN"))
    lines.append(
        "SUMMARY censused={census} admitted={a} refuse_no_mtp={n} "
        "refuse_vocab_only={v} refuse_not_proven={u}".format(
            census=len(census), a=counts["ADMITTED"],
            n=counts["REFUSE_NO_MTP"], v=counts["REFUSE_VOCAB_ONLY"],
            u=counts["REFUSE_NOT_PROVEN"],
        )
    )
    out = "\n".join(lines) + "\n"
    sys.stdout.write(out)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
