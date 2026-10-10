"""Focused proof for native diagnostic parsers and readiness policy."""

from core.native_diagnostics import (
    human_bytes,
    parse_df_available_bytes,
    parse_hex_port,
    proc_tcp_has_listener,
)
from cli.doctor import doctor_system_ready, dispatch_doctor, doctor_json_bytes, DoctorIssue, doctor_observation_issues
from cli.model_preferences import PreferenceFinding
from core.model_registry import ModelCompatibility


def _doctor_issue_codes(issues: List[DoctorIssue]) -> List[String]:
    var codes = List[String]()
    for i in range(len(issues)):
        codes.append(issues[i].code)
    return codes^


def _doctor_has_code(issues: List[DoctorIssue], code: String) -> Bool:
    var codes = _doctor_issue_codes(issues)
    for i in range(len(codes)):
        if codes[i] == code:
            return True
    return False


def test_doctor_observations() raises:
    if doctor_json_bytes(-1) != "null" or doctor_json_bytes(0) != "0" or doctor_json_bytes(1024) != "1024":
        raise Error("doctor JSON unknown/zero byte observations drifted")
    var issue = DoctorIssue("quoted", "✓ æ 🛠 a\"b\n")
    if issue.to_json() != '{"code":"quoted","action":"✓ æ 🛠 a\\"b\\n"}':
        raise Error("doctor issue JSON escaped incorrectly")
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
    if doctor_system_ready(True, False, 3, 0, True, 1024):
        raise Error("doctor reported readiness with an unreadable store")
    if doctor_system_ready(True, True, 3, 0, False, 1024):
        raise Error("doctor reported readiness with unknown disk availability")
    if doctor_system_ready(True, True, 3, 0, True, 0):
        raise Error("doctor reported readiness with no available disk space")
    # Recipe entries never count as installed weights, even in a readable store.
    var recipe_only_installed_count = 0
    if doctor_system_ready(True, True, recipe_only_installed_count, 0, True, 1024):
        raise Error("doctor reported readiness for a recipe-only catalog")
    var rejected_store = False
    try:
        dispatch_doctor(["doctor", "--model-store", ""])
    except:
        rejected_store = True
    if not rejected_store:
        raise Error("doctor accepted an empty store path")


def test_doctor_disk_fallback_issue() raises:
    """F005: falling back from the model store to '.' must raise an issue."""
    var fallback_issues = doctor_observation_issues(
        True,
        List[PreferenceFinding](),
        True,
        True,
        1,
        0,
        True,
        1024,
        True,
        True,
        "",
        False,
        ModelCompatibility(),
    )
    if not _doctor_has_code(
        fallback_issues, "disk_capacity_observed_via_fallback"
    ):
        raise Error("doctor dropped the disk-capacity fallback issue")
    var direct_issues = doctor_observation_issues(
        True,
        List[PreferenceFinding](),
        True,
        True,
        1,
        0,
        True,
        1024,
        False,
        True,
        "",
        False,
        ModelCompatibility(),
    )
    if _doctor_has_code(direct_issues, "disk_capacity_observed_via_fallback"):
        raise Error("doctor fired the fallback issue without a fallback")
    var healthy_issues = doctor_observation_issues(
        True,
        List[PreferenceFinding](),
        True,
        True,
        1,
        0,
        True,
        1024,
        False,
        True,
        "",
        False,
        ModelCompatibility(),
    )
    if len(healthy_issues) != 0:
        raise Error("doctor reported issues for a healthy observation")


def test_doctor_listener_probe_issue() raises:
    """F006: a failed listener probe must surface as a DoctorIssue."""
    var probe_failed = doctor_observation_issues(
        True,
        List[PreferenceFinding](),
        True,
        True,
        1,
        0,
        True,
        1024,
        False,
        False,
        "",
        False,
        ModelCompatibility(),
    )
    if not _doctor_has_code(probe_failed, "service_listener_probe_failed"):
        raise Error("doctor stayed silent on a failed listener probe")
    var probe_known = doctor_observation_issues(
        True,
        List[PreferenceFinding](),
        True,
        True,
        1,
        0,
        True,
        1024,
        False,
        True,
        "",
        False,
        ModelCompatibility(),
    )
    if _doctor_has_code(probe_known, "service_listener_probe_failed"):
        raise Error("doctor fired the listener issue when the probe succeeded")
