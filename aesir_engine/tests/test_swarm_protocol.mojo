# tests/test_swarm_protocol.mojo
# Verification of local credential comparison and unsupported network boundaries

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
    print("--- Testing local Swarm credential/version comparison ---")
    var valid_id = NodeIdentity("worker-node-1", "fixture-credential", "AESIR-SWARM-v1")
    if not authenticate_node_identity(valid_id, "fixture-credential"):
        raise Error("authenticate_node_identity failed for valid credentials")

    # Verify invalid token rejection
    var bad_token = NodeIdentity("worker-node-1", "wrong-token", "AESIR-SWARM-v1")
    var rejected_token = False
    try:
        _ = authenticate_node_identity(bad_token, "fixture-credential")
    except:
        rejected_token = True
    if not rejected_token:
        raise Error("authenticate_node_identity failed to reject invalid auth_token")

    # Verify invalid protocol version rejection
    var bad_version = NodeIdentity("worker-node-1", "fixture-credential", "AESIR-SWARM-v0")
    var rejected_version = False
    try:
        _ = authenticate_node_identity(bad_version, "fixture-credential")
    except:
        rejected_version = True
    if not rejected_version:
        raise Error("authenticate_node_identity failed to reject unsupported protocol version")

    print("Local Swarm credential/version comparison: PASS")


def test_swarm_join_leave_heartbeat() raises:
    print("--- Testing fail-closed swarm join and heartbeat boundaries ---")
    var cluster = SwarmCluster()
    var id1 = NodeIdentity("node-alpha", "fixture-credential", "AESIR-SWARM-v1", 1000)
    var join_rejected = False
    try:
        _ = cluster.join_mesh_authenticated(id1, "192.0.2.10", "fixture-credential")
    except error:
        join_rejected = True
        if "not implemented" not in String(error):
            raise Error("swarm join rejection omitted truth boundary")
    if not join_rejected or cluster.is_mesh_active or cluster.registry.count() != 0:
        raise Error("swarm join fabricated network state")
    if cluster.heartbeat_pulse("node-alpha", 1010):
        raise Error("heartbeat reported success without network transport")

    print("Fail-closed swarm join and heartbeat boundaries: PASS")


def test_remote_inference_dispatch() raises:
    print("--- Testing fail-closed remote swarm inference ---")
    var cluster = SwarmCluster()
    var req = RemoteInferenceRequest("req-999", "llama-3-8b", "What is Aesir?", 64, 0.7)
    var dispatch_rejected = False
    try:
        _ = cluster.dispatch_remote_inference(req, "fixture-credential")
    except error:
        dispatch_rejected = True
        if "not implemented" not in String(error):
            raise Error("remote inference rejection omitted truth boundary")
    if not dispatch_rejected:
        raise Error("remote swarm inference returned fabricated output")

    print("Fail-closed remote swarm inference: PASS")


def main() raises:
    test_swarm_node_authentication()
    test_swarm_join_leave_heartbeat()
    test_remote_inference_dispatch()
