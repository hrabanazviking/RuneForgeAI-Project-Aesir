# Direct original ALIGNED grouped-client move,copy,poison,scope and recovery consumer.
from std.sys import argv
from hailbru.soc_group_rpc import SocGroupRpcClient, open_soc_group_rpc_aligned as open_soc_group_rpc
from hailbru.hrpc_frame import HrpcFrame
from smidr.tools.hrpc_frame import _to_hex
from smidr.tools.program_integrity import _signed


def text_hex(text: String) -> String:
    var data=List[UInt8]()
    for byte in text.as_bytes():
        data.append(byte)
    return _to_hex(data)


def frame() -> HrpcFrame:
    return HrpcFrame(0,1,1,List[UInt8]())


def recover(sysfs: String, dev: String) raises:
    var client=open_soc_group_rpc(sysfs,dev)
    var reply=client.exchange(frame(),1000)
    if len(reply.body)!=0 or client.exchanges!=1 or client.input_completions!=1 or client.output_completions!=1:
        raise Error("GroupRpcAlignedAPI: fresh recovery did not complete")
    client.close()


def scoped(sysfs: String, dev: String) raises:
    var client=open_soc_group_rpc(sysfs,dev)
    var reply=client.exchange(frame(),1000)
    if len(reply.body)!=0:
        raise Error("GroupRpcAlignedAPI: scope reply differs")
    # The retained session closes at scope exit,without an explicit close here.


def main() raises:
    var args=argv()
    if len(args)!=5 or args[2]=="/sys" or args[3]=="/dev":
        raise Error("GroupRpcAlignedAPI: lifetime|poison|deadline mock-sysfs mock-dev timeout")
    if args[1]=="lifetime":
        var empty=SocGroupRpcClient()
        var refused=0
        try:
            _=empty.input_group()
        except:
            refused+=1
        var original=open_soc_group_rpc(args[2],args[3])
        var client=original^
        var copied=client.input_group()
        copied.spans[0].address+=1
        if client.input_group().spans[0].address==copied.spans[0].address:
            raise Error("GroupRpcAlignedAPI: group copy changed owner")
        for i in range(8):
            if i==0:
                client.input_handle+=1
            elif i==1:
                client.output_handle+=1
            elif i==2:
                client.input_channel+=1
            elif i==3:
                client.output_channel+=1
            elif i==4:
                client.input_address+=1
            elif i==5:
                client.output_address+=1
            elif i==6:
                client.input_mapping+=1
            else:
                client.output_mapping+=1
            var accepted=False
            try:
                _=client.input_group()
                accepted=True
            except:
                refused+=1
            if i==0:
                client.input_handle-=1
            elif i==1:
                client.output_handle-=1
            elif i==2:
                client.input_channel-=1
            elif i==3:
                client.output_channel-=1
            elif i==4:
                client.input_address-=1
            elif i==5:
                client.output_address-=1
            elif i==6:
                client.input_mapping-=1
            else:
                client.output_mapping-=1
            if accepted:
                raise Error("GroupRpcAlignedAPI: owner mutation admitted")
        for i in range(2):
            if i==0:
                client.input_body_offset+=1
            else:
                client.input_mapped_size+=1
            var accepted=False
            try:
                _=client.input_group()
                accepted=True
            except:
                refused+=1
            if i==0:
                client.input_body_offset-=1
            else:
                client.input_mapped_size-=1
            if accepted:
                raise Error("GroupRpcAlignedAPI: layout mutation admitted")
        var reply=client.exchange(frame(),1000)
        if reply.remote_status!=0 or len(reply.body)!=0:
            raise Error("GroupRpcAlignedAPI: reply differs")
        client.close()
        client.close()
        try:
            _=client.exchange(frame(),1000)
        except:
            refused+=1
        if refused!=12:
            raise Error("GroupRpcAlignedAPI: missing guard refusal")
        recover(args[2],args[3])
        scoped(args[2],args[3])
        print("{\"guard_refusals\":12,\"fresh_recovery\":true,\"physical_calls\":false}")
    elif args[1]=="preflight":
        var errors=String("")
        for i in range(6):
            var client=open_soc_group_rpc(args[2],args[3])
            var request=frame()
            var timeout=Int64(1000)
            if i==0:
                request.remote_status=0
            elif i==1:
                for _ in range(2049):
                    request.body.append(0)
            elif i==2:
                timeout=0
            elif i==3:
                timeout=-1
            elif i==4:
                timeout=60001
            else:
                client.input_handle+=1
            var error_text=String("")
            try:
                _=client.exchange(request,timeout)
            except error:
                error_text=String(error)
            if error_text.byte_length()==0 or not client.poisoned or client.available or client.session.driver.fd>=0:
                raise Error("GroupRpcAlignedAPI: invalid preflight did not poison and close")
            if i!=0:
                errors+=","
            errors+="\""+text_hex(error_text)+"\""
            client.close()
            recover(args[2],args[3])
        print("{\"preflight_refusals\":6,\"fresh_recoveries\":6,\"errors\":["+errors+"],\"physical_calls\":false}")
    elif args[1]=="poison" or args[1]=="deadline":
        var client=open_soc_group_rpc(args[2],args[3])
        var primary=String("")
        try:
            _=client.exchange(frame(),Int64(_signed(args[4])))
        except error:
            primary=String(error)
        if primary.byte_length()==0 or not client.poisoned or client.available or client.busy:
            raise Error("GroupRpcAlignedAPI: failed exchange was not permanently poisoned")
        var retained=Int(client.session.input_storage.address!=0)+Int(client.session.output_storage.address!=0)
        var refused=0
        for i in range(4):
            try:
                if i<2:
                    _=client.exchange(frame(),1000)
                else:
                    _=client.input_group()
            except:
                refused+=1
        if refused!=4:
            raise Error("GroupRpcAlignedAPI: failed owner admitted reuse")
        var cleanup=String("")
        for _ in range(2):
            try:
                client.close()
            except error:
                cleanup=String(error)
        # Only confirmed resource cleanup can be followed by same-process
        # construction;unconfirmed owners intentionally retain until exit.
        var fresh=False
        if retained==0:
            recover(args[2],args[3])
            fresh=True
        print("{\"poison_refusals\":4,\"retained\":"+String(retained)+",\"fresh_recovery\":"+(String("true") if fresh else String("false"))+",\"primary_hex\":\""+text_hex(primary)+"\",\"cleanup_hex\":\""+text_hex(cleanup)+"\",\"physical_calls\":false}")
    else:
        raise Error("GroupRpcAlignedAPI: unknown mode")
