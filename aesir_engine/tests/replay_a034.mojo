# tests/replay_a034.mojo
# A-034: Deterministic replay battery (standalone, NOT part of run_all;
# the run_all pin stays 362). Standard battery on the CPU path, RAW
# prompt only (no chat template is ever applied by this facade -- the
# A-004/A-030 oracle ids below were pinned against llama.cpp on the
# raw prompt):
#   GREEDY  temp 0.0, 32 tokens -- must equal the pinned A-004 oracle.
#   SEEDED  temp 0.8 / top_k 40 / top_p 0.95 / seed 1234, run TWICE on
#           two fresh engine instances -- token streams and FNV-1a
#           hashes must be identical.
#   ALTSEED same config, seed 999 -- stream must DIFFER (proves the
#           seed is live: before A-034 GenerationConfig.seed never
#           reached the sampler and every pass re-seeded RuneRNG(42)).
# The driver (hidden_files/run_a034.sh) also runs this binary twice
# as separate processes and diffs the full output + filed hashes.

from std.sys import argv

from aesir import AesirEngine, GenerationConfig


def fnv1a_hex(tokens: List[Int]) -> String:
    var h: UInt64 = 14695981039346656037
    for t in range(len(tokens)):
        var v = UInt64(tokens[t])
        for _ in range(8):
            h = (h ^ (v & 255)) * 1099511628211
            v >>= 8
    var digits = String("0123456789abcdef")
    var out = String("")
    for shift in range(15, -1, -1):
        out += digits[byte=Int((h >> UInt64(shift * 4)) & 15)]
    return out^


def csv(tokens: List[Int]) -> String:
    var out = String("")
    for i in range(len(tokens)):
        if i > 0:
            out += String(",")
        out += String(tokens[i])
    return out^


def oracle() -> List[Int]:
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


def seeded_config(seed: UInt64) -> GenerationConfig:
    return GenerationConfig(
        max_new_tokens=32,
        temperature=Float32(0.8),
        top_k=40,
        top_p=Float32(0.95),
        repetition_penalty=Float32(1.0),
        seed=seed,
    )


def main() raises:
    var arguments = argv()
    if len(arguments) != 2:
        raise Error("usage: replay_a034 <model.gguf>")
    var path = arguments[1]
    var prompt = String("One day, Timmy went to")

    # --- GREEDY: raw-oracle anchor (CPU engine vs pinned oracle) ---
    var engine_g = AesirEngine(path, knowledge_capacity=1)
    var greedy = engine_g.generate_tokens_config(
        prompt,
        GenerationConfig(
            max_new_tokens=32, temperature=Float32(0.0),
            repetition_penalty=Float32(1.0),
        ),
    )
    var want = oracle()
    if greedy.generated_token_count() != 32:
        raise Error("A034: greedy run did not produce 32 tokens")
    for i in range(32):
        if greedy.token_ids[i] != want[i]:
            raise Error("A034: greedy token differs from A-004 oracle")
    print("A034_GREEDY_TOKENS", csv(greedy.token_ids))
    print("A034_GREEDY_HASH", fnv1a_hex(greedy.token_ids))

    # --- SEEDED: two fresh instances, same seed -> identical ---
    var engine_a = AesirEngine(path, knowledge_capacity=1)
    var run_a = engine_a.generate_tokens_config(prompt, seeded_config(1234))
    var engine_b = AesirEngine(path, knowledge_capacity=1)
    var run_b = engine_b.generate_tokens_config(prompt, seeded_config(1234))
    if run_a.generated_token_count() != run_b.generated_token_count():
        raise Error("A034: seeded replay token count differs")
    for i in range(run_a.generated_token_count()):
        if run_a.token_ids[i] != run_b.token_ids[i]:
            raise Error("A034: seeded replay token stream differs")
    print("A034_SEEDED_TOKENS", csv(run_a.token_ids))
    print("A034_SEEDED_HASH", fnv1a_hex(run_a.token_ids))

    # --- ALT SEED: different seed -> different stream (seed is live) ---
    var engine_c = AesirEngine(path, knowledge_capacity=1)
    var run_c = engine_c.generate_tokens_config(prompt, seeded_config(999))
    var differs = run_c.generated_token_count() != run_a.generated_token_count()
    if not differs:
        for i in range(run_a.generated_token_count()):
            if run_c.token_ids[i] != run_a.token_ids[i]:
                differs = True
                break
    if not differs:
        raise Error("A034: alternate seed produced the identical stream -- seed is dead")
    print("A034_ALTSEED_TOKENS", csv(run_c.token_ids))
    print("A034_ALTSEED_HASH", fnv1a_hex(run_c.token_ids))
    print("A034_REPLAY: PASS")
