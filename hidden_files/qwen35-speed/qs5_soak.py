#!/usr/bin/env python3
"""QS-5.4 soak driver against the permanent unit on port 18434.
Usage: qs5_soak.py <duration_s> <outdir>
- Sampler thread: every 60 s appends ts, MemoryCurrent, MemoryPeak,
  NRestarts and a /health verdict to <outdir>/soak-mem.log.
- Request loop: cycles short stateless / resident multi-turn /
  medium prefill with QS-4 sampling params / long prefill legs;
  every request logged to <outdir>/soak-req.log.
- At end writes <outdir>/soak-summary.json incl. least-squares
  slope of MemoryCurrent vs time (bytes/hour).
Key read in-process, never printed. Runs detached under its own
systemd unit; this script is the whole soak."""
import json, os, subprocess, sys, threading, time, urllib.request

DUR = int(sys.argv[1]) if len(sys.argv) > 1 else 11400
OUT = sys.argv[2] if len(sys.argv) > 2 else "/home/volmarr/aesir-hipserve/hidden_files/qwen35-speed"
BASE = "http://127.0.0.1:18434"
KEY = open("/home/volmarr/.config/aesir/service.key").read().strip()
MODEL = "/mnt/vault/models/gguf/Qwen3.8-27B-Ultimate-Heretic-Uncn-Turbo-Brilli-50x-AGI-NEO-Q8_0.gguf"
SYSTEM = "You are a helpful assistant."
PASSAGE = ("The old harbour town kept its records in a stone archive above the tide line. "
  "Every spring the clerks carried the ledgers down to the counting house, checked each "
  "cargo against the harbour master's roll, and noted the ships that had wintered in the "
  "northern ports. Grain, salt, timber and dried fish filled the manifests, and the town "
  "council argued each year about the cost of repairing the eastern pier. ")
T0 = time.time()
stop = threading.Event()
mem_samples = []  # (elapsed_s, bytes)

def logline(path, line):
    with open(os.path.join(OUT, path), "a") as f:
        f.write(line + "\n")

def unit_prop(name):
    try:
        out = subprocess.run(["systemctl", "show", "aesir-gate.service", "-p", name],
                             capture_output=True, text=True, timeout=20).stdout.strip()
        return out.split("=", 1)[1] if "=" in out else "?"
    except Exception:
        return "?"

def health_ok():
    try:
        r = urllib.request.Request(BASE + "/health", headers={"Authorization": "Bearer " + KEY})
        with urllib.request.urlopen(r, timeout=30) as resp:
            d = json.load(resp)
        return d.get("status") == "ready"
    except Exception:
        return False

def sampler():
    while not stop.is_set():
        el = time.time() - T0
        mc = unit_prop("MemoryCurrent")
        mp = unit_prop("MemoryPeak")
        nr = unit_prop("NRestarts")
        ok = health_ok()
        try:
            mem_samples.append((el, int(mc)))
        except Exception:
            pass
        logline("soak-mem.log", "t=%.0f mem_current=%s mem_peak=%s nrestarts=%s health=%s" % (
            el, mc, mp, nr, "ready" if ok else "NOTREADY"))
        stop.wait(60)

def chat(messages, max_tokens, tag, **kw):
    body = {"model": MODEL, "max_tokens": max_tokens, "messages": messages}
    body.update(kw)
    r = urllib.request.Request(BASE + "/v1/chat/completions", data=json.dumps(body).encode(),
        headers={"Authorization": "Bearer " + KEY, "Content-Type": "application/json"})
    t0 = time.time()
    try:
        with urllib.request.urlopen(r, timeout=1500) as resp:
            data = json.load(resp)
        wall = time.time() - t0
        text = ""
        try:
            text = data["choices"][0]["message"]["content"] or ""
        except Exception:
            pass
        sane = len(text.strip()) >= 2
        u = data.get("usage") or {}
        logline("soak-req.log", "t=%.0f tag=%s ok=%s sane=%s wall=%.1f prompt=%s completion=%s reused=%s head=%r" % (
            t0 - T0, tag, True, sane, wall, u.get("prompt_tokens"), u.get("completion_tokens"),
            u.get("reused_prompt_tokens"), text[:48]))
        return text, True, sane
    except Exception as e:
        wall = time.time() - t0
        logline("soak-req.log", "t=%.0f tag=%s ok=False wall=%.1f err=%s" % (t0 - T0, tag, wall, repr(e)[:120]))
        return "", False, False

def words_prompt(nwords, suffix):
    reps = max(1, nwords // len(PASSAGE.split()))
    return PASSAGE * reps + suffix

def main():
    os.makedirs(OUT, exist_ok=True)
    logline("soak-req.log", "SOAK START t=0 dur=%ds" % DUR)
    th = threading.Thread(target=sampler, daemon=True)
    th.start()
    n_ok = n_fail = n_insane = 0
    cycle = 0
    convo = None
    while time.time() - T0 < DUR:
        cycle += 1
        kind = cycle % 6
        if kind == 1:
            _, ok, sane = chat([{"role": "system", "content": SYSTEM},
                {"role": "user", "content": "In one short sentence, describe a harbour at dawn. (soak %d)" % cycle}], 32, "short")
        elif kind == 2:
            if convo is None:
                convo = [{"role": "system", "content": SYSTEM},
                         {"role": "user", "content": "We are listing harbour jobs. Name one job, briefly."}]
            text, ok, sane = chat(convo, 32, "resident")
            if ok:
                convo = convo + [{"role": "assistant", "content": text},
                                 {"role": "user", "content": "Name another one, different from before, briefly."}]
                if len(convo) > 9:
                    convo = None
        elif kind == 3:
            _, ok, sane = chat([{"role": "system", "content": SYSTEM},
                {"role": "user", "content": "Write two vivid sentences about gulls over a winter harbour."}],
                48, "sampling", temperature=0.8, top_p=0.95)
        elif kind == 4:
            _, ok, sane = chat([{"role": "system", "content": SYSTEM},
                {"role": "user", "content": words_prompt(500, "Question: in one sentence, what did the clerks check each spring? (soak %d)" % cycle)}],
                48, "prefill-med", temperature=0.7)
        elif kind == 5:
            # native /v1/generate leg: min_p + repeat_penalty
            # (QS-4 wiring; the chat parser refuses min_p by design)
            body = {"prompt": "The old lighthouse keeper", "system": SYSTEM,
                    "max_tokens": 48, "temperature": 1.0, "top_p": 1.0,
                    "min_p": 0.05, "repeat_penalty": 1.1}
            t0 = time.time()
            try:
                r = urllib.request.Request(BASE + "/v1/generate", data=json.dumps(body).encode(),
                    headers={"Authorization": "Bearer " + KEY, "Content-Type": "application/json"})
                with urllib.request.urlopen(r, timeout=1500) as resp:
                    raw = resp.read().decode("utf-8", "replace")
                wall = time.time() - t0
                sane = len(raw.strip()) >= 8
                logline("soak-req.log", "t=%.0f tag=generate-minp ok=True sane=%s wall=%.1f head=%r" % (
                    t0 - T0, sane, wall, raw[:48]))
                ok = True
            except Exception as e:
                wall = time.time() - t0
                logline("soak-req.log", "t=%.0f tag=generate-minp ok=False wall=%.1f err=%s" % (
                    t0 - T0, wall, repr(e)[:120]))
                ok, sane = False, False
        else:
            _, ok, sane = chat([{"role": "system", "content": SYSTEM},
                {"role": "user", "content": words_prompt(1100, "Question: in one sentence, what filled the manifests? (soak %d)" % cycle)}],
                40, "prefill-long")
        if ok:
            n_ok += 1
            if not sane:
                n_insane += 1
        else:
            n_fail += 1
    stop.set()
    th.join(timeout=90)
    # least-squares slope of MemoryCurrent (bytes/hour)
    slope = None
    if len(mem_samples) >= 3:
        xs = [s / 3600.0 for s, _ in mem_samples]
        ys = [float(b) for _, b in mem_samples]
        xm = sum(xs) / len(xs); ym = sum(ys) / len(ys)
        den = sum((x - xm) ** 2 for x in xs)
        if den > 0:
            slope = sum((x - xm) * (y - ym) for x, y in zip(xs, ys)) / den
    summary = {"duration_s": time.time() - T0, "requests_ok": n_ok, "requests_fail": n_fail,
               "responses_insane": n_insane, "mem_samples": len(mem_samples),
               "mem_slope_bytes_per_hour": slope,
               "mem_first_bytes": mem_samples[0][1] if mem_samples else None,
               "mem_last_bytes": mem_samples[-1][1] if mem_samples else None,
               "mem_max_bytes": max(b for _, b in mem_samples) if mem_samples else None}
    with open(os.path.join(OUT, "soak-summary.json"), "w") as f:
        json.dump(summary, f, indent=2)
    logline("soak-req.log", "SOAK END %s" % json.dumps(summary))
    print("SOAK DONE", json.dumps(summary), flush=True)

if __name__ == "__main__":
    main()
