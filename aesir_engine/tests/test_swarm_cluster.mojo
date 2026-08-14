# tests/test_swarm_cluster.mojo
# Verification of local swarm descriptors and unsupported network execution

from core.swarm import SwarmNodeRole, PeerNode, PeerRegistry, TaskDispatcher, SwarmCluster

def test_swarm_node_role() raises:
    print("--- Testing SwarmNodeRole Discriminants ---")
    var success = True

    var leader = SwarmNodeRole.LEADER
    var worker = SwarmNodeRole.WORKER
    var relay = SwarmNodeRole.RELAY

    if leader.name() != "LEADER" or worker.name() != "WORKER" or relay.name() != "RELAY":
        print("FAIL: SwarmNodeRole name mismatch")
        success = False

    if success:
        print("SwarmNodeRole Discriminants: PASS")
    else:
        raise Error("SwarmNodeRole invariant mismatch")


def test_peer_node_metrics() raises:
    print("--- Testing caller-supplied PeerNode capacity arithmetic ---")
    var success = True

    var node = PeerNode("worker-01", "192.168.1.50", 11434, SwarmNodeRole.WORKER, 16384, 4096, True)

    if node.vram_free_mb() != 12288:
        print("FAIL: caller-supplied capacity calculation incorrect:", node.vram_free_mb())
        success = False

    if not node.is_alive:
        print("FAIL: PeerNode liveness state incorrect")
        success = False

    if success:
        print("caller-supplied PeerNode capacity arithmetic: PASS")
    else:
        raise Error("PeerNode metric invariant mismatch")


def test_peer_registry_and_load_balancer() raises:
    print("--- Testing caller-supplied peer selection primitive ---")
    var success = True

    var registry = PeerRegistry()
    if registry.count() != 0:
        raise Error("PeerRegistry seeded fictional peers")
    registry.register_node(
        PeerNode("local", "127.0.0.1", 11434, SwarmNodeRole.LEADER, 24576, 4096, True)
    )
    registry.register_node(
        PeerNode("worker-a", "192.0.2.10", 11434, SwarmNodeRole.WORKER, 16384, 2048, True)
    )
    registry.register_node(
        PeerNode("worker-b", "192.0.2.11", 11434, SwarmNodeRole.WORKER, 32768, 1024, True)
    )

    if registry.count() != 3:
        print("FAIL: PeerRegistry node count mismatch:", registry.count())
        success = False

    var least_loaded = registry.get_least_loaded_node()
    if least_loaded.node_id != "worker-b":
        print("FAIL: local capacity selector failed to pick least-used record:", least_loaded.node_id)
        success = False

    if success:
        print("caller-supplied peer selection primitive: PASS")
    else:
        raise Error("PeerRegistry scaffold load-balancer invariant mismatch")


def test_swarm_cluster_task_dispatch() raises:
    print("--- Testing unsupported swarm network operations ---")

    var cluster = SwarmCluster()
    if cluster.registry.count() != 0 or cluster.is_mesh_active:
        raise Error("SwarmCluster started with fictional operational state")
    if cluster.heartbeat_pulse():
        raise Error("swarm heartbeat reported success without transport")

    var join_rejected = False
    try:
        _ = cluster.join_mesh("192.0.2.1")
    except error:
        join_rejected = True
        if "not implemented" not in String(error):
            raise Error("swarm join rejection omitted stable truth text")
    if not join_rejected:
        raise Error("swarm join returned fabricated success")

    var dispatch_rejected = False
    try:
        _ = cluster.dispatch_distributed_inference(
            "aesir:latest", "Run inference across mesh"
        )
    except error:
        dispatch_rejected = True
        if "not implemented" not in String(error):
            raise Error("swarm dispatch rejection omitted stable truth text")
    if not dispatch_rejected:
        raise Error("swarm dispatch returned fabricated success")

    print("unsupported swarm network operations: PASS")
