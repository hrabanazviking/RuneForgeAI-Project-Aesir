# Actual independent Mojo create/identify/destroy; no model or inference.
from std.sys import argv
from hailbru.soc_rpc import SocRpcClient, open_soc_rpc
from hailbru.hrpc_device import (
    device_create_request, device_create_reply, device_identify_request,
    device_identify_reply, device_destroy_request, device_destroy_reply, HrpcDeviceIdentity,
)
from hailbru.errors import herror


def identify_and_destroy(mut client: SocRpcClient) raises -> HrpcDeviceIdentity:
    var handle_known = False
    var handle = UInt32(0)
    try:
        var created = client.exchange(device_create_request(0), 1000)
        handle = device_create_reply(created, 0)
        handle_known = True
        var identified = client.exchange(device_identify_request(1, handle), 1000)
        var identity = device_identify_reply(identified, 1)
        var destroyed = client.exchange(device_destroy_request(2, handle), 1000)
        device_destroy_reply(destroyed, 2)
        handle_known = False
        return identity^
    except error:
        var original = String(error)
        if handle_known:
            if client.session.connected and client.session.driver.fd >= 0 and not client.session.wait_failed:
                try:
                    var destroyed = client.exchange(device_destroy_request(3, handle), 1000)
                    device_destroy_reply(destroyed, 3)
                    handle_known = False
                except cleanup:
                    original += "; " + String(cleanup)
            if handle_known:
                original += "; remote logical-device cleanup is unconfirmed after the failed exchange"
        try:
            client.close()
        except cleanup:
            original += "; " + String(cleanup)
        raise Error(original)


def main() raises:
    var args = argv()
    if len(args) != 3:
        raise herror("BadArgs", "usage: soc_rpc_device <sysfs-root> <dev-root>")
    var client = open_soc_rpc(args[1], args[2])
    var identity = identify_and_destroy(client)
    if not identity.firmware_present or identity.architecture != 6 or identity.firmware_major != 5 or identity.firmware_minor != 3 or identity.firmware_revision != 0:
        raise herror("SocIdentityMismatch", "device identity differs from the qualified Hailo10H profile")
    var exchanges = client.exchanges
    var inputs = client.input_completions
    var outputs = client.output_completions
    var snapshots = client.irq_snapshots
    var input_desc = client.last_input_descriptors
    var output_desc = client.last_output_descriptors
    client.close()
    client.close()
    if exchanges != 3 or inputs != 3 or outputs != 3:
        raise herror("SocTransferCount", "typed lifecycle did not earn all directional completions")
    print("{\"native_mojo_rpc\":true,\"create_identify_destroy\":true,\"exchanges\":" + String(exchanges) + ",\"input_completions\":" + String(inputs) + ",\"output_completions\":" + String(outputs) + ",\"irq_snapshots\":" + String(snapshots) + ",\"last_input_descriptors\":" + String(input_desc) + ",\"last_output_descriptors\":" + String(output_desc) + ",\"architecture\":6,\"protocol_version\":" + String(identity.protocol_version) + ",\"firmware\":\"5.3.0\",\"closed\":true,\"model_loaded\":false,\"llm_inference\":false}")
