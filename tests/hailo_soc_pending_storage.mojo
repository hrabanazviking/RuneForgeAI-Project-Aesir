# Real mappings with software pending state; deliberately no DMA launch.
from std.sys import argv
from hailbru.soc_session import open_soc_session


def main() raises:
    var args = argv()
    if len(args) != 3:
        raise Error("usage: pending_storage <sysfs-root> <dev-root>")
    var session = open_soc_session(args[1], args[2])
    session.allocate_rpc_storage()
    session.input_storage.begin_transfer()
    session.output_storage.begin_transfer()
    var refused = 0
    for action in range(5):
        try:
            if action == 0:
                session.input_storage.sync(session.driver, False)
            elif action == 1:
                session.input_storage.unmap(session.driver)
            elif action == 2:
                _ = session.input_storage.read_bytes(1)
            elif action == 3:
                session.input_storage.write_message(List[UInt8]())
            else:
                session.input_storage.begin_transfer()
        except error:
            if String(error).find("SocStorageState") < 0:
                raise error
            refused += 1
    if refused != 5:
        raise Error("pending state did not refuse all unsafe operations")
    # Software uncertainty clears only after the actual assigned channels stop.
    session.close()
    if session.input_storage.transfer_pending or session.output_storage.transfer_pending or session.input_storage.address != 0 or session.output_storage.address != 0:
        raise Error("quiesced cleanup did not release pending software state/storage")
    print("{\"refusals\":5,\"software_pending_state_only\":true,\"storage_released\":true,\"user_dma_submitted\":false}")
