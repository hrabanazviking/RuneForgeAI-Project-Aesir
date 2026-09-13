# Local launch (Linux and WSL)

The repository launcher builds and starts the native Mojo application. Python
is only launch plumbing; it does not implement inference. Keep this checkout,
its prepared `.pixi` environment and model store on local disk.

## Prepare a current build

From the checkout in Linux/WSL, with Python 3, Pixi and the repository's locked
Mojo environment already installed:

```sh
python3 scripts/launch.py --build
python3 scripts/launch.py --check
```

The default target is `sm_89`, the exercised NVIDIA Ada target. Other targets
can be requested with `--build --target sm_XX`; compilation alone does not
establish physical GPU support. Build uses `pixi run --frozen --no-install
--offline --executable`: no lock update, dependency installation or network
fetch is requested. Missing prepared dependencies fail with guidance; preparing
a new environment is a separate online operation, not performed by this helper.

The executable and manifest live under `.aesir/launch/`, separate from older
manually built binaries. Only a successful build with unchanged source is
published. Concurrent builds serialize; a failed or cancelled compiler leaves
the prior executable and manifest untouched. A publication crash can leave a
checksum mismatch, which requires rebuilding rather than running unchecked.

## Start locally

```sh
python3 scripts/launch.py
python3 scripts/launch.py -- home --model-store .aesir/models
python3 scripts/launch.py -- doctor --model-store .aesir/models --json
```

You may invoke the script by its quoted absolute path from another directory.
All relative application paths resolve from the **checkout**, not the caller's
directory. Application arguments after `--` are forwarded as literal argv;
there is no shell evaluation. Home needs terminal input and output. An empty
redirected invocation prints normal CLI help. Exit status and terminal signal
handling belong to the native app because the launcher replaces itself.

Normal launch does not invoke Pixi. It verifies source filenames/bytes, build
manifest/lock bytes, the launch helper, checkout location and executable SHA-256,
and checks the four required Mojo/MAX runtime library paths. Source edits,
moving the checkout, a corrupt executable or missing artifacts require an
explicit rebuild. This is freshness/error detection in a trusted local checkout,
not code signing, a hostile-filesystem defense or a full dependency-integrity
audit. Do not edit/build concurrently with launch. `--check` is not a model,
GPU, driver or successful-inference test. Preserve the prepared environment:
native library paths can be tied to its absolute location.

## If startup fails

- Missing Python: prepare Python 3 in Linux/WSL before leaving network access.
- Missing Pixi/Mojo: restore the prepared environment; launch never installs it.
- Stale/missing build: run the explicit build command above.
- Missing shared library: restore `.pixi/envs/default` in this checkout and
  rebuild. System libraries and the NVIDIA driver are additional prerequisites;
  the helper's four library checks do not validate every transitive dependency.
- No installed models: Home remains usable. A recipe alone is not weights;
  import your existing local model bytes using the CLI `create --model` command.

Windows/WSL wrapper and desktop integration are tracked separately as S06b.
S06 is not accepted until those gates and the documented offline launch checks
are satisfied. Successful physical offline inference remains a separate witness.
