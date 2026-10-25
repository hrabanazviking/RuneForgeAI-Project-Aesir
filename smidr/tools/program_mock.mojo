# Original host-mock diagnostic for the program-object lifecycle
# owner (hailbru/soc_program.mojo). Host-mock roots only; framing
# lives here, on top of the Campaign 2 primitive. Scenarios exercise
# the full state machine and every fail-closed gate.
from std.sys import argv
from hailbru.soc_transfer import SocGroupedTransfer, open_grouped_transfer_aligned
from hailbru.soc_program import SocProgram, ProgramIdentity
from hailbru.hrpc_configure import HrpcInferStream, plain_infer_stream
from hailbru.syscall import os_page_size

comptime DIGEST = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"


def _bool(value: Bool) -> String:
    return String("true") if value else String("false")


def _identity() -> ProgramIdentity:
    return ProgramIdentity(String(DIGEST), "aesir-test-compiler",
                           String(DIGEST), String(DIGEST), String(DIGEST),
                           String(DIGEST), String(DIGEST))


def _streams() -> List[HrpcInferStream]:
    var streams = List[HrpcInferStream]()
    streams.append(plain_infer_stream("stream", 0, 0))
    return streams^


def main() raises:
    var args = argv()
    if len(args) != 5 or args[1] != "host-mock-aligned" or args[2] == "/sys" or args[3] == "/dev":
        raise Error("ProgramMock: host-mock-aligned mock-sysfs mock-dev scenario")
    for i in range(2, 4):
        if args[i].byte_length() == 0 or args[i].byte_length() >= 4096 or "\0" in args[i]:
            raise Error("ProgramMock: invalid mock root")
    var scenario = args[4]
    if scenario != "full" and scenario != "no-attest" and scenario != "bad-attest" and scenario != "teardown-order" and scenario != "early-configure" and scenario != "early-destroy" and scenario != "double-create":
        raise Error("ProgramMock: unknown scenario")
    if os_page_size() != 4096 and os_page_size() != 16384:
        raise Error("ProgramMock: expected a qualified host page size (4096 or 16384)")
    var transfer = open_grouped_transfer_aligned(args[2], args[3])
    var program = SocProgram(_identity())
    print(program.identity.describe())
    var identity_printed = True
    var refused = String("")
    try:
        if scenario == "full" or scenario == "no-attest" or scenario == "bad-attest" or scenario == "teardown-order":
            program.create(transfer, 7, "aesir-program", 4096, 1048576, 5000)
        if scenario == "full":
            program.attest_payload_delivered(String(DIGEST))
            program.configure(transfer, _streams(), _streams(), 1, 0, 0, False, 5000)
            program.activate(transfer, 5000)
            program.deactivate(transfer, 5000)
            program.shutdown(transfer, 5000)
            program.destroy_configured(transfer, 5000)
            program.destroy_infer(transfer, 5000)
        elif scenario == "no-attest":
            program.configure(transfer, _streams(), _streams(), 1, 0, 0, False, 5000)
        elif scenario == "bad-attest":
            program.attest_payload_delivered("bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb")
        elif scenario == "teardown-order":
            program.attest_payload_delivered(String(DIGEST))
            program.configure(transfer, _streams(), _streams(), 1, 0, 0, False, 5000)
            program.destroy_configured(transfer, 5000)
        elif scenario == "early-configure":
            program.configure(transfer, _streams(), _streams(), 1, 0, 0, False, 5000)
        elif scenario == "early-destroy":
            program.destroy_infer(transfer, 5000)
        elif scenario == "double-create":
            program.create(transfer, 7, "aesir-program", 4096, 1048576, 5000)
            program.create(transfer, 7, "aesir-program", 4096, 1048576, 5000)
        else:
            raise Error("ProgramMock: unknown scenario")
    except e:
        refused = String(e)
    var close_failed = False
    try:
        transfer.close()
    except:
        close_failed = True
    var accepted = refused.byte_length() == 0 and not close_failed and not program.poisoned and program.stages_completed == 7 and program.stage == 0 and transfer.exchanges == 7
    print("{\"accepted\":" + _bool(accepted) + ",\"scenario\":\"" + scenario + "\",\"identity_printed\":" + _bool(identity_printed) + ",\"stages_completed\":" + String(program.stages_completed) + ",\"stage\":" + String(program.stage) + ",\"exchanges\":" + String(transfer.exchanges) + ",\"infer_known\":" + _bool(program.infer_known) + ",\"configured_known\":" + _bool(program.configured_known) + ",\"payload_attested\":" + _bool(program.payload_attested) + ",\"poisoned\":" + _bool(program.poisoned or transfer.poisoned) + ",\"refused\":" + _bool(refused.byte_length() != 0) + ",\"close_failed\":" + _bool(close_failed) + ",\"physical_calls\":false}")
    if scenario == "full" and not accepted:
        raise Error("ProgramMock: full lifecycle scenario unaccepted")
    if scenario != "full" and refused.byte_length() == 0:
        raise Error("ProgramMock: refusal scenario was not refused")
