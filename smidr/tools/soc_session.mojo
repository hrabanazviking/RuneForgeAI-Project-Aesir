# Real assigned connection lifecycle; no user DMA buffer, RPC or model transfer.
from std.sys import argv
from hailbru.errors import herror
from hailbru.soc_session import open_soc_session


def main() raises:
    var args = argv()
    if len(args) != 3:
        raise herror("BadArgs", "usage: soc_session <sysfs-root> <dev-root>")
    var session = open_soc_session(args[1], args[2])
    session.require_open()
    var record = "{\"bdf\":\"" + session.driver.bdf + "\",\"port\":12133,\"descriptor_count_per_direction\":65536,\"descriptor_page_size\":" + String(session.page_size) + ",\"input_handle\":" + String(session.input_handle) + ",\"output_handle\":" + String(session.output_handle) + ",\"input_channel\":" + String(session.input_channel) + ",\"output_channel\":" + String(session.output_channel)
    session.close()
    session.close()
    var refused = False
    try:
        session.require_open()
    except error:
        if String(error).find("SocSessionClosed") >= 0:
            refused = True
        else:
            raise error
    if not refused:
        raise herror("SocCleanupFailed", "closed session incorrectly remained open")
    print(record + ",\"connection_closed\":true,\"repeat_close\":true,\"closed_use_refused\":true,\"user_dma_submitted\":false}")
