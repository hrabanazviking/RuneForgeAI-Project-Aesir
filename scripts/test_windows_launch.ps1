# Isolated PowerShell contracts; no WSL changes, downloads or external modules.
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$module = Import-Module (Join-Path $PSScriptRoot 'launch_windows.psm1') -Force -PassThru
$root = Split-Path $PSScriptRoot -Parent
function Assert-True($Condition, $Message) {
    if (-not $Condition) { throw $Message }
}
& $module {
    $script:calls = [Collections.Generic.List[object]]::new()
    $script:failureAt = 0
    $script:missingWsl = $false
    function script:Resolve-AesirWsl {
        if ($script:missingWsl) { throw 'WSL is missing.' }
        return 'fake-wsl'
    }
    function script:Invoke-AesirNativeWsl {
        param([string]$Executable, [string[]]$Arguments)
        $script:calls.Add($Arguments)
        $global:LASTEXITCODE = 0
        if ($script:calls.Count -eq $script:failureAt) { $global:LASTEXITCODE = 19 }
    }
}
function Reset-Test($Failure = 0, $Missing = $false) {
    & $module { param($f, $m) $script:calls.Clear(); $script:failureAt = $f; $script:missingWsl = $m } $Failure $Missing
}
function Expect-Failure($Action, $Text) {
    try { & $Action; throw 'expected rejection did not happen' }
    catch { Assert-True ($_.Exception.Message.Contains($Text)) $_.Exception.Message }
}
$literalArgs = @('home', '--model-store', 'store space', '', 'quote"', '$(touch nope); & |', [string][char]0x96ea, 'trail\')
Invoke-AesirWindowsLaunch -Root $root -Distribution 'Test Distro' -AppArgs $literalArgs
$calls = & $module { ,$script:calls.ToArray() }
Assert-True ($calls.Count -eq 3) 'expected WSL, Python and launch calls'
Assert-True ($calls[0][1] -eq 'Test Distro') 'distribution lost'
Assert-True ($calls[0][3] -eq $root) 'checkout path lost'
$payload = $calls[2][-1]
$decoded = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($payload)) | ConvertFrom-Json
Assert-True ($decoded.Count -eq $literalArgs.Count + 1) 'argument count changed'
for ($i = 0; $i -lt $literalArgs.Count; $i++) {
    Assert-True ($decoded[$i + 1] -ceq $literalArgs[$i]) "argument $i changed"
}
Reset-Test
Invoke-AesirWindowsLaunch -Root $root
$calls = & $module { ,$script:calls.ToArray() }
$decoded = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($calls[2][-1])) | ConvertFrom-Json
Assert-True ($decoded -ceq '--') 'empty invocation transport changed'
Reset-Test
Invoke-AesirWindowsLaunch -Root $root -Build -Target sm_89
$calls = & $module { ,$script:calls.ToArray() }
$decoded = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($calls[2][-1])) | ConvertFrom-Json
Assert-True (($decoded -join ',') -eq '--build,--target,sm_89') 'build transport changed'
Reset-Test 1
Expect-Failure { Invoke-AesirWindowsLaunch -Root $root } 'WSL could not open'
Assert-True ((& $module { $script:calls.Count }) -eq 1) 'launched after WSL failure'
Reset-Test 2
Expect-Failure { Invoke-AesirWindowsLaunch -Root $root } 'Python 3 is unavailable'
Assert-True ((& $module { $script:calls.Count }) -eq 2) 'launched after Python failure'
Reset-Test 3
Invoke-AesirWindowsLaunch -Root $root -Check
Assert-True ($LASTEXITCODE -eq 19) 'native failure status lost'
Reset-Test 0 $true
Expect-Failure { Invoke-AesirWindowsLaunch -Root $root } 'WSL is missing'
Reset-Test
Expect-Failure { Invoke-AesirWindowsLaunch -Root $root -Build -Check } 'mutually exclusive'
Expect-Failure { Invoke-AesirWindowsLaunch -Root $root -Check -AppArgs @('home') } 'mutually exclusive'
Expect-Failure { Invoke-AesirWindowsLaunch -Root $root -AppArgs @([string][char]0) } 'NUL'
Expect-Failure { Invoke-AesirWindowsLaunch -Root $root -AppArgs @(('a' * 25000)) } 'budget'
Expect-Failure { Invoke-AesirWindowsLaunch -Root $root -Distribution "bad`nname" } 'unsupported'
Assert-True ((& $module { $script:calls.Count }) -eq 0) 'rejected options reached WSL'
Write-Output 'PASS Windows launch: literal argv, mode transport, WSL/Python failures, exit status and preflight validation'
