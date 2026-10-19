# Owned, identity-checked driver file for the integrated-device PCIe path.
# Normal ioctls stay in HAILBRÚ and pass through the shared syscall gateway.
from hailbru.errors import herror
from hailbru.discovery import discover
from hailbru.syscall import (
    os_openat, os_close, os_ioctl, os_fd_rdev, os_host_architecture,
    errno_now, errno_name, O_RDWR, O_CLOEXEC, O_NOFOLLOW, list_dir, read_file_str,
)
from hailbru.util import trim
from hailbru.soc_abi import (
    soc_ioctl, soc_zero_bytes, soc_properties_json, soc_driver_info_json,
    SOC_PROPERTIES_SIZE, SOC_DRIVER_INFO_SIZE, _get,
)


def _node_name(name: String) raises:
    var bytes = name.as_bytes()
    if len(bytes) < 5 or len(bytes) > 32 or bytes[0] != 104 or bytes[1] != 49 or bytes[2] != 120 or bytes[3] != 45:
        raise herror("SocDriverMismatch", "unexpected integrated-device node name")
    for index in range(4, len(bytes)):
        if bytes[index] < 48 or bytes[index] > 57:
            raise herror("SocDriverMismatch", "node suffix is not decimal")


struct SocDriver(Movable):
    var arch: String
    var bdf: String
    var node: String
    var fd: Int64
    var properties: List[UInt8]
    var driver_info: List[UInt8]

    def __init__(out self):
        self.arch = String("")
        self.bdf = String("")
        self.node = String("")
        self.fd = -1
        self.properties = List[UInt8]()
        self.driver_info = List[UInt8]()

    def __deinit__(deinit self):
        if self.fd >= 0:
            # Linux close is not retried: even EINTR can have released the fd.
            if os_close(self.arch, self.fd) != 0:
                print("HailbruError[SocCleanupFailed]: implicit driver fd close failed")

    def close(mut self) raises:
        if self.fd < 0:
            return
        var fd = self.fd
        self.fd = -1
        if os_close(self.arch, fd) != 0:
            var error = errno_now()
            raise herror("SocCleanupFailed", "driver fd close: " + errno_name(error) + " (" + String(error) + ")")

    def request(mut self, operation: String, mut data: List[UInt8]) raises:
        if self.fd < 0:
            raise herror("SocSessionClosed", "driver file is closed")
        var code = soc_ioctl(operation)
        # Size comes from the ioctl itself; reject short/excess backing storage.
        var expected = Int((code >> UInt32(16)) & UInt32(16383))
        if len(data) != expected:
            raise herror("BadSocAbi", "ioctl storage does not match its encoded size")
        var result = os_ioctl(self.arch, self.fd, Int64(code), Int64(Int(data.unsafe_ptr())))
        if result != 0:
            var error = errno_now()
            raise herror("SocIoctlFailed", operation + ": " + errno_name(error) + " (" + String(error) + ")")


def open_soc_driver(sysfs_root: String, dev_root: String) raises -> SocDriver:
    var driver = SocDriver()
    driver.arch = os_host_architecture()
    driver.bdf = discover(driver.arch, sysfs_root, UInt16(0x1E60), UInt16(0x45C4))
    var base = sysfs_root + "/bus/pci/devices/" + driver.bdf + "/hailo1x"
    var names = list_dir(driver.arch, base)
    if len(names) != 1:
        raise herror("SocDriverMismatch", "expected one node belonging to the selected PCI device")
    _node_name(names[0])
    var expected_device = trim(read_file_str(driver.arch, base + "/" + names[0] + "/dev", 64))
    driver.node = names[0]
    # Nonblocking open avoids special-file hangs; nofollow rejects node symlinks.
    driver.fd = os_openat(driver.arch, dev_root + "/" + driver.node,
                           O_RDWR() | O_CLOEXEC() | Int64(0o4000) | O_NOFOLLOW(driver.arch), 0)
    if driver.fd < 0:
        var error = errno_now()
        raise herror("SocOpenFailed", errno_name(error) + " (" + String(error) + ")")
    try:
        var actual = os_fd_rdev(driver.arch, driver.fd)
        if expected_device != String(actual[0]) + ":" + String(actual[1]):
            raise herror("SocDriverMismatch", "opened character fd does not match PCI sysfs dev numbers")
        var driver_info = soc_zero_bytes(SOC_DRIVER_INFO_SIZE)
        driver.request("driver-info", driver_info)
        driver.driver_info = driver_info^
        _ = soc_driver_info_json(driver.driver_info)
        if _get(driver.driver_info, 0, 4) != 5 or _get(driver.driver_info, 4, 4) != 3 or _get(driver.driver_info, 8, 4) != 0:
            raise herror("SocDriverMismatch", "session ABI is qualified only for driver 5.3.0")
        var properties = soc_zero_bytes(SOC_PROPERTIES_SIZE)
        driver.request("properties", properties)
        driver.properties = properties^
        _ = soc_properties_json(driver.properties)
        if _get(driver.properties, 2, 4) != 2 or _get(driver.properties, 6, 4) != 0 or _get(driver.properties, 10, 8) != 1 or driver.properties[18] != 1:
            raise herror("SocDriverMismatch", "driver did not report the expected Hailo10H PCIe device with loaded firmware")
    except error:
        # Destructor is also armed, but explicit close preserves cleanup errors.
        var original = String(error)
        try:
            driver.close()
        except cleanup:
            raise herror("SocCleanupFailed", original + "; " + String(cleanup))
        raise Error(original)
    return driver^
