"""KV persistence (J-096): the benefit account graded
against J-094's filed read totals EXACTLY, the prefix
conservation, the storage burden, the privacy shape
verdicts, and the int8 store serialise/restore
round-trip graded bit-exact in J-095's R-B form with
its refusal and tamper controls. No live session, no
wall, no live restart claimed here: the live legs are
deferred to the J-098 gate recipe in the J-096 doc
(section 7).
"""
from core.kv_drafts import (
    int8_code_diff_count,
    int8_max_dequant_diff,
    int8_scale_diff_count,
    int8_state_diff_count,
)
from core.kv_int8 import Int8KVStore, attention_int8_head
from core.kv_ladder import ladder_rung
from core.kv_persistence import (
    KVP_DOES_NOT_PAY,
    KVP_PAYS,
    KVP_PRECISION_F16,
    KVP_PRECISION_INT8,
    KVP_PRIVACY_ACCEPTED,
    KVP_PRIVACY_REJECTED,
    KVP_RESTORE_EXACT,
    PersistPrivacyShape,
    deserialize_int8_store,
    kvp_benefit_name,
    kvp_benefit_verdict,
    kvp_checksum,
    kvp_file_bytes,
    kvp_kv_bytes,
    kvp_per_token,
    kvp_prefix_remaining_work,
    kvp_privacy_name,
    kvp_privacy_verdict,
    kvp_read_work,
    kvp_reread_touch,
    kvp_restore_name,
    kvp_restore_verdict,
    kvp_serialized_len,
    kvp_storage_ok,
    kvp_storage_ppm,
    kvp_traffic_bytes,
    kvp_work_per_traffic_byte,
    serialize_int8_store,
)

# The ladder witness (J-091/J-094): Qwen2.5-Coder-7B.
comptime LAYERS = 28
comptime HEADS = 4
comptime HD = 128
comptime HIDDEN = 3584
comptime QW = 3584
comptime KVW = 512
comptime FFN = 18944
comptime WEIGHTS = 4683074688

# The round-trip exercise's store shape (J-095's).
comptime SLAYERS = 2
comptime SHEADS = 2
comptime SHD = 16
comptime SWIDTH = 32
comptime SCAP = 24
comptime SLEN = 11
comptime FINGERPRINT = 424242


def expect_eq(actual: Int, expected: Int, what: String) raises:
    if actual != expected:
        raise Error(
            "KVPersistence " + what + ": expected " + String(expected)
            + ", got " + String(actual)
        )


def expect_true(cond: Bool, what: String) raises:
    if not cond:
        raise Error("KVPersistence: expected true -- " + what)


def synth(i: Int) -> Float32:
    return Float32((i * 37) % 17 - 8) / Float32(8.0)


def row_values(layer: Int, pos: Int, salt: Int) -> List[Float32]:
    var row = List[Float32]()
    for j in range(SWIDTH):
        row.append(synth(layer * 4096 + pos * SWIDTH + j + salt))
    return row^


def append_pos(
    mut store: Int8KVStore, pos: Int, k_salt: Int, v_salt: Int
) raises:
    for layer in range(SLAYERS):
        store.append(
            layer, pos, row_values(layer, pos, k_salt),
            row_values(layer, pos, v_salt),
        )


def build_plain_store() raises -> Int8KVStore:
    var store = Int8KVStore(SLAYERS, SHEADS, SHD, SCAP)
    for pos in range(SLEN):
        append_pos(store, pos, 11, 5000)
    return store^


def query_for(head: Int) -> List[Float32]:
    var q = List[Float32]()
    for j in range(SHD):
        q.append(synth(head * SHD + j + 97))
    return q^


def attn_equal(a: Int8KVStore, b: Int8KVStore, seq_len: Int) raises -> Bool:
    for layer in range(SLAYERS):
        for h in range(SHEADS):
            var oa = attention_int8_head(a, layer, h, query_for(h), seq_len)
            var ob = attention_int8_head(b, layer, h, query_for(h), seq_len)
            for j in range(SHD):
                if oa[j] != ob[j]:
                    return False
    return True


def test_codes_and_prices() raises:
    expect_eq(kvp_per_token(KVP_PRECISION_F16, LAYERS, HEADS, HD), 57344, "Coder f16/token (J-087)")
    expect_eq(kvp_per_token(KVP_PRECISION_INT8, LAYERS, HEADS, HD), 29568, "Coder int8/token (J-088)")
    expect_eq(kvp_per_token(KVP_PRECISION_F16, 32, 8, 128), 131072, "8B f16/token")
    expect_eq(kvp_per_token(KVP_PRECISION_INT8, 32, 8, 128), 67584, "8B int8/token")
    expect_eq(kvp_kv_bytes(KVP_PRECISION_F16, LAYERS, HEADS, HD, 32768), 1879048192, "Coder KV f16 @32768")
    expect_eq(kvp_file_bytes(KVP_PRECISION_INT8, LAYERS, HEADS, HD, 32768), 968884296, "Coder file int8 @32768 (72 overhead)")
    expect_eq(kvp_traffic_bytes(KVP_PRECISION_F16, LAYERS, HEADS, HD, 1024), 117440656, "traffic f16 @1024 = 2 x file")
    expect_eq(kvp_serialized_len(SLAYERS, SHEADS, SHD, SLEN), 1832, "exercise file = 72 + 11 x 160")
    if kvp_benefit_name(KVP_PAYS) != String("PAYS"):
        raise Error("KVPersistence: benefit name")
    if kvp_privacy_name(KVP_PRIVACY_ACCEPTED) != String("ACCEPTED"):
        raise Error("KVPersistence: privacy name")
    if kvp_restore_name(KVP_RESTORE_EXACT) != String("EXACT"):
        raise Error("KVPersistence: restore name")
    print("PASS: codes + prices -- per-token KV through J-087/J-088 accounting; file = 72 + KV; traffic = 2 x file")


def test_gate_work_j094() raises:
    # J-094 section 5.1's filed read-work totals, all rungs.
    var works: List[Int] = [
        6787224829952, 28411619704832, 60190493769728,
        133850004979712, 321576079720448,
    ]
    for i in range(5):
        var rung = ladder_rung(i)
        expect_eq(
            kvp_read_work(LAYERS, HIDDEN, QW, KVW, FFN, rung), works[i],
            "J-094 read work at rung " + String(rung),
        )
    print("PASS: validation gate A -- J-094 read-work totals reproduced EXACTLY at all 5 rungs")


def test_gate_kv_touch_j094() raises:
    # J-094 section 5.1/5.2's filed KV totals and host
    # touch shapes (f16), all rungs.
    var kvf: List[Int] = [
        58720256, 234881024, 469762048, 939524096, 1879048192,
    ]
    var touch: List[Int] = [
        48885150208, 556317853696, 2074708381696,
        7997707460608, 31388577710080,
    ]
    for i in range(5):
        var rung = ladder_rung(i)
        expect_eq(
            kvp_kv_bytes(KVP_PRECISION_F16, LAYERS, HEADS, HD, rung), kvf[i],
            "J-094 KV written f16 at " + String(rung),
        )
        expect_eq(
            kvp_reread_touch(KVP_PRECISION_F16, LAYERS, HEADS, HD, rung, WEIGHTS),
            touch[i], "J-094 host touch f16 at " + String(rung),
        )
    # The int8 CF host touch at the top rung (J-094 5.2).
    expect_eq(
        kvp_reread_touch(KVP_PRECISION_INT8, LAYERS, HEADS, HD, 32768, WEIGHTS),
        16475086012416, "J-094 host touch int8 CF @32768",
    )
    print("PASS: validation gate B -- J-094 KV totals + host touch shapes reproduced EXACTLY (f16 all rungs; int8 CF @32768)")


def test_benefit_account() raises:
    var wpb_f16_1024 = 0
    var wpb_int8_32768 = 0
    for i in range(5):
        var rung = ladder_rung(i)
        var work = kvp_read_work(LAYERS, HIDDEN, QW, KVW, FFN, rung)
        for p in range(2):
            var precision = KVP_PRECISION_F16 if p == 0 else KVP_PRECISION_INT8
            var traffic = kvp_traffic_bytes(precision, LAYERS, HEADS, HD, rung)
            var touch = kvp_reread_touch(precision, LAYERS, HEADS, HD, rung, WEIGHTS)
            expect_eq(
                kvp_benefit_verdict(work, traffic, touch), KVP_PAYS,
                "benefit PAYS at rung " + String(rung),
            )
            expect_true(traffic < touch, "traffic below touch")
        if i == 0:
            wpb_f16_1024 = kvp_work_per_traffic_byte(
                work, kvp_traffic_bytes(KVP_PRECISION_F16, LAYERS, HEADS, HD, rung)
            )
        if i == 4:
            wpb_int8_32768 = kvp_work_per_traffic_byte(
                work, kvp_traffic_bytes(KVP_PRECISION_INT8, LAYERS, HEADS, HD, rung)
            )
    expect_eq(wpb_f16_1024, 57792, "work/traffic-byte f16 @1024 (worst cell)")
    expect_eq(wpb_int8_32768, 165951, "work/traffic-byte int8 @32768")
    # The rule can fail, on both clauses (synthetic inputs):
    expect_eq(kvp_benefit_verdict(1000000, 5000, 4000), KVP_DOES_NOT_PAY, "traffic >= touch does not pay")
    expect_eq(kvp_benefit_verdict(4000000, 5000, 9000000), KVP_DOES_NOT_PAY, "thin work per byte does not pay")
    expect_eq(kvp_benefit_verdict(5000000, 5000, 9000000), KVP_PAYS, "boundary: work == 1000 x traffic pays")
    print("PASS: benefit account -- PAYS at all 5 rungs x both precisions; worst cell 57,792 MACs/traffic-byte; both failure clauses exercised")


def test_prefix_account() raises:
    var total = kvp_read_work(LAYERS, HIDDEN, QW, KVW, FFN, 32768)
    var prefixes: List[Int] = [1024, 4096, 8192, 16384]
    var avoided: List[Int] = [
        6787224829952, 28411619704832, 60190493769728, 133850004979712,
    ]
    for i in range(4):
        var p = prefixes[i]
        expect_eq(
            kvp_read_work(LAYERS, HIDDEN, QW, KVW, FFN, p), avoided[i],
            "prefix work avoided at " + String(p),
        )
        var remaining = kvp_prefix_remaining_work(
            LAYERS, HIDDEN, QW, KVW, FFN, 32768, p
        )
        expect_eq(remaining + avoided[i], total, "conservation W(P) + remaining == W(L)")
    expect_eq(
        kvp_prefix_remaining_work(LAYERS, HIDDEN, QW, KVW, FFN, 32768, 16384),
        187726074740736, "remaining work after a 16384 prefix",
    )
    print("PASS: prefix account -- avoided == W(P) exactly, remaining == W(L) - W(P), conservation at 4 prefixes of 32768")


def test_storage_burden() raises:
    for i in range(5):
        var rung = ladder_rung(i)
        for p in range(2):
            var precision = KVP_PRECISION_F16 if p == 0 else KVP_PRECISION_INT8
            var file = kvp_file_bytes(precision, LAYERS, HEADS, HD, rung)
            expect_true(kvp_storage_ok(file, WEIGHTS), "file <= model file at rung")
    expect_eq(
        kvp_storage_ppm(
            kvp_file_bytes(KVP_PRECISION_F16, LAYERS, HEADS, HD, 32768), WEIGHTS
        ),
        401242, "f16 file is 401,242 ppm of the model file @32768",
    )
    expect_eq(
        kvp_storage_ppm(
            kvp_file_bytes(KVP_PRECISION_INT8, LAYERS, HEADS, HD, 32768), WEIGHTS
        ),
        206890, "int8 file is 206,890 ppm @32768",
    )
    expect_true(not kvp_storage_ok(WEIGHTS + 1, WEIGHTS), "a file larger than the model fails the burden")
    print("PASS: storage burden -- file <= model file at all rungs x precisions (worst 40.12% f16 @32768); over-model file fails")


def test_roundtrip_exact() raises:
    var plain = build_plain_store()
    var bytes = serialize_int8_store(plain, SLEN, FINGERPRINT)
    expect_eq(len(bytes), 1832, "serialised length == the account's file bytes")
    expect_eq(
        len(bytes),
        kvp_file_bytes(KVP_PRECISION_INT8, SLAYERS, SHEADS, SHD, SLEN),
        "serialised length == kvp_file_bytes(int8, exercise shape)",
    )
    var restored = deserialize_int8_store(bytes, FINGERPRINT)
    expect_eq(restored.saved_len, SLEN, "restored saved_len")
    expect_eq(restored.fingerprint, FINGERPRINT, "restored fingerprint")
    expect_eq(restored.store.layers, SLAYERS, "restored layers")
    expect_eq(restored.store.max_seq_len, SCAP, "restored capacity")
    expect_eq(int8_code_diff_count(restored.store, plain, SLEN), 0, "round-trip code diff")
    expect_eq(int8_scale_diff_count(restored.store, plain, SLEN), 0, "round-trip scale diff")
    expect_eq(int8_state_diff_count(restored.store, plain, SLEN), 0, "round-trip state diff")
    expect_true(
        int8_max_dequant_diff(restored.store, plain, SLEN) == Float32(0),
        "round-trip dequantized rows identical",
    )
    expect_eq(
        kvp_restore_verdict(int8_state_diff_count(restored.store, plain, SLEN)),
        KVP_RESTORE_EXACT, "round-trip verdict EXACT (R-B form)",
    )
    expect_true(attn_equal(restored.store, plain, SLEN), "restored attention identical at every head/layer")
    # Dead rows are never stored: a store carrying extra
    # rows past saved_len serialises to the same bytes.
    var longer = build_plain_store()
    append_pos(longer, SLEN, 777, 9000)
    append_pos(longer, SLEN + 1, 777, 9000)
    var bytes2 = serialize_int8_store(longer, SLEN, FINGERPRINT)
    expect_eq(len(bytes2), len(bytes), "dead rows past saved_len add no bytes")
    var same = True
    for i in range(len(bytes)):
        if bytes2[i] != bytes[i]:
            same = False
    expect_true(same, "dead rows past saved_len change no stored byte")
    print("PASS: round-trip -- serialise/restore BIT-EXACT (0 codes, 0 scales, dequant 0.0, attention identical); dead rows never stored")


def test_checksum_tamper() raises:
    var plain = build_plain_store()
    var bytes = serialize_int8_store(plain, SLEN, FINGERPRINT)
    var refused = 0
    var t1 = List[UInt8]()
    for i in range(len(bytes)):
        t1.append(bytes[i])
    t1[100] = UInt8(Int(t1[100]) + 1) if Int(t1[100]) < 255 else UInt8(0)
    try:
        _ = deserialize_int8_store(t1, FINGERPRINT)
    except:
        refused += 1
    var t2 = List[UInt8]()
    for i in range(len(bytes)):
        t2.append(bytes[i])
    # A scale byte near the end of the payload.
    var idx = len(bytes) - 20
    t2[idx] = UInt8(Int(t2[idx]) + 1) if Int(t2[idx]) < 255 else UInt8(0)
    try:
        _ = deserialize_int8_store(t2, FINGERPRINT)
    except:
        refused += 1
    expect_eq(refused, 2, "tampered payload/scale bytes refused by checksum")
    # The checksum function itself: deterministic, and
    # the trailer of a clean file carries it.
    var body = List[UInt8]()
    for i in range(len(bytes) - 8):
        body.append(bytes[i])
    var trailer = 0
    var mult = 1
    for i in range(8):
        trailer += Int(bytes[len(bytes) - 8 + i]) * mult
        mult *= 256
    expect_eq(trailer, kvp_checksum(body), "trailer carries the header+payload checksum")
    print("PASS: checksum + tamper -- one flipped payload byte and one flipped scale byte each refused; trailer verified")


def test_restore_refusals() raises:
    var plain = build_plain_store()
    var bytes = serialize_int8_store(plain, SLEN, FINGERPRINT)
    var refused = 0
    var bad_magic = List[UInt8]()
    for i in range(len(bytes)):
        bad_magic.append(bytes[i])
    bad_magic[0] = UInt8(66)
    try:
        _ = deserialize_int8_store(bad_magic, FINGERPRINT)
    except:
        refused += 1
    var truncated = List[UInt8]()
    for i in range(len(bytes) - 1):
        truncated.append(bytes[i])
    try:
        _ = deserialize_int8_store(truncated, FINGERPRINT)
    except:
        refused += 1
    var trailing = List[UInt8]()
    for i in range(len(bytes)):
        trailing.append(bytes[i])
    trailing.append(UInt8(0))
    try:
        _ = deserialize_int8_store(trailing, FINGERPRINT)
    except:
        refused += 1
    try:
        _ = deserialize_int8_store(bytes, FINGERPRINT + 1)
    except:
        refused += 1
    var tiny = List[UInt8]()
    tiny.append(UInt8(65))
    try:
        _ = deserialize_int8_store(tiny, FINGERPRINT)
    except:
        refused += 1
    var bad_width = List[UInt8]()
    for i in range(len(bytes)):
        bad_width.append(bytes[i])
    bad_width[48] = UInt8(Int(bad_width[48]) + 8)
    try:
        _ = deserialize_int8_store(bad_width, FINGERPRINT)
    except:
        refused += 1
    expect_eq(refused, 6, "all restore refusals raised")
    print("PASS: restore refusals -- bad magic, truncated, trailing byte, fingerprint mismatch, sub-header file, inconsistent kv_width (6/6)")


def test_privacy_verdicts() raises:
    var opt_in = PersistPrivacyShape(True, True, True, True, True)
    expect_eq(kvp_privacy_verdict(opt_in), KVP_PRIVACY_ACCEPTED, "the OPT-IN shape is ACCEPTED")
    var silent = PersistPrivacyShape(False, True, False, True, True)
    expect_eq(kvp_privacy_verdict(silent), KVP_PRIVACY_REJECTED, "SILENT (default-on, unbound) is REJECTED")
    var shared = PersistPrivacyShape(True, False, True, True, False)
    expect_eq(kvp_privacy_verdict(shared), KVP_PRIVACY_REJECTED, "SHARED (world-readable, unconfined) is REJECTED")
    # Each single missing property rejects on its own:
    var cases: List[PersistPrivacyShape] = [
        PersistPrivacyShape(False, True, True, True, True),
        PersistPrivacyShape(True, False, True, True, True),
        PersistPrivacyShape(True, True, False, True, True),
        PersistPrivacyShape(True, True, True, False, True),
        PersistPrivacyShape(True, True, True, True, False),
    ]
    for i in range(len(cases)):
        expect_eq(
            kvp_privacy_verdict(cases[i]), KVP_PRIVACY_REJECTED,
            "single missing property rejects (case " + String(i) + ")",
        )
    print("PASS: privacy verdicts -- OPT-IN ACCEPTED; SILENT and SHARED REJECTED; each of the 5 properties individually disqualifying")


def test_refusals() raises:
    var refused = 0
    try:
        _ = kvp_kv_bytes(KVP_PRECISION_F16, LAYERS, HEADS, HD, 0)
    except:
        refused += 1
    try:
        _ = kvp_per_token(9, LAYERS, HEADS, HD)
    except:
        refused += 1
    try:
        _ = kvp_prefix_remaining_work(LAYERS, HIDDEN, QW, KVW, FFN, 4096, 4096)
    except:
        refused += 1
    try:
        _ = kvp_benefit_verdict(0, 100, 200)
    except:
        refused += 1
    try:
        _ = kvp_restore_verdict(-1)
    except:
        refused += 1
    var plain = build_plain_store()
    try:
        _ = serialize_int8_store(plain, 0, FINGERPRINT)
    except:
        refused += 1
    try:
        _ = serialize_int8_store(plain, SCAP + 1, FINGERPRINT)
    except:
        refused += 1
    try:
        _ = serialize_int8_store(plain, SLEN, -1)
    except:
        refused += 1
    expect_eq(refused, 8, "all accounting/serialise refusals raised")
    print("PASS: refusals -- zero length, unknown precision, prefix >= prompt, non-positive benefit input, negative diff, saved_len 0 / past capacity, negative fingerprint (8/8)")


def main() raises:
    test_codes_and_prices()
    test_gate_work_j094()
    test_gate_kv_touch_j094()
    test_benefit_account()
    test_prefix_account()
    test_storage_burden()
    test_roundtrip_exact()
    test_checksum_tamper()
    test_restore_refusals()
    test_privacy_verdicts()
    test_refusals()
    print("ALL PASS: kv persistence (11 groups)")
