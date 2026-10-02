"""Pure copied-plan, mutation, geometry and owner refusal; no GPU execution."""
from core.sampling_config import NativeSamplingConfig
from tests.turing_replay_plan import FixtureReplayPlan


def fresh() raises -> FixtureReplayPlan:
    var tokens: List[Int] = [1,2,3,4,5,6,7,8,9]
    var tiles: List[Int] = [4,4,1]
    return FixtureReplayPlan(0,100,200,300,tokens,tiles,10,NativeSamplingConfig(),0)


def test_turing_replay_plan() raises:
    var plan = fresh()
    plan.admit(0,100,200,300,64)
    for mutation in range(19):
        var broken = fresh()
        if mutation == 0: broken.mode = 1
        elif mutation == 1: broken.context += 1
        elif mutation == 2: broken.vocabulary += 1
        elif mutation == 3: broken.weights += 1
        elif mutation == 4: broken.activation += 1
        elif mutation == 5: broken.cache += 1
        elif mutation == 6: broken.pending += 1
        elif mutation == 7: broken.tokens[0] += 1
        elif mutation == 8: broken.tiles[0] = 1
        elif mutation == 9: broken.config.temperature = .7
        elif mutation == 10: broken.config.top_k += 1
        elif mutation == 11: broken.config.top_p = .9
        elif mutation == 12: broken.config.min_p = .05
        elif mutation == 13: broken.config.repetition_penalty = 1.1
        elif mutation == 14: broken.config.repeat_last_n += 1
        elif mutation == 15: broken.config.seed += 1
        elif mutation == 16: broken.draws += 1
        elif mutation == 17: broken.strategy = 1
        else: broken.checksum += 1
        var rejected = False
        try: broken.admit(0,100,200,300,64)
        except: rejected = True
        if not rejected: raise Error("Mutated replay checkpoint admitted")
    for identity in range(5):
        var rejected = False
        try: plan.admit(1 if identity == 0 else 0,101 if identity == 1 else 100,201 if identity == 2 else 200,301 if identity == 3 else 300,65 if identity == 4 else 64)
        except: rejected = True
        if not rejected: raise Error("Foreign replay ownership admitted")
    var ids: List[Int] = [1,2,3,4,5,6,7,8,9]
    var tiles: List[Int] = [4,4,1]
    var copied = FixtureReplayPlan(0,100,200,300,ids,tiles,10,NativeSamplingConfig(),0)
    ids[0] = 12
    tiles[0] = 1
    copied.admit(0,100,200,300,64)
    if copied.tokens[0] != 1 or copied.tiles[0] != 4:
        raise Error("Replay plan retained mutable caller lists")
    for invalid in range(9):
        var tokens: List[Int] = [1,2,3,4]
        var counts: List[Int] = [4]
        var pending = 10
        var draws = UInt64(0)
        var configuration = NativeSamplingConfig()
        if invalid == 0: tokens[0] = -1
        elif invalid == 1: tokens[0] = 128256
        elif invalid == 2: counts[0] = 32
        elif invalid == 3: counts[0] = 0
        elif invalid == 4: counts[0] = 1
        elif invalid == 5: pending = 128009
        elif invalid == 6: draws = 1
        elif invalid == 7: configuration.top_k = 0
        else: tokens.clear()
        var rejected = False
        try: _ = FixtureReplayPlan(0,100,200,300,tokens,counts,pending,configuration,draws)
        except: rejected = True
        if not rejected: raise Error("Invalid replay geometry/token/count/draw policy admitted")
    var matrix_ids = List[Int]()
    for i in range(37): matrix_ids.append(i)
    var matrix_tiles: List[Int] = [32,4,1]
    var sampled = NativeSamplingConfig(temperature=.7,seed=1234)
    var matrix = FixtureReplayPlan(1,100,200,300,matrix_ids,matrix_tiles,10,sampled,9)
    matrix.admit(1,100,200,300,64)
    var batched = FixtureReplayPlan(1,100,200,300,matrix_ids,matrix_tiles,10,sampled,9,1)
    batched.admit(1,100,200,300,64,1)
    var refused = False
    try: batched.admit(1,100,200,300,64,0)
    except: refused = True
    if not refused: raise Error("Replay strategy drift was admitted")


    var grouped = FixtureReplayPlan(1,100,200,300,matrix_ids,matrix_tiles,10,sampled,9,2)
    grouped.admit(1,100,200,300,64,2)
    for strategy in [0,1,3]:
        refused = False
        try: grouped.admit(1,100,200,300,64,strategy)
        except: refused = True
        if not refused: raise Error("Elementwise replay strategy drift admitted")


def main() raises:
    test_turing_replay_plan()
    print("PASS: copied/checksummed replay plan mutation geometry and owner admission")
