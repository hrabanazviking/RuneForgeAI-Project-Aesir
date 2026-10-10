# SMIÐR firmware mailbox submission primitive (H102).
#
# Implements the mailbox mechanism documented in
# docs/plunder/HAILO_COMMAND_QUEUE.md (H101): length-prefixed command at
# BAR4+0x0000, ready-flag doorbell at BAR4+0x1754 (Hailo-10H), completion
# polled on BAR0+0x018C bit 26 (read-and-clear), response read at
# BAR4+0x0640. All offsets/widths/values are study-derived; see the H101
# document for the per-claim evidence. This module invents nothing: every
# constant is cited there.
#
# L12: BAR access goes through hailbru.regs only.

from hailbru.errors import herror
from hailbru.regs import BarMapping, reg_read32, reg_write32
from hailbru.syscall import os_getpid, os_sleep_ms


def MB_CMD_SLOT() -> Int:
    return 0x0000


def MB_RESP_SLOT() -> Int:
    return 0x0640


def MB_READY_FLAG_10H() -> Int:
    # Hailo-10H raise-ready offset in the BAR4 firmware-access window.
    return 0x1754


def MB_FLAG_APP_CPU() -> UInt32:
    return UInt32(1)


def MB_FLAG_CORE_CPU() -> UInt32:
    return UInt32(2)


def MB_IRQ_STATUS_REG() -> Int:
    return 0x018C


def MB_FWCTL_DONE_BIT() -> UInt32:
    # Bit 26 of the BAR0 0x018C word: firmware-control completion
    # (software-IRQ byte bit 2, shifted from bit 24).
    return UInt32(0x04000000)


def MB_MAX_PAYLOAD() -> Int:
    return 1500


def MB_DEFAULT_TIMEOUT_MS() -> Int64:
    return 1000


struct MailboxResult:
    # Outcome of one mailbox round-trip.
    var completed: Bool
    var elapsed_ms: Int64
    var polls: Int
    var status_word: UInt32
    var resp_len: Int
    var response: List[UInt8]

    def __init__(out self):
        self.completed = False
        self.elapsed_ms = 0
        self.polls = 0
        self.status_word = 0
        self.resp_len = 0
        self.response = List[UInt8]()


def mailbox_submit(
    arch: String,
    bar0: BarMapping,
    bar4: BarMapping,
    payload: List[UInt8],
    app_cpu: Bool,
    timeout_ms: Int64,
) raises -> MailboxResult:
    # One full mailbox transaction. Fail-closed: every abnormal condition
    # raises a named error; a timeout returns completed=False (the caller
    # decides whether that is evidence or failure).
    #
    # WRITE ORDERING: sysfs PCI resource mappings are Normal non-cacheable
    # on ARM64, so stores can become visible out of order. The firmware
    # reads the command slot only after observing the doorbell, therefore
    # the command stores must be visible first (release semantics). The
    # syscall round-trip below is the barrier: exception entry/exit is
    # context-synchronizing and the kernel path drains the store buffer
    # long before the doorbell store issues.
    var res = MailboxResult()
    if len(payload) == 0:
        raise herror("BadCommand", "mailbox payload is empty")
    if len(payload) > MB_MAX_PAYLOAD():
        raise herror(
            "BadCommand",
            "payload " + String(len(payload))
            + " exceeds 1500-byte firmware-control limit",
        )
    # 1. Command slot: u32 length + payload, 4-byte aligned total.
    var total = 4 + len(payload)
    var aligned = ((total + 3) // 4) * 4
    reg_write32(bar4, MB_CMD_SLOT(), UInt32(len(payload)))
    for i in range(len(payload)):
        var p = bar4.ptr()
        p[unsafe_offset=MB_CMD_SLOT() + 4 + i] = payload[i]
    for i in range(len(payload), aligned - 4):
        var p = bar4.ptr()
        p[unsafe_offset=MB_CMD_SLOT() + 4 + i] = UInt8(0)
    # Write-ordering barrier (see docstring): the doorbell must not become
    # visible before the command stores.
    _ = os_getpid(arch)
    # 2. Doorbell: raise the ready flag for the target CPU.
    var flag = MB_FLAG_APP_CPU() if app_cpu else MB_FLAG_CORE_CPU()
    reg_write32(bar4, MB_READY_FLAG_10H(), flag)
    # 3. Poll the read-and-clear status register for the completion bit.
    var waited: Int64 = 0
    var polls = 0
    var step: Int64 = 1
    while waited < timeout_ms:
        var w = reg_read32(bar0, MB_IRQ_STATUS_REG())
        polls += 1
        res.status_word = w
        if (w & MB_FWCTL_DONE_BIT()) != 0:
            res.completed = True
            break
        os_sleep_ms("aarch64", step)
        waited += step
        if step < 10:
            step += 1
    res.polls = polls
    res.elapsed_ms = waited
    if not res.completed:
        return res^
    # 4. Response slot: u32 length + payload.
    var rlen = Int(reg_read32(bar4, MB_RESP_SLOT()))
    res.resp_len = rlen
    if rlen < 0 or rlen > MB_MAX_PAYLOAD():
        raise herror(
            "BadResponse",
            "response length " + String(rlen) + " out of range",
        )
    var rp = bar4.ptr()
    for i in range(rlen):
        res.response.append(rp[unsafe_offset=MB_RESP_SLOT() + 4 + i])
    return res^


def build_identify_request() -> List[UInt8]:
    # The H101 no-op: IDENTIFY, protocol version 2, opcode 0, app CPU.
    # Packed little-endian: u32 version, u32 opcode.
    var out = List[UInt8]()
    var version = UInt32(2)
    var opcode = UInt32(0)
    for i in range(4):
        out.append(UInt8((version >> UInt32(8 * i)) & UInt32(0xFF)))
    for i in range(4):
        out.append(UInt8((opcode >> UInt32(8 * i)) & UInt32(0xFF)))
    return out^


struct IdentifyInfo:
    # Parsed IDENTIFY response (packed layout per H101 §4).
    var version: UInt32
    var opcode: UInt32
    var status: UInt32
    var protocol_version: UInt32
    var fw_major: UInt32
    var fw_minor: UInt32
    var fw_rev: UInt32
    var board_name: String
    var device_arch: UInt32

    def __init__(out self):
        self.version = 0
        self.opcode = 0
        self.status = 0
        self.protocol_version = 0
        self.fw_major = 0
        self.fw_minor = 0
        self.fw_rev = 0
        self.board_name = ""
        self.device_arch = 0


def _u32le(b: List[UInt8], off: Int) raises -> UInt32:
    if off + 4 > len(b):
        raise herror(
            "BadResponse", "response truncated at offset " + String(off)
        )
    var v = UInt32(0)
    for i in range(4):
        v |= UInt32(b[off + i]) << UInt32(8 * i)
    return v


def parse_identify_response(resp: List[UInt8]) raises -> IdentifyInfo:
    # Validates the response header independently of the studied runtime:
    # version echo, opcode echo, status == 0. Raises on any mismatch.
    var info = IdentifyInfo()
    if len(resp) < 12:
        raise herror(
            "BadResponse",
            "identify response too short: " + String(len(resp)),
        )
    info.version = _u32le(resp, 0)
    info.opcode = _u32le(resp, 4)
    info.status = _u32le(resp, 8)
    if info.version != 2:
        raise herror(
            "BadResponse",
            "version echo mismatch: " + String(Int(info.version)),
        )
    if info.opcode != 0:
        raise herror(
            "BadResponse",
            "opcode echo mismatch: " + String(Int(info.opcode)),
        )
    if info.status != 0:
        raise herror(
            "BadResponse",
            "firmware reported status " + String(Int(info.status)),
        )
    if len(resp) < 12 + 4 + 12 + 4 + 4 + 32 + 4:
        raise herror(
            "BadResponse", "identify payload truncated at header fields"
        )
    info.protocol_version = _u32le(resp, 12)
    info.fw_major = _u32le(resp, 16)
    info.fw_minor = _u32le(resp, 20)
    info.fw_rev = _u32le(resp, 24)
    # logger_version at 28 (skipped), board_name_length at 32.
    var name_len = Int(_u32le(resp, 32))
    if name_len < 0 or name_len > 32 or 36 + name_len > len(resp):
        raise herror(
            "BadResponse", "board name length out of range"
        )
    var name = String("")
    for i in range(name_len):
        var c = resp[36 + i]
        if c == 0:
            break
        name += String(chr(Int(c)))
    info.board_name = name
    # device_architecture follows board_name[32]: offset 36+32 = 68.
    if len(resp) >= 72:
        info.device_arch = _u32le(resp, 68)
    return info^
