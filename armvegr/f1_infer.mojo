# armvegr/f1_infer.mojo
# H136 — F1 production inference CLI (Domain D1 ARMVEGR, pure Mojo).
#
# The shippable CPU inference binary: loads data/fallback/f1_config.json
# (the production configuration surface), runs prefill + decode on the
# ARMVEGR CPU path, and emits machine-readable JSON. This exact binary and
# config are what H138's coherence proof runs.
#
# Usage:
#   f1_infer --config <json> [--prompt-file <path> | --prompt <text>]
#            [--max-new-tokens N] [--seed S] [--out <json>] [--kvcheck]
# --kvcheck runs the H051-style cache-correctness probes (forward_nocache
# vs cached per-step logits, max abs err <= 1e-3) at prefill positions
# 127/511 and decode step 49.

from std.sys import argv
from std.ffi import external_call
from std.memory.alloc import unsafe_alloc
from std.origin import MutUntrackedOrigin

from armvegr.infer import Inference, infer_version
from armvegr.sp_tokenizer import SPTokenizer
from armvegr.sampler import Sampler
from armvegr.f1_config import f1_config_load, F1Config
from armvegr.bpe import _read_file
from armvegr.util import now_ns


def _usage() -> String:
    return String(
        "usage: f1_infer --config <json> [--prompt-file <path> | --prompt <text>]"
        " [--max-new-tokens N] [--seed S] [--out <json>] [--kvcheck]"
    )


def _is_dashdash(s: String) -> Bool:
    var b = s.as_bytes()
    return len(b) >= 2 and b[0] == 45 and b[1] == 45


def _get_arg(args: List[String], name: String) raises -> String:
    for i in range(len(args) - 1):
        if args[i] == name:
            return args[i + 1]
    raise Error("f1_infer: missing required arg: " + name)


def _has_flag(args: List[String], name: String) -> Bool:
    for i in range(len(args)):
        if args[i] == name:
            return True
    return False


def _get_opt(args: List[String], name: String, default: String) -> String:
    for i in range(len(args) - 1):
        if args[i] == name:
            return args[i + 1]
    return default


def _hexchar(v: Int) -> String:
    if v < 10:
        return String(v)
    var b = List[Int8]()
    b.append(Int8(97 + v - 10))  # 'a' + (v - 10)
    b.append(0)
    return String(unsafe_from_utf8_ptr=b.unsafe_ptr())


def _hex2(c: UInt8) -> String:
    return _hexchar(Int(c) // 16) + _hexchar(Int(c) % 16)


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
        elif c < 32:
            out += "\\u00" + _hex2(c)
        else:
            var b = List[Int8]()
            b.append(Int8(c))
            b.append(0)
            out += String(unsafe_from_utf8_ptr=b.unsafe_ptr())
    return out


def _write_text_file(path: String, text: String) raises:
    var src = text.as_bytes()
    var pb = List[Int8]()
    for i in range(len(src)):
        pb.append(Int8(src[i]))
    pb.append(0)
    # O_WRONLY|O_CREAT|O_TRUNC = 577.
    var fd = external_call["open64", Int32](
        pb.unsafe_ptr(), Int32(577), Int32(0o644)
    )
    _ = pb
    if fd < 0:
        raise Error("f1_infer: cannot open output: " + path)
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
            raise Error("f1_infer: short write on: " + path)
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
    var raw_args = argv()
    var args = List[String]()
    for i in range(len(raw_args)):
        args.append(String(raw_args[i]))
    # Validate flags fail-closed: every -- token must be known.
    for i in range(1, len(args)):
        var a = args[i]
        if _is_dashdash(a):
            if (
                a != "--config"
                and a != "--prompt-file"
                and a != "--prompt"
                and a != "--max-new-tokens"
                and a != "--seed"
                and a != "--out"
                and a != "--kvcheck"
            ):
                print(_usage())
                raise Error("f1_infer: unknown flag: " + a)
    var cfg_path = _get_arg(args, "--config")
    var cfg = f1_config_load(cfg_path)

    var max_new = cfg.max_new_tokens
    var mnt_cli = _get_opt(args, "--max-new-tokens", String(""))
    if mnt_cli != "":
        max_new = Int(mnt_cli)
        if max_new <= 0 or max_new > cfg.max_seq:
            raise Error("f1_infer: --max-new-tokens out of range")
    var seed_cli = _get_opt(args, "--seed", String(""))
    var seed = cfg.seed
    if seed_cli != "":
        var si = Int(seed_cli)
        if si < 0:
            raise Error("f1_infer: --seed must be >= 0")
        seed = UInt64(si)

    var prompt_text = String("")
    if _has_flag(args, "--prompt-file"):
        var ppath = _get_arg(args, "--prompt-file")
        var pdata = _read_file(ppath)
        var b = List[Int8]()
        for i in range(len(pdata)):
            b.append(Int8(pdata[i]))
        b.append(0)
        prompt_text = String(unsafe_from_utf8_ptr=b.unsafe_ptr())
    elif _has_flag(args, "--prompt"):
        prompt_text = _get_arg(args, "--prompt")
    else:
        print(_usage())
        raise Error("f1_infer: need --prompt-file or --prompt")
    if prompt_text == "":
        raise Error("f1_infer: empty prompt")

    print("F1 loading model: " + cfg.model_path)
    var t0 = now_ns()
    var inf = Inference(cfg.max_seq)
    inf.load(cfg.model_path)
    var t1 = now_ns()
    print("F1 model loaded in " + String(Float64(t1 - t0) / 1e9) + "s")

    var tok = SPTokenizer()
    tok.load(cfg.tokenizer_path)
    var ids = tok.encode(prompt_text)
    print("F1 prompt tokens: " + String(len(ids)))
    if len(ids) == 0:
        raise Error("f1_infer: prompt encodes to zero tokens")
    if len(ids) + max_new > cfg.max_seq:
        raise Error(
            "f1_infer: prompt + max_new_tokens exceeds max_seq "
            + String(cfg.max_seq)
        )

    # Prefill (timed); keep the last step's logits for decode.
    var tp0 = now_ns()
    var logits_p = inf.forward(ids[0])
    for i in range(1, len(ids)):
        logits_p = inf.forward(ids[i])
    var tp1 = now_ns()
    var prefill_s = Float64(tp1 - tp0) / 1e9
    var prefill_tps = Float64(len(ids)) / prefill_s
    print(
        "F1 prefill: " + String(len(ids)) + " tokens in "
        + String(prefill_s) + "s = " + String(prefill_tps) + " tok/s"
    )

    # Decode (timed) with the production sampler.
    var sampler = Sampler(seed)
    var gen_ids = List[Int]()
    for i in range(len(ids)):
        gen_ids.append(ids[i])
    var td0 = now_ns()
    var n_gen = 0
    for step in range(max_new):
        var logits = _logits_to_f32(logits_p, 32000)
        var next_tok = sampler.sample(
            logits, cfg.temperature, cfg.top_k, cfg.top_p,
            gen_ids, cfg.repetition_penalty,
        )
        gen_ids.append(next_tok)
        n_gen += 1
        if next_tok == 2:  # EOS
            break
        logits_p = inf.forward(next_tok)
    var td1 = now_ns()
    var decode_s = Float64(td1 - td0) / 1e9
    var decode_tps = Float64(n_gen) / decode_s
    print(
        "F1 decode: " + String(n_gen) + " tokens in "
        + String(decode_s) + "s = " + String(decode_tps) + " tok/s"
    )

    var text = tok.decode(gen_ids)
    print("F1-GENERATED-START")
    print(text)
    print("F1-GENERATED-END")

    # KV-check (optional): compare cached per-step logits against the
    # cache-free reference at probe steps.
    var kv_lines = String("")
    if _has_flag(args, "--kvcheck"):
        print("F1 kvcheck: running forward_nocache probes...")
        var probes = List[Int]()
        probes.append(127)
        probes.append(511)
        probes.append(512 + 49)  # decode step 49 (0-indexed overall step)
        for pi in range(len(probes)):
            var upto = probes[pi] + 1  # prefix length
            if upto > len(gen_ids):
                kv_lines += (
                    "probe " + String(probes[pi]) + ": SKIP (beyond generated)\n"
                )
                continue
            # Cached logits: fresh scratch instance, incremental run,
            # capture logits at the probe step.
            var ci = Inference(cfg.max_seq)
            ci.model = inf.model.shallow_copy()
            var cached = List[Float32]()
            for i in range(upto):
                var clp = ci.forward(gen_ids[i])
                if i == upto - 1:
                    cached = _logits_to_f32(clp, 32000)
            var prefix = List[Int]()
            for i in range(upto):
                prefix.append(gen_ids[i])
            var ref_p = inf.forward_nocache(prefix)
            var ref = _logits_to_f32(ref_p, 32000)
            var err = _max_abs_err(cached, ref)
            var ok = String("PASS")
            if err > Float32(1e-3):
                ok = String("FAIL")
            var line = (
                "probe step " + String(probes[pi]) + ": max_abs_err="
                + String(err) + " " + ok + "\n"
            )
            kv_lines += line
            print("F1-KVCHECK " + line)
            ci.free()
        print("F1 kvcheck done")

    var json = String("{\n")
    json += "  \"binary\": \"f1_infer\",\n"
    json += "  \"infer_version\": \"" + infer_version() + "\",\n"
    json += "  \"config_path\": \"" + _json_escape(cfg_path) + "\",\n"
    json += "  \"model_path\": \"" + _json_escape(cfg.model_path) + "\",\n"
    json += "  \"sampler\": {\"temperature\": " + String(cfg.temperature)
    json += ", \"top_k\": " + String(cfg.top_k)
    json += ", \"top_p\": " + String(cfg.top_p)
    json += ", \"repetition_penalty\": " + String(cfg.repetition_penalty)
    json += ", \"seed\": " + String(seed) + "},\n"
    json += "  \"prompt_tokens\": " + String(len(ids)) + ",\n"
    json += "  \"generated_tokens\": " + String(n_gen) + ",\n"
    json += "  \"prefill_seconds\": " + String(prefill_s) + ",\n"
    json += "  \"prefill_tokens_per_sec\": " + String(prefill_tps) + ",\n"
    json += "  \"decode_seconds\": " + String(decode_s) + ",\n"
    json += "  \"decode_tokens_per_sec\": " + String(decode_tps) + ",\n"
    json += "  \"prompt_text\": \"" + _json_escape(prompt_text) + "\",\n"
    json += "  \"generated_text\": \"" + _json_escape(text) + "\",\n"
    json += "  \"generated_ids\": ["
    for i in range(len(gen_ids)):
        if i > 0:
            json += ", "
        json += String(gen_ids[i])
    json += "],\n"
    json += "  \"kvcheck\": \"" + _json_escape(kv_lines) + "\"\n"
    json += "}\n"

    if _has_flag(args, "--out"):
        _write_text_file(_get_arg(args, "--out"), json)
        print("F1 wrote: " + _get_arg(args, "--out"))
    else:
        print("F1-JSON-START")
        print(json)
        print("F1-JSON-END")

    inf.free()
    print("F1 done (resources freed)")
