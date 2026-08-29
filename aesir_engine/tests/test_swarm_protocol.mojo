# tests/test_swarm_protocol.mojo
# Verification of Swarm Node Identity authentication, join/leave/heartbeat mesh protocol, and remote inference dispatch

from core.swarm import (
    SwarmCluster,
    PeerNode,
    SwarmNodeRole,
    NodeIdentity,
    RemoteInferenceRequest,
    RemoteInferenceResponse,
    authenticate_node_identity,
)

def test_swarm_node_authentication() raises:
    print("--- Testing Swarm Node Identity Authentication ---")
    var valid_id = NodeIdentity("worker-node-1", "secret-aesir-token", "AESIR-SWARM-v1")
    if not authenticate_node_identity(valid_id, "secret-aesir-token"):
        raise Error("authenticate_node_identity failed for valid credentials")

    # Verify invalid token rejection
    var bad_token = NodeIdentity("worker-node-1", "wrong-token", "AESIR-SWARM-v1")
    var rejected_token = False
    try:
        var _ = authenticate_node_identity(bad_token, "secret-aesir-token")
    except:
        rejected_token = True
    if not rejected_token:
        raise Error("authenticate_node_identity failed to reject invalid auth_token")

    # Verify invalid protocol version rejection
    var bad_version = NodeIdentity("worker-node-1", "secret-aesir-token", "AESIR-SWARM-v0")
    var rejected_version = False
    try:
        var _ = authenticate_node_identity(bad_version, "secret-aesir-token")
    except:
        rejected_version = True
    if not rejected_version:
        raise Error("authenticate_node_identity failed to reject unsupported protocol version")

    print("Swarm node identity authentication: PASS")


def test_swarm_join_leave_heartbeat() raises:
    print("--- Testing Swarm Join, Leave, and Heartbeat Liveness Protocol ---")
    var cluster = SwarmCluster()
    var id1 = NodeIdentity("node-alpha", "secret-aesir-token", "AESIR-SWARM-v1", 1000)

    var joined = cluster.join_mesh_authenticated(id1, "192.168.1.100", "secret-aesir-token")
    if not joined or not cluster.is_mesh_active:
        raise Error("join_mesh_authenticated failed")

    if cluster.registry.count() != 1:
        raise Error("cluster registry node count mismatch")

    var pulse_ok = cluster.heartbeat_pulse("node-alpha", 1010)
    if not pulse_ok:
        raise Error("heartbeat_pulse failed")

    var left = cluster.leave_mesh("node-alpha")
    if not left or cluster.registry.count() != 0 or cluster.is_mesh_active:
        raise Error("leave_mesh failed")

    print("Swarm join, leave, and heartbeat liveness protocol: PASS")


def test_remote_inference_dispatch() raises:
    print("--- Testing Remote Swarm Inference Dispatch ---")
    var cluster = SwarmCluster()
    var id1 = NodeIdentity("node-gpu-1", "secret-aesir-token", "AESIR-SWARM-v1", 1000)
    var _ = cluster.join_mesh_authenticated(id1, "10.0.0.50", "secret-aesir-token")

    var req = RemoteInferenceRequest("req-999", "llama-3-8b", "What is Aesir?", 64, 0.7)
    var resp = cluster.dispatch_remote_inference(req, "secret-aesir-token")

    if not resp.is_success:
        raise Error("dispatch_remote_inference failed")

    if resp.executing_node_id != "node-gpu-1":
        raise Error("dispatch_remote_inference executing node ID mismatch")

    if resp.tokens_generated != 64:
        raise Error("dispatch_remote_inference token count mismatch")

    print("Remote swarm inference dispatch: PASS")


def main() raises:
    test_swarm_node_authentication()
    test_swarm_join_leave_heartbeat()
    test_remote_inference_dispatch()
