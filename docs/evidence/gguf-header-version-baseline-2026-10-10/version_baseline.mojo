from loader.gguf import GGUFSeer
from core.mimir_well import MimirWell


def probe(version: UInt32, mut well: MimirWell) raises:
    var bytes = InlineArray[UInt8, 24](fill=0)
    bytes[0] = 0x47
    bytes[1] = 0x47
    bytes[2] = 0x55
    bytes[3] = 0x46
    bytes[4] = UInt8(version & 0xff)
    bytes[5] = UInt8((version >> 8) & 0xff)
    bytes[6] = UInt8((version >> 16) & 0xff)
    bytes[7] = UInt8((version >> 24) & 0xff)
    var seer = GGUFSeer("version-probe.gguf")
    var accepted = True
    try:
        seer.parse_header_bytes(bytes.unsafe_ptr(), 24, well)
    except:
        accepted = False
    print("VERSION", version, "ACCEPTED", accepted)


def main() raises:
    var well = MimirWell(1024)
    probe(0, well)
    probe(1, well)
    probe(2, well)
    probe(3, well)
    probe(4, well)
    probe(4294967295, well)
