"""Portable hostile-metadata and physical-span admission, with no GPU allocation."""
from core.dense_buffers import DenseBufferLayout
from core.dense_gqa_profile import DenseGQAProfile, llama3_2_3b_profile
from tests.turing_fixture_plan import TuringFixturePlan, same_fixture_layout


def corrupt_layout(mut layout: DenseBufferLayout,index: Int):
    if index == 0: layout.norm += 1
    elif index == 1: layout.query += 1
    elif index == 2: layout.key += 1
    elif index == 3: layout.value += 1
    elif index == 4: layout.attention += 1
    elif index == 5: layout.temporary += 1
    elif index == 6: layout.up += 1
    elif index == 7: layout.gate += 1
    elif index == 8: layout.stride += 1
    elif index == 9: layout.logits += 1
    elif index == 10: layout.scores += 1
    elif index == 11: layout.elements += 1
    else: layout.batch += 1


def corrupt_profile(index: Int) -> DenseGQAProfile:
    var profile = llama3_2_3b_profile()
    if index == 0: profile.architecture = "qwen2"
    elif index == 1: profile.layer_count += 1
    elif index == 2: profile.hidden_size += 1
    elif index == 3: profile.feed_forward_size += 1
    elif index == 4: profile.attention_heads += 1
    elif index == 5: profile.kv_heads += 1
    elif index == 6: profile.head_dim += 1
    elif index == 7: profile.vocabulary_size += 1
    else: profile.context_cap = 1535
    return profile^


def rejected_identity(reference: DenseBufferLayout) raises:
    var profile = llama3_2_3b_profile()
    for index in range(9):
        var rejected = False
        try: _ = TuringFixturePlan(corrupt_profile(index),reference,7,5,450396872)
        except: rejected = True
        if not rejected: raise Error("Unexercised fixture profile was admitted")
    for index in range(7):
        var major = 7 if index < 3 else (8 if index < 6 else -1)
        var minor = index if index < 6 else 5
        var rejected = False
        try: _ = TuringFixturePlan(profile,reference,major,minor,450396872)
        except: rejected = True
        if not rejected: raise Error("Unexercised physical fixture device was admitted")
    for precision in [-1,5,9223372036854775807]:
        var rejected = False
        try: _ = TuringFixturePlan(profile,reference,7,5,450396872,precision)
        except: rejected = True
        if not rejected: raise Error("Unknown fixture precision was admitted")
    for free in [-1,0,450396871]:
        var rejected = False
        try: _ = TuringFixturePlan(profile,reference,7,5,free)
        except: rejected = True
        if not rejected: raise Error("Deficient fixture headroom was admitted")


def test_turing_fixture_plan() raises:
    var profile = llama3_2_3b_profile()
    var reference = DenseBufferLayout(profile,1536,4)
    var original = reference
    var plan = TuringFixturePlan(profile,reference,7,5,450396872)
    if plan.activation_elements != 1247520 or plan.cache_elements != 88080416 or plan.device_bytes != 181961416 or plan.required_free_bytes != 450396872:
        raise Error("Guarded fixture byte accounting changed")
    if plan.layout.stride != 33824 or plan.layout.logits != 1082368 or plan.layout.scores != 1210624 or plan.layout.elements != 1247488:
        raise Error("Fixture live spans overlap shared output")
    for precision in range(5):
        _ = TuringFixturePlan(profile,reference,7,5,450396872,precision)
    var alternatives: List[DenseBufferLayout] = [DenseBufferLayout(profile,4096,4),DenseBufferLayout(profile,1536,1)]
    for alternative in alternatives:
        var rejected = False
        try: _ = TuringFixturePlan(profile,alternative,7,5,450396872)
        except: rejected = True
        if not rejected: raise Error("Wrong context or reference batch admitted")
    if not same_fixture_layout(reference,original) or reference.batch != 4 or reference.stride != 33792:
        raise Error("Fixture plan mutated the normal reference")
    for token in range(32):
        if plan.layout.token_base(token)+plan.layout.stride > plan.layout.logits:
            raise Error("Fixture token overlaps shared logits")
    for token in [-1,32]:
        var rejected = False
        try: _ = plan.layout.token_base(token)
        except: rejected = True
        if not rejected: raise Error("Fixture token bound ignored")
    for index in range(13):
        var damaged = reference
        corrupt_layout(damaged,index)
        var rejected = False
        try: _ = TuringFixturePlan(profile,damaged,7,5,450396872)
        except: rejected = True
        if not rejected: raise Error("Corrupt reference layout accepted")
        damaged = plan.layout
        corrupt_layout(damaged,index)
        rejected = False
        try: plan.admit_buffers(damaged,1247520,88080416)
        except: rejected = True
        if not rejected: raise Error("Post-allocation layout mutation accepted")
    for index in range(4):
        var a = 1247520+(index%2*2-1) if index < 2 else 1247520
        var kv = 88080416+(index%2*2-1) if index >= 2 else 88080416
        var rejected = False
        try: plan.admit_buffers(plan.layout,a,kv)
        except: rejected = True
        if not rejected: raise Error("Actual fixture length mismatch accepted")
    plan.admit_buffers(plan.layout,1247520,88080416)
    for invalid in [0,-1,9223372036854775807]:
        for which in range(2):
            var rejected = False
            try: plan.admit_buffers(plan.layout,invalid if which == 0 else 1247520,invalid if which == 1 else 88080416)
            except: rejected = True
            if not rejected: raise Error("Invalid physical fixture length accepted")
    rejected_identity(reference)


def main() raises:
    test_turing_fixture_plan()
    print("PASS: strict fixture identity, all layout fields, spans, padding and headroom")
