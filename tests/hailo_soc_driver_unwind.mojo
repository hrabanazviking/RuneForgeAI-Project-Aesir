# Test-only consumer proves the production owner closes on exception unwinding.
from std.sys import argv
from hailbru.soc_driver import open_soc_driver


def unwind(sysfs_root: String, dev_root: String) raises:
    var driver = open_soc_driver(sysfs_root, dev_root)
    raise Error("ExpectedOwnedDriverUnwind")


def main() raises:
    var args = argv()
    if len(args) != 3:
        raise Error("usage: unwind <sysfs-root> <dev-root>")
    try:
        unwind(args[1], args[2])
    except error:
        if String(error).find("ExpectedOwnedDriverUnwind") >= 0:
            print("expected exception caught after owner scope")
            return
        raise error
    raise Error("exception was not raised")
