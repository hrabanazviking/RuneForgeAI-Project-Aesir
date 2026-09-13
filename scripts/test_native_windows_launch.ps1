# Exercise actual WSL argument transport in isolated fake-app checkout.
# Does not allocate a model, install a distribution, or change user settings.
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$fixtureRoot = Join-Path ([IO.Path]::GetTempPath()) ('aesir launch space '' ' + [Guid]::NewGuid().ToString('N'))
$fixtureScripts = Join-Path $fixtureRoot 'scripts'
try {
    New-Item -ItemType Directory -Path $fixtureScripts | Out-Null
    foreach ($name in @('launch.ps1', 'launch_windows.psm1', 'launch_windows_bridge.py')) {
        Copy-Item -LiteralPath (Join-Path $PSScriptRoot $name) -Destination (Join-Path $fixtureScripts $name)
    }
    $probe = @'
import json,os,sys
print(json.dumps([os.getcwd(),sys.argv[1:]], ensure_ascii=True))
sys.exit(23)
'@
    [IO.File]::WriteAllText((Join-Path $fixtureScripts 'launch.py'), $probe, [Text.UTF8Encoding]::new($false))
    $literalArgs = @('home', '--model-store', 'store space', '', 'quote"', '$(touch nope); & |', [string][char]0x96ea, 'trail\')
    # Calling the script in-process preserves the array API on PS 5.1 and 7.
    $output = & (Join-Path $fixtureScripts 'launch.ps1') -AppArgs $literalArgs
    if ($LASTEXITCODE -ne 23) { throw "Native child status was not preserved: $LASTEXITCODE; $output" }
    $decoded = ($output -join "`n") | ConvertFrom-Json
    if ($decoded[1].Count -ne $literalArgs.Count + 1) { throw 'Native argument count changed' }
    if ($decoded[1][0] -cne '--') { throw 'Native separator lost' }
    for ($index = 0; $index -lt $literalArgs.Count; $index++) {
        if ($decoded[1][$index + 1] -cne $literalArgs[$index]) { throw "Native argument $index changed" }
    }
    if (-not $decoded[0].EndsWith((Split-Path $fixtureRoot -Leaf))) { throw 'Native checkout working directory lost' }
    Write-Output 'PASS actual Windows-to-WSL launch: spaces/apostrophe checkout, Unicode/empty/quoted argv and child exit 23'
} finally {
    # Only this test's newly created, exact files and empty directories.
    if (Test-Path -LiteralPath $fixtureScripts) {
        foreach ($name in @('launch.ps1', 'launch_windows.psm1', 'launch_windows_bridge.py', 'launch.py')) {
            $file = Join-Path $fixtureScripts $name
            if (Test-Path -LiteralPath $file) { Remove-Item -LiteralPath $file }
        }
        [IO.Directory]::Delete($fixtureScripts)
        [IO.Directory]::Delete($fixtureRoot)
    }
}
