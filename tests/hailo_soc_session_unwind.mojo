# Test-only exception consumer of the production descriptor/connection owner.
from std.sys import argv
from hailbru.soc_session import open_soc_session


def unwind(sysfs_root: String, dev_root: String) raises:
    var session = open_soc_session(sysfs_root, dev_root)
    session.require_open()
    raise Error("ExpectedOwnedSessionUnwind")


def main() raises:
    var args = argv()
    if len(args) != 3:
        raise Error("usage: unwind <sysfs-root> <dev-root>")
    try:
        unwind(args[1], args[2])
    except error:
        if String(error).find("ExpectedOwnedSessionUnwind") >= 0:
            print("expected exception caught after session scope")
            return
        raise error
    raise Error("exception was not raised")
