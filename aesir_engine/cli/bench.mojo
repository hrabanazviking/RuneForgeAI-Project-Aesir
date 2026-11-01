"""The `bench` command (Janas road J-100): sweep the
configurations the placement engine may choose (threads x devices
x pass kinds) under the settle + rounds discipline, and print the
machine report.

    aesir bench [--settle N] [--rounds N] [--pass prompt|reply|draft-check]

No --pass runs all three kinds. The bench sweeps the default
resolved placement options (every kind `auto`, no kills): `auto`
is the field the placement engine itself chooses among. `--report`
is J-101's surface and is refused here as an unknown option --
silently accepting it would fake that slice.

This module imports the core bench layer only (never the engine
facade), so the command builds at the lightest target; the filed
driver docs/janas/j100_bench.mojo calls dispatch_bench directly.
"""

from std.sys import argv

from core.bench_configurations import BenchConfig, machine_report, run_bench_sweep
from core.device_inventory import observe_device_inventory
from core.placement_options import (
    PASS_DRAFTS,
    PASS_PROMPT,
    PASS_REPLY,
    RawPlacementInputs,
    pass_name,
    resolve_placement_options,
)
from core.thread_topology import observe_cpu_facts


def _parse_count(flag: String, value: String) raises -> Int:
    """A positive decimal count for --settle / --rounds. The
    discipline's own floors (settle >= 1, rounds >= 3) are
    enforced by BenchConfig/HarnessConfig behind this parse."""
    var parsed = 0
    var raw = value.as_bytes()
    if len(raw) == 0:
        raise Error("Usage: aesir bench [--settle N] [--rounds N] [--pass prompt|reply|draft-check]")
    for index in range(len(raw)):
        var byte_value = raw[index]
        if byte_value < 48 or byte_value > 57:
            raise Error(flag + " requires a positive integer, got '" + value + "'")
        var digit = Int(byte_value - 48)
        if parsed > (2147483647 - digit) // 10:
            raise Error(flag + " value is too large")
        parsed = parsed * 10 + digit
    if parsed <= 0:
        raise Error(flag + " requires a positive integer, got '" + value + "'")
    return parsed


def _pass_kind_of(name: String) raises -> Int:
    if name == "prompt":
        return PASS_PROMPT
    if name == "draft-check" or name == "drafts":
        return PASS_DRAFTS
    if name == "reply":
        return PASS_REPLY
    raise Error(
        "Unknown bench pass kind '"
        + name
        + "' (expected prompt, reply, or draft-check)"
    )


def dispatch_bench(args: List[String]) raises:
    """args includes the command name at [0] (the dispatch's
    convention, as dispatch_hardware/dispatch_compute receive)."""
    var settle = 1
    var rounds = 5
    var only_kind = -1
    var seen = List[String]()
    var i = 1
    while i < len(args):
        var flag = args[i]
        if flag in seen:
            raise Error("Duplicate bench option: " + flag)
        if flag != "--settle" and flag != "--rounds" and flag != "--pass":
            raise Error("Unknown bench option: " + flag)
        if i + 1 >= len(args):
            raise Error("Missing value for bench option: " + flag)
        seen.append(flag)
        var value = args[i + 1]
        if flag == "--settle":
            settle = _parse_count(flag, value)
        elif flag == "--rounds":
            rounds = _parse_count(flag, value)
        else:
            only_kind = _pass_kind_of(value)
        i += 2

    var config = BenchConfig(settle, rounds)
    var options = resolve_placement_options(
        RawPlacementInputs(), RawPlacementInputs()
    )
    var inventory = observe_device_inventory()
    var facts = observe_cpu_facts()
    var report = run_bench_sweep(options, inventory, facts, config)
    if only_kind < 0:
        print(machine_report(report), end="")
        return
    # One kind was named: print the full machine header (the report
    # is the machine's artefact) with only that kind's section.
    print("aesir bench — machine report (pass: " + pass_name(only_kind) + ")", end="\n")
    print("discipline: " + report.config.describe())
    print(
        "honesty: pass-shaped micro-workload timings (harness"
        " mechanics on this machine) -- not placement verdicts"
        " for any model"
    )
    print(report.inventory.device_line())
    print(report.ladder.describe())
    for kind in report.kinds:
        if kind.pass_kind == only_kind:
            print(kind.render(), end="")
    print(
        "cells: "
        + String(report.cells_total())
        + " enumerated (all kinds), "
        + String(report.cells_measured())
        + " measured"
    )
    print("bench total " + String(report.total_ns) + " ns")


def bench_main() raises:
    """The filed driver's entry: dispatch_bench over real argv
    (argv()[0] is the binary name; the command name is supplied
    as the dispatch's args[0] convention requires)."""
    var args = List[String]()
    args.append(String("bench"))
    var raw = argv()
    for i in range(1, len(raw)):
        args.append(raw[i])
    dispatch_bench(args)
