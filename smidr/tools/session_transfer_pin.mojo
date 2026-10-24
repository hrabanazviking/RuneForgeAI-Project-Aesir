# Host-mock diagnostic only. Never run against physical roots in this slice.
from std.sys import argv
from smidr.program_envelope import build_program_envelope
from smidr.program_payload import ProgramPayloadRequest, stage_program_payload
from smidr.sealed_program_payload import seal_program_payload
from smidr.sealed_transfer_backing import SealedTransferBacking, seal_transfer_backing, sealed_transfer_window
from smidr.session_transfer_pin import pin_session_transfer
from smidr.tools.program_integrity import _integer
from smidr.tools.hrpc_frame import _to_hex
from hailbru.soc_group import encode_soc_group


def request() -> ProgramPayloadRequest:
    return ProgramPayloadRequest(17,0,"session-two-part",32768)


def backing(n: Int) raises -> SealedTransferBacking:
    var body=List[UInt8]()
    for i in range(n-56):
        body.append(UInt8((i*37+11)%256))
    var empty=List[UInt8]()
    var bytes=build_program_envelope(body,empty,empty,0,False,UInt64(n))
    var staged=stage_program_payload(bytes,request())
    var sealed=seal_program_payload(staged,request(),"aarch64",16,16)
    return seal_transfer_backing(sealed^,request(),16,16,16)


def main() raises:
    var args=argv()
    if len(args)!=5 or args[1]!="mock" or args[2].byte_length()>5:
        raise Error("SessionTransferPin: usage: mock 70|4097|16385 mock-sysfs mock-dev")
    var n=_integer(args[2])
    if n!=70 and n!=4097 and n!=16385:
        raise Error("SessionTransferPin: extent outside enumerated host batch")
    for i in range(3,5):
        if args[i].byte_length()==0 or args[i].byte_length()>=4096 or "\0" in args[i]:
            raise Error("SessionTransferPin: invalid bounded mock roots")
    var source=backing(n)
    var owner=pin_session_transfer(source^,request(),32768,65536,16,16,args[3],args[4])
    var moved=owner^
    var group=moved.owned_group()
    var wire=encode_soc_group(group)
    if len(group.spans)!=2 or group.channel!=UInt64(moved.session.input_channel) or group.descriptor_handle!=moved.session.input_handle or group.spans[0].address!=UInt64(moved.metadata.address) or group.spans[1].address!=UInt64(moved.program.address) or len(wire)!=141:
        raise Error("SessionTransferPin: group differs from same-file owned resources")
    var page=moved.page_size
    var metadata_extent=moved.metadata.mapping_bytes
    var program_extent=moved.program.mapping_bytes
    moved.finalize_session()
    # After confirmed file cleanup only: independent descriptor reads,not pointers.
    var metadata=sealed_transfer_window(moved.backing,request(),0,0,2068,2068,16,16)
    var program=sealed_transfer_window(moved.backing,request(),1,0,n,n,16,16)
    moved.close()
    moved.close()
    print("{\"same_file_group\":true,\"group_count\":2,\"page_size\":"+String(page)+",\"metadata_mapping_bytes\":"+String(metadata_extent)+",\"program_mapping_bytes\":"+String(program_extent)+",\"metadata_hex\":\""+_to_hex(metadata)+"\",\"program_hex\":\""+_to_hex(program)+"\",\"context_finalized\":true,\"host_released\":true,\"hardware_idle_confirmed\":false,\"remote_cleanup_confirmed\":false,\"dma_submitted\":false,\"execution_tested\":false}")
