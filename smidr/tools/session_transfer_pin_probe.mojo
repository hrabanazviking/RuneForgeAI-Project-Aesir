# Bounded map-only probe. Physical execution requires its published contract.
from std.sys import argv
from smidr.tools.session_transfer_pin import backing, request
from smidr.session_transfer_pin import pin_session_transfer
from smidr.sealed_transfer_backing import sealed_transfer_window
from smidr.tools.program_integrity import _integer
from smidr.tools.hrpc_frame import _to_hex
from hailbru.soc_group import encode_soc_group
from hailbru.soc_abi import soc_driver_info_json, soc_properties_json
from hailbru.soc_session import SOC_SESSION_DESC_COUNT


def main() raises:
    var args=argv()
    if len(args)!=4 or args[1].byte_length()>5:
        raise Error("SessionTransferPinProbe: usage: 70|4097|16385 sysfs-root dev-root")
    var n=_integer(args[1])
    if n!=70 and n!=4097 and n!=16385:
        raise Error("SessionTransferPinProbe: extent outside enumerated batch")
    for i in range(2,4):
        if args[i].byte_length()==0 or args[i].byte_length()>=4096 or "\0" in args[i]:
            raise Error("SessionTransferPinProbe: invalid bounded roots")
    var source=backing(n)
    var owner=pin_session_transfer(source^,request(),32768,65536,16,16,args[2],args[3])
    var group=owner.owned_group()
    var wire=encode_soc_group(group)
    if len(group.spans)!=2 or group.channel!=UInt64(owner.session.input_channel) or group.descriptor_handle!=owner.session.input_handle or group.spans[0].address!=UInt64(owner.metadata.address) or group.spans[1].address!=UInt64(owner.program.address) or group.spans[0].size!=2068 or group.spans[1].size!=UInt64(n) or len(wire)!=141:
        raise Error("SessionTransferPinProbe: group differs from owned session and views")
    var info=soc_driver_info_json(owner.session.driver.driver_info)
    var properties=soc_properties_json(owner.session.driver.properties)
    var page=owner.page_size
    var descriptor_page=owner.session.page_size
    var input_channel=owner.session.input_channel
    var output_channel=owner.session.output_channel
    var metadata_extent=owner.metadata.mapping_bytes
    var program_extent=owner.program.mapping_bytes
    owner.finalize_session()
    var metadata=sealed_transfer_window(owner.backing,request(),0,0,2068,2068,16,16)
    var program=sealed_transfer_window(owner.backing,request(),1,0,n,n,16,16)
    owner.close()
    owner.close()
    var refused=False
    try:
        _=owner.owned_group()
    except:
        refused=True
    if not refused or not owner.context_finalized:
        raise Error("SessionTransferPinProbe: closed owner remained usable")
    print("{\"mode\":\"map-only\",\"same_file_group\":true,\"group_count\":2,\"page_size\":"+String(page)+",\"descriptor_page_size\":"+String(descriptor_page)+",\"allocated_descriptors_per_direction\":"+String(SOC_SESSION_DESC_COUNT)+",\"input_channel\":"+String(input_channel)+",\"output_channel\":"+String(output_channel)+",\"metadata_mapping_bytes\":"+String(metadata_extent)+",\"program_mapping_bytes\":"+String(program_extent)+",\"driver_info\":"+info+",\"properties\":"+properties+",\"metadata_hex\":\""+_to_hex(metadata)+"\",\"program_hex\":\""+_to_hex(program)+"\",\"context_finalized\":true,\"host_released\":true,\"closed_group_refused\":true,\"hardware_idle_confirmed\":false,\"remote_cleanup_confirmed\":false,\"dma_submitted\":false,\"program_submitted\":false,\"execution_tested\":false}")
