# Real mapping/sync ownership consumer; no transfer, payload or model supplied.
from std.sys import argv
from hailbru.errors import herror
from hailbru.soc_session import open_soc_session
from hailbru.soc_storage import SOC_RPC_STORAGE_SIZE


def main() raises:
    var args = argv()
    if len(args) != 3:
        raise herror("BadArgs", "usage: soc_storage <sysfs-root> <dev-root>")
    var session = open_soc_session(args[1], args[2])
    session.allocate_rpc_storage()
    var allocation_size = session.input_storage.allocated_size
    var page_size = session.input_storage.page_size
    var input_handle = session.input_storage.handle
    var output_handle = session.output_storage.handle
    var refused = False
    try:
        _ = session.input_storage.zeroed()
    except error:
        if String(error).find("SocStorageState") < 0:
            raise error
        refused = True
    if not refused:
        raise herror("SocStorageState", "mapped storage admitted CPU access without sync")
    var release_refused = False
    try:
        session.input_storage.release()
    except error:
        if String(error).find("SocStorageState") < 0:
            raise error
        release_refused = True
    if not release_refused:
        raise herror("SocStorageState", "live mapping storage was released")
    session.input_storage.sync(session.driver, False)
    session.output_storage.sync(session.driver, False)
    if not session.input_storage.zeroed() or not session.output_storage.zeroed():
        raise herror("SocStorageFailed", "new RPC storage was not zero initialized")
    session.input_storage.sync(session.driver, True)
    session.output_storage.sync(session.driver, True)
    session.close()
    session.close()
    var closed_refused = False
    try:
        session.input_storage.sync(session.driver, False)
    except error:
        if String(error).find("SocStorageState") < 0:
            raise error
        closed_refused = True
    if not closed_refused or session.input_storage.address != 0 or session.output_storage.address != 0:
        raise herror("SocStorageState", "closed storage still usable or allocated")
    print("{\"logical_size\":" + String(SOC_RPC_STORAGE_SIZE) + ",\"allocation_size\":" + String(allocation_size) + ",\"page_size\":" + String(page_size) + ",\"input_mapping_handle\":" + String(input_handle) + ",\"output_mapping_handle\":" + String(output_handle) + ",\"zero_initialized\":true,\"cpu_access_without_sync_refused\":true,\"live_mapping_release_refused\":true,\"closed_sync_refused\":true,\"storage_released\":true,\"user_dma_submitted\":false}")
