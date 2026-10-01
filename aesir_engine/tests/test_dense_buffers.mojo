"""Checked tile ownership and unchanged single-token accounting."""
from core.dense_buffers import DenseBufferLayout, buffer_add, buffer_mul
from core.dense_gqa_profile import llama3_2_3b_profile, llama3_8b_profile, qwen3_0_6b_profile


def test_dense_buffers() raises:
    var profile = llama3_2_3b_profile()
    var one = DenseBufferLayout(profile, 4096, 1)
    var four = DenseBufferLayout(profile, 4096)
    if one.elements != profile.activation_elements(4096) or four.batch != 4:
        raise Error("Single-token layout or automatic tile changed")
    if four.stride != 33792 or four.logits != four.stride * 4 or four.scores != four.logits + 128256:
        raise Error("Dense live spans overlap")
    if (four.elements - one.elements) * 4 != 405504:
        raise Error("Compact tile duplicated shared scores/logits")
    for i in range(4):
        if four.token_base(i) + four.stride > four.logits:
            raise Error("Token scratch overlaps shared output")
    var rejected = False
    try:
        _ = four.token_base(4)
    except:
        rejected = True
    if not rejected:
        raise Error("Tile accepted out-of-range token")
    for invalid in [0, 1, 8193]:
        rejected = False
        try:
            _ = DenseBufferLayout(profile, invalid)
        except:
            rejected = True
        if not rejected:
            raise Error("Buffer context bound ignored")
    for invalid in [2, 3, 8]:
        rejected = False
        try:
            _ = DenseBufferLayout(profile, 4096, invalid)
        except:
            rejected = True
        if not rejected:
            raise Error("Unsupported tile accepted")
    if DenseBufferLayout(llama3_8b_profile(), 8192).batch != 1 or DenseBufferLayout(qwen3_0_6b_profile(), 2048).batch != 1:
        raise Error("Untested profile default was promoted")
    rejected = False
    try:
        _ = DenseBufferLayout(qwen3_0_6b_profile(), 2048, 4)
    except:
        rejected = True
    if not rejected:
        raise Error("Untested profile tile admitted")
    rejected = False
    try:
        _ = buffer_add(9223372036854775807, 1)
    except:
        rejected = True
    if not rejected:
        raise Error("Buffer addition wrapped")
    rejected = False
    try:
        _ = buffer_mul(9223372036854775807, 4)
    except:
        rejected = True
    if not rejected:
        raise Error("Buffer multiplication wrapped")


def main() raises:
    test_dense_buffers()
    print("PASS: compact tile spans, byte counts, bounds, defaults and overflow")
