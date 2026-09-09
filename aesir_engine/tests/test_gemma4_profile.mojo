"""Pure profile and memory-accounting regressions for native Gemma 4 CUDA."""
from core.gemma4_profile import gemma4_e4b_profile, gemma4_e2b_profile
from core.inference_memory import gemma4_profile_memory_plan


def test_gemma4_profiles() raises:
    var e4b = gemma4_e4b_profile()
    if e4b.layer_count != 42 or e4b.hidden_size != 2560 or e4b.feed_forward_size != 10240:
        raise Error("Gemma 4 E4B dimensions drifted")
    if e4b.kv_heads != 2 or e4b.context_cap != 32768:
        raise Error("Gemma 4 E4B KV/context profile drifted")
    if e4b.is_local(5) or not e4b.is_local(4):
        raise Error("Gemma 4 E4B attention pattern drifted")
    if e4b.kv_layer(40) != 22 or e4b.kv_layer(41) != 23:
        raise Error("Gemma 4 E4B shared KV ownership drifted")

    var e2b = gemma4_e2b_profile()
    if e2b.layer_count != 35 or e2b.hidden_size != 1536 or e2b.feed_forward_size != 6144:
        raise Error("Gemma 4 E2B dimensions drifted")
    if e2b.ffn_size(14) != 6144 or e2b.ffn_size(15) != 12288:
        raise Error("Gemma 4 E2B double-wide FFN boundary drifted")
    if e2b.attention_heads != 8 or e2b.kv_heads != 1 or e2b.context_cap != 16384:
        raise Error("Gemma 4 E2B attention/context profile drifted")
    if e2b.is_local(4) or not e2b.is_local(3) or e2b.is_local(34):
        raise Error("Gemma 4 E2B attention pattern drifted")
    if not e2b.owns_kv(14) or e2b.owns_kv(15):
        raise Error("Gemma 4 E2B KV ownership boundary drifted")
    if e2b.kv_layer(33) != 13 or e2b.kv_layer(34) != 14:
        raise Error("Gemma 4 E2B shared KV mapping drifted")

    var memory = gemma4_profile_memory_plan(3106738272, 16384, e2b)
    if memory.kv_bytes != 213909504:
        raise Error("Gemma 4 E2B 16K KV accounting mismatch")
    var rejected = False
    try:
        _ = gemma4_profile_memory_plan(3106738272, 16385, e2b)
    except:
        rejected = True
    if not rejected:
        raise Error("Gemma 4 E2B oversized context was accepted")
