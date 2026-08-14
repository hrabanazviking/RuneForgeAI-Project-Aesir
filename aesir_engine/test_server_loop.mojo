from std.ffi import external_call
from std.memory import Pointer
from std.memory.alloc import alloc, Layout

struct BifrostGate:
    var port: Int
    var server_fd: Int32
    var addr_ptr: Pointer[Int16, MutUntrackedOrigin]

    def __init__(out self, port: Int):
        self.port = port
        self.server_fd = external_call["socket", Int32](2, 1, 0)
        var allocation = alloc(Layout[Int16](count=8))
        self.addr_ptr = allocation^.unsafe_leak()
        var port_htons = (self.port >> 8) | ((self.port & 0xFF) << 8)
        self.addr_ptr.unsafe_offset(0).unsafe_write(2)
        self.addr_ptr.unsafe_offset(1).unsafe_write(Int16(port_htons))
        for i in range(2, 8):
            self.addr_ptr.unsafe_offset(i).unsafe_write(0)

    def start(self) -> Bool:
        if self.server_fd < 0:
            return False
        var optval_alloc = alloc(Layout[Int32](count=1))
        var optval = optval_alloc^.unsafe_leak()
        optval.unsafe_write(1)
        _ = external_call["setsockopt", Int32](self.server_fd, 1, 2, optval.unsafe_bitcast[Int8](), 4)
        optval.unsafe_free()
        var bind_res = external_call["bind", Int32](self.server_fd, self.addr_ptr.unsafe_bitcast[Int8](), 16)
        if bind_res < 0:
            return False
        var listen_res = external_call["listen", Int32](self.server_fd, 128)
        if listen_res < 0:
            return False
        return True

    def await_request(self) -> Int32:
        var client_addr = alloc(Layout[Int8](count=16))^.unsafe_leak()
        var client_len_alloc = alloc(Layout[Int32](count=1))
        var client_len = client_len_alloc^.unsafe_leak()
        client_len.unsafe_write(16)
        var client_fd = external_call["accept", Int32](self.server_fd, client_addr, client_len)
        client_addr.unsafe_free()
        client_len.unsafe_free()
        if client_fd >= 0:
            var buf_alloc = alloc(Layout[Int8](count=1024))
            var buf = buf_alloc^.unsafe_leak()
            var bytes_read = external_call["read", Int64](client_fd, buf.unsafe_bitcast[Int8](), 1024)
            buf.unsafe_free()
        return client_fd

    def send_response(self, client_fd: Int32, content: String):
        if client_fd < 0:
            return
        var response = String("HTTP/1.1 200 OK\r\nContent-Type: application/json\r\n\r\n{\"response\":\"") + content + String("\"}")
        var response_ptr = response.unsafe_ptr().unsafe_bitcast[Int8]()
        _ = external_call["send", Int](client_fd, response_ptr, len(response.as_bytes()), 0)
        _ = external_call["close", Int32](client_fd)

    def __deinit__(deinit self):
        if self.server_fd >= 0:
            _ = external_call["close", Int32](self.server_fd)
        self.addr_ptr.unsafe_free()

def main():
    var s = BifrostGate(11435)
    if not s.start():
        print("Fail")
        return
    print("Started")
    # Simulate stopping instead of blocking forever
