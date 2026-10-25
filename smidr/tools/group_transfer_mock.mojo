# HOST-MOCK aligned diagnostic for the minimal grouped transfer
# primitive (hailbru/soc_transfer.mojo) only. No default physical
# roots or numerical requests. Framing lives here in the diagnostic;
# the primitive itself moves raw logical packets.
from std.sys import argv
from hailbru.soc_transfer import open_grouped_transfer_aligned
from hailbru.hrpc_frame import HrpcFrame, encode_hrpc_frame, decode_hrpc_frame
from smidr.tools.program_integrity import _integer
from smidr.tools.hrpc_frame import _to_hex


def main() raises:
    var args=argv()
    if len(args)!=6 or args[1]!="host-mock-aligned" or args[2]=="/sys" or args[3]=="/dev":
        raise Error("GroupTransferMock: host-mock-aligned mock-sysfs mock-dev body-size exchanges")
    for i in range(2,4):
        if args[i].byte_length()==0 or args[i].byte_length()>=4096 or "\0" in args[i]:
            raise Error("GroupTransferMock: invalid mock root")
    if args[4].byte_length()>4 or args[5].byte_length()>1:
        raise Error("GroupTransferMock: unbounded numeric argument")
    var size=_integer(args[4])
    var count=_integer(args[5])
    if size<0 or size>2048 or count<1 or count>3:
        raise Error("GroupTransferMock: body/count outside bounded profile")
    var transfer=open_grouped_transfer_aligned(args[2],args[3])
    var group=transfer.input_group()
    if len(group.spans)!=2 or group.spans[0].size!=20 or group.spans[1].size!=2048:
        raise Error("GroupTransferMock: aligned group shape differs")
    if group.spans[0].address!=transfer.input_address or group.spans[1].address!=transfer.input_address+transfer.input_body_offset:
        raise Error("GroupTransferMock: aligned span addresses differ")
    if transfer.input_body_offset!=transfer.session.input_storage.descriptor_page() or transfer.input_mapped_size!=transfer.input_body_offset+2048:
        raise Error("GroupTransferMock: aligned layout capture differs")
    var body=List[UInt8]()
    for i in range(size):
        body.append(UInt8((i*29+7)%256))
    var replies=String("")
    for i in range(count):
        var packet=encode_hrpc_frame(HrpcFrame(UInt32(i),1,1,body))
        var received=transfer.exchange_raw(packet,1000)
        var reply=decode_hrpc_frame(received,True)
        if reply.message_id!=UInt32(i) or reply.action_id!=1 or reply.remote_status!=0:
            raise Error("GroupTransferMock: reply frame differs from the owned exchange")
        if i!=0:
            replies+=","
        replies+="\""+_to_hex(reply.body)+"\""
    var exchanges=transfer.exchanges
    var input=transfer.last_input_descriptors
    var output=transfer.last_output_descriptors
    var snapshots=transfer.irq_snapshots
    var page=transfer.session.input_storage.descriptor_page()
    var mapped=transfer.input_mapped_size
    var offset=transfer.input_body_offset
    transfer.close()
    transfer.close()
    var refused=False
    try:
        _=transfer.input_group()
    except:
        refused=True
    if not refused:
        raise Error("GroupTransferMock: closed owner remained usable")
    print("{\"exchanges\":"+String(exchanges)+",\"input_count\":"+String(input)+",\"output_count\":"+String(output)+",\"snapshots\":"+String(snapshots)+",\"replies\":["+replies+"],\"descriptor_page\":"+String(page)+",\"body_offset\":"+String(offset)+",\"mapped_size\":"+String(mapped)+",\"physical_calls\":false}")
