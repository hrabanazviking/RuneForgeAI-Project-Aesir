# Original program-object lifecycle owner (AES-PROG-001 interface).
# Composes the qualified program/configure codecs over the Campaign 2
# grouped transfer primitive. Two fail-closed laws from the 3.1 spec:
# the program-bytes phase has NO established transport mechanics, so
# configure refuses until the caller attests delivery of exactly the
# identity's encoded-program digest; and teardown order is enforced
# conservatively client-side (shutdown -> destroy-configured ->
# destroy-infer) because the receiver's ordering is NOT ESTABLISHED.
from hailbru.errors import herror
from hailbru.soc_transfer import SocGroupedTransfer
from hailbru.hrpc_frame import HrpcFrame, encode_hrpc_frame, decode_hrpc_frame
from hailbru.hrpc_program import (
    HRPC_PROGRAM_CREATE, HRPC_PROGRAM_DESTROY, HRPC_CONFIGURED_DESTROY,
    HRPC_CONFIGURED_ACTIVATE, HRPC_CONFIGURED_DEACTIVATE,
    HRPC_CONFIGURED_SHUTDOWN, program_create_request,
    program_create_reply, program_handle_request, program_empty_reply,
)
from hailbru.hrpc_configure import (
    HrpcConfigureParams, HrpcInferStream, configure_request,
    configure_reply,
)

comptime PROG_STAGE_EMPTY = 0
comptime PROG_STAGE_CREATED = 1
comptime PROG_STAGE_CONFIGURED = 2
comptime PROG_STAGE_ACTIVE = 3


struct ProgramIdentity(Copyable, Movable):
    var source_digest: String
    var compiler_version: String
    var target_profile_digest: String
    var numerical_plan_digest: String
    var placement_digest: String
    var encoded_program_digest: String
    var transport_metadata_digest: String

    def __init__(out self, source_digest: String, compiler_version: String,
                 target_profile_digest: String, numerical_plan_digest: String,
                 placement_digest: String, encoded_program_digest: String,
                 transport_metadata_digest: String):
        self.source_digest = source_digest
        self.compiler_version = compiler_version
        self.target_profile_digest = target_profile_digest
        self.numerical_plan_digest = numerical_plan_digest
        self.placement_digest = placement_digest
        self.encoded_program_digest = encoded_program_digest
        self.transport_metadata_digest = transport_metadata_digest

    def describe(self) -> String:
        return "program-identity{source=" + self.source_digest + ",compiler=" + self.compiler_version + ",target-profile=" + self.target_profile_digest + ",numerical-plan=" + self.numerical_plan_digest + ",placement=" + self.placement_digest + ",encoded-program=" + self.encoded_program_digest + ",transport-metadata=" + self.transport_metadata_digest + "}"


struct SocProgram(Movable):
    var identity: ProgramIdentity
    var stage: Int
    var infer_handle: UInt32
    var infer_known: Bool
    var configured_handle: UInt32
    var configured_known: Bool
    var queue_size: UInt32
    var vdevice_handle: UInt32
    var payload_attested: Bool
    var shutdown_done: Bool
    var next_message_id: UInt32
    var stages_completed: Int
    var poisoned: Bool

    def __init__(out self, var identity: ProgramIdentity):
        self.identity = identity^
        self.stage = PROG_STAGE_EMPTY
        self.infer_handle = 0
        self.infer_known = False
        self.configured_handle = 0
        self.configured_known = False
        self.queue_size = 0
        self.vdevice_handle = 0
        self.payload_attested = False
        self.shutdown_done = False
        self.next_message_id = 0
        self.stages_completed = 0
        self.poisoned = False

    def _exchange(mut self, mut transfer: SocGroupedTransfer, frame: HrpcFrame, timeout_ms: Int64) raises -> HrpcFrame:
        # Consumer layer (AES-TRANSFER-003): a framing failure poisons
        # the owner (and the transport) before any state advances.
        try:
            var packet = encode_hrpc_frame(frame)
            if transfer.poisoned:
                raise herror("SocTransferState", "transport already poisoned")
            var received = transfer.exchange_raw(packet, timeout_ms)
            return decode_hrpc_frame(received, True)
        except e:
            self.poisoned = True
            transfer.poisoned = True
            raise e^

    def create(mut self, mut transfer: SocGroupedTransfer, vdevice_handle: UInt32,
               name: String, program_bytes: UInt64, host_program_limit: UInt64,
               timeout_ms: Int64) raises:
        if self.poisoned or self.stage != PROG_STAGE_EMPTY:
            raise herror("SocProgramState", "create requires a fresh unpoisoned program owner")
        var mid = self.next_message_id
        var frame = program_create_request(mid, vdevice_handle, program_bytes, name, host_program_limit)
        var reply = self._exchange(transfer, frame, timeout_ms)
        try:
            self.infer_handle = program_create_reply(reply, mid)
        except e:
            self.poisoned = True
            transfer.poisoned = True
            raise e^
        self.infer_known = True
        self.vdevice_handle = vdevice_handle
        self.next_message_id += 1
        self.stage = PROG_STAGE_CREATED
        self.stages_completed += 1

    def attest_payload_delivered(mut self, encoded_program_digest: String) raises:
        # The payload phase's transport mechanics are NOT ESTABLISHED
        # (AES-PROG-001 Q2). This owner never moves program bytes and
        # never fabricates delivery: the caller must attest delivery
        # of exactly the identity's encoded program, by digest.
        if self.poisoned or self.stage != PROG_STAGE_CREATED:
            raise herror("SocProgramState", "payload attestation requires the created stage")
        if encoded_program_digest != self.identity.encoded_program_digest:
            raise herror("SocProgramState", "attested digest differs from the program identity")
        self.payload_attested = True

    def configure(mut self, mut transfer: SocGroupedTransfer,
                  var inputs: List[HrpcInferStream], var outputs: List[HrpcInferStream],
                  batch_size: UInt32, power_mode: UInt32, latency_flags: UInt32,
                  enable_kv_cache: Bool, timeout_ms: Int64) raises:
        if self.poisoned or self.stage != PROG_STAGE_CREATED:
            raise herror("SocProgramState", "configure requires the created stage")
        if not self.payload_attested:
            raise herror("SocProgramState", "configure refused: program-bytes delivery not attested (phase mechanics not established)")
        var mid = self.next_message_id
        var params = HrpcConfigureParams(self.infer_handle, self.vdevice_handle,
                                         inputs^, outputs^, batch_size,
                                         power_mode, latency_flags,
                                         enable_kv_cache)
        var frame = configure_request(mid, params^)
        var reply = self._exchange(transfer, frame, timeout_ms)
        try:
            var parsed = configure_reply(reply, mid)
            if parsed.handle == UInt32(4294967295):
                raise herror("BadConfigureRpc", "invalid configured handle sentinel")
            self.configured_handle = parsed.handle
            self.queue_size = parsed.async_queue_size
        except e:
            self.poisoned = True
            transfer.poisoned = True
            raise e^
        self.configured_known = True
        self.next_message_id += 1
        self.stage = PROG_STAGE_CONFIGURED
        self.stages_completed += 1

    def _handle_stage(mut self, mut transfer: SocGroupedTransfer, action: UInt32,
                      timeout_ms: Int64) raises:
        var mid = self.next_message_id
        var frame = program_handle_request(mid, action, self.configured_handle)
        var reply = self._exchange(transfer, frame, timeout_ms)
        try:
            program_empty_reply(reply, mid, action)
        except e:
            self.poisoned = True
            transfer.poisoned = True
            raise e^
        self.next_message_id += 1
        self.stages_completed += 1

    def activate(mut self, mut transfer: SocGroupedTransfer, timeout_ms: Int64) raises:
        if self.poisoned or self.stage != PROG_STAGE_CONFIGURED or self.shutdown_done:
            raise herror("SocProgramState", "activate requires a live configured stage")
        self._handle_stage(transfer, HRPC_CONFIGURED_ACTIVATE, timeout_ms)
        self.stage = PROG_STAGE_ACTIVE

    def deactivate(mut self, mut transfer: SocGroupedTransfer, timeout_ms: Int64) raises:
        if self.poisoned or self.stage != PROG_STAGE_ACTIVE:
            raise herror("SocProgramState", "deactivate requires the active stage")
        self._handle_stage(transfer, HRPC_CONFIGURED_DEACTIVATE, timeout_ms)
        self.stage = PROG_STAGE_CONFIGURED

    def shutdown(mut self, mut transfer: SocGroupedTransfer, timeout_ms: Int64) raises:
        if self.poisoned or self.stage != PROG_STAGE_CONFIGURED or self.shutdown_done:
            raise herror("SocProgramState", "shutdown requires a live configured stage (deactivate first)")
        self._handle_stage(transfer, HRPC_CONFIGURED_SHUTDOWN, timeout_ms)
        self.shutdown_done = True

    def destroy_configured(mut self, mut transfer: SocGroupedTransfer, timeout_ms: Int64) raises:
        # Conservative client-side order (AES-PROG-001 Q6): the
        # receiver's own ordering is NOT ESTABLISHED, so this owner
        # requires shutdown before destroy-configured.
        if self.poisoned or self.stage != PROG_STAGE_CONFIGURED or not self.configured_known:
            raise herror("SocProgramState", "destroy-configured requires the configured stage")
        if not self.shutdown_done:
            raise herror("SocProgramState", "destroy-configured refused before shutdown (teardown order not established receiver-side)")
        self._handle_stage(transfer, HRPC_CONFIGURED_DESTROY, timeout_ms)
        self.configured_known = False
        self.configured_handle = 0
        self.queue_size = 0
        self.stage = PROG_STAGE_CREATED

    def destroy_infer(mut self, mut transfer: SocGroupedTransfer, timeout_ms: Int64) raises:
        if self.poisoned or self.stage != PROG_STAGE_CREATED or not self.infer_known:
            raise herror("SocProgramState", "destroy-infer requires the created stage with no configured object")
        var mid = self.next_message_id
        var frame = program_handle_request(mid, HRPC_PROGRAM_DESTROY, self.infer_handle)
        var reply = self._exchange(transfer, frame, timeout_ms)
        try:
            program_empty_reply(reply, mid, HRPC_PROGRAM_DESTROY)
        except e:
            self.poisoned = True
            transfer.poisoned = True
            raise e^
        self.next_message_id += 1
        self.stages_completed += 1
        self.infer_known = False
        self.infer_handle = 0
        self.payload_attested = False
        self.stage = PROG_STAGE_EMPTY
