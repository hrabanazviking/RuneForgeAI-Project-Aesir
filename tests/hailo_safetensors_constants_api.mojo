# Static source window API ownership/refusal checks; no model evaluation.
from std.sys import argv
from armvegr.safetensors import SafetensorsLoader
from smidr.safetensors_constants import read_safetensors_constants
from smidr.tools.program_integrity import _integer


def main() raises:
    var args = argv()
    if len(args) != 3:
        raise Error("SafetensorsConstantsApi: expected path and case")
    var source = SafetensorsLoader()
    source.open(args[1], 65536, 16, 16, 4096, 16)
    var case_id = _integer(args[2])
    if case_id == 0:
        var first = read_safetensors_constants(source, "weight", 0, 2, 2)
        var second = read_safetensors_constants(source, "weight", 0, 2, 2)
        var saved = second.raw_words[0]
        source.descs[0].shape[0] = 999
        source.close()
        first.binding.shape[0] = 888
        first.raw_words[0] ^= 1
        first.binary32_words[0] ^= 1
        if second.binding.shape[0] != 2 or second.raw_words[0] != saved or first.binding.shape[0] == second.binding.shape[0]:
            raise Error("SafetensorsConstantsApi: windows retain borrowed storage")
        print("{\"accepted\":true,\"owned_after_close\":true}")
        return
    var name = String("weight")
    var first = 0
    var count = 2
    var bound = 2
    var saved_fd = source.fd
    var saved_size = source.file_size
    if case_id == 1:
        source.close()
    elif case_id == 2:
        source.fd = -1
    elif case_id == 3:
        source.header_size = 9223372036854775807
    elif case_id == 4:
        source.file_size = -1
    elif case_id == 5:
        name = "missing"
    elif case_id == 6:
        first = -1
    elif case_id == 7:
        count = -1
    elif case_id == 8:
        first = 5
        count = 0
    elif case_id == 9:
        bound = 1
    elif case_id == 10:
        source.descs[0].shape[0] = -1
    elif case_id == 11:
        source.descs[0].data_end = source.descs[0].data_start - 1
    elif case_id == 12:
        source.descs[0].data_start = 0
    elif case_id == 13:
        source.descs[0].data_end = Int(source.file_size) + 1
    elif case_id == 14:
        source.descs[0].dtype = 255
    elif case_id == 15:
        source.descs[0].shape[0] = 9223372036854775807
    elif case_id == 16:
        first = 3
    elif case_id == 17:
        bound = 0
    else:
        source.close()
        raise Error("SafetensorsConstantsApi: invalid case")
    var refused = False
    try:
        _ = read_safetensors_constants(source, name, first, count, bound)
    except:
        refused = True
    # Restore the real mapping owner before cleaning injected metadata faults.
    if case_id == 2:
        source.fd = saved_fd
    if case_id == 4:
        source.file_size = saved_size
    source.close()
    if not refused:
        raise Error("SafetensorsConstantsApi: invalid owner/window accepted")
    print("{\"refused\":true}")
