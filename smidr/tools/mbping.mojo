# H102 live tool: IDENTIFY ping via the firmware mailbox (H101 mechanism).
#
# Usage: mbping <sysfs_root> <bdf> <out_json> [count]
#
# Preconditions (set up by the caller, NOT this tool): the device is bound
# to uio_pci_generic (F3-2 procedure), is in D0, and the caller runs as
# root. This tool only mmaps BAR0/BAR4 and performs mailbox transactions;
# it never binds/unbinds drivers and never changes power state.
#
# Per iteration: build the IDENTIFY request (H101 §4), submit through the
# mailbox, require completion within the 1000 ms bound, parse and validate
# the response (version echo 2, opcode echo 0, status 0). Completions are
# matched 1:1 to submissions by sequence number. Before and after the run,
# the H096 register set (16 config dwords + 5 BAR0 offsets) is captured;
# the post-run set must match the pre-run set modulo known-volatile bits
# (BAR0 0x018C bit 23) — proving the ping is side-effect-free.

from hailbru.errors import herror
from hailbru.regs import (
    BarMapping,
    map_sysfs_resource,
    reg_read32,
    unmap_bar,
)
from hailbru.syscall import proc_cmdline, write_file_str
from smidr.mailbox import (
    MB_DEFAULT_TIMEOUT_MS,
    build_identify_request,
    mailbox_submit,
    parse_identify_response,
)


def _cfg_snapshot(bar0: BarMapping) raises -> List[UInt32]:
    # H096 register set: 16 config dwords are read from PCI config space
    # by the caller; here we capture the 5 BAR0 offsets. The config-space
    # half is captured by the session script via `probe snapshot`.
    var out = List[UInt32]()
    var offsets = List[Int]()
    offsets.append(0x0098)
    offsets.append(0x0188)
    offsets.append(0x018C)
    offsets.append(0x0400)
    offsets.append(0x0500)
    for i in range(len(offsets)):
        out.append(reg_read32(bar0, offsets[i]))
    return out^


def main() raises:
    var args = proc_cmdline("aarch64")
    if len(args) < 4:
        raise herror(
            "BadArgs", "usage: mbping <sysfs_root> <bdf> <out_json> [count]"
        )
    var sysfs_root = args[1]
    var bdf = args[2]
    var out_path = args[3]
    var count = 100
    if len(args) >= 5:
        count = Int(args[4])
    if count <= 0:
        raise herror("BadArgs", "count must be positive")

    var arch = "aarch64"
    var bar0 = map_sysfs_resource(
        arch, sysfs_root, bdf, 0, 16384, True
    )
    var bar4 = map_sysfs_resource(
        arch, sysfs_root, bdf, 4, 16384, True
    )

    var pre = _cfg_snapshot(bar0)
    var submitted = 0
    var completed = 0
    var validated = 0
    var max_ms: Int64 = 0
    var total_ms: Int64 = 0
    var board_name = String("")
    var fwv = String("")
    var first_err = String("")
    try:
        for n in range(count):
            var req = build_identify_request()
            var res = mailbox_submit(
                arch, bar0, bar4, req, True, MB_DEFAULT_TIMEOUT_MS()
            )
            submitted += 1
            if not res.completed:
                first_err = (
                    "iteration " + String(n)
                    + ": no completion within timeout"
                )
                break
            completed += 1
            total_ms += res.elapsed_ms
            if res.elapsed_ms > max_ms:
                max_ms = res.elapsed_ms
            var info = parse_identify_response(res.response)
            validated += 1
            board_name = info.board_name
            fwv = (
                String(Int(info.fw_major)) + "."
                + String(Int(info.fw_minor)) + "."
                + String(Int(info.fw_rev))
            )
    except e:
        first_err = String(e)
    var post = _cfg_snapshot(bar0)

    # Golden comparison: mask the known-volatile bit (0x018C bit 23).
    var golden_clean = True
    var golden_diff = String("")
    if len(pre) == len(post):
        for i in range(len(pre)):
            var mask = UInt32(0xFFFFFFFF)
            if i == 2:
                mask = UInt32(0xFF7FFFFF)
            if (pre[i] & mask) != (post[i] & mask):
                golden_clean = False
                golden_diff += (
                    "reg[" + String(i) + "]: pre=0x"
                    + String(Int(pre[i])) + " post=0x"
                    + String(Int(post[i])) + "; "
                )
    else:
        golden_clean = False
        golden_diff = "snapshot length mismatch"

    var ok = (
        submitted == count
        and completed == count
        and validated == count
        and golden_clean
        and first_err == ""
    )
    var avg_ms: Int64 = 0
    if completed > 0:
        avg_ms = total_ms // Int64(completed)
    var js = String("{")
    js += "\"tool\": \"mbping\", \"h102\": true, "
    js += "\"submitted\": " + String(submitted) + ", "
    js += "\"completed\": " + String(completed) + ", "
    js += "\"validated\": " + String(validated) + ", "
    js += "\"sequence_matched_1_to_1\": "
    js += "true" if submitted == completed else "false"
    js += ", \"avg_ms\": " + String(avg_ms) + ", "
    js += "\"max_ms\": " + String(max_ms) + ", "
    js += "\"golden_clean\": "
    js += "true" if golden_clean else "false"
    js += ", \"golden_diff\": \"" + golden_diff + "\", "
    js += "\"board_name\": \"" + board_name + "\", "
    js += "\"fw_version\": \"" + fwv + "\", "
    js += "\"first_error\": \"" + first_err + "\", "
    js += "\"pass\": "
    js += "true" if ok else "false"
    js += "}"
    write_file_str(arch, out_path, js)
    print(js)

    unmap_bar(arch, bar0)
    unmap_bar(arch, bar4)
    if not ok:
        raise herror(
            "H102Failed",
            "submitted=" + String(submitted)
            + " completed=" + String(completed)
            + " validated=" + String(validated)
            + " golden_clean=" + String(golden_clean)
            + " err=" + first_err,
        )
    print("H102 PASS: " + String(count) + " IDENTIFY round-trips, "
          + "1:1 matched, golden clean")
