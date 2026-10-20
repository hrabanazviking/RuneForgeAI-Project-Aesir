# Host-only real allocation/byte consumer. No driver is opened or simulated.
from std.sys import argv
from hailbru.errors import herror
from hailbru.syscall import os_host_architecture
from hailbru.soc_storage import SocRpcStorage, SOC_RPC_STORAGE_SIZE
from smidr.tools.hrpc_frame import _from_hex, _to_hex


def main() raises:
    var args = argv()
    if len(args) != 3:
        raise herror("BadArgs", "usage: storage_bytes <bytes|guards> <hex>")
    var data = _from_hex(args[2])
    var storage = SocRpcStorage()
    storage.allocate(os_host_architecture(), 1)
    if args[1] == "bytes":
        storage.write_message(data)
        var copy = storage.read_bytes(Int(SOC_RPC_STORAGE_SIZE))
        storage.write_message(List[UInt8]())
        if not storage.zeroed():
            raise Error("empty replacement failed to clear previous message")
        storage.release()
        print(_to_hex(copy))
    elif args[1] == "guards":
        storage.write_message(data)
        var snapshot = storage.read_bytes(Int(SOC_RPC_STORAGE_SIZE))
        if len(data) > 0:
            data[0] ^= 255
        if _to_hex(snapshot) != _to_hex(storage.read_bytes(Int(SOC_RPC_STORAGE_SIZE))):
            raise Error("storage aliased caller input")
        var refusals = 0
        var counts: List[Int] = [-1, 2069]
        for count in counts:
            try:
                _ = storage.read_bytes(count)
            except error:
                if String(error).find("SocStorageBounds") < 0:
                    raise error
                refusals += 1
        var oversized = List[UInt8]()
        for index in range(2069):
            oversized.append(255)
        try:
            storage.write_message(oversized)
        except error:
            if String(error).find("SocStorageBounds") < 0:
                raise error
            refusals += 1
        if _to_hex(snapshot) != _to_hex(storage.read_bytes(Int(SOC_RPC_STORAGE_SIZE))):
            raise Error("refused write mutated owned storage")
        # State guard proof only: no claim that a host-only flag is a DMA event.
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
        for index in range(2):
            try:
                if index == 0:
                    storage.write_message(List[UInt8]())
                else:
                    _ = storage.read_bytes(0)
            except error:
                if String(error).find("SocStorageState") < 0:
                    raise error
                refusals += 1
        if refusals != 7:
            raise Error("not every byte ownership/bounds guard refused")
        print("{\"refusals\":7,\"input_copy\":true,\"snapshot_copy\":true,\"refused_write_preserved_storage\":true,\"device_access\":false}")
    else:
        raise herror("BadArgs", "unknown byte consumer mode")
