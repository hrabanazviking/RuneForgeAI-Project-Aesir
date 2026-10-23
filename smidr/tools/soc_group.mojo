# Bounded synthetic value diagnostic; never dereferences or submits addresses.
from std.sys import argv
from hailbru.errors import herror
from hailbru.soc_group import SocUserptrSpan, SocUserptrGroup, encode_soc_group, decode_soc_group
from smidr.tools.soc_abi import _uint64
from smidr.tools.hrpc_frame import _from_hex, _to_hex


def _number(text: String) raises -> UInt64:
    if text.byte_length() > 20:
        raise herror("BadArgs", "decimal argument exceeds UInt64 work bound")
    return _uint64(text)


def main() raises:
    var args = argv()
    if len(args) == 3 and args[1] == "decode":
        if args[2].byte_length() != 282:
            raise herror("BadSocGroup", "decode requires exactly141 hexadecimal bytes")
        var group = decode_soc_group(_from_hex(args[2]))
        print(_to_hex(encode_soc_group(group)))
        return
    if len(args) < 6 or len(args) > 20 or len(args) % 2 != 0 or args[1] != "encode":
        raise herror("BadArgs", "usage: soc_group encode channel handle address size [address size...] | decode hex")
    var spans = List[SocUserptrSpan]()
    spans.reserve((len(args) - 4) // 2)
    for i in range(4, len(args), 2):
        spans.append(SocUserptrSpan(_number(args[i]), _number(args[i + 1])))
    var group = SocUserptrGroup(_number(args[2]), _number(args[3]), spans)
    print(_to_hex(encode_soc_group(group)))
