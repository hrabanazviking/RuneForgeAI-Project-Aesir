# Original one-child physical diagnostic for the program lifecycle
# observation contract (TASK_hailo10h_program_lifecycle_physical).
# Phase A: device CREATE through the Campaign 2 primitive. Phase B:
# one action-2 metadata exchange through SocProgram declaring a
# staged 64-byte test pattern (not a program), resolving to exactly
# one pre-written branch. No payload is ever sent; no configure.
from std.sys import argv
from hailbru.soc_transfer import SocGroupedTransfer, open_grouped_transfer_aligned
from hailbru.soc_program import SocProgram, ProgramIdentity
from hailbru.hrpc_frame import encode_hrpc_frame, decode_hrpc_frame
from hailbru.hrpc_device import device_create_request, device_create_reply, device_destroy_request, device_destroy_reply
from hailbru.syscall import os_page_size


def _bool(value: Bool) -> String:
    return String("true") if value else String("false")


def _identity() -> ProgramIdentity:
    # Digests are sha256 of the fixed inputs named in the contract:
    # the staged pattern bytes((i*29+7)%256) and the probe's label
    # strings. Constants, verifiable from those inputs.
    return ProgramIdentity(
        "6aab302f6d90e2d3da79fc52e4ebd1b0465d3347b9d867da6197a63edcf0b2de",
        "aesir-lifecycle-probe-0",
        "7d9216484c7a64074afd1981c6e7869de91687f77d05ac51880f76414543d3ea",
        "9598e783c3d25dbf01fbe3ab18109c334fb5b65cc0abfbac29fb8c68c02544b1",
        "83c484608300ff1b8b7f8f98209b4dce59973baa7c0a8312bd69dabde0aa1afd",
        "e7a402f6bfefa6ff48bc1fe1bb5b77e5c9c24ca9185937a8cf07a8fdaf2424f0",
        "b3d5bcad2368ea3bea27c83c3bfa0bf1253bf4d35d1ea8b804bd4ce3ba30e337")


def main() raises:
    var args = argv()
    var physical = len(args) == 2 and args[1] == "physical-once"
    var sysfs = String("/sys")
    var devices = String("/dev")
    if not physical:
        if len(args) != 4 or args[1] != "host-mock" or args[2] == "/sys" or args[3] == "/dev":
            raise Error("ProgramLifecycleProbe: physical-once OR host-mock mock-sysfs mock-dev")
        for i in range(2, 4):
            if args[i].byte_length() == 0 or args[i].byte_length() >= 4096 or "\0" in args[i]:
                raise Error("ProgramLifecycleProbe: invalid mock root")
        sysfs = args[2]
        devices = args[3]
    if os_page_size() != 16384 and physical:
        raise Error("ProgramLifecycleProbe: expected qualified Pi page size 16384")
    if os_page_size() != 4096 and os_page_size() != 16384:
        raise Error("ProgramLifecycleProbe: expected a qualified host page size")
    var transfer = open_grouped_transfer_aligned(sysfs, devices)
    var program = SocProgram(_identity())
    print(program.identity.describe())
    var branch = String("A-failed")
    var phase_a_ok = False
    var vdevice_handle = UInt32(0)
    var infer_destroy_attempted = False
    var infer_destroyed = False
    var vdevice_destroy_attempted = False
    var vdevice_destroyed = False
    var exchanges_before_b = UInt64(0)
    # Phase A: device CREATE (message id 0), consumer-validated.
    try:
        var packet = encode_hrpc_frame(device_create_request(0))
        var received = transfer.exchange_raw(packet, 5000)
        var reply = decode_hrpc_frame(received, True)
        vdevice_handle = device_create_reply(reply, 0)
        phase_a_ok = True
    except:
        # Transport failure already poisoned the owner; a refused or
        # malformed reply poisons it here (consumer law).
        transfer.poisoned = True
        phase_a_ok = False
    if phase_a_ok:
        exchanges_before_b = transfer.exchanges
        program.next_message_id = 1
        var create_failed = False
        try:
            program.create(transfer, vdevice_handle, "aesir-lifecycle-probe", 64, 1048576, 5000)
        except:
            create_failed = True
        if not create_failed:
            branch = "B1"
            # Admitted teardown: destroy-infer, then device DESTROY —
            # the latter only on an unpoisoned transport.
            infer_destroy_attempted = True
            try:
                program.destroy_infer(transfer, 5000)
                infer_destroyed = True
            except:
                infer_destroyed = False
            if not transfer.poisoned:
                vdevice_destroy_attempted = True
                try:
                    var packet = encode_hrpc_frame(device_destroy_request(3, vdevice_handle))
                    var received = transfer.exchange_raw(packet, 5000)
                    var reply = decode_hrpc_frame(received, True)
                    device_destroy_reply(reply, 3)
                    vdevice_destroyed = True
                except:
                    transfer.poisoned = True
                    vdevice_destroyed = False
        else:
            # A completed B exchange (counter advanced) with a failed
            # create means a reply arrived and was refused: B3. No
            # completed exchange means no reply: B2.
            branch = "B3" if transfer.exchanges > exchanges_before_b else "B2"
    var close_failed = False
    try:
        transfer.close()
    except:
        close_failed = True
    var retained_views = Int(transfer.session.input_storage.address != 0) + Int(transfer.session.output_storage.address != 0)
    var finalization_unconfirmed = transfer.session.finalization_unconfirmed
    var accepted = phase_a_ok and branch != "A-failed" and not close_failed and retained_views == 0 and not finalization_unconfirmed
    if branch == "B1":
        accepted = accepted and infer_destroy_attempted and (vdevice_destroy_attempted or transfer.poisoned)
    print("{\"accepted\":" + _bool(accepted) + ",\"physical_mode\":" + _bool(physical) + ",\"branch\":\"" + branch + "\",\"phase_a_ok\":" + _bool(phase_a_ok) + ",\"infer_destroy_attempted\":" + _bool(infer_destroy_attempted) + ",\"infer_destroyed\":" + _bool(infer_destroyed) + ",\"vdevice_destroy_attempted\":" + _bool(vdevice_destroy_attempted) + ",\"vdevice_destroyed\":" + _bool(vdevice_destroyed) + ",\"poisoned\":" + _bool(program.poisoned or transfer.poisoned) + ",\"retained_views\":" + String(retained_views) + ",\"finalization_unconfirmed\":" + _bool(finalization_unconfirmed) + ",\"close_failed\":" + _bool(close_failed) + ",\"exchanges\":" + String(transfer.exchanges) + ",\"snapshots\":" + String(transfer.irq_snapshots) + "}")
    if not accepted:
        raise Error("ProgramLifecycleProbe: run unaccepted (branch and facts in the JSON line)")
