# Enumerated map-only diagnostic; synthetic envelopes never reach a receiver.
from std.sys import argv
from smidr.program_envelope import build_program_envelope
from smidr.program_payload import ProgramPayloadRequest, stage_program_payload
from smidr.sealed_program_payload import seal_program_payload
from smidr.sealed_transfer_backing import seal_transfer_backing, sealed_transfer_window
from smidr.sealed_transfer_pin import SealedTransferPin, pin_sealed_transfer, view_sealed_transfer
from smidr.tools.hrpc_frame import _to_hex
from smidr.tools.program_integrity import _integer
from hailbru.soc_abi import soc_driver_info_json, soc_properties_json


def request() -> ProgramPayloadRequest:
    return ProgramPayloadRequest(17, 0, "two-part-pin", 32768)


def main() raises:
    var args = argv()
    if len(args) != 5:
        raise Error("usage: sealed_transfer_pin host|device size sysfs-root dev-root")
    if args[1] != "host" and args[1] != "device":
        raise Error("SealedTransferPin: unknown mode")
    if args[2].byte_length() > 5:
        raise Error("SealedTransferPin: numeric bound exceeded")
    var n = _integer(args[2])
    if n != 70 and n != 4097 and n != 16385:
        raise Error("SealedTransferPin: size outside enumerated batch")
    for i in range(3,5):
        if args[i].byte_length() == 0 or args[i].byte_length() >= 4096 or "\0" in args[i]:
            raise Error("SealedTransferPin: invalid bounded root")
    if args[1] == "host" and (args[3] != "-" or args[4] != "-"):
        raise Error("SealedTransferPin: host has no device roots")
    var body = List[UInt8]()
    for i in range(n-56):
        body.append(UInt8((i*37+11)%256))
    var empty = List[UInt8]()
    var bytes = build_program_envelope(body,empty,empty,0,False,UInt64(n))
    var staged = stage_program_payload(bytes,request())
    var sealed = seal_program_payload(staged,request(),"aarch64",16,16)
    var backing = seal_transfer_backing(sealed^,request(),16,16,16)
    var owner = pin_sealed_transfer(backing^,request(),32768,65536,16,16,args[3],args[4]) if args[1] == "device" else view_sealed_transfer(backing^,request(),32768,65536,16,16)
    var moved = owner^
    var page = moved.page_size
    var metadata_mapping = moved.metadata.mapping_bytes
    var program_mapping = moved.program.mapping_bytes
    var info = String("{}")
    var properties = String("{}")
    var device = args[1] == "device"
    if device:
        info = soc_driver_info_json(moved.driver.driver_info)
        properties = soc_properties_json(moved.driver.properties)
    moved.finalize_driver()
    # Verify backing AFTER confirmed driver finalization. No pointer read occurs.
    var metadata = sealed_transfer_window(moved.backing,request(),0,0,2068,2068,16,16)
    var program = sealed_transfer_window(moved.backing,request(),1,0,n,n,16,16)
    moved.close()
    moved.close()
    print("{\"mode\":\""+args[1]+"\",\"page_size\":"+String(page)
          +",\"metadata_mapping_bytes\":"+String(metadata_mapping)+",\"program_mapping_bytes\":"+String(program_mapping)
          +",\"metadata_hex\":\""+_to_hex(metadata)+"\",\"program_hex\":\""+_to_hex(program)
          +"\",\"driver_info\":"+info+",\"properties\":"+properties
          +",\"mapped_parts\":"+(String("2") if device else String("0"))
          +",\"host_released\":true,\"dma_submitted\":false,\"program_submitted\":false,\"execution_tested\":false}")
