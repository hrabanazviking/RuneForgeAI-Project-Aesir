# Original host-only API qualification;external seams never open the device.
from std.sys import argv
from hailbru.soc_session import SocSession, open_soc_session
from smidr.tools.hrpc_frame import _to_hex


def _hex(text: String) -> String:
    var data = List[UInt8]()
    for byte in text.as_bytes():
        data.append(byte)
    return _to_hex(data)


def observe(mut session: SocSession, pending: Bool, uncertain: Bool) raises:
    var primary = String("")
    try:
        session.allocate_rpc_storage()
        if pending:
            session.input_storage.begin_transfer()
            session.output_storage.begin_transfer()
    except error:
        primary = String(error)
    var allocated = Int(session.input_storage.address != 0) + Int(session.output_storage.address != 0)
    var cleanup = String("")
    try:
        session.close()
    except error:
        cleanup = String(error)
    var refusals = 0
    if uncertain:
        if not session.finalization_unconfirmed or session.driver.fd != -1 or cleanup.find("unconfirmed finalization") < 0:
            raise Error("FinalizationAPI: uncertainty was not retained")
        if session.input_storage.address != 0 and (not session.input_storage.mapping_attempted or session.input_storage.cpu_owned):
            raise Error("FinalizationAPI: input backing lost retention")
        if session.output_storage.address != 0 and (not session.output_storage.mapping_attempted or session.output_storage.cpu_owned):
            raise Error("FinalizationAPI: output backing lost retention")
        var expected_refusals = 8 if session.input_storage.address != 0 else 6
        for action in range(8):
            if session.input_storage.address == 0 and (action == 4 or action == 6):
                continue
            try:
                if action == 0:
                    session.close()
                elif action == 1:
                    session.require_open()
                elif action == 2:
                    session.allocate_rpc_storage()
                elif action == 3:
                    _ = session.input_storage.read_bytes(1)
                elif action == 4:
                    session.input_storage.release()
                elif action == 5:
                    session.input_storage.sync(session.driver, False)
                elif action == 6:
                    session.input_storage.unmap(session.driver)
                else:
                    session.enable_interrupts()
            except error:
                refusals += 1
        if refusals != expected_refusals:
            raise Error("FinalizationAPI: poisoned owner admitted unsafe reuse")
        if allocated != Int(session.input_storage.address != 0) + Int(session.output_storage.address != 0):
            raise Error("FinalizationAPI: retained allocation count changed")
    else:
        if session.finalization_unconfirmed or session.input_storage.address != 0 or session.output_storage.address != 0:
            raise Error("FinalizationAPI: confirmed finalization failed to release backing")
        session.close()
    print("{\"allocated\":" + String(allocated) + ",\"uncertain\":" + (String("true") if uncertain else String("false"))
          + ",\"reuse_refusals\":" + String(refusals) + ",\"primary_hex\":\"" + _hex(primary)
          + "\",\"cleanup_hex\":\"" + _hex(cleanup) + "\",\"physical_evidence\":false,\"dma_submitted\":false}")


def main() raises:
    var args = argv()
    if len(args) != 5 or (args[3] != "idle" and args[3] != "pending") or (args[4] != "confirmed" and args[4] != "uncertain"):
        raise Error("usage: session_finalization_api sysfs dev idle|pending confirmed|uncertain")
    var original = open_soc_session(args[1], args[2])
    var moved = original^
    observe(moved, args[3] == "pending", args[4] == "uncertain")
