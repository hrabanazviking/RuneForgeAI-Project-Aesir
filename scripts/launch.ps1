<#
.SYNOPSIS
Launch the prepared native Aesir application through WSL, without installation.
.EXAMPLE
./scripts/launch.ps1 -AppArgs @('home', '--model-store', '.aesir/models')
.EXAMPLE
./scripts/launch.ps1 -Build
#>
[CmdletBinding()]
param(
    [string]$Distribution = '',
    [switch]$Build,
    [switch]$Check,
    [string]$Target = 'sm_89',
    [AllowEmptyCollection()][AllowEmptyString()][string[]]$AppArgs = @()
)
$ErrorActionPreference = 'Stop'
try {
    Import-Module (Join-Path $PSScriptRoot 'launch_windows.psm1') -Force
    Invoke-AesirWindowsLaunch -Root (Split-Path $PSScriptRoot -Parent) `
        -Distribution $Distribution -Build:$Build -Check:$Check -Target $Target -AppArgs $AppArgs
    exit $LASTEXITCODE
} catch {
    [Console]::Error.WriteLine(('Aesir Windows launcher: ' + $_.Exception.Message))
    exit 1
}
