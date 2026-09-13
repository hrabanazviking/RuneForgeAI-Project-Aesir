Set-StrictMode -Version Latest

function Resolve-AesirWsl {
    $command = Get-Command wsl.exe -CommandType Application -ErrorAction SilentlyContinue
    if ($null -eq $command) {
        throw 'WSL is missing. Prepare WSL 2 and a Linux distribution while connected; nothing was installed.'
    }
    return $command.Source
}

function Invoke-AesirNativeWsl {
    param([string]$Executable, [string[]]$Arguments)
    # Out-Host is intentionally NOT used: inherit the real terminal streams.
    & $Executable @Arguments
}

function Invoke-AesirWindowsLaunch {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Root,
        [string]$Distribution = '',
        [switch]$Build,
        [switch]$Check,
        [string]$Target = 'sm_89',
        [AllowEmptyCollection()][AllowEmptyString()][string[]]$AppArgs = @()
    )
    if (($Build -and $Check) -or (($Build -or $Check) -and $AppArgs.Count -gt 0)) {
        throw 'Build, Check and AppArgs are mutually exclusive.'
    }
    if ($Target -notmatch '^sm_[0-9]+$') { throw 'Target must be an sm_ CUDA target such as sm_89.' }
    if (-not $Build -and $Target -ne 'sm_89') { throw 'Target is only valid with Build.' }
    if ($Distribution -match '[\x00-\x1f"]') { throw 'Distribution contains unsupported control or quote characters.' }
    $resolvedRoot = (Resolve-Path -LiteralPath $Root -ErrorAction Stop).Path
    if (-not (Test-Path -LiteralPath (Join-Path $resolvedRoot 'scripts/launch_windows_bridge.py') -PathType Leaf)) {
        throw 'Missing WSL bridge. Use a complete Project Aesir checkout.'
    }
    [string[]]$launchArgs = @('--') + $AppArgs
    if ($Build) { $launchArgs = @('--build', '--target', $Target) }
    if ($Check) { $launchArgs = @('--check') }
    foreach ($argument in $launchArgs) {
        if ($argument.Contains([string][char]0)) { throw 'AppArgs must not contain NUL characters.' }
    }
    $json = ConvertTo-Json -InputObject $launchArgs -Compress
    $payload = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($json))
    if ($payload.Length -gt 24000) { throw 'AppArgs exceed the supported Windows command-line budget.' }
    $wsl = Resolve-AesirWsl
    [string[]]$prefix = @()
    if ($Distribution) { $prefix += @('--distribution', $Distribution) }
    $prefix += @('--cd', $resolvedRoot, '--exec')
    Invoke-AesirNativeWsl $wsl ($prefix + @('/bin/true'))
    if ($LASTEXITCODE -ne 0) {
        throw 'WSL could not open this checkout in the selected distribution. Check wsl --list --verbose and the checkout mount; nothing was installed.'
    }
    Invoke-AesirNativeWsl $wsl ($prefix + @('python3', '--version')) > $null
    if ($LASTEXITCODE -ne 0) {
        throw 'Python 3 is unavailable in the selected WSL distribution. Prepare it while connected; nothing was installed.'
    }
    Invoke-AesirNativeWsl $wsl ($prefix + @('python3', 'scripts/launch_windows_bridge.py', $payload))
    # Caller reads LASTEXITCODE; never mix a status integer into application stdout.
}

Export-ModuleMember -Function Invoke-AesirWindowsLaunch
