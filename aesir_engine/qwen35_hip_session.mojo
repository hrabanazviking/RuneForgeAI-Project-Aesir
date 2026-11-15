"""Q35-6: HIP serve session for the Qwen 3.5 hybrid (qwen35).

A ControlledTextSession over Qwen35HipExecutor (core/qwen35_hip):
weights, activations, KV and the SSM state (s + conv rings) are
DEVICE-resident across turns of one conversation. The session
mirrors Qwen35CPUSession's contract and turn bookkeeping exactly
(reset semantics, snapshot-based exact prefix reuse at committed
turn boundaries only, structured output / tool calls refused);
only the evaluation engine and the snapshot byte source differ:

- Evaluation: executor.forward_chunk. Prefill uses the BATCHED
  GEMM strategy (Q35-6 (e) measurement on the fixture: batched
  9.43 ms vs GEMV loop 63.16 ms for 64 tokens, 6.7x; the two
  strategies are bit-equal on the fixture, Q35-6 (d)).
- Sampling: HOST-side over the device logit row, through the
  CPU path's own sampler (core.sampler.sample_token_from_logits
  + core.inference.replay_rng), so serve sampling semantics --
  temperature / top_k / top_p / repetition_penalty / seed -- are
  the CPU session's by construction. min_p is honored through
  the same sampler (QS-4.2); repeat_last_n has no CPU-forward
  counterpart yet and is not claimed (QS-4.3).
- Snapshots: at each committed turn boundary the session stores
  the executor's state image (readback_state: s + conv rings in
  Qwen35State order) and KV prefix image (readback_kv_prefix).
  Restore is the executor's byte-copy writeback seam, proven
  bit-exact in Q35-6 (f) (continuation logits diff 0.0). Reuse
  rules are the CPU session's two exact verifications
  (text-extension, then token-prefix), unchanged.
- Reset: bookkeeping only, like the CPU session; the state wipe
  is owned by the executor's reset-on-position-0 rule
  (forward_chunk resets exactly when start_pos == 0). Stale KV
  rows beyond the current position are never read (attention is
  causal and every position is stored before it is read).
- Tokenizer: an AesirEngine constructed resident (Q8_0 views,
  no F16 materialization) used ONLY for tokenizer access; its
  CPU forward is never called on this path.

Admission (native_serve): qwen35 + --accel hip is admitted ONLY
under --experimental-qwen35 (the fixture/experimental route).
Real-file HIP serve (Q35-6b) goes through the same experimental
gate on this slice; native (non-experimental) HIP admission is
NOT claimed and remains refused. /health reports backend "hip",
session_residency true, exact_prefix_reuse true with the detail
"snapshot-based at committed turn boundaries only", and
weight_load_mode "q8_0_resident" (the executor requires every
large weight stored Q8_0, the Q35-3r resident contract).
"""
from std.memory import Pointer
from std.memory.alloc import alloc, Layout

from loader.packed_gguf import PackedGGUF  # direct loader import anchors the package root (Q35-1 lesson)
from core.generation_control import GenerationControl, NativeGenerationStatus, ControlledTextSession
from core.sampling_config import NativeSamplingConfig
from core.prompt_prefix import reusable_prompt_prefix
from core.qwen35_hip import Qwen35HipExecutor
from core.sampler import sample_token_from_logits
from core.inference import replay_rng
from aesir import AesirEngine


struct Qwen35HipSnapshot(Copyable, Movable):
    """Device state at one committed turn boundary: the executor
    state image (s + conv rings, Qwen35State order) and KV prefix
    image (K block then V block, device layout), plus the
    committed stream and serve-presented texts the reuse checks
    verify against."""
    var boundary: Int
    var stream: List[Int]
    var conv_text: String
    var generated_text: String
    var state_image: List[Float32]
    var kv_image: List[Float32]

    def __init__(out self, boundary: Int = 0):
        self.boundary = boundary
        self.stream = List[Int]()
        self.conv_text = String("")
        self.generated_text = String("")
        self.state_image = List[Float32]()
        self.kv_image = List[Float32]()


struct Qwen35HipSession(ControlledTextSession):
    var executor: Qwen35HipExecutor
    var engine: AesirEngine
    var context_length: Int
    var sampling: NativeSamplingConfig
    var control: GenerationControl
    var healthy: Bool
    var generating: Bool
    var position: Int
    var prompt_tokens: Int
    var generated_tokens: Int
    var reused_prompt_tokens: Int
    var max_new_tokens: Int
    var pending_token: Int
    var finish_reason: String
    var stream: List[Int]
    var cached_stream: List[Int]
    var reset_required: Bool
    var snapshots: List[Qwen35HipSnapshot]
    var snapshot_limit: Int
    var conv_text: String
    var last_generated_text: String
    var turn_generated_text: String
    var logits_buf: Pointer[Scalar[DType.float16], MutUntrackedOrigin]
    var vocab_size: Int
    # Q35-7 F-4b-2 / F-4b-1: same derived stop set and leading-
    # marker trim as the CPU session (qwen35_session.mojo).
    var stop_token_ids: List[Int]
    var trim_active: Bool
    var trim_buffer: String

    def __init__(out self, path: String, context_length: Int,
                 sampling: NativeSamplingConfig = NativeSamplingConfig()) raises:
        sampling.validate()
        self.executor = Qwen35HipExecutor(path, context_length)
        self.engine = AesirEngine(path, knowledge_capacity=1, qwen35_resident=True)
        if self.engine.parser.config.architecture != "qwen35":
            raise Error("Qwen35 HIP session requires a qwen35 model")
        self.stop_token_ids = List[Int]()
        self.stop_token_ids.append(self.engine.tokenizer.eos_token_id)
        for tid in range(len(self.engine.tokenizer.token_types)):
            if self.engine.tokenizer.token_types[tid] == 3 and tid != self.engine.tokenizer.eos_token_id:
                self.stop_token_ids.append(tid)
        self.trim_active = False
        self.trim_buffer = String("")
        self.context_length = context_length
        self.vocab_size = self.executor.profile.vocabulary_size
        self.logits_buf = alloc(Layout[Scalar[DType.float16]](count=max(1, self.vocab_size))).unsafe_leak()
        self.sampling = sampling
        self.control = GenerationControl()
        self.healthy = True
        self.generating = False
        self.position = 0
        self.prompt_tokens = 0
        self.generated_tokens = 0
        self.reused_prompt_tokens = 0
        self.max_new_tokens = 0
        self.pending_token = -1
        self.finish_reason = ""
        self.stream = List[Int]()
        self.cached_stream = List[Int]()
        self.reset_required = False
        self.snapshots = List[Qwen35HipSnapshot]()
        self.snapshot_limit = 4
        self.conv_text = String("")
        self.last_generated_text = String("")
        self.turn_generated_text = String("")

    def weight_load_mode(self) -> String:
        return String("q8_0_resident")

    def is_stop_token(self, token: Int) -> Bool:
        """Q35-7 F-4b-2: eos + GGUF CONTROL token_type entries,
        derived from the loaded model's tokenizer (mirrors the
        CPU session)."""
        for i in range(len(self.stop_token_ids)):
            if self.stop_token_ids[i] == token:
                return True
        return False

    def _present_chunk(mut self, chunk: String) -> String:
        """Q35-7 F-4b-1: drop exactly one leading role-marker
        block from the turn's generated text. The observed
        shapes are "Assistant:" at byte 0 (Q35-4b T1/long) and
        "\nAssistant:" (Q35-4b T2: one leading newline token
        before the marker); one more leading newline is
        admitted for the same block. Initial bytes are held
        while they are still a proper prefix of one of those
        shapes; the decision is made as soon as the text
        diverges or a shape completes. Anything else is
        presented verbatim."""
        if not self.trim_active:
            return chunk
        var raw = self.trim_buffer + chunk
        var shapes = List[String]()
        shapes.append(String("\n\nAssistant:"))
        shapes.append(String("\nAssistant:"))
        shapes.append(String("Assistant:"))
        for i in range(len(shapes)):
            if raw.startswith(shapes[i]):
                self.trim_active = False
                self.trim_buffer = String("")
                return String(raw[byte=shapes[i].byte_length():])
        for i in range(len(shapes)):
            if shapes[i].startswith(raw):
                self.trim_buffer = raw
                return String("")
        self.trim_active = False
        self.trim_buffer = String("")
        return raw

    def _flush_trim(mut self) -> String:
        if not self.trim_active:
            return String("")
        self.trim_active = False
        var held = self.trim_buffer
        self.trim_buffer = String("")
        return held

    def _sample(mut self, logits: List[Float32], pos: Int) -> Int:
        """Host-side sampling over one device logit row, through
        the CPU path's own sampler + replay RNG (same semantics
        as forward_pass_qwen35's output stage)."""
        for i in range(self.vocab_size):
            self.logits_buf.unsafe_store(i, Scalar[DType.float16](logits[i]))
        var rng = replay_rng(self.sampling.seed, pos)
        var suppress = List[Int]()
        return sample_token_from_logits(
            self.logits_buf, self.vocab_size,
            temperature=self.sampling.temperature,
            top_k=self.sampling.top_k,
            top_p=self.sampling.top_p,
            repetition_penalty=self.sampling.repetition_penalty,
            min_p=self.sampling.min_p,
            context_tokens=self.stream,
            rng=rng,
            suppress_tokens=suppress,
        )

    def _evaluate(mut self, start: Int, end: Int) raises -> Int:
        """Evaluate stream[start:end] on the device (batched GEMM
        prefill for all but the last token) and return the sampled
        next token after position end - 1."""
        if end - start > 1:
            var chunk = List[Int]()
            for i in range(start, end - 1):
                chunk.append(self.stream[i])
            _ = self.executor.forward_chunk(chunk, start, False, 32)
        var logits = self.executor.forward_chunk(List[Int]([self.stream[end - 1]]), end - 1, True, 1)
        return self._sample(logits, end - 1)

    def _take_snapshot(mut self) raises:
        if self.position <= 0 or self.position != len(self.stream):
            return
        var snap = Qwen35HipSnapshot(self.position)
        snap.stream = self.stream.copy()
        snap.conv_text = self.conv_text
        snap.generated_text = self.turn_generated_text
        snap.state_image = self.executor.readback_state()
        snap.kv_image = self.executor.readback_kv_prefix(self.position)
        for i in range(len(self.snapshots)):
            if self.snapshots[i].boundary == snap.boundary and len(self.snapshots[i].stream) == len(snap.stream):
                var same = True
                for t in range(len(snap.stream)):
                    if self.snapshots[i].stream[t] != snap.stream[t]:
                        same = False
                        break
                if same:
                    _ = self.snapshots.pop(i)
                    break
        self.snapshots.append(snap^)
        while len(self.snapshots) > self.snapshot_limit:
            _ = self.snapshots.pop(0)

    def _restore_at(mut self, idx: Int) raises:
        ref snap = self.snapshots[idx]
        self.executor.writeback_state(snap.state_image)
        self.executor.writeback_kv_prefix(snap.kv_image, snap.boundary)
        self.stream = snap.stream.copy()
        self.position = snap.boundary
        self.conv_text = snap.conv_text
        self.last_generated_text = snap.generated_text
        self.pending_token = -1

    def snapshot_boundaries(self) -> List[Int]:
        var out = List[Int]()
        out.append(0)
        for i in range(len(self.snapshots)):
            out.append(self.snapshots[i].boundary)
        return out^

    def restore_snapshot(mut self, boundary: Int) raises -> Bool:
        if not self.healthy or self.generating:
            raise Error("Cannot restore a snapshot on a busy or failed Qwen35 HIP session")
        if self.reset_required:
            return False
        if boundary == 0:
            self.executor.reset_state()
            self.stream = List[Int]()
            self.position = 0
            self.conv_text = String("")
            self.last_generated_text = String("")
            self.pending_token = -1
            return True
        for i in range(len(self.snapshots)):
            if self.snapshots[i].boundary == boundary:
                self._restore_at(i)
                return True
        return False

    def begin_turn(mut self, prompt: String, system: String, max_tokens: Int) raises:
        if self.reset_required:
            raise Error("Interrupted qwen35 turn requires an explicit conversation reset")
        if not self.healthy or self.generating:
            raise Error("Qwen35 HIP session is busy or unusable")
        if prompt.byte_length() == 0 or prompt.byte_length() > 65536 or system.byte_length() > 65536:
            raise Error("Chat text exceeds admission bounds")
        if max_tokens < 1 or max_tokens > self.context_length:
            raise Error("Qwen35 completion ceiling must be within 1.." + String(self.context_length))
        var start = self.position
        var text = prompt
        if start == 0 and system != "":
            text = system + "\n" + prompt
        # Snapshot-reuse path decision, identical rules to the CPU
        # session: path 0 cold/resident, path 1 text-extension
        # restore, path 2 token-prefix restore.
        var path = 0
        var snap_idx = -1
        var tokens = List[Int]()
        var effective_start = start
        if start == 0:
            var best_idx = -1
            var best_boundary = 0
            var best_delta = String("")
            for i in range(len(self.snapshots)):
                ref snap = self.snapshots[i]
                if snap.boundary <= best_boundary or snap.conv_text == "":
                    continue
                var prefix = snap.conv_text + "Assistant: " + snap.generated_text + "\n" + "User: "
                if not text.startswith(prefix):
                    continue
                if text.byte_length() <= prefix.byte_length() + 1:
                    continue
                if String(text[byte=text.byte_length() - 1:]) != "\n":
                    continue
                var delta = String(text[byte=prefix.byte_length():text.byte_length() - 1])
                if delta == "" or "\nAssistant: " in delta or "\nUser: " in delta:
                    continue
                best_idx = i
                best_boundary = snap.boundary
                best_delta = delta
            if best_idx >= 0:
                var delta_tokens = self.engine.tokenizer.encode(best_delta, False)
                if len(delta_tokens) > 0:
                    path = 1
                    snap_idx = best_idx
                    tokens = delta_tokens^
                    effective_start = best_boundary
            if path == 0:
                tokens = self.engine.tokenizer.encode(text, True)
                var best2_idx = -1
                var best2_boundary = 0
                for i in range(len(self.snapshots)):
                    if self.snapshots[i].boundary > best2_boundary and reusable_prompt_prefix(self.snapshots[i].stream, tokens) >= self.snapshots[i].boundary:
                        best2_idx = i
                        best2_boundary = self.snapshots[i].boundary
                if best2_idx >= 0:
                    path = 2
                    snap_idx = best2_idx
                    effective_start = best2_boundary
        else:
            tokens = self.engine.tokenizer.encode(text, False)
        if len(tokens) == 0:
            raise Error("Qwen35 tokenizer produced no prompt tokens")
        var final_len = effective_start + len(tokens) if path != 2 else len(tokens)
        if final_len + 2 > self.context_length:
            raise Error("Qwen35 context cannot fit prompt, response and closing token; history was not truncated")
        var reason = self.control.stop_reason()
        if reason != "":
            self.reset_required = True
            self.finish_reason = reason
            raise Error("Qwen35 prefill " + reason + "; explicit reset required")
        if path == 1:
            self._restore_at(snap_idx)
            for token in tokens:
                self.stream.append(token)
            self.conv_text = text
            self.prompt_tokens = effective_start + len(tokens)
            self.reused_prompt_tokens = effective_start
        elif path == 2:
            self._restore_at(snap_idx)
            self.stream = tokens.copy()
            self.conv_text = text
            self.prompt_tokens = len(tokens)
            self.reused_prompt_tokens = effective_start
        elif start == 0:
            self.stream = tokens.copy()
            self.conv_text = text
            self.prompt_tokens = len(tokens)
            self.reused_prompt_tokens = 0
        else:
            if self.conv_text != "":
                self.conv_text = self.conv_text + "Assistant: " + self.last_generated_text + "\n" + "User: " + prompt + "\n"
            for token in tokens:
                self.stream.append(token)
            self.prompt_tokens = len(tokens)
            self.reused_prompt_tokens = 0
        self.generated_tokens = 0
        self.max_new_tokens = max_tokens
        self.finish_reason = ""
        self.turn_generated_text = String("")
        self.trim_active = True
        self.trim_buffer = String("")
        self.control.start()
        self.pending_token = self._evaluate(effective_start, len(self.stream))
        self.position = len(self.stream)
        self.generating = True

    def reset(mut self) raises:
        if not self.healthy or self.generating:
            raise Error("Cannot reset a busy or failed Qwen35 HIP session")
        # Bookkeeping only (CPU session semantics): the device
        # state wipe is owned by the executor's position-0 rule on
        # the next conversation's first forward. The snapshot
        # store deliberately SURVIVES reset().
        self.cached_stream = self.stream.copy()
        self.stream = List[Int]()
        self.position = 0
        self.generated_tokens = 0
        self.prompt_tokens = 0
        self.reused_prompt_tokens = 0
        self.pending_token = -1
        self.finish_reason = "reset"
        self.reset_required = False
        self.turn_generated_text = String("")
        self.control.deadline_ms = 0

    def configure_sampling(mut self, sampling: NativeSamplingConfig) raises:
        if not self.healthy or self.generating:
            raise Error("Cannot configure a busy or failed Qwen35 HIP session")
        sampling.validate()
        self.sampling = sampling

    def configure_output(mut self, output_mode: String) raises:
        if not self.healthy or self.generating:
            raise Error("Cannot configure output on a busy or failed Qwen35 HIP session")
        if output_mode != "":
            raise Error("Structured output is not implemented on the Qwen35 HIP session")

    def configure_tool(mut self, name: String, description: String) raises:
        _ = description
        if not self.healthy or self.generating:
            raise Error("Cannot configure tools on a busy or failed Qwen35 HIP session")
        if name != "":
            raise Error("Tool calls are not implemented on the Qwen35 HIP session")

    def configure_control(mut self, timeout_ms: Int = 0, cancel_fd: Int = -1) raises:
        if not self.healthy or self.generating:
            raise Error("Cannot configure a busy or failed Qwen35 HIP session")
        self.control = GenerationControl(timeout_ms, cancel_fd)

    def cancel(mut self, reason: String = "cancelled") raises -> String:
        if not self.healthy:
            raise Error("Cannot recover a failed Qwen35 HIP session through cancellation")
        if reason != "cancelled" and reason != "timeout":
            raise Error("Unsupported native cancellation reason")
        if not self.generating:
            return ""
        self.pending_token = -1
        self.finish_reason = reason
        self.generating = False
        self.reset_required = True
        self.control.deadline_ms = 0
        return ""

    def next_chunk(mut self) raises -> String:
        if not self.generating:
            raise Error("No active Qwen35 HIP generation")
        var stop = self.control.stop_reason()
        if stop != "":
            return self.cancel(stop)
        var token = self.pending_token
        if self.is_stop_token(token):
            self.stream.append(token)
            _ = self.executor.forward_chunk(List[Int]([token]), self.position, True, 1)
            self.position += 1
            self.finish_reason = "eos"
            self.generating = False
            var flushed = self._flush_trim()
            self.turn_generated_text += flushed
            self.last_generated_text = self.turn_generated_text
            self._take_snapshot()
            return flushed
        var chunk = self.engine.tokenizer.decode(token)
        var presented = self._present_chunk(chunk)
        self.turn_generated_text += presented
        self.generated_tokens += 1
        self.stream.append(token)
        var limit = self.generated_tokens >= self.max_new_tokens
        var full = self.position + 2 >= self.context_length
        var logits = self.executor.forward_chunk(List[Int]([token]), self.position, True, 1)
        self.pending_token = self._sample(logits, self.position)
        self.position += 1
        if limit or full:
            self.finish_reason = "context_exhausted" if full else "length"
            self.generating = False
            var tail = self._flush_trim()
            presented += tail
            self.turn_generated_text += tail
            self.last_generated_text = self.turn_generated_text
            self._take_snapshot()
        return presented

    def status(self) -> NativeGenerationStatus:
        return NativeGenerationStatus(self.healthy, self.generating, self.prompt_tokens,
                                      self.generated_tokens, self.position, self.finish_reason,
                                      self.reused_prompt_tokens)
