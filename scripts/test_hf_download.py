"""Opt-in real HTTPS download and failure-atomicity proof for the built CLI.

Supply a pinned public GGUF v3 smaller than 10 MiB. Model bytes are downloaded
only by Aesir; Python provides an independent SHA-256 oracle and test isolation.
No fixture, model, shell command, or expected response is fabricated.
"""

import argparse
import hashlib
import json
import pathlib
import stat
import subprocess
import tempfile


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ("aesir", "repo", "file", "revision", "sha256"):
        parser.add_argument("--" + name, required=True)
    parser.add_argument("--size", type=int, required=True)
    parser.add_argument("--connections", type=int, default=1)
    args = parser.parse_args()
    if not 24 <= args.size <= 10 * 1024 * 1024:
        parser.error("use a real external GGUF between 24 bytes and 10 MiB")
    executable = str(pathlib.Path(args.aesir).resolve(strict=True))
    base = [executable, "pull", args.repo, args.file, "--revision", args.revision,
            "--sha256", args.sha256, "--size", str(args.size),
            "--connections", str(args.connections)]

    with tempfile.TemporaryDirectory(prefix="aesir-hf-proof-") as directory:
        root = pathlib.Path(directory)

        def run(command, expected_error=None):
            result = subprocess.run(command, cwd=root, text=True,
                                    capture_output=True, timeout=180, check=False)
            if expected_error is None:
                if result.returncode != 0:
                    raise AssertionError(result.stdout + result.stderr)
            else:
                if (result.returncode == 0
                        or expected_error not in result.stdout + result.stderr):
                    raise AssertionError(result.stdout + result.stderr)
                if "Successfully downloaded" in result.stdout:
                    raise AssertionError("failure emitted a success claim")
            if list(root.glob("*.part.*")):
                raise AssertionError("staging files leaked after completed operation")
            return result

        # Shell syntax in a local filename must remain literal argv data.
        output = root / "model $(printf injected); 'quoted'.gguf"
        result = run(base + ["--output", str(output)])
        contents = output.read_bytes()
        if len(contents) != args.size or hashlib.sha256(contents).hexdigest() != args.sha256:
            raise AssertionError("independent size/SHA-256 verification failed")
        if contents[:8] != b"GGUF\x03\x00\x00\x00":
            raise AssertionError("downloaded external fixture is not GGUF v3")
        if "[HF] verified" not in result.stdout:
            raise AssertionError("verified transfer metadata missing")
        print("[HF LIVE PASS] HTTPS, pinned identity, checksum, literal argv path")

        run(base + ["--output", str(output)], "cannot publish download")
        if output.read_bytes() != contents:
            raise AssertionError("existing completed destination changed")
        print("[HF LIVE PASS] existing destination preserved")

        wrong_digest = base.copy()
        wrong_digest[wrong_digest.index("--sha256") + 1] = (
            ("0" if args.sha256[0] != "0" else "1") + args.sha256[1:]
        )
        rejected = root / "digest-mismatch.gguf"
        run(wrong_digest + ["--output", str(rejected)], "SHA-256 mismatch")
        if rejected.exists():
            raise AssertionError("checksum failure published a destination")
        print("[HF LIVE PASS] checksum mismatch rejected without publication")

        wrong_size = base.copy()
        wrong_size[wrong_size.index("--size") + 1] = str(args.size + 1)
        run(wrong_size + ["--output", str(rejected)], "size mismatch")
        if rejected.exists():
            raise AssertionError("size failure published a destination")
        print("[HF LIVE PASS] size mismatch rejected without publication")

        missing = base.copy()
        missing[3] = "aesir-proof-nonexistent-artifact-20260830.gguf"
        run(missing + ["--output", str(rejected)], "subprocess failed: curl")
        if rejected.exists():
            raise AssertionError("HTTP failure published a destination")
        print("[HF LIVE PASS] HTTP failure rejected without publication")

        sentinel = root / "user-data.txt"
        sentinel.write_text("preserve existing data", encoding="utf-8")
        link = root / "symlink.gguf"
        link.symlink_to(sentinel)
        run(base + ["--output", str(link)], "cannot publish download")
        if sentinel.read_text(encoding="utf-8") != "preserve existing data":
            raise AssertionError("existing symlink target was overwritten")
        print("[HF LIVE PASS] symlink destination preserved")

        config = root / "store-config.json"
        config.write_text(
            json.dumps({"storage": {"model_store_path": "store"}}),
            encoding="utf-8",
        )
        registered_output = root / "registered.gguf"
        registered = run(
            base
            + [
                "--output",
                str(registered_output),
                "--name",
                "live:v1",
                "--config",
                str(config),
            ]
        )
        if "Registered model bytes: live:v1" not in registered.stdout:
            raise AssertionError("successful registered pull omitted registration evidence")
        shown = json.loads(
            run(
                [
                    executable,
                    "show",
                    "live:v1",
                    "--format",
                    "json",
                    "--config",
                    str(config),
                ]
            ).stdout
        )
        if shown["digest"] != "sha256:" + args.sha256 or shown["size"] != args.size:
            raise AssertionError("registered pull catalog identity mismatch")
        run([executable, "verify", "live:v1", "--config", str(config)])
        blob = root / "store" / "blobs" / "sha256" / args.sha256
        if blob.read_bytes() != registered_output.read_bytes():
            raise AssertionError("registered blob bytes differ from verified download")
        if blob.stat().st_dev == pathlib.Path("/").stat().st_dev:
            if stat.S_IMODE(blob.stat().st_mode) != 0o400:
                raise AssertionError("registered blob is not owner-read-only")
        print("[HF LIVE PASS] pinned pull registered and reverified in model store")
        print("[HF LIVE SUMMARY] 7 passed, 0 failed")


if __name__ == "__main__":
    main()
