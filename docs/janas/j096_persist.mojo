"""J-096 KV persistence harness: the benefit account,
the prefix account, the privacy shape verdicts and
the int8 serialise/restore round-trip, printed from
the tree's own modules (core/kv_persistence over
core/kv_account, core/kv_int8, core/kv_ladder,
core/prompt_read and core/kv_drafts).

WITNESS (stated): the ladder's dense mid-size model,
Qwen2.5-Coder-7B (28 layers, hidden 3584, ffn 18944,
28 query heads, 4 kv heads, head_dim 128, file bytes
4,683,074,688, J-091/J-094), at the ladder rungs
1024 / 4096 / 8192 / 16384 / 32768. PERSIST lines
print, per rung and precision: J-094's read work
avoided by a FULL restore, the KV bytes, the file
bytes (72 overhead + KV), the traffic (2 x file),
the same-precision host-batched re-read touch, the
work per traffic byte, the storage ppm of the model
file, and the pre-registered benefit verdict.
PREFIX lines print, for a 32768 prompt: the work a
prefix restore avoids (exactly W(P)), the remaining
work (W(L) - W(P)), and the prefix's file bytes at
both precisions. PRIVACY lines print the three
graded shapes' verdicts. The ROUNDTRIP line prints
the J-095 exercise store (2 layers x 2 kv-heads x
head_dim 16, capacity 24, saved length 11, salts
plain K 11 / V 5000, fingerprint 424242) serialised
and restored: file bytes, the trailer checksum, the
stored-representation diffs against the saved store
through core/kv_drafts, the dequantized maximum
difference, the attention equality, and the R-B
restore verdict.

Every number is exact arithmetic or a deterministic
exercise through the tree's own modules. NO WALL, NO
LIVE RESTART AND NO LIVE BENEFIT IS MEASURED OR
PRINTED: no live session integrates the int8 store
or constructs a restored store (INTEGRATION_BLOCKED,
J-091), this VM is below its inference gate and
purplelongship is unreachable; the live legs are
deferred to the J-098 gate recipe in the J-096 doc
(section 7). Deterministic: identical output on
every run.
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
    KVP_PRECISION_F16,
    KVP_PRECISION_INT8,
    PersistPrivacyShape,
    deserialize_int8_store,
    kvp_benefit_name,
    kvp_benefit_verdict,
    kvp_checksum,
    kvp_file_bytes,
    kvp_kv_bytes,
    kvp_precision_name,
    kvp_prefix_remaining_work,
    kvp_privacy_name,
    kvp_privacy_verdict,
    kvp_read_work,
    kvp_reread_touch,
    kvp_restore_name,
    kvp_restore_verdict,
    kvp_storage_ppm,
    kvp_traffic_bytes,
    kvp_work_per_traffic_byte,
    serialize_int8_store,
)

comptime LAYERS = 28
comptime HEADS = 4
comptime HD = 128
comptime HIDDEN = 3584
comptime QW = 3584
comptime KVW = 512
comptime FFN = 18944
comptime WEIGHTS = 4683074688

comptime SLAYERS = 2
comptime SHEADS = 2
comptime SHD = 16
comptime SWIDTH = 32
comptime SCAP = 24
comptime SLEN = 11
comptime FINGERPRINT = 424242


def synth(i: Int) -> Float32:
    return Float32((i * 37) % 17 - 8) / Float32(8.0)


def row_values(layer: Int, pos: Int, salt: Int) -> List[Float32]:
    var row = List[Float32]()
    for j in range(SWIDTH):
        row.append(synth(layer * 4096 + pos * SWIDTH + j + salt))
    return row^


def build_plain_store() raises -> Int8KVStore:
    var store = Int8KVStore(SLAYERS, SHEADS, SHD, SCAP)
    for pos in range(SLEN):
        for layer in range(SLAYERS):
            store.append(
                layer, pos, row_values(layer, pos, 11),
                row_values(layer, pos, 5000),
            )
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


def main() raises:
    print(
        "PERSISTHEAD witness=coder-28x4x128 weights=4683074688"
        " overhead=72 min_work_per_traffic_byte=1000"
    )
    for i in range(5):
        var rung = ladder_rung(i)
        var work = kvp_read_work(LAYERS, HIDDEN, QW, KVW, FFN, rung)
        for p in range(2):
            var precision = KVP_PRECISION_F16 if p == 0 else KVP_PRECISION_INT8
            var traffic = kvp_traffic_bytes(precision, LAYERS, HEADS, HD, rung)
            var touch = kvp_reread_touch(precision, LAYERS, HEADS, HD, rung, WEIGHTS)
            print(
                "PERSIST rung=" + String(rung)
                + " precision=" + kvp_precision_name(precision)
                + " work_avoided=" + String(work)
                + " kv_bytes=" + String(kvp_kv_bytes(precision, LAYERS, HEADS, HD, rung))
                + " file_bytes=" + String(kvp_file_bytes(precision, LAYERS, HEADS, HD, rung))
                + " traffic=" + String(traffic)
                + " touch=" + String(touch)
                + " work_per_traffic_byte=" + String(kvp_work_per_traffic_byte(work, traffic))
                + " storage_ppm=" + String(kvp_storage_ppm(
                    kvp_file_bytes(precision, LAYERS, HEADS, HD, rung), WEIGHTS))
                + " verdict=" + kvp_benefit_name(kvp_benefit_verdict(work, traffic, touch))
            )
    for i in range(4):
        var p = ladder_rung(i)
        print(
            "PREFIX base=32768 prefix=" + String(p)
            + " work_avoided=" + String(kvp_read_work(LAYERS, HIDDEN, QW, KVW, FFN, p))
            + " remaining=" + String(kvp_prefix_remaining_work(LAYERS, HIDDEN, QW, KVW, FFN, 32768, p))
            + " file_f16=" + String(kvp_file_bytes(KVP_PRECISION_F16, LAYERS, HEADS, HD, p))
            + " file_int8=" + String(kvp_file_bytes(KVP_PRECISION_INT8, LAYERS, HEADS, HD, p))
        )
    var opt_in = PersistPrivacyShape(True, True, True, True, True)
    var silent = PersistPrivacyShape(False, True, False, True, True)
    var shared = PersistPrivacyShape(True, False, True, True, False)
    print(
        "PRIVACY shape=opt_in_bound_cache_home verdict="
        + kvp_privacy_name(kvp_privacy_verdict(opt_in))
    )
    print(
        "PRIVACY shape=silent_default_unbound verdict="
        + kvp_privacy_name(kvp_privacy_verdict(silent))
    )
    print(
        "PRIVACY shape=shared_world_readable verdict="
        + kvp_privacy_name(kvp_privacy_verdict(shared))
    )
    var plain = build_plain_store()
    var bytes = serialize_int8_store(plain, SLEN, FINGERPRINT)
    var body = List[UInt8]()
    for i in range(len(bytes) - 8):
        body.append(bytes[i])
    var restored = deserialize_int8_store(bytes, FINGERPRINT)
    var diff = int8_state_diff_count(restored.store, plain, SLEN)
    print(
        "ROUNDTRIP layers=2 heads=2 head_dim=16 cap=24 len=11 fingerprint=424242"
        + " file_bytes=" + String(len(bytes))
        + " checksum=" + String(kvp_checksum(body))
        + " code_diff=" + String(int8_code_diff_count(restored.store, plain, SLEN))
        + " scale_diff=" + String(int8_scale_diff_count(restored.store, plain, SLEN))
        + " state_diff=" + String(diff)
        + " dequant_max=" + String(int8_max_dequant_diff(restored.store, plain, SLEN))
        + " attn_equal=" + String(attn_equal(restored.store, plain, SLEN))
        + " verdict=" + kvp_restore_name(kvp_restore_verdict(diff))
    )
    print("PERSISTDONE live=NOT_PROVEN_DEFERRED_J098 walls=NOT_PROVEN")
