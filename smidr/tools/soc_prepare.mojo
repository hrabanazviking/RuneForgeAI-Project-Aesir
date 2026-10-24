# Synthetic bounded value inspector. Never dereferences/submits addresses.
from std.sys import argv
from hailbru.errors import herror
from hailbru.soc_group import SocUserptrSpan, SocUserptrGroup
from hailbru.soc_prepare import encode_soc_prepare, decode_soc_prepare, encode_soc_cancel_prepared, decode_soc_cancel_prepared
from smidr.tools.soc_group import _number
from smidr.tools.hrpc_frame import _from_hex, _to_hex


def main() raises:
    var args = argv()
    if len(args) == 3:
        if args[1] == "cancel":
            print(_to_hex(encode_soc_cancel_prepared(_number(args[2]))))
            return
        if args[1] == "decode-cancel":
            if args[2].byte_length() != 16:
                raise herror("BadSocPrepare", "cancellation decode requires exactly8 hexadecimal bytes")
            print(_to_hex(encode_soc_cancel_prepared(decode_soc_cancel_prepared(_from_hex(args[2])))))
            return
        if args[1] == "decode-prepare":
            if args[2].byte_length() != 278:
                raise herror("BadSocPrepare", "prepare decode requires exactly139 hexadecimal bytes")
            var group = decode_soc_prepare(_from_hex(args[2]))
            print(_to_hex(encode_soc_prepare(group)))
            return
    if len(args) < 6 or len(args) > 20 or len(args) % 2 != 0 or args[1] != "prepare":
        raise herror("BadArgs", "usage: soc_prepare prepare channel handle address size [address size...] | decode-prepare hex | cancel handle | decode-cancel hex")
    var spans = List[SocUserptrSpan]()
    spans.reserve((len(args)-4)//2)
    for i in range(4,len(args),2):
        spans.append(SocUserptrSpan(_number(args[i]),_number(args[i+1])))
    var group = SocUserptrGroup(_number(args[2]),_number(args[3]),spans)
    print(_to_hex(encode_soc_prepare(group)))
