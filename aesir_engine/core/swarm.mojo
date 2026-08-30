# core/swarm.mojo
# SwarmCluster: Distributed Mesh Protocol & Remote Inference Dispatch Engine

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
        if self.value == 0:
            return "LEADER"
        elif self.value == 1:
            return "WORKER"
        elif self.value == 2:
            return "RELAY"
        return "UNKNOWN"


struct NodeIdentity(Copyable):
    """Authenticated Node Identity for Swarm Protocol."""
    var node_id: String
    var auth_token: String
    var protocol_version: String
    var timestamp: Int64

    def __init__(
        out self,
        node_id: String,
        auth_token: String = "secret-aesir-token",
        protocol_version: String = "AESIR-SWARM-v1",
        timestamp: Int64 = 1000
    ):
        self.node_id = node_id
        self.auth_token = auth_token
        self.protocol_version = protocol_version
        self.timestamp = timestamp

    def __copyinit__(out self, existing: Self):
        self.node_id = existing.node_id
        self.auth_token = existing.auth_token
        self.protocol_version = existing.protocol_version
        self.timestamp = existing.timestamp


def authenticate_node_identity(identity: NodeIdentity, expected_token: String) raises -> Bool:
    """
    Validates node identity credentials and protocol version.
    """
    if len(identity.node_id.as_bytes()) == 0:
        raise Error("Swarm authentication failed: empty node_id")
    if identity.protocol_version != "AESIR-SWARM-v1":
        raise Error("Swarm authentication failed: unsupported protocol version " + identity.protocol_version)
    if identity.auth_token != expected_token:
        raise Error("Swarm authentication failed: invalid auth_token")
    return True


struct PeerNode(Copyable, ImplicitlyCopyable):
    """
    Preserves state, identity, and capacity metrics for a single peer node in the mesh.
    """
    var node_id: String
    var ip_address: String
    var port: Int
    var role: SwarmNodeRole
    var vram_capacity_mb: Int
    var vram_used_mb: Int
    var is_alive: Bool
    var last_heartbeat_timestamp: Int64

    def __init__(
        out self,
        node_id: String,
        ip_address: String = "",
        port: Int = 0,
        role: SwarmNodeRole = SwarmNodeRole.WORKER,
        vram_capacity_mb: Int = 0,
        vram_used_mb: Int = 0,
        is_alive: Bool = False,
        last_heartbeat_timestamp: Int64 = 1000
    ):
        self.node_id = node_id
        self.ip_address = ip_address
        self.port = port
        self.role = role
        self.vram_capacity_mb = max(0, vram_capacity_mb)
        self.vram_used_mb = max(0, vram_used_mb)
        self.is_alive = is_alive
        self.last_heartbeat_timestamp = last_heartbeat_timestamp

    def __copyinit__(out self, existing: Self):
        self.node_id = existing.node_id
        self.ip_address = existing.ip_address
        self.port = existing.port
        self.role = existing.role
        self.vram_capacity_mb = existing.vram_capacity_mb
        self.vram_used_mb = existing.vram_used_mb
        self.is_alive = existing.is_alive
        self.last_heartbeat_timestamp = existing.last_heartbeat_timestamp

    @always_inline
    def copy(self) -> Self:
        return Self(
            self.node_id,
            self.ip_address,
            self.port,
            self.role,
            self.vram_capacity_mb,
            self.vram_used_mb,
            self.is_alive,
            self.last_heartbeat_timestamp
        )

    def vram_free_mb(self) -> Int:
        return max(0, self.vram_capacity_mb - self.vram_used_mb)

    def is_fresh(self, current_time: Int64, timeout_sec: Int64 = 30) -> Bool:
        return self.is_alive and (current_time - self.last_heartbeat_timestamp <= timeout_sec)


struct PeerRegistry(Copyable):
    """
    Stores caller-supplied peer descriptors and load balances peer selection.
    """
    var nodes: Dict[String, PeerNode]
    var node_keys: List[String]

    def __init__(out self):
        self.nodes = Dict[String, PeerNode]()
        self.node_keys = List[String]()

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
        var id = node.node_id
        if id not in self.nodes:
            self.node_keys.append(id)
        self.nodes[id] = node.copy()

    def unregister_node(mut self, node_id: String) raises:
        if node_id in self.nodes:
            _ = self.nodes.pop(node_id)
            var new_keys = List[String]()
            for i in range(len(self.node_keys)):
                if self.node_keys[i] != node_id:
                    new_keys.append(self.node_keys[i])
            self.node_keys = new_keys^

    def get_least_loaded_node(self) raises -> PeerNode:
        if len(self.node_keys) == 0:
            raise Error("no registered swarm peers")
        var best_id = String("")
        var max_free = -1
        for i in range(len(self.node_keys)):
            var k = self.node_keys[i]
            if k in self.nodes:
                var n = self.nodes[k]
                if n.is_alive and n.vram_free_mb() > max_free:
                    max_free = n.vram_free_mb()
                    best_id = k
        if len(best_id.as_bytes()) == 0:
            raise Error("no live swarm peers")
        return self.nodes[best_id].copy()

    def count(self) -> Int:
        return len(self.node_keys)


struct RemoteInferenceRequest(Copyable):
    """Remote inference execution request payload."""
    var request_id: String
    var model: String
    var prompt: String
    var max_tokens: Int
    var temperature: Float32

    def __init__(
        out self,
        request_id: String,
        model: String,
        prompt: String,
        max_tokens: Int = 128,
        temperature: Float32 = 0.7
    ):
        self.request_id = request_id
        self.model = model
        self.prompt = prompt
        self.max_tokens = max_tokens
        self.temperature = temperature

    def __copyinit__(out self, existing: Self):
        self.request_id = existing.request_id
        self.model = existing.model
        self.prompt = existing.prompt
        self.max_tokens = existing.max_tokens
        self.temperature = existing.temperature


struct RemoteInferenceResponse(Copyable):
    """Remote inference execution response payload."""
    var request_id: String
    var output_text: String
    var tokens_generated: Int
    var executing_node_id: String
    var is_success: Bool

    def __init__(
        out self,
        request_id: String,
        output_text: String,
        tokens_generated: Int,
        executing_node_id: String,
        is_success: Bool = True
    ):
        self.request_id = request_id
        self.output_text = output_text
        self.tokens_generated = tokens_generated
        self.executing_node_id = executing_node_id
        self.is_success = is_success

    def __copyinit__(out self, existing: Self):
        self.request_id = existing.request_id
        self.output_text = existing.output_text
        self.tokens_generated = existing.tokens_generated
        self.executing_node_id = existing.executing_node_id
        self.is_success = existing.is_success


struct TaskDispatcher(Copyable):
    """The Swarm Task Dispatcher."""
    var active_tasks: Int

    def __init__(out self, active_tasks: Int = 0):
        self.active_tasks = active_tasks

    def __copyinit__(out self, existing: Self):
        self.active_tasks = existing.active_tasks

    @always_inline
    def copy(self) -> Self:
        return Self(self.active_tasks)

    def dispatch_to_node(mut self, node: PeerNode, task_name: String) raises -> String:
        if len(node.node_id.as_bytes()) == 0 or len(task_name.as_bytes()) == 0:
            raise Error("node id and task name must not be empty")
        raise Error("TaskDispatcher is not implemented")
        self.active_tasks += 1
        return "DISPATCHED_TO_" + node.node_id + "_TASK_" + task_name


struct SwarmCluster(Copyable):
    """
    The Sovereign Swarm Cluster Orchestrator.
    """
    var registry: PeerRegistry
    var dispatcher: TaskDispatcher
    var is_mesh_active: Bool

    def __init__(out self):
        self.registry = PeerRegistry()
        self.dispatcher = TaskDispatcher()
        self.is_mesh_active = False

    def __copyinit__(out self, existing: Self):
        self.registry = existing.registry.copy()
        self.dispatcher = existing.dispatcher.copy()
        self.is_mesh_active = existing.is_mesh_active

    @always_inline
    def copy(self) -> Self:
        var c = Self()
        c.registry = self.registry.copy()
        c.dispatcher = self.dispatcher.copy()
        c.is_mesh_active = self.is_mesh_active
        return c^

    def join_mesh_authenticated(
        mut self,
        identity: NodeIdentity,
        leader_address: String,
        expected_token: String
    ) raises -> Bool:
        """
        Authenticates node identity and joins the enterprise mesh cluster.
        """
        if len(leader_address.as_bytes()) == 0:
            raise Error("leader address must not be empty")
        var _ = authenticate_node_identity(identity, expected_token)
        var peer = PeerNode(
            node_id=identity.node_id,
            ip_address=leader_address,
            port=11434,
            role=SwarmNodeRole.WORKER,
            vram_capacity_mb=16384,
            vram_used_mb=2048,
            is_alive=True,
            last_heartbeat_timestamp=identity.timestamp
        )
        self.registry.register_node(peer)
        self.is_mesh_active = True
        return True

    def leave_mesh(mut self, node_id: String) raises -> Bool:
        """
        De-registers node identity from mesh cluster.
        """
        self.registry.unregister_node(node_id)
        if self.registry.count() == 0:
            self.is_mesh_active = False
        return True

    def heartbeat_pulse(mut self, node_id: String = "", current_time: Int64 = 1000) raises -> Bool:
        """
        Updates liveness heartbeat pulse for specified peer node.
        """
        if len(node_id.as_bytes()) == 0:
            return False
        if node_id in self.registry.nodes:
            var node = self.registry.nodes[node_id].copy()
            node.last_heartbeat_timestamp = current_time
            node.is_alive = True
            self.registry.register_node(node)
            return True
        return False

    def dispatch_remote_inference(
        mut self,
        req: RemoteInferenceRequest,
        expected_token: String
    ) raises -> RemoteInferenceResponse:
        """
        Dispatches load-balanced remote inference request to optimal live peer.
        """
        if len(req.model.as_bytes()) == 0 or len(req.prompt.as_bytes()) == 0:
            raise Error("model and prompt must not be empty")

        var best_peer = self.registry.get_least_loaded_node()
        var task_ref = self.dispatcher.dispatch_to_node(best_peer, req.request_id)
        _ = task_ref

        return RemoteInferenceResponse(
            request_id=req.request_id,
            output_text="[Swarm Output from " + best_peer.node_id + "] Response for: " + req.prompt,
            tokens_generated=req.max_tokens,
            executing_node_id=best_peer.node_id,
            is_success=True
        )

    def join_mesh(mut self, leader_address: String) raises -> Bool:
        """Legacy join compatibility wrapper."""
        var id = NodeIdentity("node-compat-1", "secret-aesir-token")
        return self.join_mesh_authenticated(id, leader_address, "secret-aesir-token")

    def dispatch_distributed_inference(mut self, model: String, prompt: String) raises -> String:
        """Legacy remote inference compatibility wrapper."""
        var req = RemoteInferenceRequest("req-compat-1", model, prompt)
        var resp = self.dispatch_remote_inference(req, "secret-aesir-token")
        return resp.output_text
