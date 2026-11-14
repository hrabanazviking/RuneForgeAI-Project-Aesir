"""Q35-4a: CPU serve session for the Qwen 3.5 hybrid (qwen35).

A ControlledTextSession over the engine-core path (AesirEngine +
forward_pass_qwen35 / forward_pass_qwen35_batched, Q35-3a). The
engine owns a PERSISTENT Qwen35State (SSM recurrence + conv rings)
plus the full-attention layers' KV in this session's KVCache; both
survive across turns of one conversation.

Reset semantics (the serve calls reset() before every NON-resident
request; resident continuations skip reset entirely):
- reset() ends the conversation bookkeeping: position returns to 0,
  the committed token stream is snapshotted into cached_stream
  (kept for inspection only -- NO prefix reuse is claimed or done,
  exact_prefix_reuse stays false; Q35-5 owns SSM snapshots), and a
  fresh KVCache is drawn for the full-attention layers.
- reset() deliberately does NOT wipe engine.qwen35_state. The wipe
  is owned by the engine's reset-on-position-0 rule
  (core/inference.mojo: both qwen35 forwards call state.reset()
  exactly when start_pos == 0), so the first forward of the next
  conversation starts from a zeroed SSM state, and a resident
  continuation -- which never passes through reset() and never
  restarts at position 0 -- keeps the state bit-exact (Q35-3a d1/d2).
  A genuinely new conversation is therefore: reset() + begin_turn
  at position 0. There is no mid-conversation state wipe.

Capabilities, stated honestly:
- session_residency: TRUE (state + KV persist across resident turns).
- exact_prefix_reuse: FALSE (no KV/SSM prefix snapshot reuse).
- conversation suspend/restore: NOT implemented (no state copy
  in/out); the trait has no such method, and none is faked here.
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
from core.mimir_well import KVCache
from aesir import AesirEngine, GenerationConfig


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

    def _gen_config(self) -> GenerationConfig:
        return GenerationConfig(
            max_new_tokens=self.max_new_tokens,
            temperature=self.sampling.temperature,
            top_k=self.sampling.top_k,
            top_p=self.sampling.top_p,
            repetition_penalty=self.sampling.repetition_penalty,
            seed=self.sampling.seed,
        )

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
        var tokens = self.engine.tokenizer.encode(text, start == 0)
        if len(tokens) == 0:
            raise Error("Qwen35 tokenizer produced no prompt tokens")
        if start + len(tokens) + 2 > self.context_length:
            raise Error("Qwen35 context cannot fit prompt, response and closing token; history was not truncated")
        var reason = self.control.stop_reason()
        if reason != "":
            self.reset_required = True
            self.finish_reason = reason
            raise Error("Qwen35 prefill " + reason + "; explicit reset required")
        for token in tokens:
            self.stream.append(token)
        self.prompt_tokens = len(tokens)
        self.generated_tokens = 0
        self.reused_prompt_tokens = 0
        self.max_new_tokens = max_tokens
        self.finish_reason = ""
        self.control.start()
        var cfg = self._gen_config()
        var end = start + len(tokens)
        var cap = self.engine._prefill_batch_cap()
        if cap > 1 and len(tokens) > 1:
            var idx = start
            while end - 1 - idx >= cap:
                _ = self.engine._forward_batch(self.stream, self.kv, idx, cap, cfg, True)
                idx += cap
            self.pending_token = self.engine._forward_batch(self.stream, self.kv, idx, end - idx, cfg, False)
        else:
            for p in range(start, end - 1):
                _ = self.engine._forward_position(self.stream, self.kv, p, cfg, True)
            self.pending_token = self.engine._forward_position(self.stream, self.kv, end - 1, cfg, False)
        self.position = end
        self.generating = True

    def reset(mut self) raises:
        if not self.healthy or self.generating:
            raise Error("Cannot reset a busy or failed Qwen35 CPU session")
        # Snapshot the committed stream (inspection only; no reuse is
        # claimed -- see the module docstring) and start the next
        # conversation at position 0 with a fresh KV cache. The SSM
        # state itself is wiped by the engine's position-0 rule on
        # the next conversation's first forward, never mid-stream.
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
            return ""
        var chunk = self.engine.tokenizer.decode(token)
        self.generated_tokens += 1
        self.stream.append(token)
        var limit = self.generated_tokens >= self.max_new_tokens
        var full = self.position + 2 >= self.context_length
        self.pending_token = self.engine._forward_position(self.stream, self.kv, self.position, cfg, False)
        self.position += 1
        if limit or full:
            self.finish_reason = "context_exhausted" if full else "length"
            self.generating = False
        return chunk

    def status(self) -> NativeGenerationStatus:
        return NativeGenerationStatus(self.healthy, self.generating, self.prompt_tokens,
                                      self.generated_tokens, self.position, self.finish_reason,
                                      self.reused_prompt_tokens)
