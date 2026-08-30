"""Opt-in native CLI integration; weights and hardware remain external."""
import argparse
import subprocess


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--binary", required=True)
    parser.add_argument("--llama", required=True)
    parser.add_argument("--gemma", required=True)
    args = parser.parse_args()

    def run(words, expected=0):
        result = subprocess.run([args.binary, *words], capture_output=True, text=True, timeout=240)
        if (result.returncode == 0) != (expected == 0):
            raise AssertionError((words, result.returncode, result.stdout, result.stderr))
        return result.stdout + result.stderr

    hardware = run(["hardware", "list"])
    assert "cpu:0" in hardware and "cuda:0" in hardware and "NVIDIA" in hardware
    for model, profile, context in [(args.llama, "llama3", "8192"), (args.gemma, "gemma4", "32768")]:
        plan = run(["compute", "explain", model, "--context", context])
        assert f"profile={profile}" in plan and "selected=cuda:0" in plan
        for options in [["--reserve-mib", "1048576"], ["--device", "2147483647"]]:
            rejected = run(["compute", "plan", model, *options], expected=1)
            assert "No compatible CUDA device fits" in rejected
            rejected_chat = run(["chat", model, "--accel", "cuda", "--profile", profile, *options], expected=1)
            assert "No compatible CUDA device fits" in rejected_chat and "[CUDA] native" not in rejected_chat
        completion = run(["run", model, "--accel", "cuda", "--max-tokens", "20", "Answer briefly: what is two plus two?"])
        assert "finish=eos" in completion and ("Four" in completion or "4" in completion)
        assert "backend=cuda cpu_offload=0" in completion
        print(f"PASS {profile}: auto profile, planning, impossible budgets/devices, real CUDA completion")
    print("PASS native planning CLI integration")


if __name__ == "__main__":
    main()
