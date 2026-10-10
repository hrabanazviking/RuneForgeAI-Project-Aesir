# H103 emitter: builds the three descriptors and writes them + a
# manifest as JSON. The independent TEST-ONLY checker
# (prof/smidr/check_descriptors.py) validates the emitted bytes
# field-by-field against the documented layouts.
# Usage: descemit <out_json>

from hailbru.errors import herror
from hailbru.syscall import proc_cmdline, write_file_str
from smidr.descriptor import (
    build_memcpy,
    build_noop,
    build_vecadd,
    desc_to_json,
    memcpy_notes,
    noop_notes,
    vecadd_notes,
)


def main() raises:
    var args = proc_cmdline("aarch64")
    if len(args) < 2:
        raise herror("BadArgs", "usage: descemit <out_json>")
    var js = String("{\"descriptors\": [")
    js += desc_to_json("noop", 0, build_noop(), noop_notes()) + ", "
    js += desc_to_json(
        "memcpy", 1,
        build_memcpy(UInt64(0x100000), UInt64(0x200000), 4096, 4096),
        memcpy_notes(),
    ) + ", "
    js += desc_to_json(
        "vecadd", 2,
        build_vecadd(UInt32(1), 64, UInt32(1), 64, UInt32(1), 64),
        vecadd_notes(64),
    ) + "]"

    # Malformed-input fail-closed probes (expect named BadDescriptor).
    var fails = 0
    try:
        _ = build_vecadd(UInt32(1), 0, UInt32(1), 64, UInt32(1), 64)
    except e:
        if "BadDescriptor" in String(e):
            fails += 1
    try:
        _ = build_vecadd(UInt32(1), 64, UInt32(1), 32, UInt32(1), 64)
    except e:
        if "BadDescriptor" in String(e):
            fails += 1
    try:
        _ = build_memcpy(UInt64(0x1000), UInt64(0x1000), 64, 4096)
    except e:
        if "BadDescriptor" in String(e):
            fails += 1
    try:
        _ = build_memcpy(UInt64(0x1000), UInt64(0x2000), 0, 4096)
    except e:
        if "BadDescriptor" in String(e):
            fails += 1
    try:
        _ = build_memcpy(UInt64(0x1000), UInt64(0x2000), 64, 1000)
    except e:
        if "BadDescriptor" in String(e):
            fails += 1
    js += ", \"fail_closed_probes\": " + String(fails) + "}"
    write_file_str("aarch64", args[1], js)
    print(js)
    if fails != 5:
        raise herror(
            "H103Failed",
            "fail-closed probes: " + String(fails) + "/5",
        )
    print("DESCEMIT OK: 3 descriptors, 5/5 fail-closed")
