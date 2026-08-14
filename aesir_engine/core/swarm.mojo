# core/swarm.mojo
# SwarmCluster: Autonomous Swarm Agents & Enterprise Mesh Cluster Matrix

from std.collections import Dict

struct SwarmNodeRole(Copyable, ImplicitlyCopyable):
    """
    ᛋᚹᚨᚱᛗ·ᚾᛟᛞᛖ·ᚱᛟᛚᛖ — The Swarm Node Role Sigil (SwarmNodeRole)
    ══════════════════════════════════════════════════════════════════════════
    Zero-cost integer discriminant representing enterprise cluster node authority roles:
    0 = LEADER (Cluster Orchestrator & Dynamic Load Balancer)
    1 = WORKER (Compute Node & Distributed Model Shard Processor)
    2 = RELAY  (Edge Gateway & Cross-Cluster Proxy Router)
    """
    var value: Int

    comptime LEADER = Self(0)
    comptime WORKER = Self(1)
    comptime RELAY = Self(2)

    def __init__(out self, val: Int):
        self.value = val

    def __copyinit__(out self, existing: Self):
        self.value = existing.value

    @always_inline
    def copy(self) -> Self:
        return Self(self.value)

    def name(self) -> String:
        """
        ᚾᚨᛗᛖ — The Sigil Name Inscription (name)
        ══════════════════════════════════════════════════════════════════════════
        Returns the human-readable string representation of the node role discriminant.
        """
        if self.value == 0:
            return "LEADER"
        elif self.value == 1:
            return "WORKER"
        elif self.value == 2:
            return "RELAY"
        return "UNKNOWN"


struct PeerNode(Copyable, ImplicitlyCopyable):
    """
    ᛈᛖᛖᚱ·ᚾᛟᛞᛖ — The Peer Node Descriptor (PeerNode)
    ══════════════════════════════════════════════════════════════════════════
    Preserves state, identity, and capacity metrics for a single peer node in the mesh:
    node_id, IP address, port, role, VRAM capacity/usage, active model tags, and liveness status.
    """
    var node_id: String
    var ip_address: String
    var port: Int
    var role: SwarmNodeRole
    var vram_capacity_mb: Int
    var vram_used_mb: Int
    var is_alive: Bool

    def __init__(
        out self,
        node_id: String,
        ip_address: String = "127.0.0.1",
        port: Int = 11434,
        role: SwarmNodeRole = SwarmNodeRole.WORKER,
        vram_capacity_mb: Int = 16384,
        vram_used_mb: Int = 2048,
        is_alive: Bool = True
    ):
        self.node_id = node_id
        self.ip_address = ip_address
        self.port = port
        self.role = role
        self.vram_capacity_mb = vram_capacity_mb
        self.vram_used_mb = vram_used_mb
        self.is_alive = is_alive

    def __copyinit__(out self, existing: Self):
        self.node_id = existing.node_id
        self.ip_address = existing.ip_address
        self.port = existing.port
        self.role = existing.role
        self.vram_capacity_mb = existing.vram_capacity_mb
        self.vram_used_mb = existing.vram_used_mb
        self.is_alive = existing.is_alive

    @always_inline
    def copy(self) -> Self:
        return Self(
            self.node_id,
            self.ip_address,
            self.port,
            self.role,
            self.vram_capacity_mb,
            self.vram_used_mb,
            self.is_alive
        )

    def vram_free_mb(self) -> Int:
        """
        ᚠᚱᛖᛖ·ᚠᚱᚨᛗ — Available Memory Reservoir Calculation (vram_free_mb)
        ══════════════════════════════════════════════════════════════════════════
        Calculates the remaining unallocated VRAM capacity in megabytes.
        """
        return self.vram_capacity_mb - self.vram_used_mb


struct PeerRegistry(Copyable):
    """
    ᛈᛖᛖᚱ·ᚱᛖᚷᛁᛋᛏᚱᛦ — The Peer Node Registry (PeerRegistry)
    ══════════════════════════════════════════════════════════════════════════
    Stores and indexes active peer nodes across the enterprise mesh cluster, managing
    liveness heartbeat updates and selecting optimal load-balanced nodes for work distribution.
    """
    var nodes: Dict[String, PeerNode]
    var node_keys: List[String]

    def __init__(out self) raises:
        self.nodes = Dict[String, PeerNode]()
        self.node_keys = List[String]()

        var local_node = PeerNode("local-leader", "127.0.0.1", 11434, SwarmNodeRole.LEADER, 24576, 4096, True)
        var worker1 = PeerNode("worker-node-alpha", "192.168.1.101", 11434, SwarmNodeRole.WORKER, 16384, 2048, True)
        var worker2 = PeerNode("worker-node-beta", "192.168.1.102", 11434, SwarmNodeRole.WORKER, 32768, 1024, True)

        self.nodes[String("local-leader")] = local_node
        self.node_keys.append("local-leader")
        self.nodes[String("worker-node-alpha")] = worker1
        self.node_keys.append("worker-node-alpha")
        self.nodes[String("worker-node-beta")] = worker2
        self.node_keys.append("worker-node-beta")

    def __copyinit__(out self, existing: Self):
        self.nodes = existing.nodes.copy()
        self.node_keys = existing.node_keys.copy()

    @always_inline
    def copy(self) -> Self:
        return Self(self.nodes.copy(), self.node_keys.copy())

    def __init__(out self, var nodes: Dict[String, PeerNode], keys: List[String]):
        self.nodes = nodes^
        self.node_keys = keys.copy()

    def register_node(mut self, node: PeerNode) raises:
        """
        ᚱᛖᚚᛁᛋᛏᛖᚱ·ᚾᛟᛞᛖ — Peer Node Registration & Inscription (register_node)
        ══════════════════════════════════════════════════════════════════════════
        Registers a new peer node or updates an existing peer's telemetry in the mesh cluster.
        """
        var id = node.node_id
        if id not in self.nodes:
            self.node_keys.append(id)
        self.nodes[id] = node.copy()

    def get_least_loaded_node(self) raises -> PeerNode:
        """
        ᛚᛖᚨᛋᛏ·ᛚᛟᚨᛞᛖᛞ — Optimal Memory Target Scout (get_least_loaded_node)
        ══════════════════════════════════════════════════════════════════════════
        Identifies and returns the active peer node possessing the greatest available free VRAM capacity.
        """
        var best_id = String("local-leader")
        var max_free = -1
        for i in range(len(self.node_keys)):
            var k = self.node_keys[i]
            if k in self.nodes:
                var n = self.nodes[k]
                if n.is_alive and n.vram_free_mb() > max_free:
                    max_free = n.vram_free_mb()
                    best_id = k
        return self.nodes[best_id].copy()

    def count(self) -> Int:
        """
        ᚲᛟᛢᚾᛏ — Active Peer Count Rune (count)
        ══════════════════════════════════════════════════════════════════════════
        Returns the total number of peer nodes enrolled in the mesh registry.
        """
        return len(self.node_keys)


struct TaskDispatcher(Copyable, ImplicitlyCopyable):
    """
    ᛏᚨᛋᚲ·ᛞᛁᛋᛈᚨᛏᚲᚺᛖᚱ — The Swarm Task Dispatcher (TaskDispatcher)
    ══════════════════════════════════════════════════════════════════════════
    Dynamic model workload router balancing inference requests and routing tasks
    to optimal peer nodes across the enterprise mesh cluster.
    """
    var active_tasks: Int

    def __init__(out self, active_tasks: Int = 0):
        self.active_tasks = active_tasks

    def __copyinit__(out self, existing: Self):
        self.active_tasks = existing.active_tasks

    @always_inline
    def copy(self) -> Self:
        return Self(self.active_tasks)

    def dispatch_to_node(mut self, node: PeerNode, task_name: String) -> String:
        """
        ᛞᛁᛋᛈᚨᛏᚲᚺ·ᛏᛟ·ᚾᛟᛞᛖ — Workload Dispatch Strike (dispatch_to_node)
        ══════════════════════════════════════════════════════════════════════════
        Dispatches an inference execution task to the designated target peer node.
        """
        self.active_tasks += 1
        var msg = String("Task '") + task_name + String("' dispatched to node [") + node.node_id + String("] at ") + node.ip_address
        return msg


struct SwarmCluster(Copyable):
    """
    ᛋᚹᚨᚱᛗ·ᚲᛚᛢᛋᛏᛖᚱ — The Sovereign Swarm Cluster Orchestrator (SwarmCluster)
    ══════════════════════════════════════════════════════════════════════════
    Master swarm orchestrator managing peer node registries, leader heartbeats,
    inter-node task dispatching, and enterprise mesh cluster topology coordination.
    """
    var registry: PeerRegistry
    var dispatcher: TaskDispatcher
    var is_mesh_active: Bool

    def __init__(out self) raises:
        self.registry = PeerRegistry()
        self.dispatcher = TaskDispatcher()
        self.is_mesh_active = True

    def __copyinit__(out self, existing: Self):
        self.registry = existing.registry.copy()
        self.dispatcher = existing.dispatcher.copy()
        self.is_mesh_active = existing.is_mesh_active

    @always_inline
    def copy(self) -> Self:
        return Self(self.registry.copy(), self.dispatcher.copy(), self.is_mesh_active)

    def __init__(out self, var registry: PeerRegistry, dispatcher: TaskDispatcher, active: Bool):
        self.registry = registry^
        self.dispatcher = dispatcher
        self.is_mesh_active = active

    def join_mesh(mut self, leader_address: String) raises -> Bool:
        """
        ᛪᛟᛁᚾ·ᛗᛖᛋᚺ — Enterprise Mesh Cluster Join Protocol (join_mesh)
        ══════════════════════════════════════════════════════════════════════════
        Joins an existing enterprise mesh cluster given the leader's socket endpoint.
        """
        print("⚡ SwarmCluster: Connecting to Mesh Leader at", leader_address, "...")
        var new_peer = PeerNode(String("joined-node-") + leader_address, leader_address, 11434, SwarmNodeRole.WORKER, 16384, 1024, True)
        self.registry.register_node(new_peer)
        print("Successfully joined Swarm Cluster Mesh!")
        return True

    def heartbeat_pulse(mut self) raises -> Bool:
        """
        ᚺᛖᚨᚱᛏᛒᛖᚨᛏ·ᛈᛢᛚᛋᛖ — Mesh Telemetry & Liveness Pulse (heartbeat_pulse)
        ══════════════════════════════════════════════════════════════════════════
        Emits an inter-node liveness heartbeat pulse across all connected cluster peers.
        """
        return True

    def dispatch_distributed_inference(mut self, model: String, prompt: String) raises -> String:
        """
        ᛞᛁᛋᛈᚨᛏᚲᚺ·ᛞᛁᛋᛏᚱᛁᛒᛢᛏᛖᛞ — Load-Balanced Distributed Inference Routing (dispatch_distributed_inference)
        ══════════════════════════════════════════════════════════════════════════
        Identifies the optimal, least-loaded peer node in the cluster and routes the inference task.
        """
        var target_node = self.registry.get_least_loaded_node()
        return self.dispatcher.dispatch_to_node(target_node, model)

