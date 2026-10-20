# Test-only exception consumer of owned mappings/storage.
from std.sys import argv
from hailbru.soc_session import open_soc_session


def unwind(sysfs: String, dev: String) raises:
    var session = open_soc_session(sysfs, dev)
    session.allocate_rpc_storage()
    raise Error("ExpectedStorageUnwind")


def main() raises:
    var args = argv()
    if len(args) != 3:
        raise Error("usage: storage_unwind <sysfs-root> <dev-root>")
    try:
        unwind(args[1], args[2])
    except error:
        if String(error).find("ExpectedStorageUnwind") < 0:
            raise error
        print("expected storage exception caught")
        return
    raise Error("expected exception was not raised")
