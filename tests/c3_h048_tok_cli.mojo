# tests/c3_h048_tok_cli.mojo
# H048 — tokenizer CLI for the differential test suite (TEST-ONLY, not shipped).
#
# Reads UTF-8 lines from stdin, encodes each with the requested tokenizer,
# prints one line of space-separated ids per input line.
# Usage: c3_h048_tok_cli <bpe|sp>
#   bpe: data/armvegr/gpt2_bpe.bin + data/armvegr/unicode_classes.bin
#   sp:  data/armvegr/tinyllama_tokenizer.model

from std.sys import argv
from std.ffi import external_call
from std.memory.alloc import unsafe_alloc

from armvegr.bpe import BPEModel
from armvegr.sp_tokenizer import SPTokenizer


def _read_stdin_lines() -> List[String]:
    var out = List[String]()
    var chunk = unsafe_alloc[UInt8](65536)
    var buf = List[UInt8]()
    while True:
        var got = external_call["read", Int](0, chunk, 65536)
        if got <= 0:
            break
        for i in range(Int(got)):
            buf.append(chunk.unsafe_offset(i).unsafe_load())
    chunk.unsafe_free()
    var start = 0
    for i in range(len(buf)):
        if buf[i] == 10:  # \n
            var lb = List[Int8]()
            for k in range(start, i):
                lb.append(Int8(buf[k]))
            lb.append(0)
            out.append(String(unsafe_from_utf8_ptr=lb.unsafe_ptr()))
            start = i + 1
    if start < len(buf):
        var lb2 = List[Int8]()
        for k in range(start, len(buf)):
            lb2.append(Int8(buf[k]))
        lb2.append(0)
        out.append(String(unsafe_from_utf8_ptr=lb2.unsafe_ptr()))
    return out.copy()


def main() raises:
    var args = argv()
    if len(args) < 2:
        print("usage: c3_h048_tok_cli <bpe|sp>")
        return
    var which = String(args[1])
    var lines = _read_stdin_lines()
    if which == "bpe":
        var model = BPEModel()
        model.load("data/armvegr/gpt2_bpe.bin", "data/armvegr/unicode_classes.bin")
        for i in range(len(lines)):
            var ids = model.encode(lines[i])
            var s = String("")
            for k in range(len(ids)):
                if k > 0:
                    s += " "
                s += String(ids[k])
            print(s)
    elif which == "sp":
        var tok = SPTokenizer()
        tok.load("data/armvegr/tinyllama_tokenizer.model")
        for i in range(len(lines)):
            var ids = tok.encode(lines[i])
            var s = String("")
            for k in range(len(ids)):
                if k > 0:
                    s += " "
                s += String(ids[k])
            print(s)
    else:
        print("unknown tokenizer: " + which)
