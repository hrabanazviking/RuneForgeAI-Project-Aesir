# Actual assigned-channel deadline/cancellation; maps storage but launches no DMA.
from std.sys import argv
from hailbru.soc_session import open_soc_session
from hailbru.soc_abi import soc_interrupts_json, _get
from hailbru.errors import herror


def main() raises:
    var args = argv()
    if len(args) != 3:
        raise herror("BadArgs", "usage: soc_wait <sysfs-root> <dev-root>")
    var session = open_soc_session(args[1], args[2])
    session.allocate_rpc_storage()
    var timeout = False
    try:
        _ = session.wait_interrupts(25)
    except error:
        if String(error).find("SocWaitTimeout") < 0:
            raise error
        timeout = True
    if not timeout or session.waiter.active or session.interrupts_enabled:
        raise herror("SocWaitFailed", "empty assigned channels did not timeout and join after disable")
    var result = session.waiter.result()
    if result[0] != 0 or result[1] != 0:
        raise herror("SocWaitFailed", "disabled wait did not return success")
    var irqs = soc_interrupts_json(session.waiter.payload())
    if irqs != "[]":
        raise herror("SocWaitFailed", "empty assigned channels unexpectedly completed DMA")
    var payload = session.waiter.payload()
    var mask = (UInt64(1) << UInt64(session.input_channel)) | (UInt64(1) << UInt64(session.output_channel))
    if _get(payload, 0, 8) != mask or _get(payload, 8, 8) != 0 or _get(payload, 16, 8) != 0:
        raise herror("SocWaitFailed", "wait reply did not retain the assigned engine-zero mask")
    var attempts = session.cancel_attempts
    var refused = False
    try:
        session.require_open()
    except error:
        if String(error).find("SocSessionCancelled") < 0:
            raise error
        refused = True
    if not refused:
        raise herror("SocWaitFailed", "cancelled session still admitted normal use")
    session.close()
    session.close()
    if session.input_storage.address != 0 or session.output_storage.address != 0:
        raise herror("SocWaitFailed", "closed session retained storage")
    print("{\"timed_out\":true,\"cancel_attempts\":" + String(attempts) + ",\"owned_mask\":" + String(mask) + ",\"waiter_joined\":true,\"irq_after_disable\":[],\"cancelled_use_refused\":true,\"storage_released\":true,\"user_dma_submitted\":false}")
