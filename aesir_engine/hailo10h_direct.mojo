from std.ffi import external_call
from std.memory import Pointer
from std.sys import argv


def _c_string(value: String) raises -> List[Int8]:
    var result = List[Int8]()
    for byte in value.as_bytes():
        if byte == 0:
            raise Error("Hailo argument contains an embedded NUL")
        result.append(Int8(byte))
    result.append(0)
    return result^


def _buffer_string(buffer: List[Int8]) -> String:
    return String(unsafe_from_utf8_ptr=buffer.unsafe_ptr())


struct Hailo10HSession:
    var handle: UInt64
    var open: Bool

    def __init__(out self, hef_path: String) raises:
        var path = _c_string(hef_path)
        var error = List[Int8]()
        error.resize(2048, 0)
        var handle_out: UInt64 = 0
        var status = external_call[
            "aesir_hailo10h_open", Int32
        ](path.unsafe_ptr(), Pointer(to=handle_out), error.unsafe_ptr(), UInt(2048))
        if status != 0:
            raise Error("Direct Hailo-10H open failed: " + _buffer_string(error))
        self.handle = handle_out
        self.open = True

    def generate(self, prompt: String, max_tokens: Int = 32) raises -> String:
        if not self.open:
            raise Error("Hailo-10H session is closed")
        if max_tokens <= 0 or max_tokens > 4096:
            raise Error("max_tokens must be between 1 and 4096")
        var prompt_c = _c_string(prompt)
        var output = List[Int8]()
        output.resize(65536, 0)
        var error = List[Int8]()
        error.resize(2048, 0)
        var output_len: UInt = 0
        var status = external_call[
            "aesir_hailo10h_generate", Int32
        ](self.handle, prompt_c.unsafe_ptr(), UInt32(max_tokens), output.unsafe_ptr(),
          UInt(65536), Pointer(to=output_len), error.unsafe_ptr(), UInt(2048))
        if status != 0:
            raise Error("Direct Hailo-10H generation failed: " + _buffer_string(error))
        return _buffer_string(output)

    def clear_context(self) raises:
        if not self.open:
            raise Error("Hailo-10H session is closed")
        var error = List[Int8]()
        error.resize(2048, 0)
        var status = external_call[
            "aesir_hailo10h_clear_context", Int32
        ](self.handle, error.unsafe_ptr(), UInt(2048))
        if status != 0:
            raise Error("Direct Hailo-10H clear_context failed: " + _buffer_string(error))

    def close(mut self):
        if self.open:
            external_call["aesir_hailo10h_close", NoneType](self.handle)
            self.open = False


def main() raises:
    var args = argv()
    var path = String("artifacts/Qwen2.5-1.5B-Instruct.hef")
    var prompt = String("Reply with the single word READY.")
    var max_tokens = 32
    var index = 1
    while index < len(args):
        if args[index] == "--model-path":
            if index + 1 >= len(args):
                raise Error("--model-path requires a Hailo model artifact path")
            path = args[index + 1]
            index += 2
        elif args[index] == "--max-tokens":
            if index + 1 >= len(args):
                raise Error("--max-tokens requires a positive integer")
            max_tokens = Int(args[index + 1])
            index += 2
        elif args[index] == "--prompt":
            if index + 1 >= len(args):
                raise Error("--prompt requires text")
            prompt = args[index + 1]
            index += 2
        else:
            raise Error("unsupported direct Hailo option: " + args[index])
    var session = Hailo10HSession(path)
    var result = session.generate(prompt, max_tokens)
    print(result)
    session.close()
