# Bug Report: Dynamic Heap Memory Allocation in AesirEventBus State Assignment

**Bug ID**: 0020  
**Title**: Dynamic heap memory allocation during AesirEventBus event publishing  
**Component**: `core/event_bus.mojo`  
**Status**: Resolved  

## Description
During the audit of Slice 12 (Sovereign Resilience & Self-Healing Matrix), `AesirEventBus` stored `last_event_type` as a dynamic Mojo `String` field. Calling `publish_event(event_type)` performed heap buffer reallocation and copying when assigning `self.last_event_type = event_type`. This violated the zero dynamic allocation invariant for inter-module event signals during execution.

## Fix Applied
An additive fix was applied to `core/event_bus.mojo`. The struct state was updated to store `last_event_code: Int` instead of a dynamic heap string field. `publish_event` maps string event types (`"IDLE"`, `"HEARTBEAT"`, `"MODEL_LOADED"`, `"INFERENCE_CRASH"`, `"RECOVERY_COMPLETE"`) to scalar integer discriminant codes, and `get_last_event()` returns static string representation. The struct now consists purely of primitive scalar integers (`event_count: Int`, `last_event_code: Int`), achieving 100% zero dynamic heap memory allocation.

## Mythic Engineering Rite Completed
Additive fix applied directly by The Auditor (Sólrún Hvítmynd). Invariants verified and test suite executed.
