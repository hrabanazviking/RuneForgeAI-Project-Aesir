"""Test-only reset/replay gateway preserving the exact captured execution plan."""
from tests.turing_prefill_fixture import TuringPrefillFixture
from tests.turing_replay_plan import FixtureReplayPlan
from tests.turing_fixture_plan import admit_fixture_profile, same_fixture_layout
from core.dense_buffers import DenseBufferLayout


def owner(f: TuringPrefillFixture,mode: Int) raises -> List[Int]:
    if mode != 0 and mode != 1: raise Error("Unknown replay owner")
    if mode == 0:
        return [Int(f.native.weights.unsafe_ptr()),Int(f.native.activations.unsafe_ptr()),Int(f.native.cache.unsafe_ptr()),f.native.sampler.config.repeat_last_n,0]
    return [Int(f.native.weights.unsafe_ptr()),Int(f.activations.unsafe_ptr()),Int(f.cache.unsafe_ptr()),f.sampler.config.repeat_last_n,f.execution_strategy()]


def restore(mut f: TuringPrefillFixture,plan: FixtureReplayPlan) raises:
    if f.small_attention and not f.small_replay: raise Error("Small attention sealed replay requires separate acceptance")
    f.admit_execution_strategy()
    var identity = owner(f,plan.mode)
    plan.admit(plan.mode,identity[0],identity[1],identity[2],identity[3],identity[4],f.fused_attention and plan.mode == 1,f.small_replay and f.small_attention and plan.mode == 1)
    f.admit_execution_strategy()
    if f.fused_controls or f.fused_tracing: raise Error("Control/trace-capable fused replay requires separate acceptance")
    if f.activation_precision != 0: raise Error("Checkpoint replay admits original precision0 only")
    if not f.healthy or not f.native.healthy or f.native.generating or f.native.reset_required or f.control.enabled() or f.control.reset_required or f.native.control.timeout_ms != 0 or f.native.control.cancel_fd != -1:
        raise Error("Replay requires an idle healthy uncontrolled owner")
    admit_fixture_profile(f.native.profile)
    var canonical = DenseBufferLayout(f.native.profile,1536,4)
    if f.native.context_length != 1536 or f.native.prefill_batch != 4 or f.native.prefix_cache or not same_fixture_layout(f.native.buffers,canonical) or len(f.native.activations) != canonical.elements or len(f.native.cache) != 28*2*1536*1024:
        raise Error("Replay native owner geometry or physical span drifted")
    f.buffer_plan.admit_buffers(f.layout,len(f.activations),len(f.cache))
    try:
        if plan.mode == 0:
            f.native.configure_sampling(plan.config)
            f.native.reset()
        else:
            f.sampler.configure(plan.config)
            f.reset()
        var offset = 0
        for count in plan.tiles:
            if plan.mode == 0:
                if count == 4: f.native.prefill_four(plan.tokens,offset)
                else: _ = f.native.forward(plan.tokens[offset],False)
            else: f.step(plan.tokens,offset,count)
            offset += count
        f.native.context.synchronize()
        var actual = f.native.conversation_tokens() if plan.mode == 0 else f.committed.copy()
        var position = f.native.position if plan.mode == 0 else f.position
        var history = f.native.sampler.position if plan.mode == 0 else f.sampler.position
        if position != len(plan.tokens) or history != len(plan.tokens) or len(actual) != len(plan.tokens):
            raise Error("Restored replay position/history differs from checkpoint")
        for i in range(len(actual)):
            if actual[i] != plan.tokens[i]: raise Error("Restored replay changed committed IDs")
        if plan.mode == 0: f.native.sampler.draws = plan.draws
        else: f.sampler.draws = plan.draws
        var after = owner(f,plan.mode)
        plan.admit(plan.mode,after[0],after[1],after[2],after[3],after[4],f.fused_attention and plan.mode == 1,f.small_replay and f.small_attention and plan.mode == 1)
    except:
        if plan.mode == 0: f.native.healthy = False
        else: f.healthy = False
        raise
