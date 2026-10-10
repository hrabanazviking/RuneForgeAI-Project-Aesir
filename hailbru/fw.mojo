# HAILBRU firmware layer (H072/H073/H074/H075/H076).
#
#  - H072: register identification lives in
#    docs/plunder/HAILO_FW_LOAD_REGISTERS.md (research + read-only
#    probes); the offsets below cite that document.
#  - H073: firmware_check() — existence + size + SHA-256 (pure Mojo)
#    against the H014 catalogue. Read-only; no download/fetch/network.
#    L7: the blob is user-side; Aesir never ships or fetches it.
#  - H074: chunked upload planner + staging with per-chunk verification.
#    Device-side DMA upload is F3-BANKED (no DMA path on this kernel);
#    the staging/verification logic is real and tested against an
#    emulated target.
#  - H075/H076: boot-handshake and device-ready pollers as explicit
#    state machines (no higher-order functions — version-proof). The
#    caller supplies status values (emulated in tests; reg_read32 on
#    the F3 device path).

from hailbru.errors import herror
from hailbru.syscall import (
    O_CREAT,
    O_RDONLY,
    O_RDWR,
    O_TRUNC,
    O_WRONLY,
    errno_name,
    errno_now,
    file_exists,
    os_close,
    os_clock_ms,
    os_openat,
    os_read,
    os_write,
    read_file_bytes,
)
from hailbru.syscall import unsafe_alloc


# --- firmware register offsets (BAR0 unless noted; see H072 doc) ---------
def FWREG_VENDOR_MIRROR() -> Int:
    return 0x0098  # 16-bit vendor-ID mirror, read-only (expect 0x1e60)


def FWREG_IRQ_MASK() -> Int:
    return 0x0188  # interrupt mask (R/W — never written on live device)


def FWREG_IRQ_STATUS() -> Int:
    return 0x018C  # host interrupt status, read-and-clear


def FWREG_CHAN_BITMAP0() -> Int:
    return 0x0400  # per-channel bitmap, read-and-clear


def FWREG_CHAN_BITMAP1() -> Int:
    return 0x0500  # per-channel bitmap, read-and-clear


def FWREG_ATR_BASE() -> Int:
    return 0x0700  # ATR window registers (address translation)


def FWREG_MAILBOX() -> Int:
    return 0x0000  # BAR4: mailbox window (command buffer)


def FWREG_REPLY_SLOT() -> Int:
    return 0x0640  # BAR4: reply slot (length + payload)


# --- pure-Mojo SHA-256 ------------------------------------------------------
def _rotr(x: UInt32, n: UInt32) -> UInt32:
    return (x >> n) | (x << (UInt32(32) - n))


def _sha256_block(mut h: List[UInt32], blk: List[UInt8]):
    # The 64 SHA-256 round constants (FIPS 180-4 §4.2.2).
    var kt = List[UInt32]()
    kt.append(0x428A2F98); kt.append(0x71374491); kt.append(0xB5C0FBCF)
    kt.append(0xE9B5DBA5); kt.append(0x3956C25B); kt.append(0x59F111F1)
    kt.append(0x923F82A4); kt.append(0xAB1C5ED5); kt.append(0xD807AA98)
    kt.append(0x12835B01); kt.append(0x243185BE); kt.append(0x550C7DC3)
    kt.append(0x72BE5D74); kt.append(0x80DEB1FE); kt.append(0x9BDC06A7)
    kt.append(0xC19BF174); kt.append(0xE49B69C1); kt.append(0xEFBE4786)
    kt.append(0x0FC19DC6); kt.append(0x240CA1CC); kt.append(0x2DE92C6F)
    kt.append(0x4A7484AA); kt.append(0x5CB0A9DC); kt.append(0x76F988DA)
    kt.append(0x983E5152); kt.append(0xA831C66D); kt.append(0xB00327C8)
    kt.append(0xBF597FC7); kt.append(0xC6E00BF3); kt.append(0xD5A79147)
    kt.append(0x06CA6351); kt.append(0x14292967); kt.append(0x27B70A85)
    kt.append(0x2E1B2138); kt.append(0x4D2C6DFC); kt.append(0x53380D13)
    kt.append(0x650A7354); kt.append(0x766A0ABB); kt.append(0x81C2C92E)
    kt.append(0x92722C85); kt.append(0xA2BFE8A1); kt.append(0xA81A664B)
    kt.append(0xC24B8B70); kt.append(0xC76C51A3); kt.append(0xD192E819)
    kt.append(0xD6990624); kt.append(0xF40E3585); kt.append(0x106AA070)
    kt.append(0x19A4C116); kt.append(0x1E376C08); kt.append(0x2748774C)
    kt.append(0x34B0BCB5); kt.append(0x391C0CB3); kt.append(0x4ED8AA4A)
    kt.append(0x5B9CCA4F); kt.append(0x682E6FF3); kt.append(0x748F82EE)
    kt.append(0x78A5636F); kt.append(0x84C87814); kt.append(0x8CC70208)
    kt.append(0x90BEFFFA); kt.append(0xA4506CEB); kt.append(0xBEF9A3F7)
    kt.append(0xC67178F2)
    var w = List[UInt32]()
    for i in range(16):
        var v = UInt32(0)
        for j in range(4):
            v |= UInt32(blk[i * 4 + j]) << UInt32(8 * (3 - j))
        w.append(v)
    for i in range(16, 64):
        var s0 = _rotr(w[i - 15], 7) ^ _rotr(w[i - 15], 18) ^ (
            w[i - 15] >> UInt32(3)
        )
        var s1 = _rotr(w[i - 2], 17) ^ _rotr(w[i - 2], 19) ^ (
            w[i - 2] >> UInt32(10)
        )
        w.append(w[i - 16] + s0 + w[i - 7] + s1)
    var a = h[0]; var b = h[1]; var c = h[2]; var d = h[3]
    var e = h[4]; var f = h[5]; var g = h[6]; var hh = h[7]
    for i in range(64):
        var s1 = _rotr(e, 6) ^ _rotr(e, 11) ^ _rotr(e, 25)
        var ch = (e & f) ^ ((~e) & g)
        var t1 = hh + s1 + ch + kt[i] + w[i]
        var s0 = _rotr(a, 2) ^ _rotr(a, 13) ^ _rotr(a, 22)
        var maj = (a & b) ^ (a & c) ^ (b & c)
        var t2 = s0 + maj
        hh = g; g = f; f = e; e = d + t1
        d = c; c = b; b = a; a = t1 + t2
    h[0] = h[0] + a; h[1] = h[1] + b; h[2] = h[2] + c; h[3] = h[3] + d
    h[4] = h[4] + e; h[5] = h[5] + f; h[6] = h[6] + g; h[7] = h[7] + hh


def sha256_hex(data: List[UInt8]) -> String:
    var h = List[UInt32]()
    h.append(0x6A09E667); h.append(0xBB67AE85); h.append(0x3C6EF372)
    h.append(0xA54FF53A); h.append(0x510E527F); h.append(0x9B05688C)
    h.append(0x1F83D9AB); h.append(0x5BE0CD19)
    var bitlen = UInt64(len(data)) * UInt64(8)
    var msg = List[UInt8]()
    for i in range(len(data)):
        msg.append(data[i])
    msg.append(UInt8(0x80))
    while len(msg) % 64 != 56:
        msg.append(UInt8(0))
    for i in range(8):
        msg.append(UInt8((bitlen >> UInt64(8 * (7 - i))) & UInt64(0xFF)))
    var off = 0
    while off < len(msg):
        var blk = List[UInt8]()
        for i in range(64):
            blk.append(msg[off + i])
        _sha256_block(h, blk)
        off += 64
    var hexch = "0123456789abcdef"
    var hb = List[UInt8]()
    for b in hexch.bytes():
        hb.append(b)
    var out = String("")
    for i in range(8):
        for j in range(8):
            var nib = Int((h[i] >> UInt32(4 * (7 - j))) & UInt32(0xF))
            out += String(chr(Int(hb[nib])))
    return out


def sha256_file(arch: String, path: String) raises -> String:
    # Streams the file in 64KB pieces (no whole-file buffering).
    var h = List[UInt32]()
    h.append(0x6A09E667); h.append(0xBB67AE85); h.append(0x3C6EF372)
    h.append(0xA54FF53A); h.append(0x510E527F); h.append(0x9B05688C)
    h.append(0x1F83D9AB); h.append(0x5BE0CD19)
    var fd = os_openat(arch, path, O_RDONLY(), 0)
    if fd < 0:
        var e = errno_now()
        raise herror(
            "FirmwareMissing",
            "cannot open " + path + ": " + errno_name(e),
        )
    var buf = unsafe_alloc[UInt8](65536)
    var total = UInt64(0)
    var carry = List[UInt8]()
    while True:
        var n = os_read(arch, fd, buf, 65536)
        if n < 0:
            var e = errno_now()
            buf.unsafe_free()
            _ = os_close(arch, fd)
            raise herror(
                "OsError", "read " + path + ": " + errno_name(e)
            )
        if n == 0:
            break
        total += UInt64(n)
        for i in range(Int(n)):
            carry.append(buf[unsafe_offset=i])
        while len(carry) >= 64:
            var blk = List[UInt8]()
            for i in range(64):
                blk.append(carry[i])
            _sha256_block(h, blk)
            var rest = List[UInt8]()
            for i in range(64, len(carry)):
                rest.append(carry[i])
            carry = rest^
    _ = os_close(arch, fd)
    buf.unsafe_free()
    var bitlen = total * UInt64(8)
    carry.append(UInt8(0x80))
    while len(carry) % 64 != 56:
        carry.append(UInt8(0))
    for i in range(8):
        carry.append(UInt8((bitlen >> UInt64(8 * (7 - i))) & UInt64(0xFF)))
    var off = 0
    while off < len(carry):
        var blk = List[UInt8]()
        for i in range(64):
            blk.append(carry[off + i])
        _sha256_block(h, blk)
        off += 64
    var hexch = "0123456789abcdef"
    var hb = List[UInt8]()
    for b in hexch.bytes():
        hb.append(b)
    var out = String("")
    for i in range(8):
        for j in range(8):
            var nib = Int((h[i] >> UInt32(4 * (7 - j))) & UInt32(0xF))
            out += String(chr(Int(hb[nib])))
    return out


# --- H073 firmware presence check -------------------------------------------
struct FirmwareEntry:
    var rel_path: String
    var size_bytes: Int64
    var sha256: String

    def __init__(out self, rel_path: String, size_bytes: Int64, sha256: String):
        self.rel_path = rel_path
        self.size_bytes = size_bytes
        self.sha256 = sha256


def firmware_check(
    arch: String, fw_root: String, entries: List[FirmwareEntry]
) raises -> List[FirmwareEntry]:
    # Verifies existence, size, and SHA-256 of each catalogued blob.
    # Returns the verified entries (catalogue order = deterministic
    # selection rule per H014; entries[0] is the bring-up-first blob).
    # Raises FirmwareMissing / FirmwareCorrupt. Read-only: no download,
    # no fetch, no network (H073 acceptance, L7).
    var ok = List[FirmwareEntry]()
    for i in range(len(entries)):
        ref e = entries[i]
        var full = fw_root + "/" + e.rel_path
        if not file_exists(arch, full):
            raise herror(
                "FirmwareMissing",
                "blob absent: " + full
                + " (catalogued in H014; user-side prerequisite per L7)",
            )
        var data = read_file_bytes(arch, full, e.size_bytes + 16)
        if Int64(len(data)) != e.size_bytes:
            raise herror(
                "FirmwareCorrupt",
                full + ": size " + String(len(data)) + " != catalogued "
                + String(e.size_bytes),
            )
        var digest = sha256_file(arch, full)
        if digest != e.sha256:
            raise herror(
                "FirmwareCorrupt",
                full + ": sha256 " + digest + " != catalogued "
                + e.sha256,
            )
        ok.append(FirmwareEntry(e.rel_path, e.size_bytes, e.sha256))
    return ok^


# --- H074 chunked upload (staging + per-chunk verification) ------------------
struct ChunkDesc:
    var index: Int
    var offset: Int64
    var length: Int64

    def __init__(out self, index: Int, offset: Int64, length: Int64):
        self.index = index
        self.offset = offset
        self.length = length


def fw_plan_chunks(blob_size: Int64, chunk_size: Int64) raises -> List[ChunkDesc]:
    if chunk_size <= 0:
        raise herror("DmaError", "chunk_size must be positive")
    var out = List[ChunkDesc]()
    var off = Int64(0)
    var idx = 0
    while off < blob_size:
        var ln = chunk_size
        if off + ln > blob_size:
            ln = blob_size - off
        out.append(ChunkDesc(idx, off, ln))
        off += ln
        idx += 1
    return out^


def fw_stage_verify(
    arch: String,
    blob_path: String,
    staging_path: String,
    chunk_size: Int64,
    abort_after: Int,
) raises -> String:
    # Stages the blob into `staging_path` chunk by chunk (the emulated
    # device target), verifying each chunk's SHA-256 on readback, then
    # verifies the whole staging image SHA-256 equals the blob's —
    # proving the blob was never modified in memory (H074 acceptance).
    #
    # abort_after >= 0: test hook — interrupts the upload mid-way after
    # that many chunks. The abort procedure leaves a DEFINED state (the
    # partial staging file is removed) and raises a named error; the
    # caller re-runs with abort_after=-1 to prove recovery.
    #
    # Returns the blob's SHA-256 hex on success.
    var blob = read_file_bytes(arch, blob_path, Int64(256) * 1048576)
    var blob_size = Int64(len(blob))
    if blob_size == 0:
        raise herror("FirmwareMissing", "blob empty: " + blob_path)
    var chunks = fw_plan_chunks(blob_size, chunk_size)
    var chunk_shas = List[String]()
    # Stage: write chunks sequentially.
    var wfd = os_openat(
        arch, staging_path, O_WRONLY() | O_CREAT() | O_TRUNC(), 0o644
    )
    if wfd < 0:
        var e = errno_now()
        raise herror(
            "OsError",
            "open staging " + staging_path + ": " + errno_name(e),
        )
    var aborted = False
    for i in range(len(chunks)):
        if abort_after >= 0 and i >= abort_after:
            aborted = True
            break
        ref c = chunks[i]
        var cdata = List[UInt8]()
        for j in range(Int(c.length)):
            cdata.append(blob[Int(c.offset) + j])
        var csha = sha256_hex(cdata)
        chunk_shas.append(csha)
        var wbuf = unsafe_alloc[UInt8](Int(c.length))
        for j in range(Int(c.length)):
            wbuf[unsafe_offset=j] = cdata[j]
        var w = os_write(arch, wfd, wbuf, c.length)
        wbuf.unsafe_free()
        if w != c.length:
            _ = os_close(arch, wfd)
            raise herror(
                "OsError",
                "short staging write at chunk " + String(i),
            )
    _ = os_close(arch, wfd)
    if aborted:
        # Defined abort state: truncate the partial staging image, then
        # fail closed with a named error identifying the chunk index.
        var tfd = os_openat(arch, staging_path, O_WRONLY() | O_TRUNC(), 0o644)
        if tfd >= 0:
            _ = os_close(arch, tfd)
        raise herror(
            "FirmwareUploadAborted",
            "upload interrupted after chunk " + String(abort_after)
            + " (test hook); partial staging removed — defined state; "
            + "re-run to recover",
        )
    # Per-chunk readback verification against the staging image.
    var staged = read_file_bytes(arch, staging_path, blob_size + 16)
    if Int64(len(staged)) != blob_size:
        raise herror(
            "FirmwareCorrupt",
            "staging size " + String(len(staged)) + " != blob "
            + String(blob_size),
        )
    for i in range(len(chunks)):
        ref c = chunks[i]
        var cdata = List[UInt8]()
        for j in range(Int(c.length)):
            cdata.append(staged[Int(c.offset) + j])
        var csha = sha256_hex(cdata)
        if csha != chunk_shas[i]:
            raise herror(
                "FirmwareCorrupt",
                "chunk " + String(i) + " readback sha " + csha
                + " != staged sha " + chunk_shas[i],
            )
    # Whole-image check: blob never modified in memory.
    var blob_sha = sha256_hex(blob)
    var staged_sha = sha256_hex(staged)
    if blob_sha != staged_sha:
        raise herror(
            "FirmwareCorrupt",
            "staging image sha " + staged_sha + " != blob sha " + blob_sha,
        )
    return blob_sha


# --- H075/H076 pollers (explicit state machines) -----------------------------
struct BootPoller:
    var budget_ms: Int64
    var alive_pattern: UInt32
    var alive_mask: UInt32
    var samples: List[UInt32]
    var sample_ms: List[Int64]

    def __init__(
        out self, budget_ms: Int64, alive_pattern: UInt32, alive_mask: UInt32
    ):
        self.budget_ms = budget_ms
        self.alive_pattern = alive_pattern
        self.alive_mask = alive_mask
        self.samples = List[UInt32]()
        self.sample_ms = List[Int64]()

    def step(mut self, now_ms: Int64, start_ms: Int64, status: UInt32) raises -> Int:
        # Returns 1 when the alive pattern is seen, 0 to keep polling;
        # raises FirmwareBootTimeout (with the last 20 samples) past the
        # budget. now_ms comes from os_clock_ms (monotonic).
        self.samples.append(status)
        self.sample_ms.append(now_ms)
        if (status & self.alive_mask) == (
            self.alive_pattern & self.alive_mask
        ):
            return 1
        if now_ms - start_ms > self.budget_ms:
            var tail = String("")
            var from_i = 0
            if len(self.samples) > 20:
                from_i = len(self.samples) - 20
            for i in range(from_i, len(self.samples)):
                tail += "0x" + String(Int(self.samples[i])) + "@"
                tail += String(self.sample_ms[i]) + "ms "
            raise herror(
                "FirmwareBootTimeout",
                "boot handshake exceeded " + String(self.budget_ms)
                + "ms budget; last samples: " + tail,
            )
        return 0


struct ReadyPoller:
    var budget_ms: Int64
    var ready_pattern: UInt32
    var ready_mask: UInt32

    def __init__(
        out self, budget_ms: Int64, ready_pattern: UInt32, ready_mask: UInt32
    ):
        self.budget_ms = budget_ms
        self.ready_pattern = ready_pattern
        self.ready_mask = ready_mask

    def step(self, now_ms: Int64, start_ms: Int64, status: UInt32) raises -> Int:
        # Returns 1 when ready; raises DeviceNotReady with the register
        # dump past the budget (H076 acceptance).
        if (status & self.ready_mask) == (
            self.ready_pattern & self.ready_mask
        ):
            return 1
        if now_ms - start_ms > self.budget_ms:
            raise herror(
                "DeviceNotReady",
                "device_ready timed out after " + String(self.budget_ms)
                + "ms; status register dump: 0x" + String(Int(status)),
            )
        return 0
