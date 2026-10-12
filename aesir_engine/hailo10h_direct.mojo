from std.ffi import external_call
from std.memory import Pointer
from std.sys import argv


struct _OwnedHailoText:
    var address: UInt
    var length: UInt

    def __init__(out self, address: UInt, length: UInt):
        self.address = address
        self.length = length

    def __deinit__(deinit self):
        external_call["aesir_hailo10h_free_text", NoneType](self.address)

    def text(self) raises -> String:
        var ptr = Pointer[Int8, MutUntrackedOrigin](unsafe_from_address=Int(self.address))
        var bytes = List[Byte]()
        bytes.reserve(Int(self.length))
        for index in range(Int(self.length)):
            bytes.append(Byte(ptr.unsafe_load(index)))
        return String(from_utf8=bytes)


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

    def __deinit__(deinit self):
        if self.open:
            _ = external_call["aesir_hailo10h_close", Int32](self.handle)

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

    def generate(self, prompt: String, max_tokens: Int = 128, timeout_ms: Int = 60000) raises -> String:
        if not self.open:
            raise Error("Hailo-10H session is closed")
        if max_tokens <= 0 or max_tokens > 4294967295:
            raise Error("max_tokens must fit a positive UInt32")
        if timeout_ms <= 0 or timeout_ms > 4294967295:
            raise Error("timeout_ms must fit a positive UInt32")
        if prompt.byte_length() == 0 or prompt.byte_length() > 1048576:
            raise Error("prompt must contain 1..1048576 UTF-8 bytes")
        var prompt_c = _c_string(prompt)
        var output_address: UInt = 0
        var error = List[Int8]()
        error.resize(2048, 0)
        var output_len: UInt = 0
        var status = external_call[
            "aesir_hailo10h_generate", Int32
        ](self.handle, prompt_c.unsafe_ptr(), UInt32(max_tokens), UInt32(timeout_ms),
          Pointer(to=output_address), Pointer(to=output_len), error.unsafe_ptr(), UInt(2048))
        if status != 0:
            raise Error("Direct Hailo-10H generation failed: " + _buffer_string(error))
        var output = _OwnedHailoText(output_address, output_len)
        return output.text()

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

    def describe(self) raises -> String:
        if not self.open:
            raise Error("Hailo-10H session is closed")
        var output = List[Int8]()
        output.resize(8192, 0)
        var error = List[Int8]()
        error.resize(2048, 0)
        var status = external_call["aesir_hailo10h_describe", Int32](
            self.handle, output.unsafe_ptr(), UInt(8192), error.unsafe_ptr(), UInt(2048)
        )
        if status != 0:
            raise Error("Hailo-10H diagnostics failed: " + _buffer_string(error))
        return _buffer_string(output)

    def close(mut self) raises:
        if self.open:
            if external_call["aesir_hailo10h_close", Int32](self.handle) != 0:
                raise Error("Native Hailo-10H session close failed")
            self.open = False
            self.handle = 0


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
