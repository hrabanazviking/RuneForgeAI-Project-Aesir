# Original direct lifetime/guard consumer. No numerical execution.
from std.sys import argv
from smidr.program_envelope import build_program_envelope
from smidr.program_payload import ProgramPayloadRequest, stage_program_payload
from smidr.sealed_program_payload import seal_program_payload
from smidr.sealed_transfer_backing import SealedTransferBacking, seal_transfer_backing, sealed_transfer_window
from smidr.sealed_transfer_pin import SealedTransferPin, pin_sealed_transfer, view_sealed_transfer


def request() -> ProgramPayloadRequest:
    return ProgramPayloadRequest(17,0,"two-part-pin",32768)


def backing() raises -> SealedTransferBacking:
    var body = List[UInt8]()
    for i in range(14):
        body.append(UInt8((i*37+11)%256))
    var empty = List[UInt8]()
    var program = build_program_envelope(body,empty,empty,0,False,70)
    var staged = stage_program_payload(program,request())
    var sealed = seal_program_payload(staged,request(),"aarch64",16,16)
    return seal_transfer_backing(sealed^,request(),16,16,16)


def main() raises:
    var args = argv()
    if len(args) != 4:
        raise Error("usage: sealed_transfer_pin_api guards|lifetime|poison roots roots")
    if args[1] == "guards":
        var refusals = 0
        for i in range(12):
            var source = backing()
            var expected = request()
            if i == 9:
                expected.message_id += 1
            if i == 10:
                source.program.program_bytes += 1
            if i == 11:
                source.arch = "x86_64"
            try:
                var owner = view_sealed_transfer(source^,expected,
                    0 if i==0 else (2067 if i==1 else 32768),
                    Int64(0 if i==2 else (-1 if i==3 else (4096 if i==4 else 65536))),
                    0 if i==5 else (-1 if i==6 else 16),
                    0 if i==7 else (-1 if i==8 else 16))
                owner.close()
            except:
                refusals += 1
        if refusals != 12:
            raise Error("SealedTransferPinAPI: a required guard did not refuse")
        print("{\"guard_refusals\":12,\"device_access\":false}")
    elif args[1] == "lifetime":
        var first = SealedTransferPin()
        first.close()
        first.close()
        var source = backing()
        var owner = view_sealed_transfer(source^,request(),32768,65536,16,16)
        var moved = owner^
        var copied = sealed_transfer_window(moved.backing,request(),1,0,70,70,16,16)
        moved.finalize_driver()
        moved.finalize_driver()
        moved.close()
        moved.close()
        if len(copied) != 70 or copied[56] != 11:
            raise Error("SealedTransferPinAPI: independent copied bytes changed after close")
        print("{\"moves_and_defaults\":true,\"copy_survives_close\":true,\"device_access\":false}")
    elif args[1] == "poison":
        var source = backing()
        var owner = pin_sealed_transfer(source^,request(),32768,65536,16,16,args[2],args[3])
        var refused = 0
        for i in range(3):
            try:
                if i == 2:
                    owner.finalize_driver()
                else:
                    owner.close()
            except error:
                if "cleanup_unconfirmed" not in String(error):
                    raise error
                refused += 1
        if refused != 3 or not owner.finalization_unconfirmed:
            raise Error("SealedTransferPinAPI: poisoned owner reused or close retried")
        print("{\"poisoned_reuse_refusals\":3,\"explicit_host_releases\":0}")
    else:
        raise Error("SealedTransferPinAPI: unknown mode")
