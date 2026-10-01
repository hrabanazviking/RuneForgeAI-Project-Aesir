# PowerShell contract tests left a deliberate child failure as runner status

Domain: test/launcher contract harness. Discovered during the 2026-10-01
second-brain publication audit. The preimplementation task-contract workflow and
the implementation workflow fail at the same PowerShell step despite printing
the contract PASS message. The hosted Linux native build and preceding checks pass.

`test_windows_launch.ps1` deliberately sets LASTEXITCODE=19 to assert that a failed
WSL-launched application keeps its failure status. Subsequent test cases exercise
preflight failures without invoking another native child, so the old value
survives. GitHub's pwsh wrapper propagates that global exit status at script end.

Per-case Reset-Test now clears only the test-owned exit state before the next
case. The native status-19 assertion remains before reset, production launcher
status propagation is unchanged, and a final assertion rejects a leaked test
failure code before the PASS message. Unhandled assertions still fail the script;
there is no unconditional successful exit or disabled gate.

Acceptance: the existing full hosted workflow must execute the PowerShell step,
special-file/compile probes, intentional negative control, fixture and consistency
checks successfully. This proves isolated launcher argv/status contracts; it does
not establish physical Windows, WSL, GPU or desktop execution.
