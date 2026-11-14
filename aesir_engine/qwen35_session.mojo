"""Q35-4a + Q35-5: CPU serve session for the Qwen 3.5 hybrid (qwen35).

A ControlledTextSession over the engine-core path (AesirEngine +
forward_pass_qwen35 / forward_pass_qwen35_batched, Q35-3a). The
engine owns a PERSISTENT Qwen35State (SSM recurrence + conv rings)
plus the full-attention layers' KV in this session's KVCache; both
survive across turns of one conversation.

Reset semantics (the serve calls reset() before every NON-resident
request; resident continuations skip reset entirely):
- reset() ends the conversation bookkeeping: position returns to 0,
  the committed token stream is snapshotted into cached_stream
  (kept for inspection), and a fresh KVCache is drawn for the
  full-attention layers. The Q35-5 snapshot store SURVIVES reset()
  -- that is its purpose (see below).
- reset() deliberately does NOT wipe engine.qwen35_state. The wipe
  is owned by the engine's reset-on-position-0 rule
  (core/inference.mojo: both qwen35 forwards call state.reset()
  exactly when start_pos == 0), so the first forward of the next
  conversation starts from a zeroed SSM state, and a resident
  continuation -- which never passes through reset() and never
  restarts at position 0 -- keeps the state bit-exact (Q35-3a d1/d2).
  A genuinely new conversation is therefore: reset() + begin_turn
  at position 0. There is no mid-conversation state wipe.

Q35-5 snapshot reuse (exact-prefix reuse, snapshot-based ONLY):
- At each committed turn boundary (generation finished; position ==
  len(stream)) the session stores a Qwen35Snapshot: deep copies of
  the SSM s_data + conv_data, the full-attention layers' KV prefix
  rows [0, boundary), the committed token stream, and the
  conversation text as the serve presented it (plus this turn's
  generated reply text). The zero-state at boundary 0 is kept as a
  virtual snapshot (restoring it IS state.reset(); no bytes stored).
- KV finding: KVCache (core/mimir_well.mojo) is an append-only fixed
  buffer indexed (layer * max_seq_len + pos) * kv_dim -- no wrap, no
  reorder -- so WITHIN one live cache a boundary length would
  suffice. But reset() redraws the cache over the same pool region
  and any intervening conversation overwrites prefix rows, so a
  snapshot that must survive reset() NEEDS its KV prefix bytes
  copied out and back in. Only full-attention layers carry KV rows;
  SSM layers never write the cache, so only those layers are copied.
- Reuse rule (begin_turn at position 0 only): restore the LONGEST
  snapshot whose committed stream is an exact prefix of the new
  request's stream, then evaluate only the remainder. Two exact
  verifications, never a fuzzy one:
  (1) text-extension: the resent prompt text is byte-exactly the
      snapshot's conversation text + "Assistant: " + the snapshot's
      generated reply + "\n" + "User: " + one new user message +
      "\n" (the serve's chat format; exactly one new turn, like
      resident_delta). The new request's stream is then BY
      CONSTRUCTION snapshot.stream + tokenize(new message), so the
      snapshot stream is an exact token prefix of it.
  (2) token-prefix: the tokenized new prompt itself shares an exact
      prefix with the snapshot's stream, checked with
      reusable_prompt_prefix (which also enforces the final-token
      recomputation rule: a snapshot covering the whole prompt
      offers no reuse).
  Anything else evaluates cold from position 0. SSM state is a
  summary, not positional: reuse happens ONLY at snapshot
  boundaries, never at an arbitrary shared-prefix length.
- F1 interaction (Q35-3): snapshot/restore is a byte copy on the
  SAME path, so a restored continuation is bit-exact vs the
  resident continuation evaluated the same way. No cross-path
  (per-token vs batched) equality is claimed beyond Q35-3's
  f16-ulp numbers.
- Store bound: at most snapshot_limit (default 4) turn-boundary
  snapshots per session, oldest evicted first; the zero-state is
  not counted. Real-model cost per snapshot (27B): SSM s_data
  150,994,944 B + conv rings 7,864,320 B + KV prefix 16 layers x
  boundary x 1024 x 2 B x (K and V) stored as f16 (at boundary 4096:
  268,435,456 B). 40B SSM state alone is ~235 MB per snapshot.

Capabilities, stated honestly:
- session_residency: TRUE (state + KV persist across resident turns).
- exact_prefix_reuse: TRUE, snapshot-based only (the serve reports
  it with the exact_prefix_reuse_detail qualifier "snapshot-based
  at committed turn boundaries only"); never positional SSM reuse.
- conversation suspend/restore: NOT implemented as a serve
  feature; the snapshot store is internal to this session.
- structured output / tool calls: refused, like the Llama 3 session.
- sampling: the engine CPU sampler honors temperature/top_k/top_p/
  repetition_penalty/seed from NativeSamplingConfig; min_p and
  repeat_last_n have no CPU-forward counterpart and are not claimed.

Text handling: the fixture carries no chat template, so the session
encodes the serve's prompt text as one plain stream (system text,
when present at position 0, precedes the prompt separated by a
newline; BOS is added at position 0 only) -- the same raw-text
contract as AesirEngine._run_generation.
"""
from core.generation_control import GenerationControl, NativeGenerationStatus, ControlledTextSession
from core.sampling_config import NativeSamplingConfig
from core.mimir_well import KVCache, f32
from core.prompt_prefix import reusable_prompt_prefix
from aesir import AesirEngine, GenerationConfig


struct Qwen35Snapshot(Copyable, Movable):
    """Deep copy of the hybrid state at one committed turn boundary.

    s_data / conv_data are element copies of Qwen35State's heap f32
    buffers. kv_k / kv_v hold ONLY the full-attention layers' cache
    rows [0, boundary), packed in attn_layers order, as f16 (the
    cache's own element type, so the copy is bit-exact). stream is
    the committed token stream the state summarizes; conv_text +
    generated_text are the serve-presented conversation text and
    this boundary's reply text, used by the text-extension check.
    """
    var boundary: Int
    var stream: List[Int]
    var conv_text: String
    var generated_text: String
    var attn_layers: List[Int]
    var s_data: List[Float32]
    var conv_data: List[Float32]
    var kv_k: List[Float16]
    var kv_v: List[Float16]

    def __init__(out self, boundary: Int = 0):
        self.boundary = boundary
        self.stream = List[Int]()
        self.conv_text = String("")
        self.generated_text = String("")
        self.attn_layers = List[Int]()
        self.s_data = List[Float32]()
        self.conv_data = List[Float32]()
        self.kv_k = List[Float16]()
        self.kv_v = List[Float16]()


struct Qwen35CPUSession(ControlledTextSession):
    var engine: AesirEngine
    var kv: KVCache
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
    var snapshots: List[Qwen35Snapshot]
    var snapshot_limit: Int
    var conv_text: String
    var last_generated_text: String
    var turn_generated_text: String

    def __init__(out self, path: String, context_length: Int,
                 sampling: NativeSamplingConfig = NativeSamplingConfig()) raises:
        sampling.validate()
        self.engine = AesirEngine(path, knowledge_capacity=1)
        if self.engine.parser.config.architecture != "qwen35":
            raise Error("Qwen35 CPU session requires a qwen35 model")
        if context_length < 2 or context_length > self.engine.parser.config.context_length:
            raise Error("Qwen35 CPU session context must be within 2.." + String(self.engine.parser.config.context_length))
        self.context_length = context_length
        self.engine.pool.offset = self.engine.runtime_offset
        self.kv = KVCache(
            self.context_length, self.engine.parser.config.kv_dim(),
            self.engine.pool, self.engine.parser.config.block_count,
        )
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
        self.snapshots = List[Qwen35Snapshot]()
        self.snapshot_limit = 4
        self.conv_text = String("")
        self.last_generated_text = String("")
        self.turn_generated_text = String("")

    def _gen_config(self) -> GenerationConfig:
        return GenerationConfig(
            max_new_tokens=self.max_new_tokens,
            temperature=self.sampling.temperature,
            top_k=self.sampling.top_k,
            top_p=self.sampling.top_p,
            repetition_penalty=self.sampling.repetition_penalty,
            seed=self.sampling.seed,
        )

    def _attn_layers(self) -> List[Int]:
        var out = List[Int]()
        for i in range(len(self.engine.qwen35_blocks)):
            if self.engine.qwen35_blocks[i].is_full_attn:
                out.append(i)
        return out^

    def _take_snapshot(mut self):
        """Store a snapshot at the current committed turn boundary.
        Called when generation finishes (position == len(stream)).
        Re-snapshotting an identical boundary+stream replaces the
        older entry (it becomes the newest); beyond snapshot_limit
        the oldest entries are evicted."""
        if self.position <= 0 or self.position != len(self.stream):
            return
        var snap = Qwen35Snapshot(self.position)
        snap.stream = self.stream.copy()
        snap.conv_text = self.conv_text
        snap.generated_text = self.turn_generated_text
        snap.attn_layers = self._attn_layers()
        ref st = self.engine.qwen35_state
        var s_count = st.ssm_layer_count * st.head_count * st.d_state * st.d_state
        for i in range(s_count):
            snap.s_data.append(Float32(st.s_data.unsafe_load(i)))
        var c_count = st.ssm_layer_count * max(0, st.conv_kernel - 1) * st.conv_dim
        for i in range(c_count):
            snap.conv_data.append(Float32(st.conv_data.unsafe_load(i)))
        var hidden = self.kv.hidden_dim
        var width = self.position * hidden
        for li in range(len(snap.attn_layers)):
            var base = snap.attn_layers[li] * self.kv.max_seq_len * hidden
            for j in range(width):
                snap.kv_k.append(self.kv.k.data.unsafe_load(base + j))
                snap.kv_v.append(self.kv.v.data.unsafe_load(base + j))
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

    def _restore_at(mut self, idx: Int):
        """Copy snapshot idx back into the live state + KV prefix and
        adopt its committed stream / position / conversation text."""
        ref snap = self.snapshots[idx]
        ref st = self.engine.qwen35_state
        for i in range(len(snap.s_data)):
            st.s_data.unsafe_store(i, Scalar[f32](snap.s_data[i]))
        for i in range(len(snap.conv_data)):
            st.conv_data.unsafe_store(i, Scalar[f32](snap.conv_data[i]))
        var hidden = self.kv.hidden_dim
        var width = snap.boundary * hidden
        for li in range(len(snap.attn_layers)):
            var base = snap.attn_layers[li] * self.kv.max_seq_len * hidden
            var src = li * width
            for j in range(width):
                self.kv.k.data.unsafe_store(base + j, snap.kv_k[src + j])
                self.kv.v.data.unsafe_store(base + j, snap.kv_v[src + j])
        self.stream = snap.stream.copy()
        self.position = snap.boundary
        self.conv_text = snap.conv_text
        self.last_generated_text = snap.generated_text
        self.pending_token = -1

    def snapshot_boundaries(self) -> List[Int]:
        """Boundaries currently restorable: the virtual zero-state
        at 0 first, then each stored turn-boundary snapshot."""
        var out = List[Int]()
        out.append(0)
        for i in range(len(self.snapshots)):
            out.append(self.snapshots[i].boundary)
        return out^

    def restore_snapshot(mut self, boundary: Int) raises -> Bool:
        """Restore the snapshot at an exact committed boundary (0 =
        the zero-state). Returns False when no such snapshot is
        stored; the caller then evaluates cold."""
        if not self.healthy or self.generating:
            raise Error("Cannot restore a snapshot on a busy or failed Qwen35 CPU session")
        if self.reset_required:
            return False
        if boundary == 0:
            ref st = self.engine.qwen35_state
            st.reset()
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
            raise Error("Qwen35 CPU session is busy or unusable")
        if prompt.byte_length() == 0 or prompt.byte_length() > 65536 or system.byte_length() > 65536:
            raise Error("Chat text exceeds admission bounds")
        if max_tokens < 1 or max_tokens > self.context_length:
            raise Error("Qwen35 completion ceiling must be within 1.." + String(self.context_length))
        var start = self.position
        var text = prompt
        if start == 0 and system != "":
            text = system + "\n" + prompt
        # Q35-5: decide the evaluation path BEFORE mutating anything.
        # path 0 = cold / resident (evaluate tokens from start),
        # path 1 = text-extension snapshot restore (tokens = the one
        # new user message; stream = snapshot stream + tokens),
        # path 2 = token-prefix snapshot restore (tokens = the full
        # tokenized prompt; stream = tokens; evaluate from boundary).
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
        # Apply the chosen path: stream becomes the full committed
        # stream of this turn; positions [0, effective_start) are
        # already evaluated (resident) or restored (snapshot paths).
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
        self.control.start()
        var cfg = self._gen_config()
        var end = len(self.stream)
        var cap = self.engine._prefill_batch_cap()
        if cap > 1 and end - effective_start > 1:
            var idx = effective_start
            while end - 1 - idx >= cap:
                _ = self.engine._forward_batch(self.stream, self.kv, idx, cap, cfg, True)
                idx += cap
            self.pending_token = self.engine._forward_batch(self.stream, self.kv, idx, end - idx, cfg, False)
        else:
            for p in range(effective_start, end - 1):
                _ = self.engine._forward_position(self.stream, self.kv, p, cfg, True)
            self.pending_token = self.engine._forward_position(self.stream, self.kv, end - 1, cfg, False)
        self.position = end
        self.generating = True

    def reset(mut self) raises:
        if not self.healthy or self.generating:
            raise Error("Cannot reset a busy or failed Qwen35 CPU session")
        # Snapshot the committed stream (inspection) and start the
        # next conversation at position 0 with a fresh KV cache. The
        # SSM state itself is wiped by the engine's position-0 rule
        # on the next conversation's first forward, never mid-stream.
        # The Q35-5 snapshot store deliberately SURVIVES reset(): a
        # later begin_turn may restore one of its boundaries.
        self.cached_stream = self.stream.copy()
        self.stream = List[Int]()
        self.engine.pool.offset = self.engine.runtime_offset
        self.kv = KVCache(
            self.context_length, self.engine.parser.config.kv_dim(),
            self.engine.pool, self.engine.parser.config.block_count,
        )
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
            raise Error("Cannot configure a busy or failed Qwen35 CPU session")
        sampling.validate()
        self.sampling = sampling

    def configure_output(mut self, output_mode: String) raises:
        if not self.healthy or self.generating:
            raise Error("Cannot configure output on a busy or failed Qwen35 CPU session")
        if output_mode != "":
            raise Error("Structured output is not implemented on the Qwen35 CPU session")

    def configure_tool(mut self, name: String, description: String) raises:
        _ = description
        if not self.healthy or self.generating:
            raise Error("Cannot configure tools on a busy or failed Qwen35 CPU session")
        if name != "":
            raise Error("Tool calls are not implemented on the Qwen35 CPU session")

    def configure_control(mut self, timeout_ms: Int = 0, cancel_fd: Int = -1) raises:
        if not self.healthy or self.generating:
            raise Error("Cannot configure a busy or failed Qwen35 CPU session")
        self.control = GenerationControl(timeout_ms, cancel_fd)

    def cancel(mut self, reason: String = "cancelled") raises -> String:
        if not self.healthy:
            raise Error("Cannot recover a failed Qwen35 CPU session through cancellation")
        if reason != "cancelled" and reason != "timeout":
            raise Error("Unsupported native cancellation reason")
        if not self.generating:
            return ""
        # The SSM state sits mid-stream; a cancelled conversation is
        # not resumable, so the next turn requires an explicit reset
        # (whose position-0 forward wipes the state honestly).
        self.pending_token = -1
        self.finish_reason = reason
        self.generating = False
        self.reset_required = True
        self.control.deadline_ms = 0
        return ""

    def next_chunk(mut self) raises -> String:
        if not self.generating:
            raise Error("No active Qwen35 CPU generation")
        var stop = self.control.stop_reason()
        if stop != "":
            return self.cancel(stop)
        var cfg = self._gen_config()
        var token = self.pending_token
        if token == self.engine.tokenizer.eos_token_id:
            self.stream.append(token)
            _ = self.engine._forward_position(self.stream, self.kv, self.position, cfg, False)
            self.position += 1
            self.finish_reason = "eos"
            self.generating = False
            self.last_generated_text = self.turn_generated_text
            self._take_snapshot()
            return ""
        var chunk = self.engine.tokenizer.decode(token)
        self.turn_generated_text += chunk
        self.generated_tokens += 1
        self.stream.append(token)
        var limit = self.generated_tokens >= self.max_new_tokens
        var full = self.position + 2 >= self.context_length
        self.pending_token = self.engine._forward_position(self.stream, self.kv, self.position, cfg, False)
        self.position += 1
        if limit or full:
            self.finish_reason = "context_exhausted" if full else "length"
            self.generating = False
            self.last_generated_text = self.turn_generated_text
            self._take_snapshot()
        return chunk

    def status(self) -> NativeGenerationStatus:
        return NativeGenerationStatus(self.healthy, self.generating, self.prompt_tokens,
                                      self.generated_tokens, self.position, self.finish_reason,
                                      self.reused_prompt_tokens)
