# A-050 Ledger -- Tokenizer edge battery (team-09)

- Base: 0cacfc61 (worktree HEAD at takeover; seat main 259ad427 has
  since banked A-048, 48 of 216 -- this branch diverged before that
  banking and the keeper reconciles at banking, per the union re-pin
  pattern). Previous lead stalled after the first suite run, before
  docs/commit; fresh lead verified everything from disk and finished.
- Slice: A-050 -- Tokenizer edge battery. Roadmap: "Unicode, emoji,
  control tokens, empty and oversized inputs vs reference outputs.
  Acceptance: battery green or divergences filed with verdicts."
- Filed battery doc: docs/bench/A050_TOKENIZER_EDGE_BATTERY.md
  (sha256 5e2f63fc20dc38fc8d98e48890189a2e227b4d576de5512df56bd8b4a5a1b555).

## Deliverables

- aesir_engine/tests/test_tokenizer_edge_a050.mojo (new, 243 lines,
  sha256 f498ce484ce51ed45ee1cd5e12d3ce5a5de56ef9b19dad0801acc57b7c9fc9cb):
  6 cases -- edge_empty_and_bos, edge_no_vocab_fallback,
  edge_unicode_emoji, edge_control_tokens, edge_invalid_utf8,
  edge_oversized. Expected ids hard-coded from the independent
  reference (below), never from the code under test.
- aesir_engine/tests/run_all.mojo (sha256
  cd60fb2290bbe1a4ba61e13388f945d16397df418208399881f3a4bec1e7719b):
  import + 6 run_case registrations (tokenizer.edge_*) and the
  finish pin 424 -> 430 (see Bugs).
- Reference evidence (untracked, preserved in hidden_files/):
  a050_ref.py sha256 03e27e459790ff9975b417fb5498ffe15123307b7469fc1fd0d9a2045fd3801c
  (independent Python implementation of the documented RuneWeaver
  contract: SPM score-greedy + byte fallback + special splitting,
  fail-closed on unregistered canonical spellings);
  a050_ref_output.log sha256 33f5a41fb3ae976469fe44d8417092b1faba4987276f6b25ebbde92622c9dd5e.

## Battery coverage (all vs reference; full detail in the filed doc)

- Unicode/emoji: hello variants, single emoji, flag sequence (two
  regional indicators -> 8 byte tokens, not collapsed), ZWJ family
  sequence (19 byte tokens, joiners preserved), Elder Futhark runes,
  Arabic, combining e + U+0301 (no NFC composition), tab/newline byte
  tokens, mixed text; 7 stream-decoder round-trips byte-exact.
- Control tokens: registered specials split byte-level in text/alone/
  adjacent; byte-token spelling "<0x41>" treated as literal data;
  unregistered canonical "<|endoftext|>" fails closed with the error
  naming the spelling (reference raises identically).
- Empty input: "" -> [], ""+BOS -> [1], spaces-only -> [10,10,10].
- No-vocab fallback: bare RuneWeaver encodes raw UTF-8 bytes as ids
  ("ab" -> [97,98], emoji/runes per byte) -- lossless, no UNK.
- Invalid UTF-8: 6 malformed byte strings (truncated 4-byte, lone
  continuation, overlong, CESU-8 surrogate, >U+10FFFF, valid +
  truncated tail) each collapse the whole input to a single unknown
  id -- fail-closed, no partial encode.
- Oversized: "ab" x50000 -> 100,000 tokens; "hello " x10000 ->
  50,000; emoji x10000 -> 40,000; every position pattern-checked.

## E-MASTER suite (hidden_files/run_a050.sh, gfx1151, run_all.mojo, pin 424 -> 430)

- hidden_files/a050_run_all.log sha256
  a4d12c3dc30a666804cf9e57ae9f744237d4c4817f4e9e8239747e8396177339:
  427 passed / 1 failed / 2 skipped / 430 total = baseline
  421/1/2/424 (A-048 seat gate) + exactly the 6 new tokenizer.edge_*
  cases, all PASS. Sole failure = pre-existing tolerated
  gguf.tensor_directory_interface (J-022 drift; roads A-165/A-121).
  Skips = the 2 pre-declared.
- Pre-pin first run preserved as hidden_files/a050_run_all_prepin.log
  sha256 c00ca9e2aadeac7d5cce46a8ca2ea6711ecb8a24866d5a597c739db29943ecd7:
  identical counts; its finish error was the count-mismatch class
  because of the pin defect below.

## Bugs / follow-ups

- Bookkeeping defect found and fixed in scope: the 6 cases were
  registered but ledger.finish still expected 424, so the suite
  summary raised "counted an unexpected number of cases" instead of
  the normal recorded-failures class. Pin bumped 424 -> 430 with an
  A-050 re-pin comment; suite re-run green-modulo-tolerated-failure
  (above). (The keeper applies the usual union re-pin at banking if
  A-049 lands cases first.)
- No engine bug discovered. Divergences vs reference: NONE. One
  coverage note filed in the doc: the reference's ctrl_chars trio
  (0x01/0x02/0x1F) is not asserted as its own case; the same
  byte-fallback behaviour is asserted via tab/newline tokens.
- No README touched. No merge/push -- keeper banks in roadmap order
  (A-049 banks before A-050).

- Commit: 054c1d9bcb894227130689ba7626690496c3dd50 on yrsa/aesir-team-09 ("A-050: Tokenizer edge battery", 3 files: test file + run_all.mojo + bench doc). CAMPAIGN_STATE.md and hidden_files/ left untracked per the banking pattern.
