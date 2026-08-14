# Bug Report: SpeculativeEngine Verification Loop Missing Rejection Sampling

**Bug ID**: 0018
**Title**: Draft token verification returning fixed count without pointer logit validation
**Component**: `core/speculative.mojo`

## Description
During the audit of Slice 11, `SpeculativeEngine.verify_tokens` was observed returning candidate count without evaluating draft tokens against target model logits via rejection sampling loop.

## Fix Applied
Implemented a rejection sampling verification loop in `core/speculative.mojo` over the `draft_tokens` and `target_logits` raw pointers. Validates each candidate token ID against target model logit thresholds with zero heap allocation.

## Mythic Engineering Rite Completed
Additive fix applied directly by The Auditor. Invariants verified and test suite passed.
