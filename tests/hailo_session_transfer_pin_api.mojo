# Direct original guard, move, scope and uncertain-finalization consumer.
from std.sys import argv
from smidr.session_transfer_pin import SessionTransferPin, pin_session_transfer
from smidr.tools.session_transfer_pin import backing, request
from hailbru.soc_group import encode_soc_group


def fresh(sysfs: String, dev: String) raises -> SessionTransferPin:
    var source=backing(70)
    return pin_session_transfer(source^,request(),32768,65536,16,16,sysfs,dev)


def main() raises:
    var args=argv()
    if len(args)!=4:
        raise Error("usage: session_transfer_pin_api guards|lifetime|poison|cleanup mock-sysfs mock-dev")
    if args[1]=="guards":
        var refused=0
        for i in range(14):
            var source=backing(70)
            var expected=request()
            if i==9:
                expected.message_id+=1
            if i==10:
                source.program.program_bytes+=1
            if i==11:
                source.arch="x86_64"
            var accepted=False
            try:
                var owner=pin_session_transfer(source^,expected,
                    0 if i==0 else (2067 if i==1 else 32768),
                    Int64(0 if i==2 else (-1 if i==3 else (4096 if i==4 else 65536))),
                    0 if i==5 else (-1 if i==6 else 16),
                    0 if i==7 else (-1 if i==8 else 16),
                    "" if i==12 else args[2], "" if i==13 else args[3])
                owner.close()
                accepted=True
            except:
                refused+=1
            if accepted:
                raise Error("SessionTransferPinAPI: constructor guard accepted invalid input")
            var recovery=fresh(args[2],args[3])
            _=recovery.owned_group()
            recovery.close()
        var owner=fresh(args[2],args[3])
        for i in range(8):
            if i==0:
                owner.session.driver.fd+=1
            elif i==1:
                owner.session.input_handle+=1
            elif i==2:
                owner.session.output_handle+=1
            elif i==3:
                owner.session.input_channel+=1
            elif i==4:
                owner.metadata.address+=1
            elif i==5:
                owner.program.logical_bytes+=1
            elif i==6:
                owner.metadata.mapped=False
            else:
                owner.program.retained=False
            var accepted=False
            try:
                _=owner.owned_group()
                accepted=True
            except:
                refused+=1
            # Restore our deliberately changed field before independent cleanup.
            if i==0:
                owner.session.driver.fd-=1
            elif i==1:
                owner.session.input_handle-=1
            elif i==2:
                owner.session.output_handle-=1
            elif i==3:
                owner.session.input_channel-=1
            elif i==4:
                owner.metadata.address-=1
            elif i==5:
                owner.program.logical_bytes-=1
            elif i==6:
                owner.metadata.mapped=True
            else:
                owner.program.retained=True
            if accepted:
                raise Error("SessionTransferPinAPI: changed ownership tuple accepted")
            var group=owner.owned_group()
            if len(encode_soc_group(group))!=141:
                raise Error("SessionTransferPinAPI: restored owner failed")
            owner.close()
            owner=fresh(args[2],args[3])
        owner.close()
        print("{\"guard_refusal_recovery_cycles\":"+String(refused)+",\"physical_calls\":false}")
    elif args[1]=="lifetime":
        var empty=SessionTransferPin()
        empty.close()
        empty.close()
        var owner=fresh(args[2],args[3])
        var moved=owner^
        _=moved.owned_group()
        moved.finalize_session()
        moved.finalize_session()
        var refused=False
        try:
            _=moved.owned_group()
        except:
            refused=True
        if not refused or not moved.context_finalized:
            raise Error("SessionTransferPinAPI: finalized owner exposed a live group")
        moved.close()
        moved.close()
        print("{\"moves_scope_defaults_and_repeat_close\":true,\"finalized_group_refused\":true}")
    elif args[1]=="poison":
        var owner=fresh(args[2],args[3])
        var refused=0
        for i in range(4):
            try:
                if i<2:
                    owner.close()
                elif i==2:
                    owner.finalize_session()
                else:
                    _=owner.owned_group()
            except:
                refused+=1
        if refused!=4 or not owner.finalization_unconfirmed or owner.context_finalized:
            raise Error("SessionTransferPinAPI: uncertain finalization was reused")
        print("{\"poisoned_reuse_refusals\":4,\"explicit_host_releases\":0}")
    elif args[1]=="cleanup":
        var owner=fresh(args[2],args[3])
        var failed=False
        try:
            owner.close()
        except:
            failed=True
        if not failed or not owner.context_finalized or owner.finalization_unconfirmed or owner.metadata.view_owned or owner.program.view_owned or owner.backing.metadata_fd>=0 or owner.backing.program.fd>=0:
            raise Error("SessionTransferPinAPI: confirmed cleanup error retained or misreported ownership")
        owner.close()
        print("{\"cleanup_error_preserved\":true,\"file_close_confirmed\":true,\"host_released\":true,\"hardware_idle_confirmed\":false}")
    else:
        raise Error("SessionTransferPinAPI: unknown mode")
