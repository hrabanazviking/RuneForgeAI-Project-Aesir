# core/session.mojo
# Session Context & KV-Cache Isolation Architecture for Project Aesir


struct SessionContext(Copyable, ImplicitlyCopyable):
    """Encapsulates session state, cancellation triggers, and resource bounds."""

    var session_id: String
    var is_cancelled: Bool
    var created_timestamp: UInt64
    var last_accessed_timestamp: UInt64
    var active_tokens: Int
    var max_context: Int
    var session_kv_offset: Int

    def __init__(
        out self,
        session_id: String,
        max_context: Int = 4096,
        created_timestamp: UInt64 = 0,
    ):
        self.session_id = session_id
        self.is_cancelled = False
        self.created_timestamp = created_timestamp
        self.last_accessed_timestamp = created_timestamp
        self.active_tokens = 0
        self.max_context = max_context
        self.session_kv_offset = 0

    def __copyinit__(out self, existing: Self):
        self.session_id = existing.session_id
        self.is_cancelled = existing.is_cancelled
        self.created_timestamp = existing.created_timestamp
        self.last_accessed_timestamp = existing.last_accessed_timestamp
        self.active_tokens = existing.active_tokens
        self.max_context = existing.max_context
        self.session_kv_offset = existing.session_kv_offset

    @always_inline
    def copy(self) -> Self:
        var res = Self(self.session_id, self.max_context, self.created_timestamp)
        res.is_cancelled = self.is_cancelled
        res.last_accessed_timestamp = self.last_accessed_timestamp
        res.active_tokens = self.active_tokens
        res.session_kv_offset = self.session_kv_offset
        return res^

    def touch(mut self, current_timestamp: UInt64):
        """Updates the session's last_accessed_timestamp."""
        self.last_accessed_timestamp = current_timestamp

    def is_expired(self, current_timestamp: UInt64, ttl_seconds: UInt64) -> Bool:
        """Returns True if current_timestamp exceeds last_accessed_timestamp by ttl_seconds."""
        if ttl_seconds == 0 or current_timestamp <= self.last_accessed_timestamp:
            return False
        return (current_timestamp - self.last_accessed_timestamp) > ttl_seconds

    def cancel(mut self):
        """Triggers cooperative cancellation for this session."""
        self.is_cancelled = True

    def validate(self) raises:
        """Validates session parameters."""
        if self.session_id == "":
            raise Error("SessionContext session_id cannot be empty")
        if self.max_context <= 0:
            raise Error("SessionContext max_context must be a positive integer")


struct SessionManager(Copyable):
    """Manages active session limits, registry lookup, and cache isolation bounds."""

    var max_concurrent_sessions: Int
    var active_session_count: Int
    var sessions: List[SessionContext]

    def __init__(out self, max_concurrent_sessions: Int = 16):
        self.max_concurrent_sessions = max_concurrent_sessions
        self.active_session_count = 0
        self.sessions = List[SessionContext]()

    def __copyinit__(out self, existing: Self):
        self.max_concurrent_sessions = existing.max_concurrent_sessions
        self.active_session_count = existing.active_session_count
        self.sessions = existing.sessions.copy()

    @always_inline
    def copy(self) -> Self:
        var res = Self(self.max_concurrent_sessions)
        res.active_session_count = self.active_session_count
        res.sessions = self.sessions.copy()
        return res^

    def register_session(mut self, session: SessionContext) raises:
        """Registers a new session ensuring concurrency limits and uniqueness are respected."""
        session.validate()
        for i in range(len(self.sessions)):
            if self.sessions[i].session_id == session.session_id:
                raise Error("SessionManager duplicate session_id: " + session.session_id)

        if len(self.sessions) >= self.max_concurrent_sessions:
            raise Error("SessionManager limit exceeded: cannot register session " + session.session_id)

        self.sessions.append(session)
        self.active_session_count = len(self.sessions)

    def get_session(self, session_id: String) raises -> SessionContext:
        """Retrieves a registered session by session_id."""
        for i in range(len(self.sessions)):
            if self.sessions[i].session_id == session_id:
                return self.sessions[i]
        raise Error("SessionManager session not found: " + session_id)

    def release_session(mut self, session: SessionContext) raises:
        """Releases session resources by session_id."""
        session.validate()
        var found = False
        var updated = List[SessionContext]()
        for i in range(len(self.sessions)):
            if self.sessions[i].session_id == session.session_id:
                found = True
            else:
                updated.append(self.sessions[i])

        if not found:
            raise Error("SessionManager cannot release unregistered session_id: " + session.session_id)

        self.sessions = updated.copy()
        self.active_session_count = len(self.sessions)

    def evict_expired_sessions(mut self, current_timestamp: UInt64, ttl_seconds: UInt64) -> Int:
        """Evicts all active sessions that have exceeded ttl_seconds."""
        var active = List[SessionContext]()
        var evicted_count = 0
        for i in range(len(self.sessions)):
            if self.sessions[i].is_expired(current_timestamp, ttl_seconds):
                evicted_count += 1
            else:
                active.append(self.sessions[i])
        self.sessions = active.copy()
        self.active_session_count = len(self.sessions)
        return evicted_count
