"""KV persistence accounting + int8 store serialisation
(Janas road J-096).

The roadmap text: "KV persistence question. Session KV
saved/restored across restarts (the long-prompt re-read
avoided): benefit measured; privacy/storage shape
decided on evidence; built only if it pays."

DESIGN, stated up front (the J-096 doc,
docs/janas/J096_KV_PERSISTENCE.md, is its normative
text; this header records the definitions and verdict
rules PRE-REGISTERED before any J-096 number was
produced).

(a) THE PERSISTENCE QUESTION AND ITS CANDIDATE
SHAPES. A session that ends with a long prompt's KV
in memory loses it; the next session pays the whole
prompt read again (J-094's account: work, KV written,
touch shapes). Persistence saves the KV to a file at
session end and restores it at the next open, so the
read is paid once. Candidate shapes, all priced in
this module:
  FULL -- every committed position's KV is saved
    (the whole prompt's rows), per precision (f16
    through J-087's census, per-row int8 through
    J-088's store).
  PREFIX -- only the first P positions are saved
    (the shared-prefix case: a system prompt / file
    header many sessions begin with); a later prompt
    of L > P tokens restores P rows and reads only
    the suffix.
No other shape is priced: per-layer or per-head
partial saves break attention's need for every
layer's rows at a position, and a shape that saves
rows past the committed length saves dead state
(J-095's dead rows) by definition.

(b) BENEFIT DEFINITION (filed units only; no wall is
measured on this VM in this slice, so the benefit is
graded in the account's own units, exactly as J-094
graded the read). For a FULL save/restore at length
L, per precision:
  WORK AVOIDED = J-094's read work at L (prefill
    attention + projection MACs, through
    core/prompt_read over core/kv_ladder over
    core/prefill_anatomy). Restoring avoids the
    read's work and nothing else: the model still
    loads, and the first generated token still pays
    its head pass (J-094 section 2 -- never charged
    to the read, never claimed as saved here).
  FILE BYTES = KVP_OVERHEAD_BYTES (64 header + 8
    trailer, the serialised form of section (d))
    plus the KV total at L at the precision (through
    core/kv_account for f16, core/kv_int8 for int8,
    so this account cannot drift from J-087/J-088).
  TRAFFIC = 2 x FILE BYTES (one write at save, one
    read at restore -- both directions charged, so
    the benefit is never graded on the restore leg
    alone).
  RE-READ TOUCH = J-094's host-batched touch shape
    at L at the SAME precision (KV read shape +
    weight-pass bytes + KV written, through
    core/prompt_read): the conservative surface
    comparator -- the host-batched shape is the
    smallest surface shape J-094 files at either
    precision (the GPU width-1 shape is larger at
    every rung), so the benefit is graded against
    the cheapest re-read the tree offers.
  WORK PER TRAFFIC BYTE = WORK AVOIDED // TRAFFIC
    (floored; exact integer arithmetic).
For a PREFIX save of P at a prompt of L > P: WORK
AVOIDED = the read work at P exactly (the suffix's
remaining work is W(L) - W(P) by the causal-pair
account: suffix projections are per-token constant
and suffix attention pairs are the total pairs
minus the prefix pairs -- conservation asserted in
the tests, not assumed); FILE BYTES and TRAFFIC as
above at P. STORAGE BURDEN = FILE BYTES as floored
ppm of the model's file bytes, and a file larger
than the model it serves is a burden failure at
that rung whatever the work says.

(c) PRIVACY / STORAGE SHAPE, AND ITS DECISION RULE.
A saved KV file is PROMPT-EQUIVALENT data: its rows
are a deterministic function of the prompt's tokens
and the model's weights (J-087's layout, J-088's
quantizer), a restored store continues the prompt
exactly (that is the feature), and the file must
therefore be handled as the prompt's plaintext is
handled. A persistence SHAPE is the tuple (opt-in
per save, owner-only access, bound to the model +
shape + length it came from with mismatch refused,
explicitly deletable in one operation, confined to
the engine's cache home). DECISION RULE
(pre-registered): a shape is ACCEPTED iff all five
properties hold; any shape missing one is REJECTED
as a persistence shape whatever its benefit --
silence, sharing, unbound reuse, undeletable
retention or stray copies are each disqualifying.
The graded shapes: SILENT (default-on, unbound,
cache-home, deletable, owner-only by platform
default alone is NOT counted as owner-only -- the
shape must state it) REJECTED; SHARED
(world-readable or synced) REJECTED; OPT-IN
(explicit save, owner-only, bound, deletable,
cache-home) the only ACCEPTED shape. Location,
permissions and deletion are HOST duties at session
level (no session is wired in this slice); the
module grades shapes mechanically
(kvp_privacy_verdict) and enforces the BINDING
property at the store level (the fingerprint of
section (d)).

(d) THE SERIALISED FORM (int8; built only under the
verdict rule below). Byte layout, all integers
little-endian u64 by arithmetic, scales as their
exact f32 bytes:
  header 64 B: magic "AESIRKV1" (8 B), then layers,
    kv_heads, head_dim, max_seq_len, saved_len,
    kv_width, fingerprint (7 x 8 B). The fingerprint
    is a caller-stated opaque non-negative integer
    the host derives from the model file (its sha
    pin's first bytes, by host contract); the module
    stores and compares it, it does not derive it.
  payload: the committed positions only -- for
    each layer in order: its K codes segment
    (saved_len x kv_width bytes), its V codes
    segment, its K scales segment (saved_len x
    kv_heads f32), its V scales segment -- exactly
    saved_len x the per-row int8 per-token price in
    total, no dead rows.
  trailer 8 B: a corruption checksum (rolling
    h = (h*31 + byte) mod 2^31-1 over header +
    payload) as u64. It detects corruption; it is
    not a signature and authenticates nothing.
Restore refuses: wrong magic, implausible shape,
saved_len outside (0, capacity], kv_width not
heads x head_dim, fingerprint mismatch against the
caller's expectation, total length not exactly
header + payload + trailer, checksum mismatch.
Round-trip exactness is graded in J-095's R-B form
at the precision's own representation: the restored
store must equal the saved store BIT-EXACT (codes
and scales, through core/kv_drafts' diff functions)
over the saved length -- the serialisation is
lossless by construction (every stored scalar is
copied verbatim), and the tests prove the
construction, they do not assume it.

VERDICT RULE (pre-registered) -- BUILT ONLY IF IT
PAYS. The minimal mechanism of section (d) is built
iff ALL of:
  (1) ACCOUNT BENEFIT: at every ladder rung
    (1024..32768) and both precisions, the FULL
    shape's benefit verdict is PAYS, where PAYS
    means TRAFFIC < RE-READ TOUCH and WORK AVOIDED
    >= TRAFFIC x KVP_MIN_WORK_PER_TRAFFIC_BYTE
    (1000 MACs per traffic byte -- three orders of
    magnitude, stated before measuring; a shape
    whose restore traffic rivals the re-read it
    replaces, or whose saved work is thin per byte
    moved, does not pay), and the STORAGE BURDEN
    holds at every rung (FILE BYTES <= the witness
    file's bytes);
  (2) EXACTNESS IS PROVABLE at the store level in
    the R-B form above (the format is lossless by
    construction -- if the round-trip exercise
    showed any diff, the mechanism would be
    withdrawn, not filed);
  (3) AN ACCEPTED PRIVACY SHAPE EXISTS under rule
    (c) (it does iff the OPT-IN shape grades
    ACCEPTED).
A measured REJECTION (nothing built) is a complete
closure on this road (J-025 / J-027 / J-090
precedents); the verdict is whatever the filed
numbers say. The F16 mechanism is NOT built even
if the rule passes: no List-backed f16 store
exists to serialise (the host cache is the well's
RuneTensor storage, J-087 section 3.1), so f16
persistence is priced here and its mechanism is
deferred to the J-098 gate recipe with the host
integration (J-088 section 7). Session wiring is
NOT built at either precision: int8 session
integration is INTEGRATION_BLOCKED (J-091) and no
session constructs a restored store today -- the
inspect asserts the no-wiring fact. Every live
benefit (any wall, any tok/s, any end-to-end
restart) is NOT PROVEN in this slice and is filed
as DEFERRED-WITH-REASON to the J-098 gate.

WHY THIS IS NOT J-027'S QUESTION. J-027 rejected
persisting an expert MAP because a prefetch fetch
costs exactly the demand miss it replaces
(conservation, proven there). A KV row's restore
fetch costs its stored bytes once, while re-reading
its token costs full projections plus attention
over every prior pair (J-094's account): whether
the same conservation holds here is exactly what
the benefit rule measures, and the rule is stated
so it can fail.

HOST CONTRACT: (1) price every persistence claim
through this module; (2) a save happens only on an
explicit opt-in naming the OPT-IN shape of rule
(c), owner-only in the cache home, deletable by one
explicit operation; (3) restore only through
deserialize_int8_store with the expected fingerprint
stated from the opened model's pin -- a mismatch is
a refusal, never a fallback to a re-read that hides
it (a caller MAY re-read after a refusal, but the
refusal is filed, not smoothed over); (4) a live
wall may be filed only from a run under the J-096
doc section 7 recipe at the J-098 gate (guarded
window, sha-pin, machine state, ids-first
raw-oracle grading, never llama-cli
--single-turn).
"""

from std.collections import InlineArray

from core.kv_account import KV_ELEM_F16, kv_bytes_per_token
from core.kv_int8 import Int8KVStore, kv8_bytes_per_token
from core.prompt_read import read_touch_shape, read_work_total
from core.prefill_anatomy import SURFACE_HOST_BATCHED

comptime KVP_PRECISION_F16 = 0
comptime KVP_PRECISION_INT8 = 1

comptime KVP_PAYS = 0
comptime KVP_DOES_NOT_PAY = 1

comptime KVP_PRIVACY_ACCEPTED = 0
comptime KVP_PRIVACY_REJECTED = 1

comptime KVP_RESTORE_EXACT = 0
comptime KVP_RESTORE_NOT_EXACT = 1

comptime KVP_HEADER_BYTES = 64
comptime KVP_TRAILER_BYTES = 8
comptime KVP_OVERHEAD_BYTES = 72
comptime KVP_MIN_WORK_PER_TRAFFIC_BYTE = 1000
comptime KVP_CHECKSUM_MOD = 2147483647
# A crafted header must not be able to name a store
# whose allocation dwarfs any real cache: total code
# elements (layers x capacity x width) above this are
# refused as an implausible shape before allocation.
comptime KVP_MAX_STORE_ELEMENTS = 268435456


def kvp_precision_name(code: Int) raises -> String:
    if code == KVP_PRECISION_F16:
        return String("f16")
    if code == KVP_PRECISION_INT8:
        return String("int8")
    raise Error("KVPersistence: unknown precision code")


def kvp_benefit_name(code: Int) raises -> String:
    if code == KVP_PAYS:
        return String("PAYS")
    if code == KVP_DOES_NOT_PAY:
        return String("DOES_NOT_PAY")
    raise Error("KVPersistence: unknown benefit verdict code")


def kvp_privacy_name(code: Int) raises -> String:
    if code == KVP_PRIVACY_ACCEPTED:
        return String("ACCEPTED")
    if code == KVP_PRIVACY_REJECTED:
        return String("REJECTED")
    raise Error("KVPersistence: unknown privacy verdict code")


def kvp_restore_name(code: Int) raises -> String:
    if code == KVP_RESTORE_EXACT:
        return String("EXACT")
    if code == KVP_RESTORE_NOT_EXACT:
        return String("NOT_EXACT")
    raise Error("KVPersistence: unknown restore verdict code")


# -- accounting ---------------------------------------------------------


def kvp_per_token(
    precision: Int, layers: Int, kv_heads: Int, head_dim: Int
) raises -> Int:
    """KV bytes per token at a precision, through the
    precision's own accounting (J-087 f16 census,
    J-088 per-row int8 store price)."""
    if precision == KVP_PRECISION_F16:
        return kv_bytes_per_token(layers, kv_heads, head_dim, KV_ELEM_F16)
    if precision == KVP_PRECISION_INT8:
        return kv8_bytes_per_token(layers, kv_heads, head_dim)
    raise Error("KVPersistence: unknown precision code")


def kvp_kv_bytes(
    precision: Int, layers: Int, kv_heads: Int, head_dim: Int, length: Int
) raises -> Int:
    """KV bytes held by `length` committed positions."""
    if length <= 0:
        raise Error("KVPersistence: a save length must be positive")
    return kvp_per_token(precision, layers, kv_heads, head_dim) * length


def kvp_file_bytes(
    precision: Int, layers: Int, kv_heads: Int, head_dim: Int, length: Int
) raises -> Int:
    """Serialised file bytes for a save of `length`
    positions: the stated overhead (header + trailer)
    plus the KV bytes -- the format stores committed
    positions only, never dead rows or free capacity."""
    return KVP_OVERHEAD_BYTES + kvp_kv_bytes(
        precision, layers, kv_heads, head_dim, length
    )


def kvp_traffic_bytes(
    precision: Int, layers: Int, kv_heads: Int, head_dim: Int, length: Int
) raises -> Int:
    """Total persistence traffic of one save/restore
    cycle: the file written once and read once."""
    return 2 * kvp_file_bytes(precision, layers, kv_heads, head_dim, length)


def kvp_read_work(
    layers: Int,
    hidden: Int,
    q_width: Int,
    kv_width: Int,
    ffn: Int,
    length: Int,
) raises -> Int:
    """J-094's prompt-read work at `length` (attention
    + projection MACs), through core/prompt_read. A
    FULL restore at L avoids exactly this at L; a
    PREFIX restore of P avoids exactly this at P."""
    if length <= 0:
        raise Error("KVPersistence: a read length must be positive")
    return read_work_total(layers, hidden, q_width, kv_width, ffn, length)


def kvp_prefix_remaining_work(
    layers: Int,
    hidden: Int,
    q_width: Int,
    kv_width: Int,
    ffn: Int,
    prompt_length: Int,
    prefix_length: Int,
) raises -> Int:
    """Work a prompt of `prompt_length` still pays
    after restoring a prefix of `prefix_length`:
    W(L) - W(P) exactly (the header's conservation)."""
    if prefix_length <= 0 or prefix_length >= prompt_length:
        raise Error(
            "KVPersistence: a prefix must satisfy 0 < prefix < prompt length"
        )
    return kvp_read_work(
        layers, hidden, q_width, kv_width, ffn, prompt_length
    ) - kvp_read_work(layers, hidden, q_width, kv_width, ffn, prefix_length)


def kvp_reread_touch(
    precision: Int, layers: Int, kv_heads: Int, head_dim: Int,
    length: Int, weights_bytes: Int,
) raises -> Int:
    """The re-read the restore replaces, in J-094's
    conservative comparator form: the host-batched
    touch shape at the precision's per-token price."""
    if weights_bytes <= 0:
        raise Error("KVPersistence: weights must be positive")
    var pt = kvp_per_token(precision, layers, kv_heads, head_dim)
    return read_touch_shape(pt, SURFACE_HOST_BATCHED, length, weights_bytes)


def kvp_work_per_traffic_byte(work_avoided: Int, traffic_bytes: Int) raises -> Int:
    """Floored MACs of avoided read work per byte of
    persistence traffic (both directions charged)."""
    if work_avoided <= 0 or traffic_bytes <= 0:
        raise Error("KVPersistence: work and traffic must be positive")
    return work_avoided // traffic_bytes


def kvp_benefit_verdict(
    work_avoided: Int, traffic_bytes: Int, reread_touch: Int
) raises -> Int:
    """The header's rule (1) in mechanical form: PAYS
    iff the traffic is strictly below the re-read
    touch it replaces AND the avoided work is at
    least KVP_MIN_WORK_PER_TRAFFIC_BYTE per traffic
    byte. Any other outcome is DOES_NOT_PAY, filed
    with its numbers, never rounded into a pass."""
    if work_avoided <= 0 or traffic_bytes <= 0 or reread_touch <= 0:
        raise Error("KVPersistence: benefit inputs must be positive")
    if traffic_bytes >= reread_touch:
        return KVP_DOES_NOT_PAY
    if work_avoided < traffic_bytes * KVP_MIN_WORK_PER_TRAFFIC_BYTE:
        return KVP_DOES_NOT_PAY
    return KVP_PAYS


def kvp_storage_ppm(file_bytes: Int, weights_bytes: Int) raises -> Int:
    """The save file's size as floored parts per
    million of the model file it serves."""
    if file_bytes <= 0 or weights_bytes <= 0:
        raise Error("KVPersistence: storage inputs must be positive")
    return file_bytes * 1000000 // weights_bytes


def kvp_storage_ok(file_bytes: Int, weights_bytes: Int) raises -> Bool:
    """The burden half of rule (1): a persistence
    file larger than the model file fails at that
    rung whatever the work account says."""
    if file_bytes <= 0 or weights_bytes <= 0:
        raise Error("KVPersistence: storage inputs must be positive")
    return file_bytes <= weights_bytes


# -- privacy shape verdict (rule (c)) -----------------------------------


struct PersistPrivacyShape(Copyable, ImplicitlyCopyable):
    """One persistence shape's five graded properties
    (the header's rule (c)): explicit opt-in per save,
    owner-only access, binding to model + shape +
    length with mismatch refused, one-operation
    explicit deletion, confinement to the cache home."""

    var opt_in: Bool
    var owner_only: Bool
    var bound: Bool
    var deletable: Bool
    var confined: Bool

    def __init__(
        out self,
        opt_in: Bool,
        owner_only: Bool,
        bound: Bool,
        deletable: Bool,
        confined: Bool,
    ):
        self.opt_in = opt_in
        self.owner_only = owner_only
        self.bound = bound
        self.deletable = deletable
        self.confined = confined


def kvp_privacy_verdict(shape: PersistPrivacyShape) -> Int:
    """ACCEPTED iff all five properties hold; any one
    missing rejects the shape outright."""
    if (
        shape.opt_in
        and shape.owner_only
        and shape.bound
        and shape.deletable
        and shape.confined
    ):
        return KVP_PRIVACY_ACCEPTED
    return KVP_PRIVACY_REJECTED


# -- the serialised int8 form (section (d)) -----------------------------


def _put_u64(mut out: List[UInt8], value: Int) raises:
    if value < 0:
        raise Error("KVPersistence: a header field cannot be negative")
    var t = value
    for _ in range(8):
        out.append(UInt8(t % 256))
        t //= 256
    if t != 0:
        raise Error("KVPersistence: a header field exceeds 64 bits")


def _get_u64(data: List[UInt8], offset: Int) raises -> Int:
    if offset < 0 or offset + 8 > len(data):
        raise Error("KVPersistence: a header field lies outside the file")
    var value = 0
    var mult = 1
    for i in range(8):
        value += Int(data[offset + i]) * mult
        mult *= 256
    return value


def _put_f32(mut out: List[UInt8], value: Float32):
    var arr = InlineArray[Float32, 1](fill=value)
    var bp = arr.unsafe_ptr().unsafe_bitcast[UInt8]()
    for i in range(4):
        out.append(bp.unsafe_load(i))


def _get_f32(data: List[UInt8], offset: Int) raises -> Float32:
    if offset < 0 or offset + 4 > len(data):
        raise Error("KVPersistence: a scale lies outside the file")
    var arr = InlineArray[UInt8, 4](fill=UInt8(0))
    for i in range(4):
        arr[i] = data[offset + i]
    return arr.unsafe_ptr().unsafe_bitcast[Float32]().unsafe_load(0)


def _put_code(mut out: List[UInt8], code: Int8):
    var v = Int(code)
    out.append(UInt8(v + 256) if v < 0 else UInt8(v))


def _get_code(byte: UInt8) -> Int8:
    var v = Int(byte)
    return Int8(v - 256) if v >= 128 else Int8(v)


def kvp_checksum(data: List[UInt8]) -> Int:
    """The trailer's corruption checksum: rolling
    h = (h*31 + byte) mod (2^31 - 1) over every byte
    before the trailer. Detects corruption; it is not
    a signature and authenticates nothing."""
    var h = 0
    for i in range(len(data)):
        h = (h * 31 + Int(data[i])) % KVP_CHECKSUM_MOD
    return h


def kvp_serialized_len(
    layers: Int, kv_heads: Int, head_dim: Int, saved_len: Int
) raises -> Int:
    """The exact byte length serialize_int8_store
    produces for a store of this shape at this saved
    length: kvp_file_bytes at int8, by construction."""
    return kvp_file_bytes(KVP_PRECISION_INT8, layers, kv_heads, head_dim, saved_len)


def serialize_int8_store(
    store: Int8KVStore, saved_len: Int, fingerprint: Int
) raises -> List[UInt8]:
    """Serialise the store's committed positions
    (0..<saved_len) in the section (d) form. Positions
    at or past saved_len are dead or unwritten and are
    never stored. The fingerprint is the caller's
    opaque model binding (host contract (3))."""
    if saved_len <= 0 or saved_len > store.max_seq_len:
        raise Error(
            "KVPersistence: saved_len must sit inside (0, capacity]"
        )
    if fingerprint < 0:
        raise Error("KVPersistence: the fingerprint cannot be negative")
    var out = List[UInt8]()
    var magic: List[Int] = [65, 69, 83, 73, 82, 75, 86, 49]  # AESIRKV1
    for i in range(8):
        out.append(UInt8(magic[i]))
    _put_u64(out, store.layers)
    _put_u64(out, store.kv_heads)
    _put_u64(out, store.head_dim)
    _put_u64(out, store.max_seq_len)
    _put_u64(out, saved_len)
    _put_u64(out, store.kv_width)
    _put_u64(out, fingerprint)
    # Payload: per layer K codes, V codes, K scales, V scales.
    for layer in range(store.layers):
        var cbase = (layer * store.max_seq_len) * store.kv_width
        var n = saved_len * store.kv_width
        for j in range(n):
            _put_code(out, store.k_data[cbase + j])
        for j in range(n):
            _put_code(out, store.v_data[cbase + j])
        var sbase = (layer * store.max_seq_len) * store.kv_heads
        var m = saved_len * store.kv_heads
        for j in range(m):
            _put_f32(out, store.k_scales[sbase + j])
        for j in range(m):
            _put_f32(out, store.v_scales[sbase + j])
    var trailer = kvp_checksum(out)
    _put_u64(out, trailer)
    return out^


struct RestoredKV(Movable):
    """A restored int8 store plus the header facts its
    file carried: the saved length the caller resumes
    at, and the fingerprint it was bound to."""

    var store: Int8KVStore
    var saved_len: Int
    var fingerprint: Int

    def __init__(
        out self, store: Int8KVStore, saved_len: Int, fingerprint: Int
    ):
        self.store = store.copy()
        self.saved_len = saved_len
        self.fingerprint = fingerprint


def deserialize_int8_store(
    data: List[UInt8], expected_fingerprint: Int
) raises -> RestoredKV:
    """Parse and verify a serialised int8 store (the
    header's refusal list, in order: size, magic,
    shape, binding, exact length, checksum), then
    rebuild the store with its committed positions in
    place. Any refusal raises; nothing is partially
    restored and no fallback hides a refusal."""
    if expected_fingerprint < 0:
        raise Error("KVPersistence: the expected fingerprint cannot be negative")
    if len(data) < KVP_OVERHEAD_BYTES:
        raise Error("KVPersistence: the file is shorter than header + trailer")
    var magic: List[Int] = [65, 69, 83, 73, 82, 75, 86, 49]  # AESIRKV1
    for i in range(8):
        if Int(data[i]) != magic[i]:
            raise Error("KVPersistence: bad magic -- not an AESIRKV1 file")
    var layers = _get_u64(data, 8)
    var kv_heads = _get_u64(data, 16)
    var head_dim = _get_u64(data, 24)
    var capacity = _get_u64(data, 32)
    var saved_len = _get_u64(data, 40)
    var kv_width = _get_u64(data, 48)
    var fingerprint = _get_u64(data, 56)
    if layers <= 0 or kv_heads <= 0 or head_dim <= 0 or capacity <= 0:
        raise Error("KVPersistence: the header names an implausible shape")
    if kv_width != kv_heads * head_dim:
        raise Error("KVPersistence: the header's kv_width is inconsistent")
    if layers * capacity * kv_width > KVP_MAX_STORE_ELEMENTS:
        raise Error("KVPersistence: the header names an implausible shape")
    if saved_len <= 0 or saved_len > capacity:
        raise Error("KVPersistence: saved_len lies outside (0, capacity]")
    if fingerprint != expected_fingerprint:
        raise Error(
            "KVPersistence: fingerprint mismatch -- the file is bound to a"
            " different model than the caller opened; refusing"
        )
    var expected_len = kvp_serialized_len(layers, kv_heads, head_dim, saved_len)
    if len(data) != expected_len:
        raise Error(
            "KVPersistence: the file length is not exactly header + payload"
            " + trailer for its header"
        )
    var body = List[UInt8]()
    for i in range(len(data) - KVP_TRAILER_BYTES):
        body.append(data[i])
    if _get_u64(data, len(data) - KVP_TRAILER_BYTES) != kvp_checksum(body):
        raise Error("KVPersistence: checksum mismatch -- the file is corrupt")
    var store = Int8KVStore(layers, kv_heads, head_dim, capacity)
    var offset = KVP_HEADER_BYTES
    for layer in range(layers):
        var cbase = (layer * capacity) * kv_width
        var n = saved_len * kv_width
        for j in range(n):
            store.k_data[cbase + j] = _get_code(data[offset + j])
        offset += n
        for j in range(n):
            store.v_data[cbase + j] = _get_code(data[offset + j])
        offset += n
        var sbase = (layer * capacity) * kv_heads
        var m = saved_len * kv_heads
        for j in range(m):
            store.k_scales[sbase + j] = _get_f32(data, offset + j * 4)
        offset += m * 4
        for j in range(m):
            store.v_scales[sbase + j] = _get_f32(data, offset + j * 4)
        offset += m * 4
    return RestoredKV(store^, saved_len, fingerprint)


def kvp_restore_verdict(diff_count: Int) raises -> Int:
    """The R-B form of J-095, for a restored store:
    EXACT iff its stored-representation difference
    against the saved store over the saved length is
    exactly zero (codes and scales, counted through
    core/kv_drafts by the caller)."""
    if diff_count < 0:
        raise Error("KVPersistence: a difference count cannot be negative")
    if diff_count == 0:
        return KVP_RESTORE_EXACT
    return KVP_RESTORE_NOT_EXACT
