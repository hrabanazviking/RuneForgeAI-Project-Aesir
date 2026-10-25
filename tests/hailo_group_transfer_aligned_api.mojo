# Direct original ALIGNED grouped-TRANSFER move,copy,poison,scope and recovery consumer.
from std.sys import argv
from hailbru.soc_transfer import SocGroupedTransfer, open_grouped_transfer_aligned as open_transfer
from hailbru.hrpc_frame import encode_hrpc_frame, decode_hrpc_frame
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


def packet() raises -> List[UInt8]:
    return encode_hrpc_frame(frame())


def exchange(mut client: SocGroupedTransfer, timeout: Int64) raises -> HrpcFrame:
    # The primitive is framing-free by design: a reply that fails frame
    # validation is a consumer-layer failure, and the consumer poisons
    # the owner exactly as the RPC client's exchange does (poison,
    # close, cleanup failure composes SocCleanupFailed).
    var raw=client.exchange_raw(packet(),timeout)
    try:
        var reply=decode_hrpc_frame(raw,True)
        if reply.message_id!=0 or reply.action_id!=1:
            raise Error("RpcReplyMismatch: received frame differs from the owned exchange")
        if reply.remote_status!=0:
            raise Error("RpcRemoteFailure: grouped control returned status " + String(reply.remote_status))
        return reply^
    except error:
        client.poisoned=True
        var original=String(error)
        try:
            client.close()
        except cleanup:
            raise Error("SocCleanupFailed: " + original + "; " + String(cleanup))
        raise Error(original)


def recover(sysfs: String, dev: String) raises:
    var client=open_transfer(sysfs,dev)
    var reply=exchange(client,1000)
    if len(reply.body)!=0 or client.exchanges!=1 or client.input_completions!=1 or client.output_completions!=1:
        raise Error("GroupTransferAPI: fresh recovery did not complete")
    client.close()


def scoped(sysfs: String, dev: String) raises:
    var client=open_transfer(sysfs,dev)
    var reply=exchange(client,1000)
    if len(reply.body)!=0:
        raise Error("GroupTransferAPI: scope reply differs")
    # The retained session closes at scope exit,without an explicit close here.


def main() raises:
    var args=argv()
    if len(args)!=5 or args[2]=="/sys" or args[3]=="/dev":
        raise Error("GroupTransferAPI: lifetime|poison|deadline mock-sysfs mock-dev timeout")
    if args[1]=="lifetime":
        var empty=SocGroupedTransfer()
        var refused=0
        try:
            _=empty.input_group()
        except:
            refused+=1
        var original=open_transfer(args[2],args[3])
        var client=original^
        var copied=client.input_group()
        copied.spans[0].address+=1
        if client.input_group().spans[0].address==copied.spans[0].address:
            raise Error("GroupTransferAPI: group copy changed owner")
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
                raise Error("GroupTransferAPI: owner mutation admitted")
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
                raise Error("GroupTransferAPI: layout mutation admitted")
        var reply=exchange(client,1000)
        if reply.remote_status!=0 or len(reply.body)!=0:
            raise Error("GroupTransferAPI: reply differs")
        client.close()
        client.close()
        try:
            _=exchange(client,1000)
        except:
            refused+=1
        if refused!=12:
            raise Error("GroupTransferAPI: missing guard refusal")
        recover(args[2],args[3])
        scoped(args[2],args[3])
        print("{\"guard_refusals\":12,\"fresh_recovery\":true,\"physical_calls\":false}")
    elif args[1]=="preflight":
        var errors=String("")
        for i in range(6):
            var client=open_transfer(args[2],args[3])
            var raw=packet()
            var timeout=Int64(1000)
            if i==0:
                raw=List[UInt8]()
                for _ in range(2069):
                    raw.append(0)
            elif i==1:
                timeout=0
            elif i==2:
                timeout=-1
            elif i==3:
                timeout=60001
            elif i==4:
                client.input_handle+=1
            else:
                client.input_mapped_size+=1
            var error_text=String("")
            try:
                _=client.exchange_raw(raw,timeout)
            except error:
                error_text=String(error)
            if error_text.byte_length()==0 or not client.poisoned or client.available or client.session.driver.fd>=0:
                raise Error("GroupTransferAPI: invalid preflight did not poison and close")
            if i!=0:
                errors+=","
            errors+="\""+text_hex(error_text)+"\""
            client.close()
            recover(args[2],args[3])
        print("{\"preflight_refusals\":6,\"fresh_recoveries\":6,\"errors\":["+errors+"],\"physical_calls\":false}")
    elif args[1]=="poison" or args[1]=="deadline":
        var client=open_transfer(args[2],args[3])
        var primary=String("")
        try:
            _=exchange(client,Int64(_signed(args[4])))
        except error:
            primary=String(error)
        if primary.byte_length()==0 or not client.poisoned or client.available or client.busy:
            raise Error("GroupTransferAPI: failed exchange was not permanently poisoned")
        var retained=Int(client.session.input_storage.address!=0)+Int(client.session.output_storage.address!=0)
        var refused=0
        for i in range(4):
            try:
                if i<2:
                    _=exchange(client,1000)
                else:
                    _=client.input_group()
            except:
                refused+=1
        if refused!=4:
            raise Error("GroupTransferAPI: failed owner admitted reuse")
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
        raise Error("GroupTransferAPI: unknown mode")
