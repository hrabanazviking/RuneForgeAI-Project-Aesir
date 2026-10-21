# Rotary mathematical compiler acceptance

Final hardened verification:104 methods/2864 native calls pass across16 suites.
The new five-method suite has153 calls,76 accepted and77 expected refusals;
37 complete rotary structures,18 complete old-output comparisons,75 mutation
refusals,two short policy refusals and three exact/ownership checks. Fourteen
compiler regressions94/2559 include108 frozen consumer comparisons; decoder
policy5/152 includes40 complete NoPE graphs. Thirty entrypoints rebuild cleanly.
Six isolated test-owned single-primitive vectors cover256 output scalars.
No production numerical executor, model/layer/attention forward or device access.

Full original stdout/stderr/traces remain in the external task work archive;
archive-identities.json pins every retained file. This published receipt contains
compact per-call output identities, final commands/logs/manifests, one complete
representative compiler output and all tiny primitive values. Binaries remain
outside Git. New validation hardening followed the first complete140-call run;
final153-call evidence is separate. Initial move-return/compiler warnings and an
early missing-executable harness failure are retained, with successful reruns.
No new hardware numerical encoding fact was found by the bounded public recheck.
