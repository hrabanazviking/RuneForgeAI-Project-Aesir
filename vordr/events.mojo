# VÖRÐR structured event log (H141+).
#
# Every VÖRÐR action emits a structured JSON line:
#   {"ts_ms": <monotonic ms>, "kind": "<event>", "slice": "H1xx", ...fields}
# L11 (degrade honestly): no silent fallbacks — every degrade, retry,
# reset, and recovery transition emits its event at the moment it
# engages. The H159 fallback audit is machine-checked against these.

from hailbru.syscall import append_file_str, os_clock_ms
from hailbru.util import trim


def event_emit(arch: String, log_path: String, kind: String, fields: String) raises:
    # fields: pre-formatted '"k": v, "k2": v2' fragment (no braces).
    var ts = os_clock_ms(arch)
    var line = (
        "{\"ts_ms\": " + String(ts) + ", \"kind\": \"" + kind
        + "\", \"slice\": \"C8\"" + (", " + fields if trim(fields).byte_length() > 0 else "")
        + "}\n"
    )
    append_file_str(arch, log_path, line)


def event_emit_slice(
    arch: String, log_path: String, slice_id: String, kind: String, fields: String
) raises:
    var ts = os_clock_ms(arch)
    var line = (
        "{\"ts_ms\": " + String(ts) + ", \"kind\": \"" + kind
        + "\", \"slice\": \"" + slice_id + "\""
        + (", " + fields if trim(fields).byte_length() > 0 else "") + "}\n"
    )
    append_file_str(arch, log_path, line)


def json_str(s: String) -> String:
    # Minimal JSON string escaping for event fields (quotes/backslash).
    var out = String("\"")
    for b in s.bytes():
        var c = Int(b)
        if c == 34:
            out += "\\\""
        elif c == 92:
            out += "\\\\"
        elif c == 10:
            out += "\\n"
        else:
            out += String(chr(c))
    out += "\""
    return out
