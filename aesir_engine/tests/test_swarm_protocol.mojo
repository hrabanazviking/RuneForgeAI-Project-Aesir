# tests/test_swarm_protocol.mojo
# Verification of local swarm authentication and fail-closed network boundaries

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
    var valid_id = NodeIdentity("worker-node-1", "unit-test-token-32", "AESIR-SWARM-v1")
    if not authenticate_node_identity(valid_id, "unit-test-token-32"):
        raise Error("authenticate_node_identity failed for valid credentials")

    # Verify invalid token rejection
    var bad_token = NodeIdentity("worker-node-1", "wrong-token", "AESIR-SWARM-v1")
    var rejected_token = False
    try:
        var _ = authenticate_node_identity(bad_token, "unit-test-token-32")
    except:
        rejected_token = True
    if not rejected_token:
        raise Error("authenticate_node_identity failed to reject invalid auth_token")

    # Verify invalid protocol version rejection
    var bad_version = NodeIdentity("worker-node-1", "unit-test-token-32", "AESIR-SWARM-v0")
    var rejected_version = False
    try:
        var _ = authenticate_node_identity(bad_version, "unit-test-token-32")
    except:
        rejected_version = True
    if not rejected_version:
        raise Error("authenticate_node_identity failed to reject unsupported protocol version")

    print("Swarm node identity authentication: PASS")


def test_swarm_join_leave_heartbeat() raises:
    print("--- Testing Unsupported Swarm Join, Leave, and Heartbeat Boundaries ---")
    var cluster = SwarmCluster()
    var id1 = NodeIdentity("node-alpha", "unit-test-token-32", "AESIR-SWARM-v1", 1000)

    var join_rejected = False
    try:
        _ = cluster.join_mesh_authenticated(id1, "192.0.2.100", "unit-test-token-32")
    except error:
        join_rejected = "not implemented" in String(error)
    if not join_rejected:
        raise Error("join_mesh_authenticated reported a network join")

    if cluster.heartbeat_pulse("node-alpha", 1010):
        raise Error("heartbeat_pulse reported network liveness")

    var leave_rejected = False
    try:
        _ = cluster.leave_mesh("node-alpha")
    except error:
        leave_rejected = "not implemented" in String(error)
    if not leave_rejected:
        raise Error("leave_mesh reported a network leave")

    if cluster.registry.count() != 0 or cluster.is_mesh_active:
        raise Error("unsupported network calls mutated cluster state")

    print("Unsupported swarm join, leave, and heartbeat boundaries: PASS")


def test_remote_inference_dispatch() raises:
    print("--- Testing Remote Swarm Inference Dispatch ---")
    var cluster = SwarmCluster()

    var req = RemoteInferenceRequest("req-999", "llama-3-8b", "What is Aesir?", 64, 0.7)
    var dispatch_failed = False
    try:
        var resp = cluster.dispatch_remote_inference(req, "unit-test-token-32")
    except error:
        dispatch_failed = True
        if "not implemented" not in String(error):
            raise Error("dispatch_remote_inference rejection omitted truth boundary")
    
    if not dispatch_failed:
        raise Error("dispatch_remote_inference failed to reject unsupported operation")
    if cluster.registry.count() != 0 or cluster.dispatcher.active_tasks != 0:
        raise Error("unsupported remote dispatch mutated cluster state")

    print("Remote swarm inference dispatch: PASS")


def main() raises:
    test_swarm_node_authentication()
    test_swarm_join_leave_heartbeat()
    test_remote_inference_dispatch()
