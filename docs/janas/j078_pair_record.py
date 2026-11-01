#!/usr/bin/env python3
"""J-078 pair record: the assistant-pair gate applied to
the ground the road has actually filed.

This is the Python mirror of core/assistant_pairing.mojo's
rules (same order, same bounds), in the J-076/J-077 pattern.
Its inputs are filed facts, each cited at its row:

- the roadmap's Gemma pair, from J-076 section 3 (the
  assistant file absent at ledger level; Gemma main files
  absent on the VM, directories unread);
- real VM files, from J-076 section 2's census (verdicts,
  file bytes) and J-074 section 3's tokenizer probe
  (the zen ladder's tokenizer identity across quants);
- two SIMULATED Gemma fixtures with the exact stated sizes
  the Mojo suite proves (labelled SIMULATED at every row --
  they are the module's fixtures, not files).

Resident inputs for the real-file rows are the files' byte
sizes as filed by J-076 (a stated proxy for residency in a
record about admissibility, not a residency measurement);
KV/scratch for those rows are stated as 0 because the rows
turn on rules checked before the budget rule. The sizing
arithmetic below replicates plan_shared_cache_pool /
plan_expert_cache_budget (J-018/J-026) exactly: reserve =
summed resident + summed KV + summed scratch + total // 5,
budget = max(0, free - reserve), hard cap applied when set,
below floor when budget < per-token routed bytes.

Run from the repo root. Deterministic: two runs over the
same filed facts are byte-identical.
"""

TOTAL = 32_000_000_000
FREE = 20_000_000_000
PER_TOKEN = 1_000_000


def sizing(pair_resident, pair_kv, pair_scratch, free=FREE):
    reserve = pair_resident + pair_kv + pair_scratch + TOTAL // 5
    budget = free - reserve
    if budget < 0:
        budget = 0
    return budget, reserve, budget < PER_TOKEN


def evaluate(row):
    """The module's rules, in the module's order."""
    name_t, name_a = row["target_name"], row["assistant_name"]
    if not name_t or not name_a:
        return "REFUSE_EMPTY_FILE_NAME", row
    if not row["target_present"] or not row["assistant_present"]:
        return "REFUSE_MISSING_FILE", row
    if not row["target_read"] or not row["assistant_read"]:
        return "REFUSE_UNCENSUSED_FILE", row
    if row["target_verdict"] == "VOCAB_ONLY" or row["assistant_verdict"] == "VOCAB_ONLY":
        return "REFUSE_VOCAB_ONLY", row
    if row["target_family"] == "unknown" or row["assistant_family"] == "unknown" \
            or row["target_family"] != row["assistant_family"]:
        return "REFUSE_FAMILY_MISMATCH", row
    if row["assistant_verdict"] == "WITH_MTP":
        if row["assistant_gate_kind"] != "assistant_model":
            return "REFUSE_ASSISTANT_FORM", row
        row["route"] = "head_assistant"
    elif row["assistant_verdict"] == "NO_MTP":
        row["route"] = "standalone_model"
    else:
        return "REFUSE_ASSISTANT_FORM", row
    if not row["tokenizer_verified"]:
        return "REFUSE_TOKENIZER_UNVERIFIED", row
    if not row["tokenizer_identical"]:
        return "REFUSE_TOKENIZER_MISMATCH", row
    if row["assistant_resident"] * 2 > row["target_resident"]:
        return "REFUSE_ASSISTANT_NOT_SMALLER", row
    a_foot = row["assistant_resident"] + row["assistant_kv"] + row["assistant_scratch"]
    t_foot = row["target_resident"] + row["target_kv"] + row["target_scratch"]
    row["assistant_footprint"] = a_foot
    row["pair_footprint"] = a_foot + t_foot
    row["share_per_mille"] = (a_foot * 1000) // (a_foot + t_foot)
    if a_foot * 4 > a_foot + t_foot:
        return "REFUSE_OVER_BUDGET_SHARE", row
    if row["k"] < 1 or row["k"] > 15:
        return "REFUSE_K_OVER_CAP", row
    budget, reserve, below = sizing(
        row["target_resident"] + row["assistant_resident"],
        row["target_kv"] + row["assistant_kv"],
        row["target_scratch"] + row["assistant_scratch"],
    )
    row["budget"] = budget
    row["reserve"] = reserve
    if budget <= 0 or below:
        return "REFUSE_BUDGET_EXCEEDED", row
    return "ADMITTED", row


def base(**kw):
    row = dict(
        target_name="", assistant_name="", target_present=True,
        assistant_present=True, target_read=True, assistant_read=True,
        target_verdict="NO_MTP", assistant_verdict="NO_MTP",
        target_family="gemma4", assistant_family="gemma4",
        assistant_gate_kind="", tokenizer_verified=True,
        tokenizer_identical=True, target_resident=0, assistant_resident=0,
        target_kv=0, assistant_kv=0, target_scratch=0, assistant_scratch=0,
        k=4, route="none", budget=0, reserve=0,
        assistant_footprint=0, pair_footprint=0, share_per_mille=0,
    )
    row.update(kw)
    return row


ROWS = [
    # 1. The roadmap's Gemma pair, as it stands tonight
    # (J-076 section 3): no assistant file exists in the
    # wave at ledger level, and no Gemma main file is on
    # this VM. Rule 1 refuses the pair before anything else.
    base(
        target_name="Gemma 4 main file (absent on VM, J-076)",
        assistant_name="Gemma 4 assistant file (absent at ledger level, J-076)",
        target_present=False, assistant_present=False,
        target_read=False, assistant_read=False,
    ),
    # 2. Real files: a Llama-family file cannot assist a
    # Qwen3 target (J-076 section 2 verdicts and bytes).
    base(
        target_name="zen-4b.i1-Q4_K_M.gguf",
        assistant_name="tinyllama.Q4_0.gguf",
        target_family="qwen3", assistant_family="llama3",
        target_resident=2_497_281_216, assistant_resident=637_699_456,
        tokenizer_verified=False, tokenizer_identical=False,
    ),
    # 3. Real files: the same model in a larger quant is
    # not a drafter -- its tokenizer IS identical (J-074
    # section 3, proven across quants) and it still refuses
    # on size, which is the rule doing its work.
    base(
        target_name="zen-4b.i1-Q4_K_M.gguf",
        assistant_name="zen-4b.i1-Q6_K.gguf",
        target_family="qwen3", assistant_family="qwen3",
        target_resident=2_497_281_216, assistant_resident=3_306_261_696,
    ),
    # 4. Real files: a vocab fixture cannot draft.
    base(
        target_name="zen-4b.i1-Q4_K_M.gguf",
        assistant_name="ggml-vocab-gemma-4.gguf",
        target_family="qwen3", assistant_family="gemma4",
        assistant_verdict="VOCAB_ONLY",
        target_resident=2_497_281_216, assistant_resident=0,
        tokenizer_verified=False, tokenizer_identical=False,
    ),
    # 5. A file that exists (on purplelongship) but whose
    # directory no census has read tonight is uncensused:
    # NOT PROVEN in either direction (J-076 section 3).
    base(
        target_name="zen-4b.i1-Q4_K_M.gguf",
        assistant_name="Qwen3-Next-80B-A3B-Instruct-Q4_K_M.gguf",
        target_family="qwen3", assistant_family="qwen3-next",
        assistant_read=False,
        target_resident=2_497_281_216, assistant_resident=48_506_100_512,
        tokenizer_verified=False, tokenizer_identical=False,
    ),
    # 6. SIMULATED Gemma fixture, head form -- the Mojo
    # suite's exact stated sizes (test_assistant_pairing).
    base(
        target_name="gemma-target.gguf (SIMULATED)",
        assistant_name="gemma-assistant.gguf (SIMULATED)",
        assistant_verdict="WITH_MTP", assistant_gate_kind="assistant_model",
        target_resident=8_000_000_000, assistant_resident=1_000_000_000,
        target_kv=1_000_000_000, assistant_kv=0,
        target_scratch=100_000_000, assistant_scratch=50_000_000,
    ),
    # 7. SIMULATED Gemma fixture, standalone form.
    base(
        target_name="gemma-target.gguf (SIMULATED)",
        assistant_name="gemma-assistant.gguf (SIMULATED)",
        target_resident=8_000_000_000, assistant_resident=1_000_000_000,
        target_kv=1_000_000_000, assistant_kv=200_000_000,
        target_scratch=100_000_000, assistant_scratch=50_000_000,
    ),
]


def main():
    counts = {}
    for row in ROWS:
        reason, row = evaluate(row)
        counts[reason] = counts.get(reason, 0) + 1
        if reason == "ADMITTED":
            print(
                f"ADMITTED target={row['target_name']} "
                f"assistant={row['assistant_name']} route={row['route']} "
                f"share_per_mille={row['share_per_mille']} "
                f"budget_bytes={row['budget']} reserve_bytes={row['reserve']}"
            )
        else:
            print(
                f"REFUSED target={row['target_name']} "
                f"assistant={row['assistant_name']} reason={reason}"
                f" -- assistant pair not run"
            )
    admitted = counts.get("ADMITTED", 0)
    print(
        f"SUMMARY rows={len(ROWS)} admitted={admitted} "
        f"refuse_missing_file={counts.get('REFUSE_MISSING_FILE', 0)} "
        f"refuse_uncensused={counts.get('REFUSE_UNCENSUSED_FILE', 0)} "
        f"refuse_vocab_only={counts.get('REFUSE_VOCAB_ONLY', 0)} "
        f"refuse_family_mismatch={counts.get('REFUSE_FAMILY_MISMATCH', 0)} "
        f"refuse_not_smaller={counts.get('REFUSE_ASSISTANT_NOT_SMALLER', 0)}"
    )
    print(
        "NOTE admitted rows are the SIMULATED fixtures only; "
        "no real pair is admitted on any filed fact tonight"
    )


if __name__ == "__main__":
    main()
