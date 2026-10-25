# Original explicit one-child grouped TRANSFER diagnostic. One CREATE
# exchange through the minimal primitive (hailbru/soc_transfer.mojo)
# on aligned backing; consumer-layer reply validation as qualified
# under AES-TRANSFER-003. No model operation, no lifecycle.
from std.sys import argv
from hailbru.soc_transfer import SocGroupedTransfer, open_grouped_transfer_aligned
from hailbru.hrpc_frame import encode_hrpc_frame, decode_hrpc_frame
from hailbru.hrpc_device import device_create_request, device_create_reply
from hailbru.syscall import os_page_size


def _json_bool(value: Bool) -> String:
    return String("true") if value else String("false")


def main() raises:
    var args = argv()
    var physical = len(args) == 2 and args[1] == "physical-once"
    var sysfs = String("/sys")
    var devices = String("/dev")
    if not physical:
        if len(args) != 4 or args[1] != "host-mock" or args[2] == "/sys" or args[3] == "/dev":
            raise Error("GroupTransferProbe: physical-once OR host-mock mock-sysfs mock-dev")
        for i in range(2, 4):
            if args[i].byte_length() == 0 or args[i].byte_length() >= 4096 or "\0" in args[i]:
                raise Error("GroupTransferProbe: invalid mock root")
        sysfs = args[2]
        devices = args[3]
    # Admission precedes the fresh owner. Driver/device properties are
    # checked by open_soc_driver before descriptor allocation, mapping
    # or launch.
    if os_page_size() != 16384:
        raise Error("GroupTransferProbe: expected qualified host page size 16384")
    var exchange_completed = False
    var handle_known = False
    var poisoned = False
    var primary_error = False
    var close_error = False
    var retained_views = 0
    var finalization_unconfirmed = False
    var input_descriptors = Int64(0)
    var output_descriptors = Int64(0)
    var snapshots = UInt64(0)
    var input_completions = UInt64(0)
    var output_completions = UInt64(0)
    var transfer = SocGroupedTransfer()
    var opened = False
    try:
        transfer = open_grouped_transfer_aligned(sysfs, devices)
        opened = True
    except:
        primary_error = True
        poisoned = True
    if opened:
        try:
            var packet = encode_hrpc_frame(device_create_request(0))
            var received = transfer.exchange_raw(packet, 5000)
            exchange_completed = True
            input_descriptors = transfer.last_input_descriptors
            output_descriptors = transfer.last_output_descriptors
            snapshots = transfer.irq_snapshots
            input_completions = transfer.input_completions
            output_completions = transfer.output_completions
            # Consumer layer (AES-TRANSFER-003): the primitive is
            # framing-free, so reply validation — and poisoning the
            # owner on any framing failure — lives here.
            try:
                var reply = decode_hrpc_frame(received, True)
                if reply.message_id != 0 or reply.action_id != 20:
                    raise Error("RpcReplyMismatch: received frame differs from the owned exchange")
                if reply.remote_status != 0:
                    raise Error("RpcRemoteFailure: grouped control returned status " + String(reply.remote_status))
                _ = device_create_reply(reply, 0)
                handle_known = True
            except:
                transfer.poisoned = True
                primary_error = True
        except:
            primary_error = True
        poisoned = transfer.poisoned
        try:
            transfer.close()
        except:
            close_error = True
        retained_views = Int(transfer.session.input_storage.address != 0) + Int(transfer.session.output_storage.address != 0)
        finalization_unconfirmed = transfer.session.finalization_unconfirmed
    var accepted = exchange_completed and handle_known and not poisoned and not primary_error and not close_error and retained_views == 0 and not finalization_unconfirmed and input_completions == 1 and output_completions == 1
    # No handle, identity-bearing wire, serial or logger value is printed.
    print("{\"accepted\":" + _json_bool(accepted) + ",\"physical_mode\":" + _json_bool(physical) + ",\"exchange_completed\":" + _json_bool(exchange_completed) + ",\"handle_known\":" + _json_bool(handle_known) + ",\"poisoned\":" + _json_bool(poisoned) + ",\"primary_error\":" + _json_bool(primary_error) + ",\"close_error\":" + _json_bool(close_error) + ",\"retained_views\":" + String(retained_views) + ",\"finalization_unconfirmed\":" + _json_bool(finalization_unconfirmed) + ",\"input_descriptors\":" + String(input_descriptors) + ",\"output_descriptors\":" + String(output_descriptors) + ",\"snapshots\":" + String(snapshots) + ",\"input_completions\":" + String(input_completions) + ",\"output_completions\":" + String(output_completions) + "}")
    if not accepted:
        raise Error("GroupTransferProbe: exchange, validation or finalization unconfirmed")
