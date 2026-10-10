# SMIÐR minimal command descriptor builder (H103).
#
# Builds well-formed command descriptors for three op types. HONESTY
# CONTRACT (L5, H101): every field is either study-documented (with the
# study cited in the field's doc comment) or explicitly marked UNKNOWN.
# The builder NEVER invents a chip encoding: where the chip's expected
# bit layout is unknown, the descriptor carries an explicit UNKNOWN
# sentinel with documented meaning — "no magic bytes without a
# documented meaning" (H104 acceptance, applied here too).
#
# Op types:
#   NOOP   — the mailbox IDENTIFY command, byte-exact per H101 §4
#            (study: control_protocol.h opcode table + packed layout).
#   MEMCPY — SMIÐR envelope carrying the studied VDMA descriptor FIELD
#            SET (study: HAILO_PCIE_TRANSPORT_GUIDE.md §4 — page-size/
#            control, address low/high halves, remaining/status). The
#            exact chip-side byte layout is UNCORROBORATED (BAR2 never
#            programmed live); this descriptor is host-side intent, not
#            a chip-executable program.
#   VECADD — SMIÐR envelope with tensor descriptors (H019 element 2)
#            and an explicitly-UNKNOWN compute section (H019 element 1
#            encoding unknown). The UNKNOWN sentinel proves the builder
#            did not fabricate a chip encoding.
#
# Mojo 1.1 note: move semantics forbid transferring a borrowed value
# into a struct field, and `owned` params are gone — so builders return
# the payload List directly and notes ride alongside as Strings. All
# cross-function value passing is borrowed reads or owned temporaries.

from hailbru.errors import herror


def OP_NOOP() -> Int:
    return 0


def OP_MEMCPY() -> Int:
    return 1


def OP_VECADD() -> Int:
    return 2


def DESC_MAGIC() -> UInt32:
    # "SMDR" — SMIÐR's own magic; never confusable with a vendor HEF (L3).
    return UInt32(0x534D4452)


def DESC_VERSION() -> UInt32:
    return UInt32(1)


def DTYPE_FP16() -> UInt32:
    return UInt32(1)


def COMPUTE_UNKNOWN() -> UInt32:
    # Sentinel: the chip's compute encoding is unknown; SMIÐR emits this
    # instead of inventing bytes. Documented meaning, not magic.
    return UInt32(0xFFFFFFFF)


struct ByteBuf:
    var data: List[UInt8]

    def __init__(out self):
        self.data = List[UInt8]()

    def put_u32(mut self, v: UInt32):
        for i in range(4):
            self.data.append(UInt8((v >> UInt32(8 * i)) & UInt32(0xFF)))

    def put_u16(mut self, v: UInt16):
        self.data.append(UInt8(v & UInt16(0xFF)))
        self.data.append(UInt8((v >> UInt16(8)) & UInt16(0xFF)))

    def take(mut self) -> List[UInt8]:
        # Move-out (self.data^) is rejected: the field must stay
        # initialized at return. Copy element-wise, then reset.
        var out = List[UInt8]()
        for i in range(len(self.data)):
            out.append(self.data[i])
        self.data = List[UInt8]()
        return out^


def _envelope(op: Int, body: List[UInt8]) -> List[UInt8]:
    var out = ByteBuf()
    out.put_u32(DESC_MAGIC())
    out.put_u32(DESC_VERSION())
    out.put_u32(UInt32(op))
    out.put_u32(UInt32(len(body)))
    for i in range(len(body)):
        out.data.append(body[i])
    return out.take()


def _hex_of(payload: List[UInt8]) -> String:
    var s = String("")
    for i in range(len(payload)):
        var v = Int(payload[i])
        var hi = v >> 4
        var lo = v & 15
        s += String(chr(48 + hi if hi < 10 else 87 + hi))
        s += String(chr(48 + lo if lo < 10 else 87 + lo))
    return s


def desc_to_json(name: String, op: Int, payload: List[UInt8], notes: String) -> String:
    var js = String("{\"name\": \"" + name + "\", ")
    js += "\"op\": " + String(op) + ", "
    js += "\"bytes\": \"" + _hex_of(payload) + "\", "
    js += "\"len\": " + String(len(payload)) + ", "
    js += "\"notes\": \"" + notes + "\"}"
    return js


def build_noop() -> List[UInt8]:
    # Byte-exact IDENTIFY mailbox command per H101 §4: u32 length (8)
    # followed by the 8-byte packed request (version=2, opcode=0).
    var body = ByteBuf()
    body.put_u32(UInt32(8))
    body.put_u32(UInt32(2))
    body.put_u32(UInt32(0))
    return _envelope(OP_NOOP(), body.take())


def noop_notes() -> String:
    return String(
        "NOOP: firmware mailbox IDENTIFY (H101 section 4). "
        "Byte-exact: len=8, version=2, opcode=0. Side-effect-free."
    )


def _is_pow2(v: Int) -> Bool:
    return v > 0 and (v & (v - 1)) == 0


def build_memcpy(
    src_addr: UInt64, dst_addr: UInt64, nbytes: Int, page_size: Int
) raises -> List[UInt8]:
    # Fail closed on malformed inputs BEFORE emitting any bytes.
    if nbytes <= 0:
        raise herror("BadDescriptor", "memcpy nbytes must be positive")
    if not _is_pow2(page_size):
        raise herror("BadDescriptor", "memcpy page_size must be a power of 2")
    if src_addr == dst_addr:
        raise herror("BadDescriptor", "memcpy src == dst")
    var body = ByteBuf()
    body.put_u32(UInt32(page_size))  # page-size/control (study §4)
    body.put_u32(UInt32(src_addr & UInt64(0xFFFFFFFF)))  # addr low
    body.put_u32(UInt32(src_addr >> UInt64(32)))  # addr high
    body.put_u32(UInt32(dst_addr & UInt64(0xFFFFFFFF)))
    body.put_u32(UInt32(dst_addr >> UInt64(32)))
    body.put_u32(UInt32(nbytes))
    body.put_u32(UInt32(0))  # remaining/status: engine-updated (study §4)
    return _envelope(OP_MEMCPY(), body.take())


def memcpy_notes() -> String:
    return String(
        "MEMCPY: studied VDMA descriptor field set "
        "(HAILO_PCIE_TRANSPORT_GUIDE.md section 4). Host-side intent; "
        "chip-side BAR2 programming UNCORROBORATED — not claimed "
        "chip-executable."
    )


def build_vecadd(
    a_dtype: UInt32,
    a_nelems: Int,
    b_dtype: UInt32,
    b_nelems: Int,
    c_dtype: UInt32,
    c_nelems: Int,
) raises -> List[UInt8]:
    # Fail closed on malformed inputs BEFORE emitting any bytes.
    if a_nelems <= 0 or b_nelems <= 0 or c_nelems <= 0:
        raise herror("BadDescriptor", "vecadd tensor has zero length")
    if a_dtype != DTYPE_FP16() or b_dtype != DTYPE_FP16():
        raise herror("BadDescriptor", "vecadd inputs must be fp16")
    if c_dtype != DTYPE_FP16():
        raise herror("BadDescriptor", "vecadd output must be fp16")
    if a_nelems != b_nelems or a_nelems != c_nelems:
        raise herror(
            "BadDescriptor", "vecadd tensor element counts differ"
        )
    var body = ByteBuf()
    body.put_u32(DTYPE_FP16())
    body.put_u32(UInt32(a_nelems))
    body.put_u32(UInt32(1))  # ndim = 1
    body.put_u32(UInt32(a_nelems))  # dim0
    # Compute section: explicitly UNKNOWN — SMIÐR does not invent the
    # chip's vector-add encoding (H019 element 1). The sentinel's
    # meaning is documented; it is not magic.
    body.put_u32(COMPUTE_UNKNOWN())
    body.put_u32(UInt32(0))  # flags, reserved
    return _envelope(OP_VECADD(), body.take())


def vecadd_notes(nelems: Int) -> String:
    return String(
        "VECADD: tensor descriptors per H019 element 2 (fp16, length "
        + String(nelems) + "). Compute encoding UNKNOWN "
        "(H019 element 1): sentinel 0xFFFFFFFF marks the unfilled "
        "chip section. Not chip-executable until the encoding is "
        "learned; H105 will test this."
    )
