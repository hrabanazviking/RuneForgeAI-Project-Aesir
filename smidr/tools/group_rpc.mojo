# HOST-MOCK diagnostic only. No default physical roots or numerical requests.
from std.sys import argv
from hailbru.soc_group_rpc import open_soc_group_rpc
from hailbru.hrpc_frame import HrpcFrame
from smidr.tools.program_integrity import _integer
from smidr.tools.hrpc_frame import _to_hex


def main() raises:
    var args=argv()
    if len(args)!=6 or args[1]!="host-mock" or args[2]=="/sys" or args[3]=="/dev":
        raise Error("GroupRpcMock: host-mock mock-sysfs mock-dev body-size exchanges")
    for i in range(2,4):
        if args[i].byte_length()==0 or args[i].byte_length()>=4096 or "\0" in args[i]:
            raise Error("GroupRpcMock: invalid mock root")
    if args[4].byte_length()>4 or args[5].byte_length()>1:
        raise Error("GroupRpcMock: unbounded numeric argument")
    var size=_integer(args[4])
    var count=_integer(args[5])
    if size<0 or size>2048 or count<1 or count>3:
        raise Error("GroupRpcMock: body/count outside bounded profile")
    var client=open_soc_group_rpc(args[2],args[3])
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
    client.close()
    client.close()
    var refused=False
    try:
        _=client.input_group()
    except:
        refused=True
    if not refused:
        raise Error("GroupRpcMock: closed owner remained usable")
    print("{\"exchanges\":"+String(exchanges)+",\"input_count\":"+String(input)+",\"output_count\":"+String(output)+",\"snapshots\":"+String(snapshots)+",\"replies\":["+replies+"],\"physical_calls\":false}")
