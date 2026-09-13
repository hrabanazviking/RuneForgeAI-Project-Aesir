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

## Windows PowerShell entry

Use PowerShell 5.1 or 7 in a terminal, from this checkout:

```powershell
./scripts/launch.ps1 -Build
./scripts/launch.ps1 -Check
./scripts/launch.ps1
./scripts/launch.ps1 -AppArgs @('home', '--model-store', '.aesir/models')
./scripts/launch.ps1 -Distribution 'Ubuntu' -AppArgs @('home', '--help')
```

`-Distribution` is optional: omitted selects your existing WSL default. Use the
distribution where you prepared this checkout's environment. `-Build`, `-Check`
and `-AppArgs` are mutually exclusive. `-Target sm_89` applies to building.
For literal application options, use the explicit PowerShell array form above
rather than concatenating a command string. Arguments cross the Windows/WSL
boundary as bounded UTF-8 JSON/base64; no shell evaluates their contents.

The wrapper checks the checkout mount and Python 3 in that distribution, then
uses the same Linux launcher. WSL or Python failure yields an actionable error.
It never installs WSL, starts an installer, changes the default distribution,
shuts down WSL, or changes execution policy. If local PowerShell policy blocks
scripts, inspect/trust the source under your usual policy; this helper does not
bypass organizational settings. Your prepared WSL 2 system and NVIDIA support
remain prerequisites, not features supplied by the wrapper.

## Linux desktop entry export

```sh
python3 scripts/export_desktop_entry.py
python3 scripts/export_desktop_entry.py --output /your/chosen/new/Aesir.desktop
```

The first command previews the entry; the second creates exactly one new file
in an existing directory. Existing files and symlinks are refused. Neither
command installs it into a desktop menu, creates Windows shortcuts, changes
permissions/trust metadata, or opens a new terminal. If desired, install/trust
the exported file using your desktop's normal procedure. It uses
`Terminal=true`, requires `/usr/bin/python3` and a desktop-configured terminal,
and opens Home through the verified-build launcher. WSL without a configured
Linux desktop terminal should use the PowerShell entry instead.

The entry follows the [freedesktop Exec specification](https://specifications.freedesktop.org/desktop-entry/latest/exec-variables.html).
Its constant command contains an encoded checkout path to keep reserved
characters and field-code-like text literal. Moving the checkout requires a
rebuild and a newly exported entry.

## Verification scope and remaining gates

`test_windows_launch.ps1` tests option/preflight/error behavior with an isolated
WSL adapter. `test_native_windows_launch.ps1` exercises actual WSL transport in
a temporary fake-app checkout, including literal argv and exit 23; it does not
prove inference. Both passed on PowerShell 5.1 and 7. Actual native Home help and
build checks also passed through the Windows wrapper in this prepared checkout.

`test_platform_launch.py` tests bridge/export behavior; the Gio/GLib case parses
the desktop file and executes its command against a fake app. It reports a skip
if those optional parser bindings are missing. It does not launch a graphical
desktop terminal. `unshare -Urn python3 scripts/test_native_launch.py` exercises
native Home startup with external networking unavailable.

S06's remaining acceptance witnesses are a coordinated cold-host/WSL startup
and a graphical desktop click-through on a supported desktop. Neither is
claimed from fresh child processes or parser tests. We do not shut down the
user's active WSL sessions to manufacture a cold-start test. Successful physical
offline inference remains a separate witness; no model was loaded in these tests.
