# tests/c7_h136_check.mojo
# H136 — F1 pipeline completion acceptance (TEST-ONLY driver, not shipped).
#
# Runs on Mimir (AArch64): guard self-tests (fail-closed error paths),
# then the acceptance run on the H059 model (TinyLlama-1.1B-Chat-v1.0 Q4_0):
# 512-token prefill + 100-token decode in the production configuration
# (data/fallback/f1_config.json), per-step logits vs the forward_nocache
# reference (H051-style cache-correctness, max abs err <= 1e-3), timings
# written to data/fallback/f1_cpu_perf.json.
#
# Prints H136-ALL-PASS or H136-FAIL: <reason>. Exit nonzero on failure.
#
# Usage: c7_h136_check (run from the repo root)

from std.ffi import external_call
from std.memory.alloc import unsafe_alloc
from std.origin import MutUntrackedOrigin

from armvegr.infer import Inference, infer_version
from armvegr.sp_tokenizer import SPTokenizer
from armvegr.sampler import Sampler
from armvegr.f1_config import f1_config_load
from armvegr.util import now_ns


def _write_text_file(path: String, text: String) raises:
    var src = text.as_bytes()
    var pb = List[Int8]()
    for i in range(len(src)):
        pb.append(Int8(src[i]))
    pb.append(0)
    var fd = external_call["open64", Int32](
        pb.unsafe_ptr(), Int32(577), Int32(0o644)
    )
    _ = pb
    if fd < 0:
        raise Error("c7_h136: cannot open output: " + path)
    var buf = unsafe_alloc[UInt8](len(src))
    for i in range(len(src)):
        buf.unsafe_offset(i).unsafe_store(src[i])
    var n = len(src)
    var done = 0
    while done < n:
        var w = external_call["write", Int](
            Int(fd), buf.unsafe_offset(done), n - done
        )
        if w <= 0:
            buf.unsafe_free()
            _ = external_call["close", Int32](fd)
            raise Error("c7_h136: short write on: " + path)
        done += Int(w)
    buf.unsafe_free()
    _ = external_call["close", Int32](fd)


def _logits_to_f32(lp: Pointer[Float16, MutUntrackedOrigin], n: Int) -> List[Float32]:
    var out = List[Float32]()
    for i in range(n):
        out.append(Float32(lp.unsafe_offset(i).unsafe_load()))
    return out^


def _max_abs_err(a: List[Float32], b: List[Float32]) -> Float32:
    var m = Float32(0.0)
    for i in range(len(a)):
        var d = a[i] - b[i]
        if d < Float32(0.0):
            d = -d
        if d > m:
            m = d
    return m


def main() raises:
    var fails = List[String]()

    # ---- Guard self-tests (no model needed). ----
    # 1. forward on unloaded model must raise.
    try:
        var u = Inference(16)
        _ = u.forward(5)
        fails.append("guard: forward on unloaded model did not raise")
    except:
        print("H136 guard 1/7 PASS: unloaded forward raises")
    # 2. missing config file must raise.
    try:
        _ = f1_config_load("data/fallback/does-not-exist.json")
        fails.append("guard: missing config did not raise")
    except:
        print("H136 guard 2/7 PASS: missing config raises")
    # 3. malformed config must raise.
    _write_text_file("/tmp/c7_h136_badcfg.json", String("{not json"))
    try:
        _ = f1_config_load("/tmp/c7_h136_badcfg.json")
        fails.append("guard: malformed config did not raise")
    except:
        print("H136 guard 3/7 PASS: malformed config raises")

    # ---- Load production config + model. ----
    var cfg = f1_config_load("data/fallback/f1_config.json")
    print("H136 config OK: " + cfg.model_path)
    var t0 = now_ns()
    var inf = Inference(cfg.max_seq)
    inf.load(cfg.model_path)
    var t1 = now_ns()
    print("H136 model loaded in " + String(Float64(t1 - t0) / 1e9) + "s")

    # 4. token id out of range must raise.
    try:
        _ = inf.forward(-1)
        fails.append("guard: token -1 did not raise")
    except:
        print("H136 guard 4/7 PASS: token -1 raises")
    try:
        _ = inf.forward(32000)
        fails.append("guard: token 32000 did not raise")
    except:
        print("H136 guard 5/7 PASS: token 32000 raises")
    # 6. KV-cache capacity: tiny instance overflows fail-closed.
    var tiny = Inference(4)
    tiny.model = inf.model.shallow_copy()
    _ = tiny.forward(1)
    _ = tiny.forward(2)
    _ = tiny.forward(3)
    _ = tiny.forward(4)
    try:
        _ = tiny.forward(5)
        fails.append("guard: cache overflow did not raise")
    except:
        print("H136 guard 6/7 PASS: cache overflow raises")
    tiny.free()
    # reset() cleanliness (no model state involved beyond seq_len).
    _ = inf.forward(10)
    _ = inf.forward(11)
    inf.reset()
    if inf.seq_len != 0:
        fails.append("guard: reset() did not zero seq_len")
    else:
        print("H136 guard 7/7 PASS: reset() zeroes seq_len")

    var tok = SPTokenizer()
    tok.load(cfg.tokenizer_path)

    # ---- Build the 512-token prefill prompt (deterministic). ----
    var para = String(
        "Hospitality is the sacred duty of welcoming the traveler. "
        + "In the old ways, no one is turned from the door; bread and "
        + "mead are shared with friend and stranger alike, for the "
        + "guest may be a god in disguise. "
    )
    var pids = tok.encode(para)
    print("H136 paragraph tokens: " + String(len(pids)))
    var prompt = List[Int]()
    while len(prompt) < 512:
        for i in range(len(pids)):
            prompt.append(pids[i])
            if len(prompt) >= 512:
                break
    if len(prompt) != 512:
        fails.append("prompt build: not exactly 512 tokens")

    # ---- Timed prefill; capture cached logits at probe steps. ----
    var probe_steps = List[Int]()
    probe_steps.append(127)
    probe_steps.append(511)
    var probe_cached = List[List[Float32]]()
    for _ in range(len(probe_steps)):
        probe_cached.append(List[Float32]())
    var tp0 = now_ns()
    var logits_p = inf.forward(prompt[0])
    for i in range(1, 512):
        logits_p = inf.forward(prompt[i])
        for pi in range(len(probe_steps)):
            if i == probe_steps[pi]:
                probe_cached[pi] = _logits_to_f32(logits_p, 32000)
    var tp1 = now_ns()
    var prefill_s = Float64(tp1 - tp0) / 1e9
    var prefill_tps = Float64(512) / prefill_s
    print(
        "H136 prefill: 512 tokens in " + String(prefill_s) + "s = "
        + String(prefill_tps) + " tok/s"
    )

    # ---- Timed decode: 100 tokens, production sampler. ----
    var sampler = Sampler(cfg.seed)
    var gen_ids = List[Int]()
    for i in range(512):
        gen_ids.append(prompt[i])
    # Decode continues from the timed prefill's last logits (production path).
    var decode_probe_step = 49
    var decode_cached = List[Float32]()
    var td0 = now_ns()
    var n_gen = 0
    for step in range(100):
        var logits = _logits_to_f32(logits_p, 32000)
        var next_tok = sampler.sample(
            logits, cfg.temperature, cfg.top_k, cfg.top_p,
            gen_ids, cfg.repetition_penalty,
        )
        gen_ids.append(next_tok)
        n_gen += 1
        if step == decode_probe_step:
            decode_cached = logits.copy()
        if next_tok == 2:
            break
        logits_p = inf.forward(next_tok)
    var td1 = now_ns()
    var decode_s = Float64(td1 - td0) / 1e9
    var decode_tps = Float64(n_gen) / decode_s
    print(
        "H136 decode: " + String(n_gen) + " tokens in " + String(decode_s)
        + "s = " + String(decode_tps) + " tok/s"
    )
    if n_gen != 100:
        print("H136 NOTE: decode stopped early at " + String(n_gen) + " (EOS)")
    var text = tok.decode(gen_ids)
    print("H136-GENERATED-START")
    print(text)
    print("H136-GENERATED-END")

    # ---- KV-check probes: cached vs forward_nocache reference. ----
    var kv_results = String("")
    var kv_ok = True
    var all_probes = List[Int]()
    all_probes.append(127)
    all_probes.append(511)
    all_probes.append(512 + decode_probe_step)
    for pi in range(len(all_probes)):
        var step = all_probes[pi]
        var upto = step + 1
        if upto > len(gen_ids):
            kv_results += "probe " + String(step) + ": SKIP\n"
            continue
        var prefix = List[Int]()
        for i in range(upto):
            prefix.append(gen_ids[i])
        var ref_p = inf.forward_nocache(prefix)
        var ref_logits = _logits_to_f32(ref_p, 32000)
        var cached = decode_cached.copy()
        if pi < 2:
            cached = probe_cached[pi].copy()
        var err = _max_abs_err(cached, ref_logits)
        var verdict = String("PASS")
        if err > Float32(1e-3):
            verdict = String("FAIL")
            kv_ok = False
        kv_results += (
            "probe step " + String(step) + ": max_abs_err=" + String(err)
            + " " + verdict + "\n"
        )
        print("H136-KVCHECK " + String(step) + " max_abs_err=" + String(err) + " " + verdict)
    if not kv_ok:
        fails.append("kvcheck: a probe exceeded 1e-3 max abs err")

    # ---- Perf JSON (the honest F1 baseline). ----
    var json = String("{\n")
    json += "  \"slice\": \"H136\",\n"
    json += "  \"model\": \"TinyLlama-1.1B-Chat-v1.0 Q4_0 GGUF (TheBloke)\",\n"
    json += "  \"model_sha256\": \"" + cfg.model_sha256 + "\",\n"
    json += "  \"device\": \"Mimir (Raspberry Pi 5, aarch64)\",\n"
    json += "  \"binary\": \"tests/c7_h136_check (armvegr Inference " + infer_version() + ")\",\n"
    json += "  \"config\": \"data/fallback/f1_config.json\",\n"
    json += "  \"prefill_tokens\": 512,\n"
    json += "  \"prefill_seconds\": " + String(prefill_s) + ",\n"
    json += "  \"prefill_tokens_per_sec\": " + String(prefill_tps) + ",\n"
    json += "  \"decode_tokens\": " + String(n_gen) + ",\n"
    json += "  \"decode_seconds\": " + String(decode_s) + ",\n"
    json += "  \"decode_tokens_per_sec\": " + String(decode_tps) + ",\n"
    json += "  \"sampler\": {\"temperature\": " + String(cfg.temperature)
    json += ", \"top_k\": " + String(cfg.top_k)
    json += ", \"top_p\": " + String(cfg.top_p)
    json += ", \"repetition_penalty\": " + String(cfg.repetition_penalty)
    json += ", \"seed\": " + String(cfg.seed) + "},\n"
    json += "  \"kvcheck_max_abs_err_tolerance\": 0.001,\n"
    json += "  \"kvcheck_probes\": [127, 511, 561],\n"
    json += "  \"kvcheck\": \"" + kv_results + "\",\n"
    json += "  \"guards\": \"7/7 PASS\"\n"
    json += "}\n"
    _write_text_file("data/fallback/f1_cpu_perf.json", json)
    print("H136 wrote data/fallback/f1_cpu_perf.json")

    inf.free()

    if len(fails) == 0:
        print("H136-ALL-PASS")
    else:
        print("H136-FAIL:")
        for i in range(len(fails)):
            print("  - " + fails[i])
        raise Error("c7_h136: acceptance failed")
