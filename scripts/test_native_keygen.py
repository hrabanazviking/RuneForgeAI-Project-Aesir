"""Exercise exclusive native key creation, protection and publication races."""
import argparse
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
import re
import stat
import subprocess
import tempfile


def check(binary):
    def run(path):
        return subprocess.run([binary, "keygen", str(path)], capture_output=True, timeout=30)

    with tempfile.TemporaryDirectory(prefix="aesir-native-key-") as directory:
        root = Path(directory)
        first, second = root / "first.key", root / "second.key"
        for target in [first, second]:
            result = run(target)
            assert result.returncode == 0, result.stderr.decode(errors="replace")
            data = target.read_bytes()
            assert re.fullmatch(b"[0-9a-f]{64}\n", data), "invalid key shape"
            assert stat.S_IMODE(target.stat().st_mode) == 0o600
            assert data.strip() not in result.stdout + result.stderr, "key leaked in process output"
        original = first.read_bytes()
        assert original != second.read_bytes(), "native random keys repeated"
        for name in ["x" * size for size in range(1, 34)] + ["Halló-🌊.key"]:
            target = root / name
            assert run(target).returncode == 0 and target.exists(), "path was not terminated correctly"
            assert re.fullmatch(b"[0-9a-f]{64}\n", target.read_bytes())
        assert run(first).returncode != 0 and first.read_bytes() == original
        link = root / "symlink"
        link.symlink_to(first)
        assert run(link).returncode != 0 and link.is_symlink() and first.read_bytes() == original
        dangling = root / "dangling"
        dangling.symlink_to(root / "missing")
        assert run(dangling).returncode != 0 and not (root / "missing").exists()
        assert run(root / "missing-parent" / "key").returncode != 0
        raced = root / "raced.key"
        with ThreadPoolExecutor(max_workers=4) as pool:
            outcomes = list(pool.map(run, [raced] * 4))
        assert sum(result.returncode == 0 for result in outcomes) == 1, "publication race replaced a key"
        assert re.fullmatch(b"[0-9a-f]{64}\n", raced.read_bytes())
        assert not list(root.glob(".aesir-key-*")), "temporary key links leaked"
    print("PASS native random key generation: mode, shape, distinct keys, no disclosure, no overwrite, symlinks, race and cleanup")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--binary", required=True)
    check(parser.parse_args().binary)
