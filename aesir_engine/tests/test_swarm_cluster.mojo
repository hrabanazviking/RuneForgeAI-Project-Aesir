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

    # Test overflow zero-floor protection when used > capacity
    var overused_node = PeerNode("worker-overflow", "192.168.1.51", 11434, SwarmNodeRole.WORKER, 1000, 2000, True)
    if overused_node.vram_free_mb() != 0:
        print("FAIL: overused PeerNode free VRAM did not clamp to zero")
        success = False

    # Test negative VRAM initialization clamping
    var neg_node = PeerNode("worker-neg", "192.168.1.52", 11434, SwarmNodeRole.WORKER, -100, -50, True)
    if neg_node.vram_capacity_mb != 0 or neg_node.vram_used_mb != 0:
        print("FAIL: negative VRAM attributes were not clamped to zero")
        success = False

    if success:
        print("caller-supplied PeerNode capacity arithmetic: PASS")
    else:
        raise Error("PeerNode metric invariant mismatch")


def test_peer_registry_and_load_balancer() raises:
    print("--- Testing caller-supplied peer selection primitive ---")
    var success = True

    var registry = PeerRegistry()
    # Test empty registry get_least_loaded_node rejection
    var empty_rejected = False
    try:
        _ = registry.get_least_loaded_node()
    except:
        empty_rejected = True
    if not empty_rejected:
        print("FAIL: empty PeerRegistry get_least_loaded_node failed to raise Error")
        success = False

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
    var dispatcher = TaskDispatcher()
    var empty_dispatch_rejected = False
    try:
        var empty_node = PeerNode("", "127.0.0.1", 11434, SwarmNodeRole.WORKER, 1000, 500, True)
        _ = dispatcher.dispatch_to_node(empty_node, "test_task")
    except error:
        empty_dispatch_rejected = True
        if "must not be empty" not in String(error):
            raise Error("swarm empty dispatch rejection omitted empty error text")
    if not empty_dispatch_rejected:
        raise Error("TaskDispatcher allowed dispatch to node with empty ID")

    var valid_dispatch_rejected = False
    try:
        var local_node = PeerNode(
            "local", "127.0.0.1", 11434,
            SwarmNodeRole.WORKER, 1000, 500, True
        )
        _ = dispatcher.dispatch_to_node(local_node, "test_task")
    except error:
        valid_dispatch_rejected = True
        if "not implemented" not in String(error):
            raise Error("swarm dispatch rejection omitted truth boundary")
    if not valid_dispatch_rejected:
        raise Error("TaskDispatcher fabricated a dispatch success string")

    if cluster.registry.count() != 0 or cluster.is_mesh_active:
        raise Error("SwarmCluster started with fictional operational state")
    if cluster.heartbeat_pulse():
        raise Error("swarm heartbeat reported success without transport")

    # Test empty leader address join mesh rejection
    var empty_join_rejected = False
    try:
        _ = cluster.join_mesh("")
    except error:
        empty_join_rejected = True
        if "must not be empty" not in String(error):
            raise Error("swarm empty join rejection omitted empty error text")
    if not empty_join_rejected:
        raise Error("SwarmCluster allowed join_mesh with empty leader address")

    # Test empty model parameter dispatch rejection
    var empty_dist_rejected = False
    try:
        _ = cluster.dispatch_distributed_inference("", "Run inference across mesh")
    except error:
        empty_dist_rejected = True
        if "must not be empty" not in String(error):
            raise Error("swarm empty dispatch rejection omitted empty error text")
    if not empty_dist_rejected:
        raise Error("SwarmCluster allowed dispatch_distributed_inference with empty model")

    var join_rejected = False
    try:
        _ = cluster.join_mesh("192.0.2.1")
    except error:
        join_rejected = "explicit credentials" in String(error)
    if not join_rejected or cluster.is_mesh_active:
        raise Error("unauthenticated swarm join fabricated success")

    var output_failed = False
    try:
        var output = cluster.dispatch_distributed_inference(
            "aesir:latest", "Run inference across mesh"
        )
    except error:
        output_failed = True
        if "not implemented" not in String(error):
             raise Error("swarm dispatch rejection omitted truth boundary")
    if not output_failed:
        raise Error("swarm dispatch returned empty output text")

    print("unsupported swarm network operations: PASS")
