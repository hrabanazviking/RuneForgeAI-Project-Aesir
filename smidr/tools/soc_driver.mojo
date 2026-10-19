# Physical read-only driver query. No descriptors, connection, DMA or inference.
from std.sys import argv
from hailbru.errors import herror
from hailbru.soc_driver import open_soc_driver
from hailbru.soc_abi import soc_properties_json, soc_driver_info_json, soc_zero_bytes


def main() raises:
    var args = argv()
    if len(args) != 3:
        raise herror("BadArgs", "usage: soc_driver <sysfs-root> <dev-root>")
    var driver = open_soc_driver(args[1], args[2])
    var record = "{\"bdf\":\"" + driver.bdf + "\",\"node\":\"" + driver.node + "\",\"arch\":\"" + driver.arch + "\",\"driver\":" + soc_driver_info_json(driver.driver_info) + ",\"properties\":" + soc_properties_json(driver.properties)
    driver.close()
    driver.close()
    # Confirm operations cannot reach the kernel once the owner closes.
    var data = soc_zero_bytes(12)
    var refused = False
    try:
        driver.request("driver-info", data)
    except error:
        if String(error).find("SocSessionClosed") >= 0:
            refused = True
        else:
            raise error
    if not refused:
        raise herror("SocCleanupFailed", "closed driver unexpectedly accepted a request")
    print(record + ",\"fd_closed\":true,\"repeat_close\":true,\"closed_request_refused\":true,\"dma_submitted\":false}")
