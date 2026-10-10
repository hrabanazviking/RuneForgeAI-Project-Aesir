# HAILBRU firmware boot engine (H074/H075/H076) — REAL UIO path.
#
# Reimplements the vendor driver's STRATEGY_PCIE_BARS boot flow from
# hailo1x_pci-5.3.0 (common/pcie_common.c, linux/pcie/src/pcie.c):
#   stage 1: customer_certificate.bin -> 0xA0000,
#            scu_fw.bin (header-parsed) -> app-firmware writes
#   stage 2: u-boot-<sku>.dtb.signed -> 0xA8004
#   stage 3: u-boot-spl.bin -> 0x80300000,
#            [u-boot-tfa.itb -> 0x8032C000, optional],
#            fitImage -> 0x88000000, image-fs -> 0x90000000
# Each stage: files written via the ATR-windowed PIO path through BAR4
# (fw_access), stage triggered by writing 1 to the trigger address,
# completion signalled by the BOOT_IRQ soft-IRQ (0x018C bit 25) which
# the UIO session delivers as an MSI.
#
# STATUS ON MIMIR (2026-10-10): UNBLOCKED. Vendor source read from the
# installed DKMS tree (/usr/src/hailo1x_pci-5.3.0); blobs used are the
# H073-verified staged files under /lib/firmware/hailo/hailo10h/
# (L7: never fetched, never shipped). Requires the UIO session
# (uio_pci_generic bound, hailo1x unbound) — H005 §6 forbids BAR writes
# while the vendor driver is bound.
#
# All multi-byte values are little-endian.

from hailbru.errors import herror
from hailbru.irq import uio_irq_wait
from hailbru.regs import (
    BarMapping,
    reg_read32,
    reg_write32,
    reg_write32_verified,
)
from hailbru.syscall import read_file_bytes


# --- ATR window programming (BAR0 + 0x700) ---
def ATR_BASE() -> Int64:
    return 0x700


def ATR_STRIDE() -> Int64:
    return 0x20


def ATR_PARAM() -> UInt32:
    return UInt32(0x17)


def ATR_TRSL_PARAM() -> UInt32:
    return UInt32(6)


def ATR_TABLE_SIZE() -> Int64:
    return 0x1000


def PCIE_BLOCK_ADDRESS_ATR1() -> UInt32:
    # The firmware programs ATR1's translation address to this value
    # when it is up — the "firmware loaded" signal
    # (hailo_pcie_is_firmware_loaded).
    return UInt32(0x200000)


# --- interrupt registers ---
def ISTATUS_HOST() -> Int64:
    return 0x018C


def IMASK_HOST() -> Int64:
    return 0x0188


def ISTATUS_HOST_MASK() -> UInt32:
    return UInt32(0xFF00FFFF)


def BOOT_IRQ_BIT() -> Int:
    # HAILO_PCIE_BOOT_IRQ = 0x2 in the sw_interrupts field
    # (istatus >> 24) -> istatus bit 25.
    return 25


# --- firmware addresses (HAILO_BOARD_TYPE_HAILO10H) ---
def FW_BOOT_FW_HEADER() -> Int64:
    return 0x88000


def FW_BOOT_KEY_CERT() -> Int64:
    return 0x88018


def FW_BOOT_CONT_CERT() -> Int64:
    return 0x886A8


def FW_APP_CODE_RAM_BASE() -> Int64:
    return 0x20000


def FW_BOOT_STATUS() -> Int64:
    return 0x80000


def FW_SKU_ID_OFFSET() -> Int64:
    return 0xDEFFC


def FW_SCU_LOG_ADDRESS() -> Int64:
    return 0x000DF000


def FW_MAGIC_HAILO15() -> UInt32:
    return UInt32(0xE905DAAB)


def FW_HEADER_SIZE() -> Int:
    return 24


def FW_CERT_HEADER_SIZE() -> Int:
    return 8


# --- stage triggers ---
def STAGE1_TRIGGER() -> Int64:
    return 0x88C98


def STAGE2_TRIGGER() -> Int64:
    return 0xDEFF8


def STAGE3_TRIGGER() -> Int64:
    return 0x802FF000


def FW_BLOB_ROOT() -> String:
    return "/lib/firmware/hailo/hailo10h"


def _u32le(data: List[UInt8], off: Int) -> UInt32:
    return (
        UInt32(data[off])
        | (UInt32(data[off + 1]) << 8)
        | (UInt32(data[off + 2]) << 16)
        | (UInt32(data[off + 3]) << 24)
    )


def fw_atr_program(bar0: BarMapping, index: Int64, trsl: Int64) raises:
    # hailo_pcie_configure_atr_table: 5 x u32 at 0x700 + index*0x20.
    var base = Int(ATR_BASE() + index * ATR_STRIDE())
    reg_write32(bar0, base, ATR_PARAM() | (UInt32(index) << 12))
    reg_write32(bar0, base + 4, UInt32(0))  # atr_src
    reg_write32(bar0, base + 8, UInt32(trsl & 0xFFFFFFFF))
    reg_write32(bar0, base + 12, UInt32((trsl >> 32) & 0xFFFFFFFF))
    reg_write32(bar0, base + 16, ATR_TRSL_PARAM())


def fw_atr_read_trsl1(bar0: BarMapping, index: Int64) raises -> UInt32:
    var base = Int(ATR_BASE() + index * ATR_STRIDE())
    return reg_read32(bar0, base + 8)


def fw_is_loaded(bar0: BarMapping) raises -> Bool:
    # hailo_pcie_is_firmware_loaded: ATR1 trsl_addr_1 == 0x200000.
    return fw_atr_read_trsl1(bar0, 1) == PCIE_BLOCK_ADDRESS_ATR1()


def _write_bar4_chunk(bar4: BarMapping, offset: Int, data: List[UInt8], start: Int, length: Int) raises:
    var p = bar4.ptr()
    for i in range(length):
        (p + offset + i)[] = data[start + i]


def _read_bar4_chunk(bar4: BarMapping, offset: Int, length: Int) raises -> List[UInt8]:
    var out = List[UInt8]()
    var p = bar4.ptr()
    for i in range(length):
        out.append((p + offset + i)[])
    return out^


def fw_write_memory(
    bar0: BarMapping, bar4: BarMapping, dest: Int64, data: List[UInt8]
) raises:
    # write_memory(): ATR0-windowed PIO through BAR4 (fw_access, 4KB).
    # Saves and restores the previous ATR0 (the firmware uses ATR too).
    var prev_lo = fw_atr_read_trsl1(bar0, 0)
    var prev_base = Int(ATR_BASE())
    var prev_param = reg_read32(bar0, prev_base)
    var prev_src = reg_read32(bar0, prev_base + 4)
    var prev_hi = reg_read32(bar0, prev_base + 12)
    var prev_trsl_param = reg_read32(bar0, prev_base + 16)
    var total = len(data)
    var done = 0
    try:
        var base_addr = dest & ~Int64(ATR_TABLE_SIZE() - 1)
        if base_addr != dest:
            var first = Int(
                min(
                    Int64(ATR_TABLE_SIZE()) - (dest - base_addr),
                    Int64(total),
                )
            )
            fw_atr_program(bar0, 0, base_addr)
            _write_bar4_chunk(bar4, Int(dest - base_addr), data, 0, first)
            done = first
        while done < total:
            var chunk = total - done
            if chunk > Int(ATR_TABLE_SIZE()):
                chunk = Int(ATR_TABLE_SIZE())
            fw_atr_program(bar0, 0, dest + Int64(done))
            _write_bar4_chunk(bar4, 0, data, done, chunk)
            done += chunk
    except e:
        # Restore the previous ATR0 exactly as found, then re-raise.
        reg_write32(bar0, prev_base, prev_param)
        reg_write32(bar0, prev_base + 4, prev_src)
        reg_write32(bar0, prev_base + 8, prev_lo)
        reg_write32(bar0, prev_base + 12, prev_hi)
        reg_write32(bar0, prev_base + 16, prev_trsl_param)
        raise e
    reg_write32(bar0, prev_base, prev_param)
    reg_write32(bar0, prev_base + 4, prev_src)
    reg_write32(bar0, prev_base + 8, prev_lo)
    reg_write32(bar0, prev_base + 12, prev_hi)
    reg_write32(bar0, prev_base + 16, prev_trsl_param)


def fw_read_memory(
    bar0: BarMapping, bar4: BarMapping, src: Int64, length: Int
) raises -> List[UInt8]:
    # read_memory(): ATR0-windowed PIO reads through BAR4.
    var prev_base = Int(ATR_BASE())
    var prev_param = reg_read32(bar0, prev_base)
    var prev_src = reg_read32(bar0, prev_base + 4)
    var prev_lo = reg_read32(bar0, prev_base + 8)
    var prev_hi = reg_read32(bar0, prev_base + 12)
    var prev_trsl_param = reg_read32(bar0, prev_base + 16)
    var out = List[UInt8]()
    try:
        var base_addr = src & ~Int64(ATR_TABLE_SIZE() - 1)
        var done = 0
        if base_addr != src:
            var first = Int(
                min(
                    Int64(ATR_TABLE_SIZE()) - (src - base_addr),
                    Int64(length),
                )
            )
            fw_atr_program(bar0, 0, base_addr)
            var c0 = _read_bar4_chunk(bar4, Int(src - base_addr), first)
            for i in range(len(c0)):
                out.append(c0[i])
            done = first
        while done < length:
            var chunk = length - done
            if chunk > Int(ATR_TABLE_SIZE()):
                chunk = Int(ATR_TABLE_SIZE())
            fw_atr_program(bar0, 0, src + Int64(done))
            var cn = _read_bar4_chunk(bar4, 0, chunk)
            for i in range(len(cn)):
                out.append(cn[i])
            done += chunk
    except e:
        reg_write32(bar0, prev_base, prev_param)
        reg_write32(bar0, prev_base + 4, prev_src)
        reg_write32(bar0, prev_base + 8, prev_lo)
        reg_write32(bar0, prev_base + 12, prev_hi)
        reg_write32(bar0, prev_base + 16, prev_trsl_param)
        raise e
    reg_write32(bar0, prev_base, prev_param)
    reg_write32(bar0, prev_base + 4, prev_src)
    reg_write32(bar0, prev_base + 8, prev_lo)
    reg_write32(bar0, prev_base + 12, prev_hi)
    reg_write32(bar0, prev_base + 16, prev_trsl_param)
    return out^


struct FwScuParts:
    # Parsed layout of scu_fw.bin (validated like the vendor driver).
    var header: List[UInt8]  # firmware_header_t, 24 bytes
    var code: List[UInt8]
    var key: List[UInt8]
    var content: List[UInt8]

    def __init__(out self):
        self.header = List[UInt8]()
        self.code = List[UInt8]()
        self.key = List[UInt8]()
        self.content = List[UInt8]()


def fw_parse_scu(data: List[UInt8]) raises -> FwScuParts:
    # Mirrors FW_VALIDATION__validate_fw_header + validate_cert_header
    # for HAILO_BOARD_TYPE_HAILO10H (magic HAILO15). Fail-closed.
    var parts = FwScuParts()
    if len(data) < FW_HEADER_SIZE() + FW_CERT_HEADER_SIZE() + 80:
        raise herror("FwError", "scu_fw.bin too small to hold headers")
    var magic = _u32le(data, 0)
    if magic != FW_MAGIC_HAILO15():
        raise herror(
            "FwError",
            "scu_fw.bin bad magic 0x" + String(Int(magic)),
        )
    var header_version = _u32le(data, 4)
    if header_version != 0:
        raise herror("FwError", "scu_fw.bin unsupported header version")
    var code_size = Int(_u32le(data, 20))
    if code_size < 80 or code_size > 0x40000:
        raise herror("FwError", "scu_fw.bin insane code_size")
    var cert_off = FW_HEADER_SIZE() + code_size
    if cert_off + FW_CERT_HEADER_SIZE() > len(data):
        raise herror("FwError", "scu_fw.bin truncated at cert header")
    var key_size = Int(_u32le(data, cert_off))
    var content_size = Int(_u32le(data, cert_off + 4))
    if key_size > 0x1000 or content_size > 0x1000:
        raise herror("FwError", "scu_fw.bin insane cert sizes")
    if cert_off + FW_CERT_HEADER_SIZE() + key_size + content_size > len(data):
        raise herror("FwError", "scu_fw.bin truncated at cert data")
    for i in range(FW_HEADER_SIZE()):
        parts.header.append(data[i])
    for i in range(code_size):
        parts.code.append(data[FW_HEADER_SIZE() + i])
    var key_off = cert_off + FW_CERT_HEADER_SIZE()
    for i in range(key_size):
        parts.key.append(data[key_off + i])
    var content_off = key_off + key_size
    for i in range(content_size):
        parts.content.append(data[content_off + i])
    return parts^


def fw_enable_interrupts(bar0: BarMapping) raises:
    # hailo_pcie_enable_interrupts: IMASK |= full mask; clear pending.
    var mask = reg_read32(bar0, Int(IMASK_HOST()))
    reg_write32(bar0, Int(IMASK_HOST()), mask | ISTATUS_HOST_MASK())
    _ = reg_read32(bar0, Int(ISTATUS_HOST()))  # read-and-clear
    reg_write32(bar0, 0x400, UInt32(0xFFFFFFFF))
    reg_write32(bar0, 0x500, UInt32(0xFFFFFFFF))


def fw_wait_boot_irq(
    arch: String, bar0: BarMapping, uio_fd: Int64, timeout_ms: Int64
) raises -> Bool:
    # Wait for the BOOT_IRQ soft-IRQ (0x018C bit 25) via UIO MSI.
    # Returns True on boot-IRQ, False on timeout (fail-closed: the
    # caller decides). Other interrupt bits are consumed and ignored.
    var deadline_chunks = Int(timeout_ms // 1000 + 1)
    for _ in range(deadline_chunks):
        try:
            _ = uio_irq_wait(arch, uio_fd, 1000)
        except e:
            if "IrqTimeout" in String(e):
                continue
            raise e
        var istatus = reg_read32(bar0, Int(ISTATUS_HOST()))
        if (Int(istatus) >> BOOT_IRQ_BIT()) & 1:
            return True
    return False


def fw_trigger(bar0: BarMapping, bar4: BarMapping, trigger_addr: Int64) raises:
    # hailo_trigger_firmware_boot: write u32 1 to the trigger address.
    var one = List[UInt8]()
    one.append(1)
    one.append(0)
    one.append(0)
    one.append(0)
    fw_write_memory(bar0, bar4, trigger_addr, one)


def fw_boot_status(bar0: BarMapping, bar4: BarMapping) raises -> Int64:
    # hailo_get_boot_status: u32 at 0x80000 via the ATR window.
    var raw = fw_read_memory(bar0, bar4, FW_BOOT_STATUS(), 4)
    return Int64(_u32le(raw, 0))


def fw_sku_id(bar0: BarMapping, bar4: BarMapping) raises -> Int64:
    # hailo_read_sku_id: GPIO bits at 0xDEFFC (ATR-windowed).
    var raw = fw_read_memory(bar0, bar4, FW_SKU_ID_OFFSET(), 4)
    var gpio = _u32le(raw, 0)
    if (Int(gpio) & (1 << 0)) == 0:
        return Int64(-1)  # HAILO_SKU_ID_DEFAULT
    var sku = Int64(0)
    for i in range(6):
        if (Int(gpio) >> (1 + i)) & 1:
            sku |= Int64(1) << Int64(i)
    return sku


def fw_read_scu_log(
    bar0: BarMapping, bar4: BarMapping, max_len: Int
) raises -> List[UInt8]:
    return fw_read_memory(bar0, bar4, FW_SCU_LOG_ADDRESS(), max_len)
