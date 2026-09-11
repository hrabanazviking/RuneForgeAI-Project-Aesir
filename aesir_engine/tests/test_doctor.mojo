"""Focused proof for native diagnostic parsers and readiness policy."""

from core.native_diagnostics import (
    human_bytes,
    parse_df_available_bytes,
    parse_hex_port,
    proc_tcp_has_listener,
)
from cli.doctor import doctor_system_ready


def test_doctor_observations() raises:
    if parse_hex_port("2CAA") != 11434:
        raise Error("doctor hexadecimal TCP port parsing drifted")
    var bad_hex_rejected = False
    try:
        _ = parse_hex_port("2CZZ")
    except:
        bad_hex_rejected = True
    if not bad_hex_rejected:
        raise Error("doctor accepted a malformed hexadecimal TCP port")

    var tcp = (
        "  sl  local_address rem_address   st tx_queue rx_queue\n"
        + "   0: 0100007F:2CAA 00000000:0000 0A 00000000:00000000\n"
        + "   1: 0100007F:1F90 00000000:0000 01 00000000:00000000\n"
    )
    if not proc_tcp_has_listener(tcp, 11434):
        raise Error("doctor missed an observed LISTEN socket")
    if proc_tcp_has_listener(tcp, 8080):
        raise Error("doctor treated an established socket as a listener")

    var df = (
        "Filesystem 1024-blocks Used Available Capacity Mounted on\n"
        + "/dev/nvme0n1 1000 400 600 40% /\n"
    )
    if parse_df_available_bytes(df) != 614400:
        raise Error("doctor disk-space parser selected the wrong df column")
    if human_bytes(8 * 1024 * 1024 * 1024) != "8.0 GiB":
        raise Error("doctor byte formatter drifted")


def test_doctor_readiness_policy() raises:
    if not doctor_system_ready(True, True, 3, 0, True, 1024):
        raise Error("doctor rejected a healthy offline inference system")
    if doctor_system_ready(True, True, 0, 0, True, 1024):
        raise Error("doctor reported readiness without an installed model")
    if doctor_system_ready(True, True, 3, 1, True, 1024):
        raise Error("doctor reported readiness with a broken model")
    if doctor_system_ready(False, True, 3, 0, True, 1024):
        raise Error("doctor reported CUDA readiness without a compatible GPU")
