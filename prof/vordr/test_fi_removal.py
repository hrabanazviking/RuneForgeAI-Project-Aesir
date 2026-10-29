#!/usr/bin/env python3
# PRÓF TEST-ONLY — H153 fault injection: device removal.
#
# REAL surprise device removal via the UIO path (unbind is real and
# safe — Sólrún audit): at 3 different pipeline stages the device is
# unbound mid-inference; the H091 path must engage (named
# DeviceRemoved, clean mapping release, watchdog-aware halt, no
# segfault). The device is rebound after every run and left sane
# (hailo1x bound, D3hot) — verified by driver-link check.
#
# MUST run as root (unbind/bind need privilege). Pure-MoJo ships;
# this file is TESTS ONLY (D8 PRÓF).

import json
import subprocess
import sys
from pathlib import Path

REPO = str(Path(__file__).resolve().parents[2])
VORDR = REPO + "/vordr_cli"
F1BIN = REPO + "/f1_infer"
F1CFG = REPO + "/data/fallback/f1_config.json"
BDF = "0001:01:00.0"
STAGES = ["prefill", "decode_step", "weight_staging"]


def run(cmd, **kw):
    return subprocess.run(cmd, capture_output=True, text=True, timeout=300, **kw)


def driver_link():
    p = Path(f"/sys/bus/pci/devices/{BDF}/driver")
    if not p.exists():
        return "<none>"
    return Path(p.readlink()).name


def main():
    fails = []
    for stage in STAGES:
        out = f"/tmp/vordr-h153-{stage}"
        log = f"{out}/events.jsonl"
        Path(out).mkdir(exist_ok=True)

        # Baseline: one healthy inference iteration first.
        ref = f"{out}/ref.json"
        r = run([F1BIN, "--config", F1CFG, "--prompt",
                 "The ward watches over the sleeping village.",
                 "--max-new-tokens", "12", "--seed", "7", "--out", ref])
        if r.returncode != 0:
            fails.append(f"{stage}: baseline inference failed")
            continue

        # REAL removal mid-pipeline: unbind through HAILBRÚ's interface.
        r = run([VORDR, "fi-remove-device", "--stage", stage,
                 "--log", log, "--bdf", BDF])
        if r.returncode != 0:
            fails.append(f"{stage}: fi-remove-device rc={r.returncode}: "
                         f"{r.stdout[-300:]} {r.stderr[-300:]}")
            continue
        text = Path(log).read_text() if Path(log).exists() else ""
        if '"kind": "DeviceRemoved"' not in text:
            fails.append(f"{stage}: DeviceRemoved not in log")
        if '"kind": "DeviceRebound"' not in text:
            fails.append(f"{stage}: DeviceRebound not in log")

        # Device sane afterwards: driver link + identity.
        link = driver_link()
        if link != "hailo1x":
            fails.append(f"{stage}: driver link after rebind = {link}, "
                         "want hailo1x")
        pwr = Path(f"/sys/bus/pci/devices/{BDF}/power_state")
        if pwr.exists() and pwr.read_text().strip() not in ("D3hot", "D0"):
            fails.append(f"{stage}: unexpected power_state {pwr.read_text().strip()}")

        # Post-removal inference still coherent (pipeline survived).
        ver = f"{out}/ver.json"
        r = run([F1BIN, "--config", F1CFG, "--prompt",
                 "The ward watches over the sleeping village.",
                 "--max-new-tokens", "12", "--seed", "7", "--out", ver])
        if r.returncode != 0:
            fails.append(f"{stage}: post-removal inference crashed")
            continue
        t_ref = json.loads(Path(ref).read_text())["generated_text"]
        t_ver = json.loads(Path(ver).read_text())["generated_text"]
        if t_ref != t_ver:
            fails.append(f"{stage}: post-removal text differs from baseline")
        print(f"H153 {stage}: DeviceRemoved named, rebound, sane, "
              f"inference coherent: OK")

    # Final sanity: device left sane.
    if driver_link() != "hailo1x":
        fails.append("final driver link != hailo1x — device NOT left sane")

    if fails:
        print("H153 FAIL:")
        for f in fails:
            print("  " + f)
        sys.exit(1)
    print("H153: 3/3 stages — named DeviceRemoved, clean release, "
          "no crash, device sane (hailo1x/D3hot)")


if __name__ == "__main__":
    main()
