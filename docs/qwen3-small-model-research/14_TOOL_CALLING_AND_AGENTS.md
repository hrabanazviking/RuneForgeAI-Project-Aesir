# 14 - Tool Calling, Agents, and Structured Output

**Research snapshot:** 2026-11-02

Qwen3 was explicitly trained for agentic/tool use, making these small dense models attractive for Aesir worker hierarchies. The engine's job is not to invent a brittle tool protocol. It should preserve Qwen-compatible templates, expose structured output cleanly, and validate every action boundary.

---

# 1. Official Qwen guidance

Qwen recommends Qwen-Agent for canonical function-calling templates/parsers and warns that reasoning models should not use stopword-based ReAct templates because thought text can contain stop words and accidentally trigger tool behavior.

Source:
https://github.com/QwenLM/Qwen3/blob/main/docs/source/framework/function_call.md

Aesir design rule:

> Tool execution must be triggered by parsed protocol structure, never by a magic word appearing in free text or reasoning.

---

# 2. Agent stack separation

A clean stack:

```text
Qwen3 model
  -> token generation
  -> Qwen3 reasoning/final/tool protocol parser
  -> structured tool-call object
  -> schema validator
  -> application permission/policy layer
  -> tool execution
  -> structured tool result
  -> chat-template renderer
  -> model continuation
```

Do not let the model's raw text directly become executable function arguments.

---

# 3. Tool-call object

Aesir's protocol layer should normalize calls to something like:

```text
ToolCall {
    id
    name
    arguments_json
    parse_status
    schema_status
}
```

The actual wire format can follow the OpenAI-compatible API surface where useful, but internal execution should remain typed/validated.

---

# 4. Thinking separation

Tool parsers must ignore ordinary reasoning text.

Bad design:

```text
if output contains "search(" -> execute search
```

Correct design:

```text
parse only the assistant tool-call protocol region
```

This matters especially in thinking mode because the model may discuss hypothetical functions or syntax before deciding what to call.

---

# 5. Model-size roles

## 0.6B

Use for narrow, cheap agent tasks:

- classify intent;
- select one of a small tool set;
- extract obvious arguments;
- rewrite search query;
- repair a nearly-valid structure.

Require validation and escalate ambiguous cases.

## 1.7B

Strong worker candidate:

- multi-tool choice;
- simple planning;
- RAG query decomposition;
- structured summaries;
- routine command construction.

## 4B

Main agent/supervisor candidate:

- broader tool sets;
- multi-step plans;
- coding tools;
- synthesis over tool results.

## 8B

Escalation/judge:

- ambiguous plans;
- complex dependencies;
- verification before expensive operations;
- high-quality synthesis.

---

# 6. Tool schema cost

Tool definitions consume prompt tokens and therefore:

- increase prefill time;
- increase KV memory;
- reduce space for user content/reasoning.

Aesir/applications should support tool filtering:

```text
all registered tools
 -> small router selects relevant subset
 -> only relevant schemas are rendered into target prompt
```

This is a natural job for 0.6B/1.7B.

---

# 7. Prefix caching tool schemas

If the tool set is stable, cache the rendered system+tool prefix KV.

If only a subset changes, consider multiple cached prefixes keyed by tool-set hash.

Cache key must include:

- exact ordered tool schema;
- template version;
- model SHA;
- quant/architecture semantics;
- reasoning template mode if it alters prefix tokens.

---

# 8. Schema validation

Every tool call should be checked for:

- known tool name;
- required fields;
- field types;
- enum constraints;
- additional-property policy;
- string/number bounds where application provides them;
- parse completion.

If invalid:

1. do not execute;
2. optionally send validation error back to model for repair;
3. cap retries;
4. escalate model or return error.

---

# 9. Constrained decoding

If Aesir gains grammar/JSON-schema constrained decoding, use it for the structural portion of tool calls.

Potential benefits:

- fewer malformed calls;
- smaller models become more reliable agents;
- fewer repair turns;
- deterministic syntax without forcing semantic choices.

But constraints should not select *which* tool or invent missing data. They only enforce legal structure.

---

# 10. Tool-result compression

Tools can return huge payloads. Do not blindly append them to context.

Strategies:

- application selects relevant fields;
- 0.6B/1.7B summarizes large raw result;
- preserve source IDs/links for traceability;
- store raw result externally;
- feed target only necessary content.

This directly saves prefill time and KV memory.

---

# 11. Agent memory

Separate durable application memory from transformer context.

```text
long-term memory store
 -> retrieve relevant items
 -> render compact context
 -> model
```

A 128K window is not a substitute for retrieval/memory architecture. Huge transcripts waste compute and can lower relevance.

---

# 12. Multi-agent hierarchy

Aesir can use model sizes as roles rather than clones:

```text
0.6B Router
  -> 1.7B Worker A
  -> 1.7B Worker B
  -> 4B Supervisor
  -> 8B Judge only when needed
```

Advantages:

- lower average latency/energy;
- parallelizable independent subtasks;
- expensive model reserved for uncertainty;
- natural fit for heterogeneous hardware.

The supervisor should receive concise structured worker outputs, not every worker's entire reasoning transcript.

---

# 13. Confidence without fake probabilities

Do not treat the model's self-reported confidence sentence as calibrated probability.

Useful escalation signals:

- schema failure;
- repeated repair attempts;
- contradictory worker outputs;
- low logit margin where available and calibrated;
- tool execution error;
- explicit inability;
- task class known to fail on smaller model;
- verification model disagreement.

---

# 14. Deterministic replay

For debugging an agent action, record:

- model/quant SHA;
- exact token IDs;
- tool schema JSON;
- reasoning mode;
- sampler parameters + RNG seed where deterministic;
- generated token IDs;
- parsed tool call;
- validation result;
- tool result.

This makes agent failures reproducible instead of mystical.

---

# 15. Benchmark tasks

Build an Aesir `qwen3_agent_suite` with:

### Single tool
- obvious tool choice;
- required arguments;
- optional fields;
- enum fields.

### Tool ambiguity
- two similarly named tools;
- irrelevant tools in list;
- user asks for no action.

### Multi-step
- tool A result determines tool B call;
- retry after recoverable error;
- no infinite tool loop.

### Reasoning safety
- tool-like text inside quotation;
- tool name inside `<think>`;
- prompt injection inside tool result;
- malformed JSON.

### Scale
- 5 / 20 / 100 tool schemas.

Score exact success, not subjective prose quality.

---

# 16. Small-model agent economics

A smaller model can outperform a larger one systemically if it completes most routine tool work and escalates only failures.

Measure:

```text
success rate
average wall time per completed task
average joules per completed task
escalation rate
tool retries
context tokens
```

This metric is more useful than isolated benchmark accuracy for an always-on agent.

---

# 17. Sources

- https://github.com/QwenLM/Qwen3/blob/main/docs/source/framework/function_call.md
- https://huggingface.co/Qwen/Qwen3-0.6B
- https://arxiv.org/abs/2505.09388
