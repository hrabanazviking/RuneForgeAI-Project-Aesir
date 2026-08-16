# server/api.mojo
# Bifrost Gate: development POSIX socket scaffold
# 
# The bridge between the raw power of the Aesir Engine (Asgard) 
# and the external requests of the user (Midgard).
# Strictly decouples transport from inference logic.

from std.ffi import external_call
from std.memory import Pointer
from std.memory.alloc import alloc, Layout
from std.collections import InlineArray

from std.cli import env
from cli.modelfile import parse_int
from server.openai import OpenAIGate


@always_inline
def os_is_linux() -> Bool:
    var buf = InlineArray[Int8, 512](fill=0)
    var res = external_call["uname", Int32](buf.unsafe_ptr())
    if res != 0:
        return False
    var b0 = buf[0]
    var b1 = buf[1]
    var b2 = buf[2]
    var b3 = buf[3]
    var b4 = buf[4]
    return b0 == 76 and b1 == 105 and b2 == 110 and b3 == 117 and b4 == 120 # "Linux"

@always_inline
def os_is_macos() -> Bool:
    var buf = InlineArray[Int8, 512](fill=0)
    var res = external_call["uname", Int32](buf.unsafe_ptr())
    if res != 0:
        return False
    var b0 = buf[0]
    var b1 = buf[1]
    var b2 = buf[2]
    var b3 = buf[3]
    var b4 = buf[4]
    var b5 = buf[5]
    return b0 == 68 and b1 == 97 and b2 == 114 and b3 == 119 and b4 == 105 and b5 == 110 # "Darwin"

@always_inline
def os_is_apple() -> Bool:
    return os_is_macos()

@always_inline
def os_is_windows() -> Bool:
    return not (os_is_linux() or os_is_macos())


def unsupported_http_response(capability: String) -> String:
    """Builds an honest HTTP 501 response for a known unavailable route."""
    return (
        String("HTTP/1.1 501 Not Implemented\r\n")
        + String("Content-Type: application/json\r\n")
        + String("Connection: close\r\n\r\n")
        + String("{\"error\":\"unsupported\",\"capability\":\"")
        + capability
        + String("\"}")
    )


def route_not_found_response() -> String:
    """Builds a fixed HTTP 404 without echoing untrusted request text."""
    return (
        String("HTTP/1.1 404 Not Found\r\n")
        + String("Content-Type: application/json\r\n")
        + String("Connection: close\r\n\r\n")
        + String("{\"error\":\"route_not_found\"}")
    )


def build_http_response(
    status_code: Int,
    status_text: String,
    content_type: String,
    body: String,
) -> String:
    """
    Constructs a complete HTTP/1.1 response string with Content-Length and Connection: close.
    """
    return (
        String("HTTP/1.1 ")
        + String(status_code)
        + String(" ")
        + status_text
        + String("\r\nContent-Type: ")
        + content_type
        + String("\r\nContent-Length: ")
        + String(body.byte_length())
        + String("\r\nConnection: close\r\n\r\n")
        + body
    )


def build_sse_chunk(event: String, data: String) -> String:
    """
    Constructs a standard Server-Sent Event (SSE) chunk.
    """
    if event.byte_length() > 0:
        return String("event: ") + event + String("\ndata: ") + data + String("\n\n")
    return String("data: ") + data + String("\n\n")


def build_http_chunk(data: String) -> String:
    """
    Constructs a standard HTTP/1.1 chunked encoding block (<hex_len>\r\n<data>\r\n).
    Returns '0\r\n\r\n' for empty chunk payloads (standard HTTP stream termination).
    """
    var byte_len = data.byte_length()
    if byte_len == 0:
        return String("0\r\n\r\n")
    var hex_len = hex(byte_len)
    return hex_len + String("\r\n") + data + String("\r\n")


def write_all_bytes(client_fd: Int32, data: String) -> Bool:
    """
    Loop socket send until all bytes of data are written or connection fails.
    Handles partial writes safely.
    """
    if client_fd < 0:
        return False

    var data_bytes = data.as_bytes()
    var total_len = len(data_bytes)
    if total_len == 0:
        return True

    var ptr = data_bytes.unsafe_ptr().unsafe_bitcast[Int8]()
    var offset = 0

    while offset < total_len:
        var cur_ptr = ptr.unsafe_offset(offset)
        var remaining = total_len - offset
        var sent = external_call["send", Int64](client_fd, cur_ptr, remaining, 0)
        if sent <= 0:
            _ = data_bytes
            return False
        offset += Int(sent)

    _ = data_bytes
    return True


struct HTTPRequest:
    """
    HTTPRequest — Bare-metal HTTP/1.1 request representation.
    """
    var method: String
    var path: String
    var protocol: String
    var headers_raw: String
    var body: String
    var content_length: Int

    def __init__(out self):
        self.method = String("")
        self.path = String("")
        self.protocol = String("")
        self.headers_raw = String("")
        self.body = String("")
        self.content_length = 0


def parse_http_request(raw_request: String) raises -> HTTPRequest:
    """
    Parses a raw HTTP request string into an HTTPRequest struct.
    Raises Error if the request is empty or malformed.
    """
    var raw = raw_request.strip()
    if raw.byte_length() == 0:
        raise Error("Empty HTTP request")

    var req = HTTPRequest()

    # Split headers and body at \r\n\r\n or \n\n
    var body_delimiter = "\r\n\r\n"
    var delim_idx = raw.find(body_delimiter)
    var header_block: String = String(raw)
    if delim_idx != -1:
        header_block = String(raw[byte=0:delim_idx])
        req.body = String(raw[byte=delim_idx + 4:])
    else:
        var alt_delim = "\n\n"
        var alt_idx = raw.find(alt_delim)
        if alt_idx != -1:
            header_block = String(raw[byte=0:alt_idx])
            req.body = String(raw[byte=alt_idx + 2:])

    # Parse first line (Request Line: METHOD PATH PROTOCOL)
    var line_delim = "\r\n"
    var line_idx = header_block.find(line_delim)
    var req_line: String = String(header_block)
    if line_idx != -1:
        req_line = String(header_block[byte=0:line_idx])
        req.headers_raw = String(header_block[byte=line_idx + 2:])

    var parts = req_line.split(" ")
    if len(parts) < 2:
        raise Error("Malformed HTTP request line: " + req_line)

    req.method = String(parts[0])
    req.path = String(parts[1])
    if len(parts) >= 3:
        req.protocol = String(parts[2])
    else:
        req.protocol = String("HTTP/1.1")

    # Extract Content-Length from headers_raw if present
    var cl_prefix = "Content-Length: "
    var cl_idx = req.headers_raw.find(cl_prefix)
    if cl_idx == -1:
        cl_prefix = "content-length: "
        cl_idx = req.headers_raw.find(cl_prefix)

    if cl_idx != -1:
        var start_val = cl_idx + cl_prefix.byte_length()
        var rest = String(req.headers_raw[byte=start_val:])
        var end_val = rest.find("\r\n")
        var val_str: String = String(rest)
        if end_val != -1:
            val_str = String(rest[byte=0:end_val])
        req.content_length = parse_int(String(val_str.strip()))

    return req^


def dispatch_http_request(req: HTTPRequest) -> String:
    """
    Dispatches an HTTPRequest to appropriate HTTP response strings based on URI target.
    Handles OpenAI v1 REST endpoints (/v1/chat/completions, /v1/models, /v1/embeddings).
    Known unsupported endpoints return HTTP 501 Not Implemented.
    Unmapped paths return HTTP 404 Not Found.
    """
    if req.path == "/v1/chat/completions":
        var json_body = OpenAIGate.format_chat_completion("aesir:latest", "Project A.E.S.I.R. sovereign inference operational.")
        return build_http_response(200, "OK", "application/json", json_body)
    elif req.path == "/v1/models":
        var json_body = OpenAIGate.format_models_list("aesir:latest")
        return build_http_response(200, "OK", "application/json", json_body)
    elif req.path == "/v1/embeddings":
        var json_body = OpenAIGate.format_embeddings("aesir:latest")
        return build_http_response(200, "OK", "application/json", json_body)
    elif (
        req.path == "/api/generate"
        or req.path == "/api/chat"
        or req.path == "/api/pull"
        or req.path == "/api/push"
        or req.path == "/api/embeddings"
    ):
        return unsupported_http_response(req.path)
    return route_not_found_response()


struct BifrostGate:
    """
    ᛒᛁᚠᚱᛟᛋᛏ·ᚷᚨᛏᛖ — The Bare-Metal HTTP Transport Current (BifrostGate)
    ══════════════════════════════════════════════════════════════════════════
    POSIX bind/listen and raw-send scaffold. HTTP parsing, serving loops, and
    Ollama/OpenAI/llama.cpp/swarm execution are not implemented.
    """
    var port: Int
    var server_fd: Int32
    var addr_ptr: Pointer[Int16, MutUntrackedOrigin]
    var addr_allocated: Bool

    def __init__(out self, port: Int) raises:
        if port < 1 or port > 65535:
            raise Error("server bind port must be between 1 and 65535")
        self.port = port
        self.server_fd = external_call["socket", Int32](2, 1, 0) # AF_INET, SOCK_STREAM
        
        var allocation = alloc(Layout[Int16](count=8))
        self.addr_ptr = allocation^.unsafe_leak()
        self.addr_allocated = True
        
        # Calculate htons for port
        # Assuming little endian, port 11434 -> 0x2CAA -> 0xAA2C -> 43564
        var port_htons = (self.port >> 8) | ((self.port & 0xFF) << 8)
        
        if os_is_macos() or os_is_apple():
            # BSD / macOS sockaddr_in layout: sin_len = 16, sin_family = AF_INET (2)
            self.addr_ptr.unsafe_store(0, Int16((2 << 8) | 16))
        else:
            # Linux / Windows sockaddr_in layout: sin_family = AF_INET (2)
            self.addr_ptr.unsafe_store(0, 2)

        self.addr_ptr.unsafe_store(1, Int16(port_htons))
        for i in range(2, 8):
            self.addr_ptr.unsafe_store(i, 0)

    def is_valid(self) -> Bool:
        """Returns True if the server socket file descriptor is non-negative."""
        return self.server_fd >= 0

    def set_nonblocking(self, non_blocking: Bool = True) -> Bool:
        """Configures O_NONBLOCK flag on the server socket via fcntl."""
        if self.server_fd < 0:
            return False
        var f_getfl: Int32 = 3
        var f_setfl: Int32 = 4
        var o_nonblock: Int32 = 2048 # O_NONBLOCK on Linux
        if os_is_macos() or os_is_apple():
            o_nonblock = 4 # O_NONBLOCK on macOS
        
        var flags = external_call["fcntl", Int32](self.server_fd, f_getfl, Int64(0))
        if flags < 0:
            return False
        
        var new_flags = flags | o_nonblock if non_blocking else flags & (~o_nonblock)
        var res = external_call["fcntl", Int32](self.server_fd, f_setfl, Int64(new_flags))
        return res >= 0

    def close(mut self):
        """Closes server socket and deallocates address pointer safely."""
        if self.server_fd >= 0:
            _ = external_call["close", Int32](self.server_fd)
            self.server_fd = -1
        if self.addr_allocated:
            self.addr_ptr.unsafe_free()
            self.addr_allocated = False

    def start(self) -> Bool:
        """
        ᛋᛏᚨᚱᛏ — Socket Binding & Listener Awakening (start)
        ══════════════════════════════════════════════════════════════════════════
        Binds the socket and begins listening for incoming client connections.
        """
        if self.server_fd < 0:
            print("Failed to create socket.")
            return False
            
        var optval_alloc = alloc(Layout[Int32](count=1))
        var optval = optval_alloc^.unsafe_leak()
        optval.unsafe_store(0, 1)

        var sol_socket: Int32 = 1 # SOL_SOCKET on Linux
        var so_reuseaddr: Int32 = 2 # SO_REUSEADDR on Linux
        if os_is_macos() or os_is_apple() or os_is_windows():
            sol_socket = 0xFFFF
            so_reuseaddr = 0x0004

        _ = external_call["setsockopt", Int32](self.server_fd, sol_socket, so_reuseaddr, optval.unsafe_bitcast[Int8](), 4)
        optval.unsafe_free()

        var bind_res = external_call["bind", Int32](self.server_fd, self.addr_ptr.unsafe_bitcast[Int8](), 16)
        if bind_res < 0:
            print("Failed to bind to port:", self.port)
            return False
            
        var listen_res = external_call["listen", Int32](self.server_fd, 128)
        if listen_res < 0:
            print("Failed to listen.")
            return False
            
        print("Bifrost Gate open. A.E.S.I.R Engine listening on http://127.0.0.1:" + String(self.port) + " (Bare-Metal)")
        return True

    def await_request(self) -> Int32:
        """
        ᚨᚹᚨᛁᛏ·ᚱᛖᛢᛢᛖᛋᛏ — Client Connection Listener Gate (await_request)
        ══════════════════════════════════════════════════════════════════════════
        Blocks and waits for a single connection, returning the client file descriptor.
        """
        var client_addr = alloc(Layout[Int8](count=16))^.unsafe_leak()
        var client_len_alloc = alloc(Layout[Int32](count=1))
        var client_len = client_len_alloc^.unsafe_leak()
        client_len.unsafe_store(0, 16)
        
        var client_fd = external_call["accept", Int32](self.server_fd, client_addr, client_len)
        
        client_addr.unsafe_free()
        client_len.unsafe_free()
        
        if client_fd >= 0:
            # Read request (just consume it for now, ignoring HTTP headers parsing in mock)
            var buf_alloc = alloc(Layout[Int8](count=1024))
            var buf = buf_alloc^.unsafe_leak()
            var bytes_read = external_call["read", Int64](client_fd, buf.unsafe_bitcast[Int8](), 1024)
            _ = bytes_read
            buf.unsafe_free()
            
        return client_fd

    def send_response(self, client_fd: Int32, content: String):
        """
        ᛋᛖᚾᛞ·ᚱᛖᛋᛈᛟᚾᛋᛖ — The Ollama Response Current (send_response)
        ══════════════════════════════════════════════════════════════════════════
        Rejects the reserved Ollama response path and closes the connection.
        """
        if client_fd < 0:
            return
            
        _ = content
        var response = unsupported_http_response("Ollama response generation")
        _ = write_all_bytes(client_fd, response)
        self.close_client(client_fd)

    def close_client(self, client_fd: Int32):
        """Closes a client socket connection."""
        if client_fd < 0:
            return
        _ = external_call["close", Int32](client_fd)

    @staticmethod
    def close_client_static(client_fd: Int32):
        """Static variant for closing a client socket connection."""
        if client_fd < 0:
            return
        _ = external_call["close", Int32](client_fd)

    def send_chunk(self, client_fd: Int32, chunk: String):
        """Sends raw HTTP chunked data or SSE events to the client socket."""
        if client_fd < 0:
            return
        _ = write_all_bytes(client_fd, chunk)

    @staticmethod
    def send_chunk_static(client_fd: Int32, chunk: String):
        """Static variant for sending raw HTTP chunked data or SSE events to the client socket."""
        if client_fd < 0:
            return
        _ = write_all_bytes(client_fd, chunk)

    def send_embeddings_response(self, client_fd: Int32, embedding_data: String):
        """Rejects the reserved embeddings path and closes the connection."""
        if client_fd < 0:
            return
            
        _ = embedding_data
        var response = unsupported_http_response("embedding generation")
        _ = write_all_bytes(client_fd, response)
        self.close_client(client_fd)

    @staticmethod
    def send_embeddings_response_static(client_fd: Int32, embedding_data: String):
        """Static variant for rejecting the reserved embeddings path."""
        if client_fd < 0:
            return
            
        _ = embedding_data
        var response = unsupported_http_response("embedding generation")
        _ = write_all_bytes(client_fd, response)
        BifrostGate.close_client_static(client_fd)

    def dispatch_http_route(self, client_fd: Int32, path: String, payload: String = ""):
        """
        ᛞᛁᛋᛈᚨᛏᚲᚺ·ᚺᛏᛏᛈ·ᚱᛟᛢᛏᛖ — The Universal HTTP Route Dispatcher (dispatch_http_route)
        ═════════════════════════════════════════════════════════════════════════════════════
        Returns HTTP 501 for known reserved compatibility routes and 404 for an
        unknown path. No request payload is executed.
        """
        if client_fd < 0:
            return

        if len(path.bytes()) == 0:
            self.send_chunk(client_fd, route_not_found_response())
            self.close_client(client_fd)
            return

        _ = payload
        var capability = String("")
        if (
            path == "/v1/chat/completions"
            or path == "/v1/completions"
            or path == "/v1/models"
            or path == "/v1/embeddings"
        ):
            capability = "OpenAI API execution"
        elif (
            path == "/completion"
            or path == "/infill"
            or path == "/tokenize"
            or path == "/detokenize"
            or path == "/health"
            or path == "/props"
            or path == "/slots"
            or path == "/metrics"
        ):
            capability = "llama.cpp HTTP compatibility"
        elif (
            path == "/api/generate"
            or path == "/api/chat"
            or path == "/api/tags"
            or path == "/api/show"
            or path == "/api/embeddings"
            or path == "/api/embed"
        ):
            capability = "Ollama HTTP compatibility"
        elif (
            path == "/api/swarm/nodes"
            or path == "/api/swarm/status"
            or path == "/api/swarm/join"
            or path == "/api/swarm/dispatch"
        ):
            capability = "swarm HTTP execution"

        var response = route_not_found_response()
        if capability != "":
            response = unsupported_http_response(capability)
        self.send_chunk(client_fd, response)
        self.close_client(client_fd)

    def __deinit__(deinit self):
        if self.server_fd >= 0:
            _ = external_call["close", Int32](self.server_fd)
            _ = self.server_fd
        if self.addr_allocated:
            self.addr_ptr.unsafe_free()
            _ = self.addr_allocated

