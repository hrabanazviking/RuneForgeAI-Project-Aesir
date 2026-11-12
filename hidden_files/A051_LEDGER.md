# A-051 Ledger — Chat-template goldens (team-01)

- Slice: A-051 — Chat-template goldens. Per-family template rendering vs
  golden files. Acceptance: goldens pass; oracle rule — goldens are raw
  renderings kept for template tests only, never as inference-grading
  inputs.
- Base: seat main 259ad427 (48 of 216 banked, A-001..A-048), worktree
  reset --hard onto it after backing CAMPAIGN_STATE.md + hidden_files
  to /tmp/a051_backup (tracked hidden_files restored from git after
  the restore; git status verified clean apart from the standing
  untracked CAMPAIGN_STATE.md, aesir_engine/hip_bridge.c,
  hidden_files/a010_probes/, hidden_files/a024_bench.json).
- Renderer under test: aesir_engine/loader/chat_template.mojo
  (RuneChatTemplate.format_chat) with styles chatml / llama3 / llama2 /
  gemma (+ gemma3 alias). Family list per the A-048 architecture
  matrix (docs/bench/A048_ARCHITECTURE_LOAD_MATRIX.md): llama, qwen2,
  qwen3, qwen35, gemma, gemma2, gemma4, mistral (bonus row M-008).

## What was built

- aesir_engine/tests/test_chat_template_goldens_a051.mojo — 5 cases.
  Fixed RAW conversation for every family: system "You are a helpful
  assistant." / user "Hello!" / assistant "Hi there." / user "What is
  2+2?" (plain contents, no surrounding whitespace, no control-token
  spellings, so the renderings are trim- and escape-invariant).
- Golden files (committed with the slice, small):
  aesir_engine/tests/goldens/chat_template/
  - chatml.txt  196 B  sha256 8f59f45163b4279b9350f8332634261ae593549946752a505e31154e62c49531
  - llama3.txt  334 B  sha256 1102182404f57f0f84ab049ef5ae551affa9524a369b0586010f9fa33d9739c4
  - llama2.txt  106 B  sha256 ba8bf245b9a24869b546007cfdd40e9cf68cb63b469a7e5eb8d46213eadc7a9f
  - gemma.txt   213 B  sha256 5be3cfc4bc4df2a05c63b01ab03cd277475d855a90c80cc3cb622bfdb0741e70
- Registration choice: E-MASTER cases in aesir_engine/tests/run_all.mojo
  (chat_template.golden_chatml / _llama3 / _llama2 / _gemma /
  _family_routing), finish pin 424 -> 429 (+5 exactly). Chosen over a
  standalone harness because E-MASTER is the campaign's canonical gate
  and every recent slice registers there; the pre-existing
  test_chat_template_hardening.mojo remains standalone (unchanged).

## Golden provenance (not blind snapshots)

Each golden was derived from the family's canonical published
template form, then cross-checked: the shared two-message prefix
(system+user) of the ChatML, Llama-3 and Llama-2 goldens matches
byte-for-byte the expectations already pinned independently in
aesir_engine/tests/test_inference.mojo (section 3-5), and the Gemma
golden follows the published <start_of_turn>role form with the
engine's documented role mapping (assistant -> model). The assistant
turn and second user turn extend the same canonical forms.

## Documented divergences from the published canonical forms

Filed honestly; the goldens pin the engine's forms where they differ,
for the fixed conversation above:
- BOS: no string renderer emits <s>/<bos>; BOS is tokenizer-level in
  this engine (loader/tokenizer.mojo encode(add_bos=...)). Exception:
  Llama-3's canonical string form itself starts with
  <|begin_of_text|>, and format_llama3 emits it.
- Llama-2: canonical appends </s> after an assistant turn; the engine
  leaves EOS to the sampler and pads the assistant turn with spaces
  (" " + content + " "). Golden pins the engine form.
- Gemma: canonical template trims content and defines no system role;
  the engine maps system -> user (a separate user turn) and does not
  trim. The fixed conversation is trim-invariant, so only the system
  mapping is exercised, and the golden pins it deliberately.
- Gemma 3: canonical adds system handling and image tokens; the
  text-only framing is the same <start_of_turn> form, and style
  "gemma3" routes to the same renderer — the gemma case asserts both
  style names against the one golden.

## Honestly scoped out (no golden claimed)

- gemma4: NO string golden. Gemma 4's prompt construction is
  token-level in loader/gemma4_tokenizer.mojo (append_message builds
  <|turn> ... <turn|> token sequences), not RuneChatTemplate string
  rendering; a string golden against format_gemma would pin the wrong
  tokens (<start_of_turn>). detect_template_family maps its
  <|turn>/<turn|> template to the "gemma" family and
  NativeTokenizerSelection binds arch gemma4 at metadata level — the
  family_routing case pins exactly that, no more. Gemma 4 rendering
  coverage stays with the Gemma 4 tokenizer parity fixtures.
- mistral: NO golden. RuneChatTemplate has no Mistral renderer; its
  [INST] templates detect as llama2. A-048 row M-008 likewise showed
  the generic path applying no Mistral-specific modifier.
- qwen35: covered by the ChatML golden at template level only. There
  is no qwen35 branch in NativeTokenizerSelection.from_metadata; it
  binds ChatML through the detected-template path (expected ==
  "unknown"), which the family_routing case pins. (A-048 M-004's
  qwen35 load failure is an SSM-metadata matter, unrelated to chat
  templates.)

## Suite gate

- hidden_files/run_a051_suite.sh (A-042 suite pattern) ->
  hidden_files/a051_run_all.log, sha256
  c115159451fae66c8bd379be58990f4f61c6410f2332de424417648b14fd0fb2
- Counts READ FROM THE LOG: 426 passed / 1 failed / 2 skipped /
  429 total = baseline at 259ad427 (421/1/2 of 424) + exactly the 5
  new cases. All 5 chat_template.golden_* cases PASS in the log.
- Sole failure: gguf.tensor_directory_interface — the pre-existing
  tolerated J-022 drift, unchanged. Skips: the 2 pre-declared.
  MOJO_EXIT=1 matches the A-042 gate log (same tolerated failure).
- Standalone pre-check of the 5 cases (scratch main, deleted after):
  all PASS, byte counts 196 / 334 / 106 / 213 / 213 (gemma3 alias).

## Bugs / next work

- No new bug found in the renderers for the covered families; the
  divergences above are documented design differences, filed here.
- Recorded as next work in CAMPAIGN_STATE.md: the A-033 taxonomy gap
  (no dedicated execution-not-implemented error code, roaded to
  A-089) remains open; gemma4 string-template rendering is NOT a gap
  (token-level builder is its canonical path here).

## Banking

- NOT merged, NOT pushed. Awaiting keeper banking in roadmap order
  (A-049, A-050 bank before A-051).
