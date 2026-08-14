# main.mojo
# Entry point for Project Aesir Inference Engine

from aesir import AesirEngine
from server.api import BifrostGate

def main():
    print("======================================")
    print("Project A.E.S.I.R. Inference Engine")
    print("Target: Bare-Metal Mojo (CUDA/ROCm)")
    print("======================================")
    
    # 1. Instantiate the Engine (Encapsulates Core & Loader)
    var engine = AesirEngine(String("model.gguf"))

    # 2. Open the Bifrost Gate (HTTP Server)
    var server = BifrostGate(11434)
    if not server.start():
        print("FATAL: BifrostGate failed to open.")
        return

    # 3. The Eternal Loop (Event/Inference Loop)
    print("Watching the rainbow bridge for API requests...")
    # Simulate a single run loop to not block the tests indefinitely
    # In production, this would be `while True:`
    for _ in range(1):
        # We don't want to actually block on await_request during CI/tests
        # So we'll just mock the invocation.
        # client_fd = server.await_request()
        var client_fd: Int32 = -1
        
        print("Mock: Client connected!")
        
        # Parse prompt (mocked)
        var prompt = String("Tell me a story.")
        
        # Generate
        var response_text = engine.generate(prompt)
        
        # Send
        server.send_response(client_fd, response_text)
        print("Mock: Response sent to client via BifrostGate.")
