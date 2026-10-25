# HOST-MOCK aligned diagnostic only. No default physical roots or numerical requests.
from std.sys import argv
from hailbru.soc_group_rpc import open_soc_group_rpc_aligned
from hailbru.hrpc_frame import HrpcFrame
from smidr.tools.program_integrity import _integer
from smidr.tools.hrpc_frame import _to_hex


def main() raises:
    var args=argv()
    if len(args)!=6 or args[1]!="host-mock-aligned" or args[2]=="/sys" or args[3]=="/dev":
        raise Error("GroupRpcAlignedMock: host-mock-aligned mock-sysfs mock-dev body-size exchanges")
    for i in range(2,4):
        if args[i].byte_length()==0 or args[i].byte_length()>=4096 or "\0" in args[i]:
            raise Error("GroupRpcAlignedMock: invalid mock root")
    if args[4].byte_length()>4 or args[5].byte_length()>1:
        raise Error("GroupRpcAlignedMock: unbounded numeric argument")
    var size=_integer(args[4])
    var count=_integer(args[5])
    if size<0 or size>2048 or count<1 or count>3:
        raise Error("GroupRpcAlignedMock: body/count outside bounded profile")
    var client=open_soc_group_rpc_aligned(args[2],args[3])
    var group=client.input_group()
    if len(group.spans)!=2 or group.spans[0].size!=20 or group.spans[1].size!=2048:
        raise Error("GroupRpcAlignedMock: aligned group shape differs")
    if group.spans[0].address!=client.input_address or group.spans[1].address!=client.input_address+client.input_body_offset:
        raise Error("GroupRpcAlignedMock: aligned span addresses differ")
    if client.input_body_offset!=client.session.input_storage.descriptor_page() or client.input_mapped_size!=client.input_body_offset+2048:
        raise Error("GroupRpcAlignedMock: aligned layout capture differs")
    var body=List[UInt8]()
    for i in range(size):
        body.append(UInt8((i*29+7)%256))
    var replies=String("")
    for i in range(count):
        var reply=client.exchange(HrpcFrame(UInt32(i),1,1,body),1000)
        if i!=0:
            replies+=","
        replies+="\""+_to_hex(reply.body)+"\""
    var exchanges=client.exchanges
    var input=client.last_input_descriptors
    var output=client.last_output_descriptors
    var snapshots=client.irq_snapshots
    var page=client.session.input_storage.descriptor_page()
    var mapped=client.input_mapped_size
    var offset=client.input_body_offset
    client.close()
    client.close()
    var refused=False
    try:
        _=client.input_group()
    except:
        refused=True
    if not refused:
        raise Error("GroupRpcAlignedMock: closed owner remained usable")
    print("{\"exchanges\":"+String(exchanges)+",\"input_count\":"+String(input)+",\"output_count\":"+String(output)+",\"snapshots\":"+String(snapshots)+",\"replies\":["+replies+"],\"descriptor_page\":"+String(page)+",\"body_offset\":"+String(offset)+",\"mapped_size\":"+String(mapped)+",\"physical_calls\":false}")
