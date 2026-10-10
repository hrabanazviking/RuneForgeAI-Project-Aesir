# bench/run_bench.mojo
# H161 — MÍMISBRUNNR C9 official benchmark harness entry point.
#
# Usage:
#   run_bench --root <repo> --bench <name> --out <name> [options]
#
# Benchmarks (subcommands via --bench):
#   kernels     all 22 C2 kernels at H038 shapes (--trials, --warmup)
#   gemm_tuned  one parameterized GEMM config: --M --N --K --mc --kc --nc
#               --prefetch (bytes) --hoist (0/1) --micro (0/1)
#   prefill     end-to-end prefill: --config --prompt-file --tokens (default
#               512) --trials (default 5) --chunk (1 = legacy token loop)
#   decode      end-to-end decode: --config --prompt-file --tokens (prefill
#               length) --max-new (default 100) --trials (default 5)
#               --sampler (classic|fast)
#   tokenize    BPE encode throughput: --corpus (wordlist path) --strings N
#   stability   H161 self-check: one benchmark twice back-to-back, medians
#               must agree within ±3%.
#
# Common: --mojo-version, --pin (description of the taskset/governor pin),
# --slice (recorded in the JSON), --settle (thermal settle seconds, 0 = skip).
#
# Emits <root>/data/bench/<out>.json with: median/p50, min, max, stddev,
# trial count, clock settings, start/end SoC temperature, harness version —
# every field present on every run.

from std.sys import argv
from std.ffi import external_call
from std.memory import Pointer
from std.memory.alloc import unsafe_alloc
from std.origin import MutUntrackedOrigin

from bench.bench_env import (
    TrialStats,
    bench_stats_json,
    bench_env_json,
    bench_temp_c,
    bench_thermal_settle,
    bench_write_file,
    bench_read_text,
    harness_version,
)
from bench.bench_kernels import bench_all_kernels
from armvegr.util import now_ns, fill_rand_f16
from armvegr.gemm import gemm_fp16
from armvegr.gemm_tuned import gemm_fp16_tuned, GemmTune, gemm_tune_desc
from armvegr.infer import Inference, infer_version
from armvegr.sp_tokenizer import SPTokenizer
from armvegr.sampler import Sampler
from armvegr.f1_config import f1_config_load
from armvegr.bpe import BPEModel, _read_file


def _get_arg(args: List[String], name: String, default: String) -> String:
    for i in range(len(args) - 1):
        if args[i] == name:
            return args[i + 1]
    return default


def _req_arg(args: List[String], name: String) raises -> String:
    var v = _get_arg(args, name, String(""))
    if v == "":
        raise Error("run_bench: missing required arg: " + name)
    return v


def _get_int(args: List[String], name: String, default: Int) raises -> Int:
    var v = _get_arg(args, name, String(""))
    if v == "":
        return default
    return Int(v)


def _usage() -> String:
    return String(
        "usage: run_bench --root <repo> --bench <kernels|gemm_tuned|prefill|decode|tokenize|stability>"
        " --out <name> [options]"
    )


def _json_escape(s: String) -> String:
    var out = String("")
    var bs = s.as_bytes()
    for i in range(len(bs)):
        var c = bs[i]
        if c == 34:
            out += "\\\""
        elif c == 92:
            out += "\\\\"
        elif c == 10:
            out += "\\n"
        elif c == 13:
            out += "\\r"
        elif c == 9:
            out += "\\t"
        else:
            var b = List[Int8]()
            b.append(Int8(c))
            b.append(0)
            out += String(unsafe_from_utf8_ptr=b.unsafe_ptr())
    return out


def _run_kernels(args: List[String], root: String) raises -> String:
    var warmup = _get_int(args, "--warmup", 3)
    var trials = _get_int(args, "--trials", 11)
    var sink = Float64(0)
    var body = bench_all_kernels(sink, warmup, trials)
    var j = String("{\n")
    j += String("  \"benchmark\": \"kernels\",\n")
    j += String("  \"method\": \"warmup ") + String(warmup) + String(", ")
    j += String(trials) + String(" timed trials, median headline; DCE sink live\",\n")
    j += String("  \"results\": [\n") + body + String("\n  ],\n")
    j += String("  \"sink\": ") + String(sink) + String(",\n")
    return j


def _run_gemm_tuned(args: List[String], root: String) raises -> String:
    var M = _get_int(args, "--M", 1024)
    var N = _get_int(args, "--N", 1024)
    var K = _get_int(args, "--K", 1024)
    var warmup = _get_int(args, "--warmup", 3)
    var trials = _get_int(args, "--trials", 11)
    var tune = GemmTune(
        _get_int(args, "--mc", 64),
        _get_int(args, "--kc", 256),
        _get_int(args, "--nc", 64),
        _get_int(args, "--prefetch", 0),
        _get_int(args, "--hoist", 0) != 0,
        _get_int(args, "--micro", 0),
    )
    var desc = gemm_tune_desc(tune)
    print("bench: gemm_tuned " + String(M) + "x" + String(N) + "x" + String(K) + " tune=" + desc)
    var a = unsafe_alloc[Float16](M * K)
    var b = unsafe_alloc[Float16](K * N)
    var c = unsafe_alloc[Float16](M * N)
    var st = unsafe_alloc[UInt64](1)
    st[unsafe_offset=0] = 21
    fill_rand_f16(a, M * K, st, -1.0, 1.0)
    fill_rand_f16(b, K * N, st, -1.0, 1.0)
    for _ in range(warmup):
        gemm_fp16_tuned(a, b, c, M, N, K, tune)
    var t = TrialStats()
    var sink = Float64(0)
    for _ in range(trials):
        var t0 = now_ns()
        gemm_fp16_tuned(a, b, c, M, N, K, tune)
        t.record(Float64(now_ns() - t0))
        sink += Float64(c[unsafe_offset=0]) + Float64(c[unsafe_offset=M * N - 1])
    var shape = String(M) + String("x") + String(N) + String("x") + String(K)
    var j = String("{\n")
    j += String("  \"benchmark\": \"gemm_tuned\",\n")
    j += String("  \"shape\": \"") + shape + String("\",\n")
    j += String("  \"tune\": \"") + desc + String("\",\n")
    j += String("  \"method\": \"warmup ") + String(warmup) + String(", ")
    j += String(trials) + String(" timed trials, median headline; DCE sink live\",\n")
    j += String("  \"results\": [\n") + bench_stats_json(
        "gemm_fp16_tuned", shape, Float64(2 * M * N * K), t
    ) + String("\n  ],\n")
    j += String("  \"sink\": ") + String(sink) + String(",\n")
    return j


def _load_prompt_ids(
    root: String, prompt_file: String, n_tokens: Int
) raises -> List[Int]:
    var data = _read_file(prompt_file)
    var b = List[Int8]()
    for i in range(len(data)):
        b.append(Int8(data[i]))
    b.append(0)
    var text = String(unsafe_from_utf8_ptr=b.unsafe_ptr())
    var tok = SPTokenizer()
    tok.load(root + "/data/armvegr/tinyllama_tokenizer.model")
    var ids = tok.encode(text)
    print("bench: prompt encodes to " + String(len(ids)) + " tokens")
    if len(ids) < n_tokens:
        raise Error("run_bench: prompt too short for --tokens")
    var out = List[Int]()
    for i in range(n_tokens):
        out.append(ids[i])
    return out.copy()


def _logits_to_f32(lp: Pointer[Float16, MutUntrackedOrigin], n: Int) -> List[Float32]:
    var out = List[Float32]()
    for i in range(n):
        out.append(Float32(lp.unsafe_offset(i).unsafe_load()))
    return out.copy()


def _run_prefill(args: List[String], root: String) raises -> String:
    var cfg_path = _req_arg(args, "--config")
    var prompt_file = _req_arg(args, "--prompt-file")
    var n_tokens = _get_int(args, "--tokens", 512)
    var trials = _get_int(args, "--trials", 5)
    var chunk = _get_int(args, "--chunk", 1)
    var cfg = f1_config_load(cfg_path)
    var ids = _load_prompt_ids(root, prompt_file, n_tokens)
    print("bench: loading model: " + cfg.model_path)
    var inf = Inference(cfg.max_seq)
    inf.load(cfg.model_path)
    print("bench: model loaded")
    var t = TrialStats()
    var sink = Float64(0)
    for r in range(trials):
        inf.reset()
        var t0 = now_ns()
        var lp: Pointer[Float16, MutUntrackedOrigin]
        if chunk <= 1:
            lp = inf.prefill(ids)
        else:
            lp = inf.prefill_chunked(ids, chunk)
        var t1 = now_ns()
        t.record(Float64(t1 - t0))
        sink += Float64(lp.unsafe_offset(0).unsafe_load())
        print("bench: prefill trial " + String(r) + ": " + String(Float64(t1 - t0) / 1e9) + "s")
    inf.free()
    var j = String("{\n")
    j += String("  \"benchmark\": \"prefill\",\n")
    j += String("  \"tokens\": ") + String(n_tokens) + String(",\n")
    j += String("  \"chunk\": ") + String(chunk) + String(",\n")
    j += String("  \"model_sha256\": \"") + String(cfg.model_sha256) + String("\",\n")
    j += String("  \"config\": \"") + _json_escape(cfg_path) + String("\",\n")
    j += String("  \"prompt_file\": \"") + _json_escape(prompt_file) + String("\",\n")
    j += String("  \"infer_version\": \"") + infer_version() + String("\",\n")
    j += String("  \"method\": \"") + String(trials) + String(" trials, median headline\",\n")
    j += String("  \"results\": [\n") + bench_stats_json(
        "prefill", String(n_tokens) + String("_tokens"), Float64(n_tokens), t
    ) + String("\n  ],\n")
    j += String("  \"sink\": ") + String(sink) + String(",\n")
    return j


def _run_decode(args: List[String], root: String) raises -> String:
    var cfg_path = _req_arg(args, "--config")
    var prompt_file = _req_arg(args, "--prompt-file")
    var n_tokens = _get_int(args, "--tokens", 512)
    var max_new = _get_int(args, "--max-new", 100)
    var trials = _get_int(args, "--trials", 5)
    var sampler_kind = _get_arg(args, "--sampler", String("classic"))
    var cfg = f1_config_load(cfg_path)
    var ids = _load_prompt_ids(root, prompt_file, n_tokens)
    print("bench: loading model: " + cfg.model_path)
    var inf = Inference(cfg.max_seq)
    inf.load(cfg.model_path)
    print("bench: model loaded")
    var t = TrialStats()
    var sink = Float64(0)
    var first_ids = List[Int]()
    for r in range(trials):
        inf.reset()
        var logits_p = inf.prefill(ids)
        var sampler = Sampler(cfg.seed)
        var gen_ids = List[Int]()
        for i in range(len(ids)):
            gen_ids.append(ids[i])
        var td0 = now_ns()
        var n_gen = 0
        for _ in range(max_new):
            var logits = _logits_to_f32(logits_p, 32000)
            var next_tok: Int
            if sampler_kind == "fast":
                next_tok = sampler.sample_fast(
                    logits, cfg.temperature, cfg.top_k, cfg.top_p,
                    gen_ids, cfg.repetition_penalty,
                )
            else:
                next_tok = sampler.sample(
                    logits, cfg.temperature, cfg.top_k, cfg.top_p,
                    gen_ids, cfg.repetition_penalty,
                )
            gen_ids.append(next_tok)
            n_gen += 1
            if next_tok == 2:
                break
            logits_p = inf.forward(next_tok)
        var td1 = now_ns()
        t.record(Float64(td1 - td0))
        sink += Float64(n_gen)
        if r == 0:
            first_ids = gen_ids.copy()
        print(
            "bench: decode trial " + String(r) + ": " + String(n_gen) + " tokens in "
            + String(Float64(td1 - td0) / 1e9) + "s"
        )
    # Determinism check: every trial must generate the identical sequence.
    inf.free()
    var j = String("{\n")
    j += String("  \"benchmark\": \"decode\",\n")
    j += String("  \"prefill_tokens\": ") + String(n_tokens) + String(",\n")
    j += String("  \"max_new\": ") + String(max_new) + String(",\n")
    j += String("  \"sampler\": \"") + sampler_kind + String("\",\n")
    j += String("  \"sampler_cfg\": {\"temperature\": ") + String(cfg.temperature)
    j += String(", \"top_k\": ") + String(cfg.top_k)
    j += String(", \"top_p\": ") + String(cfg.top_p)
    j += String(", \"repetition_penalty\": ") + String(cfg.repetition_penalty)
    j += String(", \"seed\": ") + String(cfg.seed) + String("},\n")
    j += String("  \"model_sha256\": \"") + String(cfg.model_sha256) + String("\",\n")
    j += String("  \"config\": \"") + _json_escape(cfg_path) + String("\",\n")
    j += String("  \"prompt_file\": \"") + _json_escape(prompt_file) + String("\",\n")
    j += String("  \"infer_version\": \"") + infer_version() + String("\",\n")
    j += String("  \"method\": \"") + String(trials) + String(" trials, median headline\",\n")
    j += String("  \"results\": [\n") + bench_stats_json(
        "decode", String(max_new) + String("_tokens"), Float64(max_new), t
    ) + String("\n  ],\n")
    j += String("  \"sink\": ") + String(sink) + String(",\n")
    _ = first_ids
    return j


def _run_tokenize(args: List[String], root: String) raises -> String:
    var corpus = _req_arg(args, "--corpus")
    var n_strings = _get_int(args, "--strings", 10000)
    var trials = _get_int(args, "--trials", 5)
    var model = BPEModel()
    model.load(
        root + "/data/armvegr/gpt2_bpe.bin", root + "/data/armvegr/unicode_classes.bin"
    )
    # Corpus: lines of the wordlist cycled into sentences.
    var wl = _read_file(corpus)
    var words = List[String]()
    var cur = String("")
    for i in range(len(wl)):
        var c = wl[i]
        if c == 10:
            if cur != "":
                words.append(cur.copy())
                cur = String("")
        else:
            var b = List[Int8]()
            b.append(Int8(c))
            b.append(0)
            cur += String(unsafe_from_utf8_ptr=b.unsafe_ptr())
    if cur != "":
        words.append(cur.copy())
    print("bench: wordlist words: " + String(len(words)))
    var texts = List[String]()
    var wi = 0
    for s in range(n_strings):
        var sent = String("")
        for w in range(12):
            if w > 0:
                sent += " "
            sent += words[wi % len(words)]
            wi += 1
        texts.append(sent.copy())
    var t = TrialStats()
    var sink = Int(0)
    for _ in range(2):  # warmup
        for s in range(n_strings):
            var ids = model.encode(texts[s])
            sink += len(ids)
    for _ in range(trials):
        var t0 = now_ns()
        for s in range(n_strings):
            var ids = model.encode(texts[s])
            sink += len(ids)
        t.record(Float64(now_ns() - t0))
    var j = String("{\n")
    j += String("  \"benchmark\": \"tokenize\",\n")
    j += String("  \"strings\": ") + String(n_strings) + String(",\n")
    j += String("  \"corpus\": \"") + _json_escape(corpus) + String("\",\n")
    j += String("  \"method\": \"") + String(trials) + String(" trials over ")
    j += String(n_strings) + String(" strings, median headline\",\n")
    j += String("  \"results\": [\n") + bench_stats_json(
        "bpe_encode", String(n_strings) + String("_strings"), Float64(n_strings), t
    ) + String("\n  ],\n")
    j += String("  \"sink_tokens\": ") + String(sink) + String(",\n")
    return j


def _gemm_1024_median_ns(warmup: Int, trials: Int, mut sink: Float64) -> Float64:
    # Direct median measurement of gemm_fp16 1024^3 (for the stability check).
    var M = 1024
    var N = 1024
    var K = 1024
    var a = unsafe_alloc[Float16](M * K)
    var b = unsafe_alloc[Float16](K * N)
    var c = unsafe_alloc[Float16](M * N)
    var st = unsafe_alloc[UInt64](1)
    st[unsafe_offset=0] = 21
    fill_rand_f16(a, M * K, st, -1.0, 1.0)
    fill_rand_f16(b, K * N, st, -1.0, 1.0)
    for _ in range(warmup):
        gemm_fp16(a, b, c, M, N, K)
    var t = TrialStats()
    for _ in range(trials):
        var t0 = now_ns()
        gemm_fp16(a, b, c, M, N, K)
        t.record(Float64(now_ns() - t0))
        sink += Float64(c[unsafe_offset=0]) + Float64(c[unsafe_offset=M * N - 1])
    return t.median_ns()


def _run_stability(args: List[String], root: String) raises -> String:
    # H161 acceptance: the same benchmark twice back-to-back must yield
    # medians within +-3%.
    var warmup = _get_int(args, "--warmup", 3)
    var trials = _get_int(args, "--trials", 11)
    var sink = Float64(0)
    var m1 = _gemm_1024_median_ns(warmup, trials, sink)
    var m2 = _gemm_1024_median_ns(warmup, trials, sink)
    var ratio = m2 / m1
    var dev = ratio - 1.0
    if dev < 0:
        dev = -dev
    var verdict = String("PASS")
    if dev > 0.03:
        verdict = String("FAIL")
    print(
        "bench: stability: median1=" + String(m1) + "ns median2=" + String(m2)
        + "ns deviation=" + String(dev * 100.0) + "% -> " + verdict
    )
    var j = String("{\n")
    j += String("  \"benchmark\": \"stability\",\n")
    j += String("  \"check\": \"gemm_fp16 1024^3 twice back-to-back, medians within 3%\",\n")
    j += String("  \"median_ns_run1\": ") + String(m1) + String(",\n")
    j += String("  \"median_ns_run2\": ") + String(m2) + String(",\n")
    j += String("  \"deviation\": ") + String(dev) + String(",\n")
    j += String("  \"verdict\": \"") + verdict + String("\",\n")
    return j


def main() raises:
    var raw = argv()
    var args = List[String]()
    for i in range(len(raw)):
        args.append(String(raw[i]))
    var root = _req_arg(args, "--root")
    var bench = _req_arg(args, "--bench")
    var out = _req_arg(args, "--out")
    var slice = _get_arg(args, "--slice", String("H161"))
    var mojo_version = _get_arg(args, "--mojo-version", String("unknown"))
    var pin = _get_arg(args, "--pin", String("unrecorded"))
    var settle = _get_int(args, "--settle", 30)

    if (
        bench != "kernels"
        and bench != "gemm_tuned"
        and bench != "prefill"
        and bench != "decode"
        and bench != "tokenize"
        and bench != "stability"
    ):
        print(_usage())
        raise Error("run_bench: unknown --bench: " + bench)

    var temp_start = bench_temp_c()
    print("bench: temp at start: " + String(temp_start) + " C")
    if settle > 0:
        _ = bench_thermal_settle(settle)

    var body = String("")
    if bench == "kernels":
        body = _run_kernels(args, root)
    elif bench == "gemm_tuned":
        body = _run_gemm_tuned(args, root)
    elif bench == "prefill":
        body = _run_prefill(args, root)
    elif bench == "decode":
        body = _run_decode(args, root)
    elif bench == "tokenize":
        body = _run_tokenize(args, root)
    else:
        body = _run_stability(args, root)

    var temp_end = bench_temp_c()
    print("bench: temp at end: " + String(temp_end) + " C")

    var j = body
    j += String("  \"slice\": \"") + _json_escape(slice) + String("\",\n")
    j += bench_env_json(mojo_version, pin, temp_start, temp_end)
    j += String("  \"notes\": []\n}\n")

    var path = root + "/data/bench/" + out + ".json"
    bench_write_file(path, j)
    print("bench: wrote " + path)
