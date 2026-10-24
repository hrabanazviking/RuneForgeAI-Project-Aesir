# Bounded synthetic events only. No driver, real clock or pointer access.
from std.sys import argv
from hailbru.errors import herror
from hailbru.soc_exchange_progress import SocExchangeProgress
from smidr.tools.soc_group import _number
from smidr.tools.program_integrity import _signed
from smidr.tools.hrpc_frame import _from_hex


def number(text: String) raises -> Int64:
    if text.byte_length() > 21:
        raise herror("BadArgs", "signed decimal exceeds bounded input length")
    return Int64(_signed(text))


def channel(text: String) raises -> UInt8:
    var value = _number(text)
    if value > 255:
        raise herror("BadArgs", "channel exceeds UInt8")
    return UInt8(value)


def flag(value: Bool) -> String:
    return String("true") if value else String("false")


def main() raises:
    var args = argv()
    if len(args) < 11 or len(args) > 75 or len(args) % 2 != 1:
        raise herror("BadArgs", "usage: in out in-cap out-cap start timeout budget in-count out-count launch-time [time irq-hex...]")
    var owner = SocExchangeProgress(channel(args[1]), channel(args[2]), _number(args[3]), _number(args[4]), number(args[5]), number(args[6]), Int(number(args[7])))
    var launch_time = number(args[10])
    owner.launched(channel(args[2]), number(args[9]), launch_time)
    owner.launched(channel(args[1]), number(args[8]), launch_time)
    for i in range(11,len(args),2):
        if args[i+1].byte_length() != 770:
            raise herror("BadArgs", "IRQ snapshot requires exactly385 hexadecimal bytes")
        owner.consume(_from_hex(args[i+1]),number(args[i]))
    var remaining = owner.remaining_ms(owner.last_time)
    print("{\"input_descriptors\":" + String(owner.progress.input_descriptors) + ",\"output_descriptors\":" + String(owner.progress.output_descriptors) + ",\"input_done\":" + flag(owner.progress.input_done) + ",\"output_done\":" + flag(owner.progress.output_done) + ",\"complete\":" + flag(owner.complete()) + ",\"snapshots\":" + String(owner.snapshots) + ",\"remaining_ms\":" + String(remaining) + "}")
