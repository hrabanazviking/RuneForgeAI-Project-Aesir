# tests/test_swarm_cluster.mojo
# Verification of Autonomous Swarm Agents & Enterprise Mesh Cluster Matrix (Phase 14)

from core.swarm import SwarmNodeRole, PeerNode, PeerRegistry, TaskDispatcher, SwarmCluster

def test_swarm_node_role():
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
        print("SwarmNodeRole Discriminants: FAIL")


def test_peer_node_metrics():
    print("--- Testing PeerNode State & VRAM Capacity Metrics ---")
    var success = True

    var node = PeerNode("worker-01", "192.168.1.50", 11434, SwarmNodeRole.WORKER, 16384, 4096, True)

    if node.vram_free_mb() != 12288:
        print("FAIL: Free VRAM capacity calculation incorrect:", node.vram_free_mb())
        success = False

    if not node.is_alive:
        print("FAIL: PeerNode liveness state incorrect")
        success = False

    if success:
        print("PeerNode Metrics: PASS")
    else:
        print("PeerNode Metrics: FAIL")


def test_peer_registry_and_load_balancer() raises:
    print("--- Testing PeerRegistry & Dynamic VRAM Load Balancer ---")
    var success = True

    var registry = PeerRegistry()

    if registry.count() != 3:
        print("FAIL: PeerRegistry node count mismatch:", registry.count())
        success = False

    var least_loaded = registry.get_least_loaded_node()
    if least_loaded.node_id != "worker-node-beta":
        print("FAIL: Dynamic VRAM load balancer failed to pick least loaded node:", least_loaded.node_id)
        success = False

    if success:
        print("PeerRegistry & Load Balancer: PASS")
    else:
        print("PeerRegistry & Load Balancer: FAIL")


def test_swarm_cluster_task_dispatch() raises:
    print("--- Testing SwarmCluster Task Dispatcher ---")
    var success = True

    var cluster = SwarmCluster()
    var dispatch_msg = cluster.dispatch_distributed_inference("aesir:latest", "Run inference across mesh")

    if "dispatched to node [worker-node-beta]" not in dispatch_msg:
        print("FAIL: Distributed task dispatch message mismatch:", dispatch_msg)
        success = False

    if not cluster.heartbeat_pulse():
        print("FAIL: Heartbeat pulse failed")
        success = False

    if success:
        print("SwarmCluster Task Dispatcher: PASS")
    else:
        print("SwarmCluster Task Dispatcher: FAIL")
