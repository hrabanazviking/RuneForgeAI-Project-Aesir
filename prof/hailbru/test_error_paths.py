"""H078 — HAILBRÚ error-path tests (Python tests only; shipped code is pure Mojo).

Every scenario drives the compiled `probe` CLI against scratch sysfs trees
and asserts the EXACT `HailbruError[Code]` the Mojo layer raises. No hardware
needed; the binary path is taken from $HAILBRU_PROBE or ./probe.

Run: HAILBRU_PROBE=/path/to/probe python3 -m pytest prof/hailbru/test_error_paths.py -q
"""
import json
import os
import struct
import subprocess
import sys

import pytest

PROBE = os.environ.get("HAILBRU_PROBE", "./probe")
VENDOR = 0x1E60
DEVICE = 0x45C4
BDF = "0001:01:00.0"


def run(*args):
    p = subprocess.run(
        [PROBE, *args], capture_output=True, text=True, timeout=120
    )
    return p.returncode, p.stdout + p.stderr


def expect_code(args, code):
    rc, out = run(*args)
    assert rc != 0, f"expected failure, got rc=0: {out[:200]}"
    assert f"HailbruError[{code}]" in out, (
        f"expected HailbruError[{code}] in output, got: {out[:300]}"
    )
    return out


def make_sysfs(root, vendor=VENDOR, device=DEVICE, with_config=True,
               config_len=256, with_resource=True):
    """Scratch /sys tree: $root/sys/bus/pci/devices/<BDF>/..."""
    d = os.path.join(root, "sys", "bus", "pci", "devices", BDF)
    os.makedirs(d, exist_ok=True)
    with open(os.path.join(d, "vendor"), "w") as f:
        f.write(f"0x{vendor:04x}\n")
    with open(os.path.join(d, "device"), "w") as f:
        f.write(f"0x{device:04x}\n")
    with open(os.path.join(d, "class"), "w") as f:
        f.write("0x0b4000\n")
    if with_config:
        cfg = bytearray(config_len)
        struct.pack_into("<H", cfg, 0x0, vendor)
        struct.pack_into("<H", cfg, 0x2, device)
        with open(os.path.join(d, "config"), "wb") as f:
            f.write(bytes(cfg))
    if with_resource:
        with open(os.path.join(d, "resource"), "w") as f:
            f.write("0x000000001800000000 0x000000001800003fff 0x000000000014220c\n")
            f.write("0x000000001800008000 0x000000001800008fff 0x000000000014220c\n")
            f.write("0x000000001800004000 0x000000001800007fff 0x000000000014220c\n")
    return os.path.join(root, "sys")


# --- discovery -----------------------------------------------------------
def test_01_discover_no_matching_device(tmp_path):
    sysroot = make_sysfs(str(tmp_path), vendor=0x1234, device=0x5678)
    expect_code(["discover", "--sysfs-root", sysroot], "DeviceNotFound")


def test_02_discover_missing_sysfs_root(tmp_path):
    expect_code(
        ["discover", "--sysfs-root", str(tmp_path / "nope")], "BadSysfs"
    )


def test_03_identity_bad_bdf_format():
    expect_code(["identity", "--bdf", "not-a-bdf"], "BadBdf")


def test_04_identity_missing_device(tmp_path):
    sysroot = make_sysfs(str(tmp_path))
    expect_code(
        ["identity", "--sysfs-root", sysroot, "--bdf", "0000:ff:00.0"],
        "ConfigReadFailed",
    )


def test_05_identity_class_mismatch_fail_closed(tmp_path):
    sysroot = make_sysfs(str(tmp_path), config_len=64)
    # 64-byte config has zero class bytes -> census mismatch, fail closed
    expect_code(
        ["identity", "--sysfs-root", sysroot, "--bdf", BDF], "IdentityMismatch"
    )


def test_05b_identity_short_config_rejected(tmp_path):
    sysroot = make_sysfs(str(tmp_path), config_len=4)
    out = expect_code(
        ["identity", "--sysfs-root", sysroot, "--bdf", BDF],
        "ConfigReadFailed",
    )
    assert "too short" in out


# --- bars ----------------------------------------------------------------
def test_06_bars_missing_resource(tmp_path):
    sysroot = make_sysfs(str(tmp_path), with_resource=False)
    expect_code(
        ["bars", "--sysfs-root", sysroot, "--bdf", BDF], "BarParseFailed"
    )


def test_07_bars_malformed_resource_line(tmp_path):
    sysroot = make_sysfs(str(tmp_path))
    rd = os.path.join(sysroot, "bus", "pci", "devices", BDF, "resource")
    with open(rd, "w") as f:
        f.write("not-hex at all\n")
    expect_code(
        ["bars", "--sysfs-root", sysroot, "--bdf", BDF], "BarParseFailed"
    )


def test_08_bars_json_shape(tmp_path):
    sysroot = make_sysfs(str(tmp_path))
    rc, out = run("bars", "--sysfs-root", sysroot, "--bdf", BDF)
    assert rc == 0, out[:200]
    d = json.loads(out)
    bars = d["bars"]
    assert d["bdf"] == BDF
    assert len(bars) == 3
    assert bars[0]["size"] == 0x4000 and bars[0]["flags"] == 0x14220C


# --- mechanism -------------------------------------------------------------
def test_09_mechanism_selects_sysfs_recon_on_bare_tree(tmp_path):
    devroot = str(tmp_path / "dev")
    os.makedirs(devroot)
    rc, out = run("mechanism", "--dev-root", devroot)
    assert rc == 0, out[:200]
    d = json.loads(out)
    assert d["selected"] == "sysfs-recon"
    assert d["vfio"]["available"] is False
    assert d["uio"]["available"] is False


def test_10_uio_step_unbind_no_driver_registered(tmp_path):
    sysroot = make_sysfs(str(tmp_path))
    expect_code(
        ["uio-step", "--sysfs-root", sysroot, "--bdf", BDF,
         "--step", "unbind"],
        "MechanismUnavailable",
    )


def test_11_uio_step_unbind_needs_root(tmp_path):
    sysroot = make_sysfs(str(tmp_path))
    drv = os.path.join(sysroot, "bus", "pci", "drivers", "uio_pci_generic")
    os.makedirs(drv, exist_ok=True)
    with open(os.path.join(drv, "new_id"), "w") as f:
        f.write("")
    # driver present but no --as-root: privilege gate must refuse
    expect_code(
        ["uio-step", "--sysfs-root", sysroot, "--bdf", BDF,
         "--step", "unbind"],
        "PrivilegeRequired",
    )


# --- dma -------------------------------------------------------------------
def test_12_uio_step_unknown_step(tmp_path):
    sysroot = make_sysfs(str(tmp_path))
    expect_code(
        ["uio-step", "--sysfs-root", sysroot, "--bdf", BDF,
         "--step", "frobnicate"],
        "BadSysfs",
    )


def test_13_uio_step_missing_step_flag(tmp_path):
    sysroot = make_sysfs(str(tmp_path))
    out = expect_code(
        ["uio-step", "--sysfs-root", sysroot, "--bdf", BDF], "BadSysfs"
    )
    assert "needs --sysfs-root/--step" in out


def test_14_dma_selftest_matrix_passes():
    rc, out = run("dma-selftest")
    assert rc == 0, out[:300]
    assert "SELFTEST dma" in out and "OK" in out


# --- irq -------------------------------------------------------------------
def test_15_regs_probe_bad_bdf():
    expect_code(["regs-probe", "--bdf", "zz:zz:zz.z"], "BadBdf")


def test_16_irq_selftest_synthetic_ok():
    rc, out = run("irq-selftest")
    assert rc == 0, out[:300]
    assert "10000/10000 exact" in out


# --- firmware ---------------------------------------------------------------
def test_17_fwcheck_no_entries():
    expect_code(["fwcheck", "--fw-root", "/lib/firmware/hailo"], "BadSysfs")


def test_18_fwcheck_missing_blob(tmp_path):
    expect_code(
        [
            "fwcheck", "--fw-root", str(tmp_path),
            "--entry", "hailo10h/nope.bin:" + "0" * 64 + ":0x10",
        ],
        "FirmwareMissing",
    )


def test_19_fwcheck_size_mismatch(tmp_path):
    p = tmp_path / "a.bin"
    p.write_bytes(b"hello")
    expect_code(
        [
            "fwcheck", "--fw-root", str(tmp_path),
            "--entry", "a.bin:" + "0" * 64 + ":0x9999",
        ],
        "FirmwareCorrupt",
    )


def test_20_fwcheck_hash_mismatch(tmp_path):
    p = tmp_path / "b.bin"
    p.write_bytes(b"hello")
    expect_code(
        [
            "fwcheck", "--fw-root", str(tmp_path),
            "--entry", "b.bin:" + "1" * 64 + ":0x5",
        ],
        "FirmwareCorrupt",
    )


def test_21_fwcheck_bad_entry_shape():
    expect_code(
        ["fwcheck", "--fw-root", "/tmp", "--entry", "no-colons-here"],
        "BadSysfs",
    )


def test_22_fwcheck_happy_path_verifies(tmp_path):
    import hashlib
    p = tmp_path / "c.bin"
    p.write_bytes(b"hailbru-firmware-bytes")
    h = hashlib.sha256(b"hailbru-firmware-bytes").hexdigest()
    rc, out = run(
        "fwcheck", "--fw-root", str(tmp_path),
        "--entry", f"c.bin:{h}:0x16",
    )
    assert rc == 0, out[:300]
    d = json.loads(out)
    assert d["verified"][0]["sha256"] == h


# --- boot / ready ------------------------------------------------------------
def test_23_boot_selftest_names_timeout():
    rc, out = run("boot-selftest")
    assert rc == 0, out[:200]
    assert "FirmwareBootTimeout" in out


def test_24_ready_selftest_names_notready():
    rc, out = run("ready-selftest")
    assert rc == 0, out[:200]
    assert "DeviceNotReady" in out


# --- regs ---------------------------------------------------------------------
def test_25_regs_selftest_emulated_ok(tmp_path):
    epath = str(tmp_path / "emubars.bin")
    with open(epath, "wb") as f:
        f.write(b"\x00" * 0x4000)
    rc, out = run("regs-selftest", "--emulated", epath)
    assert rc == 0, out[:300]
    assert "50/50" in out


def test_25b_regs_selftest_needs_emulated_path():
    expect_code(["regs-selftest"], "BadSysfs")


def test_26_regs_probe_missing_device(tmp_path):
    sysroot = make_sysfs(str(tmp_path), vendor=0x1234, device=0x5678)
    expect_code(["regs-probe", "--sysfs-root", sysroot], "DeviceNotFound")


if __name__ == "__main__":
    sys.exit(pytest.main([__file__, "-q"]))
