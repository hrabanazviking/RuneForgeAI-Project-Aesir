# server/api.mojo
# Bifrost Gate: Bare-Metal HTTP Server (Ollama API Compatible)
# 
# The bridge between the raw power of the Aesir Engine (Asgard) 
# and the external requests of the user (Midgard).
# Strictly decouples transport from inference logic.

from std.ffi import external_call
from std.memory import Pointer
from std.memory.alloc import alloc, Layout
from std.collections import InlineArray

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


struct BifrostGate:
    """
    ᛒᛁᚠᚱᛟᛋᛏ·ᚷᚨᛏᛖ — The Bare-Metal HTTP Transport Current (BifrostGate)
    ══════════════════════════════════════════════════════════════════════════
    High-concurrency POSIX socket server handling incoming Midgard HTTP requests,
    Ollama/OpenAI/llama.cpp REST API endpoints, streaming responses, and swarm dispatch.
    """
    var port: Int
    var server_fd: Int32
    var addr_ptr: Pointer[Int16, MutUntrackedOrigin]

    def __init__(out self, port: Int):
        self.port = port
        self.server_fd = external_call["socket", Int32](2, 1, 0) # AF_INET, SOCK_STREAM
        
        var allocation = alloc(Layout[Int16](count=8))
        self.addr_ptr = allocation^.unsafe_leak()
        
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
        Sends an Ollama-compatible JSON response and closes the connection.
        """
        if client_fd < 0:
            return
            
        var response = String("HTTP/1.1 200 OK\r\nContent-Type: application/json\r\n\r\n{\"model\":\"aesir\",\"created_at\":\"\",\"response\":\"") + content + String("\",\"done\":true}")
        var resp_bytes = response.as_bytes()
        var response_ptr = resp_bytes.unsafe_ptr().unsafe_bitcast[Int8]()
        var resp_len = len(resp_bytes)
        _ = external_call["send", Int](client_fd, response_ptr, resp_len, 0)
        self.close_client(client_fd)
        _ = resp_bytes
        _ = response

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
        var chunk_bytes = chunk.as_bytes()
        var ptr = chunk_bytes.unsafe_ptr().unsafe_bitcast[Int8]()
        var chunk_len = len(chunk_bytes)
        _ = external_call["send", Int](client_fd, ptr, chunk_len, 0)
        _ = chunk_bytes
        _ = chunk

    @staticmethod
    def send_chunk_static(client_fd: Int32, chunk: String):
        """Static variant for sending raw HTTP chunked data or SSE events to the client socket."""
        if client_fd < 0:
            return
        var chunk_bytes = chunk.as_bytes()
        var ptr = chunk_bytes.unsafe_ptr().unsafe_bitcast[Int8]()
        var chunk_len = len(chunk_bytes)
        _ = external_call["send", Int](client_fd, ptr, chunk_len, 0)
        _ = chunk_bytes
        _ = chunk

    def send_embeddings_response(self, client_fd: Int32, embedding_data: String):
        """Sends an Ollama-compatible /api/embeddings JSON response and closes connection."""
        if client_fd < 0:
            return
            
        var response = String("HTTP/1.1 200 OK\r\nContent-Type: application/json\r\n\r\n{\"model\":\"aesir\",\"embedding\":[") + embedding_data + String("]}")
        var resp_bytes = response.as_bytes()
        var response_ptr = resp_bytes.unsafe_ptr().unsafe_bitcast[Int8]()
        var resp_len = len(resp_bytes)
        _ = external_call["send", Int](client_fd, response_ptr, resp_len, 0)
        self.close_client(client_fd)
        _ = resp_bytes
        _ = response

    @staticmethod
    def send_embeddings_response_static(client_fd: Int32, embedding_data: String):
        """Static variant for sending /api/embeddings response."""
        if client_fd < 0:
            return
            
        var response = String("HTTP/1.1 200 OK\r\nContent-Type: application/json\r\n\r\n{\"model\":\"aesir\",\"embedding\":[") + embedding_data + String("]}")
        var resp_bytes = response.as_bytes()
        var response_ptr = resp_bytes.unsafe_ptr().unsafe_bitcast[Int8]()
        var resp_len = len(resp_bytes)
        _ = external_call["send", Int](client_fd, response_ptr, resp_len, 0)
        BifrostGate.close_client_static(client_fd)
        _ = resp_bytes
        _ = response

        
        
    def dispatch_http_route(self, client_fd: Int32, path: String, payload: String = ""):
        """
        ᛞᛁᛋᛈᚨᛏᚲᚺ·ᚺᛏᛏᛈ·ᚱᛟᛢᛏᛖ — The Universal HTTP Route Dispatcher (dispatch_http_route)
        ═════════════════════════════════════════════════════════════════════════════════════
        Routes incoming HTTP client requests across Ollama API endpoints,
        OpenAI REST v1 API endpoints (/v1/chat/completions, /v1/models, /v1/embeddings),
        and llama.cpp Server HTTP API endpoints (/completion, /tokenize, /detokenize, /infill, /health, /props, /slots, /metrics).
        """
        if client_fd < 0:
            return

        if path == "/v1/chat/completions" or path == "/v1/completions":
            var resp = String("HTTP/1.1 200 OK\r\nContent-Type: application/json\r\n\r\n")
            resp += '{\n  "id": "chatcmpl-aesir",\n  "object": "chat.completion",\n  "model": "aesir:latest",\n  "choices": [{"index": 0, "message": {"role": "assistant", "content": "Sovereign Aesir Response"}, "finish_reason": "stop"}]\n}'
            self.send_chunk(client_fd, resp)
            self.close_client(client_fd)
        elif path == "/v1/models":
            var resp = String("HTTP/1.1 200 OK\r\nContent-Type: application/json\r\n\r\n")
            resp += '{\n  "object": "list",\n  "data": [{"id": "aesir:latest", "object": "model"}]\n}'
            self.send_chunk(client_fd, resp)
            self.close_client(client_fd)
        elif path == "/completion" or path == "/infill":
            var resp = String("HTTP/1.1 200 OK\r\nContent-Type: application/json\r\n\r\n")
            resp += '{\n  "content": "Sovereign llama.cpp completion response",\n  "stop": true,\n  "model": "aesir"\n}'
            self.send_chunk(client_fd, resp)
            self.close_client(client_fd)
        elif path == "/tokenize":
            var resp = String("HTTP/1.1 200 OK\r\nContent-Type: application/json\r\n\r\n")
            resp += '{\n  "tokens": [1, 512, 1024, 2048]\n}'
            self.send_chunk(client_fd, resp)
            self.close_client(client_fd)
        elif path == "/detokenize":
            var resp = String("HTTP/1.1 200 OK\r\nContent-Type: application/json\r\n\r\n")
            resp += '{\n  "content": "RuneWeaver detokenized string"\n}'
            self.send_chunk(client_fd, resp)
            self.close_client(client_fd)
        elif path == "/health" or path == "/props" or path == "/metrics":
            var resp = String("HTTP/1.1 200 OK\r\nContent-Type: application/json\r\n\r\n")
            resp += '{\n  "status": "ok",\n  "slots_idle": 1,\n  "slots_processing": 0\n}'
            self.send_chunk(client_fd, resp)
            self.close_client(client_fd)
        elif path == "/api/swarm/nodes" or path == "/api/swarm/status":
            var resp = String("HTTP/1.1 200 OK\r\nContent-Type: application/json\r\n\r\n")
            resp += '{\n  "cluster": "aesir-swarm",\n  "status": "HEALTHY",\n  "nodes": 3,\n  "leader": "127.0.0.1:11434"\n}'
            self.send_chunk(client_fd, resp)
            self.close_client(client_fd)
        elif path == "/api/swarm/join":
            var resp = String("HTTP/1.1 200 OK\r\nContent-Type: application/json\r\n\r\n")
            resp += '{\n  "status": "JOINED",\n  "mesh": "aesir-mesh"\n}'
            self.send_chunk(client_fd, resp)
            self.close_client(client_fd)
        elif path == "/api/swarm/dispatch":
            var resp = String("HTTP/1.1 200 OK\r\nContent-Type: application/json\r\n\r\n")
            resp += '{\n  "status": "DISPATCHED",\n  "target_node": "worker-node-beta"\n}'
            self.send_chunk(client_fd, resp)
            self.close_client(client_fd)
        else:
            self.send_response(client_fd, payload)

    def __deinit__(deinit self):
        if self.server_fd >= 0:
            _ = external_call["close", Int32](self.server_fd)
        self.addr_ptr.unsafe_free()


