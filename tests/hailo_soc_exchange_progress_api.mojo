# Direct original event/lifetime/poison checks; no OS operations.
from hailbru.soc_exchange_progress import SocExchangeProgress
from hailbru.soc_abi import soc_zero_bytes, _put


def snapshot(input: UInt8, output: UInt8, first: UInt8, second: UInt8) raises -> List[UInt8]:
    var data = soc_zero_bytes(385)
    _put(data,0,8,(UInt64(1)<<UInt64(input))|(UInt64(1)<<UInt64(output)))
    data[24]=2
    data[26]=input
    data[27]=first
    data[29]=output
    data[30]=second
    return data^


def fresh() raises -> SocExchangeProgress:
    var owner=SocExchangeProgress(3,19,16,32,100,100,32)
    owner.launched(19,11,100)
    owner.launched(3,7,101)
    return owner^


def recover() raises:
    var owner=fresh()
    var moved=owner^
    moved.consume(snapshot(3,19,1,1),199)
    if not moved.complete() or moved.progress.input_descriptors!=7 or moved.progress.output_descriptors!=11 or moved.remaining_ms(199)!=1:
        raise Error("ObservedAPI: fresh recovery/move failed")


def poison(owner: SocExchangeProgress) raises:
    if not owner.poisoned or owner.complete():
        raise Error("ObservedAPI: failed event did not poison")


def main() raises:
    var refusals=0
    for which in range(8):
        var owner=fresh()
        var accepted=False
        try:
            if which==0:
                owner.launched(3,7,102)
            elif which==1:
                owner.consume(snapshot(3,19,1,254),102)
            elif which==2:
                owner.consume(snapshot(3,19,1,1),200)
            elif which==3:
                _=owner.remaining_ms(100)
            elif which==4:
                owner.launched(19,0,102)
            elif which==5:
                owner.launched(19,-1,102)
            elif which==6:
                owner.consume(soc_zero_bytes(384),102)
            else:
                for _ in range(33):
                    owner.consume(snapshot(3,19,0,0),102)
            accepted=True
        except:
            pass
        if accepted:
            raise Error("ObservedAPI: invalid event accepted")
        poison(owner)
        if owner.progress.input_done or owner.progress.output_done:
            raise Error("ObservedAPI: invalid batch committed partial progress")
        for attempt in range(3):
            accepted=False
            try:
                if attempt==0:
                    owner.consume(snapshot(3,19,1,1),103)
                elif attempt==1:
                    owner.launched(19,11,103)
                else:
                    _=owner.remaining_ms(103)
                accepted=True
            except:
                pass
            if accepted:
                raise Error("ObservedAPI: poisoned owner revived")
            poison(owner)
            recover()
            refusals+=1
        recover()
        refusals+=1
    # Exact final snapshot may finish; a later duplicate may never revive it.
    var owner=fresh()
    for _ in range(31):
        owner.consume(snapshot(3,19,0,0),102)
    owner.consume(snapshot(3,19,1,1),199)
    if not owner.complete() or owner.snapshots!=32:
        raise Error("ObservedAPI: final-budget completion refused")
    var accepted=False
    try:
        owner.consume(snapshot(3,19,0,0),199)
        accepted=True
    except:
        pass
    if accepted:
        raise Error("ObservedAPI: exhausted budget reused")
    poison(owner)
    recover()
    refusals+=1
    # Input launch before D2H posting refuses and permanently poisons.
    var unposted=SocExchangeProgress(3,19,16,32,0,10,1)
    accepted=False
    try:
        unposted.launched(3,1,0)
        accepted=True
    except:
        pass
    if accepted:
        raise Error("ObservedAPI: H2D before D2H accepted")
    poison(unposted)
    recover()
    refusals+=1
    print("{\"refusal_recovery_cycles\":"+String(refusals)+",\"poison_retries\":24,\"atomic_refusals\":8,\"physical_calls\":false}")
