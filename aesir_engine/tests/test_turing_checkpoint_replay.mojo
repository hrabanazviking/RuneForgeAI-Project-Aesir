"""Owning-context exact-boundary reset/replay; no time or persisted-format score."""
from std.sys import argv
from max.gpu.host import HostBuffer
from tests.turing_prefill_fixture import TuringPrefillFixture
from tests.turing_replay_plan import FixtureReplayPlan
from tests.turing_checkpoint_replay import owner, restore
from tests.test_turing_decode_quality import policy, prepare, advance, save, mismatch
from tests.test_turing_model_prefill import inputs, logits


def values(f: TuringPrefillFixture) -> List[Int]:
    return [Int(f.native.host_output[0]),Int(f.host_output[0]),f.native.position,f.position,
        f.native.sampler.position,f.sampler.position,Int(f.native.sampler.draws),Int(f.sampler.draws)]


def record(label: String,index: Int,step: Int,s: List[Int]):
    print(label+","+String(index)+","+String(step)+","+String(s[0])+","+String(s[1])+","+String(s[2])+","+String(s[3])+","+String(s[4])+","+String(s[5])+","+String(s[6])+","+String(s[7]))


def tiles(mode: Int) -> List[Int]:
    var result = List[Int]()
    var left = 36
    while left > 0:
        var count = 32 if mode == 1 and left >= 32 else (4 if left >= 4 else 1)
        result.append(count)
        left -= count
    # The final prefix ID and eight generated scalar additions retain boundaries.
    for _ in range(9): result.append(1)
    return result^


def history(f: TuringPrefillFixture,expected: List[Int]) raises:
    var actual = f.native.conversation_tokens()
    if len(actual) != len(expected) or len(f.committed) != len(expected): raise Error("Checkpoint causal history length changed")
    for i in range(len(expected)):
        if actual[i] != expected[i] or f.committed[i] != expected[i]: raise Error("Checkpoint causal ID changed")


def reject_damage(mut f: TuringPrefillFixture,mut plan: FixtureReplayPlan) raises:
    var before = values(f)
    var native_owner = owner(f,0)
    var matrix_owner = owner(f,1)
    var calls = f.down128_calls
    var sealed_strategy = plan.strategy
    for damage in range(4 if f.down128 else 3):
        if damage == 0: plan.tiles[0] -= 1
        elif damage == 1: plan.weights += 1
        elif damage == 2: plan.draws += 1
        else: plan.strategy = (plan.strategy+1)%4
        var rejected = False
        try: restore(f,plan)
        except: rejected = True
        if damage == 0: plan.tiles[0] += 1
        elif damage == 1: plan.weights -= 1
        elif damage == 2: plan.draws -= 1
        else: plan.strategy = sealed_strategy
        if not rejected or not f.healthy or not f.native.healthy:
            raise Error("Invalid replay plan was accepted or poisoned a healthy owner")
        var after = values(f)
        for i in range(8):
            if after[i] != before[i]: raise Error("Invalid replay plan mutated sampled/committed state")
        if f.down128:
            var native_after = owner(f,0)
            var matrix_after = owner(f,1)
            if calls != f.down128_calls: raise Error("Invalid down128 replay plan changed enqueue counter")
            for i in range(5):
                if native_owner[i] != native_after[i] or matrix_owner[i] != matrix_after[i]:
                    raise Error("Invalid down128 replay plan changed actual buffer/sampler owner")
        history(f,plan.tokens)


def reject_flag_drift(mut f: TuringPrefillFixture,plan: FixtureReplayPlan) raises:
    var before = values(f)
    var native_owner = owner(f,0)
    var matrix_owner = owner(f,1)
    var calls = f.down128_calls
    f.batched_elementwise = False
    var refused = False
    try: restore(f,plan)
    except: refused = True
    f.batched_elementwise = True
    if not refused or not f.healthy or not f.native.healthy or calls != f.down128_calls:
        raise Error("Down128 replay flag drift mutated or poisoned owner")
    var after = values(f)
    var native_after = owner(f,0)
    var matrix_after = owner(f,1)
    for i in range(8):
        if before[i] != after[i]: raise Error("Down128 flag refusal changed sampled/committed state")
    for i in range(5):
        if native_owner[i] != native_after[i] or matrix_owner[i] != matrix_after[i]:
            raise Error("Down128 flag refusal changed buffer/sampler owner")
    history(f,plan.tokens)


def collect(mut f: TuringPrefillFixture,index: Int) raises:
    var prefix = inputs(f,"Explain how a knowledge graph connects documents, entities and their evidence. Write three sentences.")
    if len(prefix) != 37: raise Error("Checkpoint public prefix identity changed")
    prepare(f,prefix,policy(index))
    for _ in range(8):
        var token = Int(f.native.host_output[0])
        if token == 128001 or token == 128009: raise Error("Unexpected terminal checkpoint history")
        advance(f,token)
    var committed = f.native.conversation_tokens()
    history(f,committed)
    var native_owner = owner(f,0)
    var matrix_owner = owner(f,1)
    var pending = Int(f.native.host_output[0])
    var n = FixtureReplayPlan(0,native_owner[0],native_owner[1],native_owner[2],committed,tiles(0),pending,f.native.sampler.config,f.native.sampler.draws)
    var m = FixtureReplayPlan(1,matrix_owner[0],matrix_owner[1],matrix_owner[2],committed,tiles(1),pending,f.sampler.config,f.sampler.draws,matrix_owner[4])
    print("CASE,"+String(index)+",37,45,4")
    for i in range(len(committed)): print("INPUT,"+String(index)+","+String(i)+","+String(committed[i]))
    for mode in range(2):
        var counts = tiles(mode)
        var start = 0
        for i in range(len(counts)):
            print("TILE,"+String(index)+","+String(mode)+","+String(i)+","+String(start)+","+String(counts[i]))
            start += counts[i]
    if f.down128: print("DOWN_ROWS128,"+String(index)+","+String(f.down128_calls))
    record("CHECKPOINT",index,8,values(f))
    reject_damage(f,n)
    reject_damage(f,m)
    if f.down128: reject_flag_drift(f,m)
    print("REFUSAL,"+String(index)+","+String(9 if f.down128 else 6)+",45,45,1")
    var native = f.native.context.enqueue_create_host_buffer[DType.float32](4*128256)
    var matrix = f.native.context.enqueue_create_host_buffer[DType.float32](4*128256)
    var baseline = List[List[Int]]()
    var expected = committed.copy()
    for step in range(4):
        if pending == 128001 or pending == 128009: raise Error("Unexpected terminal continuation")
        advance(f,pending)
        expected.append(pending)
        history(f,expected)
        var nv = logits(f,0)
        var mv = logits(f,1)
        save(native,nv,step)
        save(matrix,mv,step)
        baseline.append(values(f))
        record("BASE",index,step,baseline[step])
        pending = baseline[step][0]
    f.guards()
    print("GUARD,"+String(index)+",0,1088,0")
    restore(f,n)
    restore(f,m)
    history(f,committed)
    var restored = values(f)
    print("RESTORED,"+String(index)+",45,45,45,45,"+String(restored[6])+","+String(restored[7])+","+String(n.pending)+",1")
    if f.down128: print("RESTORED_DOWN_ROWS128,"+String(index)+","+String(f.down128_calls))
    pending = n.pending
    expected = committed.copy()
    for step in range(4):
        advance(f,pending)
        expected.append(pending)
        history(f,expected)
        var nv = logits(f,0)
        var mv = logits(f,1)
        record("REPLAY",index,step,values(f))
        print("BITS,"+String(index)+","+String(step)+","+String(mismatch(native,nv,step))+","+String(mismatch(matrix,mv,step)))
        for i in range(128256):
            print("LOGIT,"+String(index)+","+String(step)+","+String(i)+","+String(Float64(native[step*128256+i]))+","+String(Float64(matrix[step*128256+i]))+","+String(Float64(nv[i]))+","+String(Float64(mv[i])))
        pending = baseline[step][0]
    f.guards()
    print("GUARD,"+String(index)+",1,1088,0")


def main() raises:
    var args = argv()
    if len(args) != 2 and len(args) != 3: raise Error("usage: test_turing_checkpoint_replay MODEL.gguf [STRATEGY0/1/2/3]")
    var flag = Int(args[2]) if len(args) == 3 else 0
    if flag < 0 or flag > 3: raise Error("Checkpoint execution strategy must be0/1/2/3")
    var f = TuringPrefillFixture(args[1],0,Bool(flag>0),Bool(flag>=2),Bool(flag==3))
    if len(args) == 3:
        if flag == 3: print("ATTENTION,rope_cache_elementwise_down128,1,32")
        elif flag == 2: print("ATTENTION,rope_cache_elementwise_grid,1,32")
        else: print("ATTENTION,rope_cache_grid,"+String(flag)+",32")
    print("META,1,turing_checkpoint,1536,128256,2,4")
    for index in range(2):
        var p = policy(index)
        print("POLICY,"+String(index)+","+String(Float64(p.temperature))+","+String(p.top_k)+","+String(Float64(p.top_p))+","+String(Float64(p.min_p))+","+String(Float64(p.repetition_penalty))+","+String(p.repeat_last_n)+","+String(p.seed))
    for index in range(2): collect(f,index)
    print("COMPLETE,turing_checkpoint,2,8,1026048,4352,"+String(18 if f.down128 else 12))
