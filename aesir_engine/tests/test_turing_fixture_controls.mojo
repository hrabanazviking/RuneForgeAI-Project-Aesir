"""Owned real control aborts and complete post-reset vector collection."""
from std.sys import argv
from std.ffi import external_call
from std.collections import InlineArray
from core.generation_control import monotonic_milliseconds
from cli.interrupts import ChatInterrupts, consume_interrupts
from tests.turing_prefill_fixture import TuringPrefillFixture, ignore_layer
from tests.test_turing_model_prefill import inputs, run, logits


def signal_layer(layer: Int) raises:
    if layer == 8:
        var owner = external_call["pthread_self",UInt64]()
        if external_call["pthread_kill",Int32](owner,Int32(2)) != 0:
            raise Error("Cannot deliver owned control SIGINT")


def fail_layer(layer: Int) raises:
    if layer == 1: raise Error("Owned unexpected observer exception")


def refusal(mut f: TuringPrefillFixture,tokens: List[Int],poisoned: Bool) raises -> Int:
    var rejects = 0
    var sampler = f.sampler.position
    var reason = f.control.reason
    var healthy = f.healthy
    for operation in range(4 if poisoned else 3):
        var rejected = False
        try:
            if operation == 0: f.step(tokens,0,32)
            elif operation == 1: f.configure_control()
            elif operation == 2: f.start_control()
            else: f.reset()
        except: rejected = True
        if not rejected or f.position != 0 or len(f.committed) != 0 or f.sampler.position != sampler or f.control.reason != reason or f.healthy != healthy:
            raise Error("Interrupted fixture reuse mutated uncommitted state")
        rejects += 1
    return rejects


def recovered(mut f: TuringPrefillFixture,tokens: List[Int],index: Int) raises:
    var weight = Int(f.native.weights.unsafe_ptr())
    var activation = Int(f.activations.unsafe_ptr())
    var cache = Int(f.cache.unsafe_ptr())
    f.reset()
    if f.position != 0 or len(f.committed) != 0 or f.sampler.position != 0 or not f.healthy or f.control.reset_required or f.control.reason != "" or f.control.started or f.control.generation.deadline_ms != 0:
        raise Error("Explicit reset retained aborted tile state")
    if weight != Int(f.native.weights.unsafe_ptr()) or activation != Int(f.activations.unsafe_ptr()) or cache != Int(f.cache.unsafe_ptr()):
        raise Error("Control reset replaced immutable weights or owned buffers")
    print("RESET,"+String(index)+",0,0,0,1,0,1,1,1,0,0")
    f.configure_control()
    _ = run(f,tokens,0)
    var native = logits(f,0)
    _ = run(f,tokens,1)
    var matrix = logits(f,1)
    for i in range(128256):
        print("LOGIT,"+String(index)+","+String(i)+","+String(Float64(native[i]))+","+String(Float64(matrix[i])))
    f.guards()
    print("GUARD,"+String(index)+",1088,0")


def abort_case(mut f: TuringPrefillFixture,tokens: List[Int],index: Int,fd: Int) raises:
    f.reset()
    if index == 0:
        f.configure_control(10000)
        f.start_control()
        f.control.generation.deadline_ms = monotonic_milliseconds()-1
    elif index == 1:
        f.configure_control(10)
        f.start_control()
    else:
        f.configure_control(0,fd if index == 2 else 2147483647)
        f.start_control()
    var rejected = False
    try:
        if index == 2: f.step(tokens,0,32,False,signal_layer)
        else: f.step(tokens,0,32)
    except: rejected = True
    var reason = "timeout" if index < 2 else ("cancelled" if index == 2 else "control_error")
    var layers = f.control.completed_layers
    var sampler = 32 if index == 1 or index == 2 else 0
    if not rejected or not f.healthy or not f.control.reset_required or f.control.reason != reason or f.position != 0 or len(f.committed) != 0 or f.sampler.position != sampler:
        raise Error("Control abort committed or lost its reset requirement")
    if (index == 1 and not 0 < layers < 28) or (index == 2 and layers != 8) or ((index == 0 or index == 3) and layers != 0):
        raise Error("Control did not stop at the declared physical layer boundary")
    print("CONTROL,"+String(index)+","+reason+","+String(layers)+",0,0,"+String(sampler)+",1,1")
    f.guards()
    print("ABORT_GUARD,"+String(index)+",1088,0")
    print("REFUSAL,"+String(index)+","+String(refusal(f,tokens,False))+",0")
    if index == 2:
        if not consume_interrupts(fd) or consume_interrupts(fd):
            raise Error("Control consumed or duplicated its caller-owned SIGINT")
        print("SIGINT_OWNER,2,1,0")
    recovered(f,tokens,index)


def exercise(path: String) raises:
    var interrupts = ChatInterrupts()
    var f = TuringPrefillFixture(path)
    var tokens = inputs(f,"Explain how a knowledge graph connects documents, entities and their evidence. Write three sentences.")
    if len(tokens) != 37: raise Error("Recovery public prompt changed")
    print("META,1,fixture_controls,1536,32,128256,4,1")
    for i in range(len(tokens)): print("INPUT,"+String(i)+","+String(tokens[i]))
    for index in range(4): abort_case(f,tokens,index,interrupts.fd)
    f.reset()
    f.configure_control(1000000)
    f.start_control()
    var failed = False
    try: f.step(tokens,0,32,False,fail_layer)
    except: failed = True
    if not failed or f.healthy or f.position != 0 or len(f.committed) != 0 or f.sampler.position != 32 or f.control.completed_layers != 1:
        raise Error("Unexpected observer failure did not poison fixture")
    print("POISON,1,0,0,32,0,"+String(refusal(f,tokens,True))+",0")
    f.guards()
    print("POISON_GUARD,1088,0")
    _ = interrupts


def main() raises:
    var args = argv()
    if len(args) != 2: raise Error("usage: test_turing_fixture_controls MODEL.gguf")
    var before = InlineArray[UInt64,16](fill=0)
    var after = InlineArray[UInt64,16](fill=0)
    if external_call["pthread_sigmask",Int32](Int32(0),Int(0),Int(before.unsafe_ptr())) != 0:
        raise Error("Cannot observe original owner mask")
    exercise(args[1])
    if external_call["pthread_sigmask",Int32](Int32(0),Int(0),Int(after.unsafe_ptr())) != 0:
        raise Error("Cannot observe restored owner mask")
    for i in range(16):
        if before[i] != after[i]: raise Error("Control leaked owner signal mask")
    print("MASK_RESTORED,1")
    print("COMPLETE,fixture_controls,4,513024,1,9792,1")
