# Host-only aligned layout admission and CPU scatter/gather consumer.
# No driver is opened or simulated; storage is a real host allocation.
from std.sys import argv
from std.memory import Pointer
from std.origin import MutUntrackedOrigin
from hailbru.errors import herror
from hailbru.syscall import os_host_architecture
from hailbru.soc_storage import (
    SocRpcStorage, SOC_RPC_STORAGE_SIZE, SOC_RPC_HEADER_SIZE, SOC_RPC_BODY_SIZE,
    soc_rpc_layout_legacy, soc_rpc_layout_aligned,
)
from smidr.tools.hrpc_frame import _from_hex, _to_hex
from smidr.tools.program_integrity import _integer


def raw_hex(storage: SocRpcStorage, offset: Int, count: Int) -> String:
    var bytes = Pointer[UInt8, MutUntrackedOrigin](unsafe_from_address=Int(storage.address))
    var data = List[UInt8]()
    for index in range(count):
        data.append(bytes[unsafe_offset=offset + index])
    return _to_hex(data)


def raw_all_zero(storage: SocRpcStorage, offset: Int, count: Int) -> Bool:
    var bytes = Pointer[UInt8, MutUntrackedOrigin](unsafe_from_address=Int(storage.address))
    for index in range(count):
        if bytes[unsafe_offset=offset + index] != 0:
            return False
    return True


def main() raises:
    var args = argv()
    if len(args) < 2:
        raise herror("BadArgs", "usage: aligned_storage <layout|layout-legacy|scatter|guards> ...")
    if args[1] == "layout":
        if len(args) != 3:
            raise herror("BadArgs", "usage: aligned_storage layout <descriptor-page>")
        var layout = soc_rpc_layout_aligned(UInt64(_integer(args[2])))
        print("{\"page\":" + String(layout.descriptor_page) + ",\"body_offset\":" + String(layout.body_offset) + ",\"mapped_size\":" + String(layout.mapped_size) + ",\"logical_size\":" + String(SOC_RPC_STORAGE_SIZE) + ",\"aligned\":true}")
    elif args[1] == "layout-legacy":
        if len(args) != 2:
            raise herror("BadArgs", "usage: aligned_storage layout-legacy")
        var layout = soc_rpc_layout_legacy()
        print("{\"page\":" + String(layout.descriptor_page) + ",\"body_offset\":" + String(layout.body_offset) + ",\"mapped_size\":" + String(layout.mapped_size) + ",\"logical_size\":" + String(SOC_RPC_STORAGE_SIZE) + ",\"aligned\":false}")
    elif args[1] == "scatter":
        if len(args) != 4:
            raise herror("BadArgs", "usage: aligned_storage scatter <descriptor-page> <hex>")
        var page = _integer(args[2])
        var data = _from_hex(args[3])
        var storage = SocRpcStorage()
        if page == 0:
            storage.allocate(os_host_architecture(), 1)
        else:
            storage.allocate_aligned(os_host_architecture(), 1, UInt64(page))
        storage.write_message(data)
        var gather = storage.read_message()
        var header = raw_hex(storage, 0, Int(SOC_RPC_HEADER_SIZE))
        var body = raw_hex(storage, Int(storage.body_offset()), Int(SOC_RPC_BODY_SIZE))
        var gap_size = Int(storage.body_offset()) - Int(SOC_RPC_HEADER_SIZE)
        var gap_zero = raw_all_zero(storage, Int(SOC_RPC_HEADER_SIZE), gap_size)
        storage.write_message(List[UInt8]())
        var cleared = storage.zeroed()
        var allocated = storage.allocated_size
        var mapped = storage.mapped_size()
        var offset = storage.body_offset()
        storage.release()
        print("{\"gather\":\"" + _to_hex(gather) + "\",\"header\":\"" + header + "\",\"body\":\"" + body + "\",\"gap_all_zero\":" + (String("true") if gap_zero else String("false")) + ",\"gap_size\":" + String(gap_size) + ",\"cleared\":" + (String("true") if cleared else String("false")) + ",\"allocated_size\":" + String(allocated) + ",\"mapped_size\":" + String(mapped) + ",\"body_offset\":" + String(offset) + "}")
    elif args[1] == "guards":
        if len(args) != 3:
            raise herror("BadArgs", "usage: aligned_storage guards <descriptor-page>")
        var page = UInt64(_integer(args[2]))
        var refusals = 0
        var storage = SocRpcStorage()
        storage.allocate_aligned(os_host_architecture(), 1, page)
        var oversized = List[UInt8]()
        for _ in range(2069):
            oversized.append(255)
        try:
            storage.write_message(oversized)
        except error:
            if String(error).find("SocStorageBounds") < 0:
                raise error
            refusals += 1
        var counts: List[Int] = [-1, 2069]
        for count in counts:
            try:
                _ = storage.read_bytes(count)
            except error:
                if String(error).find("SocStorageBounds") < 0:
                    raise error
                refusals += 1
        try:
            storage.allocate_aligned(os_host_architecture(), 1, page)
        except error:
            if String(error).find("SocStorageState") < 0:
                raise error
            refusals += 1
        storage.cpu_owned = False
        try:
            storage.write_message(List[UInt8]())
        except error:
            if String(error).find("SocStorageState") < 0:
                raise error
            refusals += 1
        try:
            _ = storage.read_bytes(1)
        except error:
            if String(error).find("SocStorageState") < 0:
                raise error
            refusals += 1
        storage.cpu_owned = True
        storage.release()
        var bad_direction = SocRpcStorage()
        try:
            bad_direction.allocate_aligned(os_host_architecture(), 3, page)
        except error:
            if String(error).find("SocStorageState") < 0:
                raise error
            refusals += 1
        print("{\"refusals\":" + String(refusals) + "}")
    else:
        raise herror("BadArgs", "unknown aligned storage mode")
