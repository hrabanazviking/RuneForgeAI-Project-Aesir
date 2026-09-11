"""Read-only Linux observations used by local diagnostic presentation."""

from core.observation_integer import bounded_decimal
from core.posix_process import run_checked_argv


def parse_hex_port(value: String) raises -> Int:
    """Parses one procfs hexadecimal TCP port without accepting overflow."""
    if len(value.bytes()) == 0 or len(value.bytes()) > 4:
        raise Error("TCP port hex value must contain 1..4 digits")
    var result = 0
    for byte in value.as_bytes():
        var digit = -1
        if byte >= 48 and byte <= 57:
            digit = Int(byte - 48)
        elif byte >= 65 and byte <= 70:
            digit = Int(byte - 55)
        elif byte >= 97 and byte <= 102:
            digit = Int(byte - 87)
        if digit < 0:
            raise Error("TCP port contains a non-hexadecimal digit")
        result = result * 16 + digit
    return result


def proc_tcp_has_listener(text: String, port: Int) raises -> Bool:
    """Returns whether a Linux /proc/net/tcp snapshot has a LISTEN socket."""
    if port <= 0 or port > 65535:
        raise Error("TCP diagnostic port must be within 1..65535")
    for line in text.split("\n"):
        var fields = line.split()
        if len(fields) < 4 or String(fields[3]) != "0A":
            continue
        var local = String(fields[1]).split(":")
        if len(local) != 2:
            continue
        try:
            if parse_hex_port(String(local[1])) == port:
                return True
        except:
            continue
    return False


def observe_tcp_listener(port: Int) raises -> Bool:
    """Observes the current network namespace; it does not contact the socket."""
    var ipv4 = String("")
    var ipv6 = String("")
    var read_any = False
    try:
        with open("/proc/net/tcp", "r") as source:
            ipv4 = source.read()
            read_any = True
    except:
        pass
    try:
        with open("/proc/net/tcp6", "r") as source:
            ipv6 = source.read()
            read_any = True
    except:
        pass
    if not read_any:
        raise Error("Linux TCP socket observations are unavailable")
    return proc_tcp_has_listener(ipv4, port) or proc_tcp_has_listener(ipv6, port)


def parse_df_available_bytes(text: String) raises -> Int:
    """Parses the available 1024-byte block column from POSIX `df -Pk`."""
    var available_blocks = -1
    for line in text.split("\n"):
        var fields = line.split()
        if len(fields) < 6 or String(fields[0]) == "Filesystem":
            continue
        try:
            available_blocks = bounded_decimal(String(fields[3]))
        except:
            continue
    if available_blocks < 0:
        raise Error("df returned no parseable available-space observation")
    if available_blocks > 9223372036854775807 // 1024:
        raise Error("disk available-space observation overflows native integer")
    return available_blocks * 1024


def observe_disk_available_bytes(path: String) raises -> Int:
    """Observes filesystem capacity through argv-only POSIX df execution."""
    return parse_df_available_bytes(run_checked_argv(["df", "-Pk", path], 16384))


def human_bytes(value: Int) -> String:
    """Formats a non-negative byte count with one binary-unit decimal place."""
    if value < 0:
        return "unknown"
    var unit = 1
    var suffix = String("bytes")
    if value >= 1099511627776:
        unit = 1099511627776
        suffix = "TiB"
    elif value >= 1073741824:
        unit = 1073741824
        suffix = "GiB"
    elif value >= 1048576:
        unit = 1048576
        suffix = "MiB"
    elif value >= 1024:
        unit = 1024
        suffix = "KiB"
    if unit == 1:
        return String(value) + " bytes"
    var whole = value // unit
    var tenth = ((value % unit) * 10) // unit
    return String(whole) + "." + String(tenth) + " " + suffix
