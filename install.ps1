#Requires -Version 5.1
<#
.SYNOPSIS
    Zest Package Manager Installer for Windows.

.DESCRIPTION
    Installs Zest — the package manager for the Kiwi Programming Language.

.PARAMETER User
    Install for the current user only (default). Installs to %LOCALAPPDATA%\zest.

.PARAMETER System
    Install system-wide to %ProgramFiles%\zest. Requires elevation.

.PARAMETER Prefix
    Install to a custom directory.

.PARAMETER Uninstall
    Remove Zest.

.PARAMETER Update
    Remove the existing installation and reinstall the latest version.

.EXAMPLE
    # User install (default):
    .\install.ps1

    # System-wide install:
    .\install.ps1 -System

    # Custom prefix:
    .\install.ps1 -Prefix C:\Tools\zest

    # Update:
    .\install.ps1 -Update

    # Uninstall:
    .\install.ps1 -Uninstall

    # One-liner install from the web:
    irm https://raw.githubusercontent.com/fuseraft/zest/main/install.ps1 | iex
#>

[CmdletBinding(DefaultParameterSetName = 'User')]
param(
    [Parameter(ParameterSetName = 'User')]
    [switch]$User,

    [Parameter(ParameterSetName = 'System', Mandatory)]
    [switch]$System,

    [Parameter(ParameterSetName = 'Custom', Mandatory)]
    [string]$Prefix,

    [switch]$Uninstall,
    [switch]$Update
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# -------------------------------------------------------------------------
# Helpers
# -------------------------------------------------------------------------
function Write-Info    ($msg) { Write-Host "  • $msg" -ForegroundColor Cyan }
function Write-Ok      ($msg) { Write-Host "  ✓ $msg" -ForegroundColor Green }
function Write-Warn    ($msg) { Write-Host "  ! $msg" -ForegroundColor Yellow }
function Write-Header  ($msg) { Write-Host "`n$msg" -ForegroundColor White }
function Write-Fatal   ($msg) { Write-Host "  ✗ ERROR: $msg" -ForegroundColor Red; exit 1 }

# -------------------------------------------------------------------------
# Resolve install prefix
# -------------------------------------------------------------------------
$InstallPrefix = switch ($PSCmdlet.ParameterSetName) {
    'System' { Join-Path $env:ProgramFiles 'zest' }
    'Custom' { $Prefix }
    default  { Join-Path $env:LOCALAPPDATA 'zest' }
}

$BinDir = Join-Path $InstallPrefix 'bin'

# -------------------------------------------------------------------------
# Elevation check for System installs
# -------------------------------------------------------------------------
function Test-Admin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    ([Security.Principal.WindowsPrincipal]$id).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if ($System -and -not (Test-Admin)) {
    Write-Warn "System install requires elevation. Re-launching as Administrator..."
    $argList = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $MyInvocation.MyCommand.Path)
    if ($Update)    { $argList += '-Update' }
    if ($Uninstall) { $argList += '-Uninstall' }
    $argList += '-System'
    Start-Process powershell -Verb RunAs -ArgumentList $argList
    exit 0
}

# -------------------------------------------------------------------------
# Uninstall
# -------------------------------------------------------------------------
if ($Uninstall) {
    Write-Header 'Uninstalling Zest'
    if (-not (Test-Path $InstallPrefix)) {
        Write-Warn "No Zest installation found at $InstallPrefix"
        exit 0
    }
    Remove-Item -Recurse -Force $InstallPrefix

    # Remove from PATH
    $scope = if ($System) { 'Machine' } else { 'User' }
    $regPath = if ($System) {
        'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Environment'
    } else {
        'HKCU:\Environment'
    }
    $current = (Get-ItemProperty -Path $regPath -Name Path -ErrorAction SilentlyContinue).Path
    if ($current -and $current -like "*$BinDir*") {
        $updated = ($current -split ';' | Where-Object { $_ -and $_ -ne $BinDir }) -join ';'
        Set-ItemProperty -Path $regPath -Name Path -Value $updated
        Write-Info "Removed $BinDir from $scope PATH"
    }

    Write-Ok "Zest uninstalled from $InstallPrefix"
    exit 0
}

# -------------------------------------------------------------------------
# Banner
# -------------------------------------------------------------------------
Write-Host @'
                                           
                                    ,d     
                                    88     
888888888   ,adPPYba,  ,adPPYba,  MM88MMM  
     a8P"  a8P_____88  I8[    ""    88     
  ,d8P'    8PP"""""""   `"Y8ba,     88     
,d8"       "8b,   ,aa  aa    ]8I    88,    
888888888   `"Ybbd8"'  `"YbbdP"'    "Y888  

'@ -ForegroundColor Green

Write-Header 'Zest Installer'
Write-Info "Prefix    : $InstallPrefix"

# -------------------------------------------------------------------------
# Prerequisites
# -------------------------------------------------------------------------
Write-Header 'Checking prerequisites'

$kiwiPath = Get-Command kiwi -ErrorAction SilentlyContinue
if (-not $kiwiPath) {
    Write-Fatal "Kiwi is not installed or not in PATH. Install Kiwi first: https://github.com/fuseraft/kiwi"
}
Write-Info "kiwi      : $($kiwiPath.Source)"

# -------------------------------------------------------------------------
# Update: remove old install first
# -------------------------------------------------------------------------
if ($Update -and (Test-Path $InstallPrefix)) {
    Write-Info 'Removing previous installation...'
    Remove-Item -Recurse -Force $InstallPrefix
    Write-Ok 'Old installation removed'
}

New-Item -ItemType Directory -Force -Path $BinDir | Out-Null

# -------------------------------------------------------------------------
# Locate or clone the repository
# -------------------------------------------------------------------------
Write-Header 'Installing Zest'

$RepoUrl  = 'https://github.com/fuseraft/zest'
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$CleanupRepo = $false

if (Test-Path (Join-Path $ScriptDir 'zest.kiwi')) {
    $RepoDir = $ScriptDir
    Write-Info "Using local repository at $RepoDir"
} else {
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        Write-Fatal 'git is required to clone the Zest repository.'
    }
    $RepoDir = Join-Path ([System.IO.Path]::GetTempPath()) ('zest_' + [System.IO.Path]::GetRandomFileName())
    $CleanupRepo = $true
    Write-Info 'Cloning Zest repository...'
    git clone --depth=1 $RepoUrl $RepoDir 2>&1 | Out-Null
    Write-Ok 'Repository cloned'
}

try {
    # -------------------------------------------------------------------------
    # Copy files
    # -------------------------------------------------------------------------
    Copy-Item (Join-Path $RepoDir 'zest.kiwi') (Join-Path $InstallPrefix 'zest.kiwi') -Force
    $libSrc = Join-Path $RepoDir 'lib'
    $libDst = Join-Path $InstallPrefix 'lib'
    if (Test-Path $libDst) { Remove-Item -Recurse -Force $libDst }
    Copy-Item $libSrc $libDst -Recurse -Force
    Write-Ok 'Zest scripts installed'

    # -------------------------------------------------------------------------
    # Create zest.cmd wrapper
    # -------------------------------------------------------------------------
    $wrapperPath = Join-Path $BinDir 'zest.cmd'
    @'
@echo off
for %%I in ("%~dp0..") do set "ZEST_HOME=%%~fI"
kiwi "%ZEST_HOME%\zest.kiwi" %*
'@ | Set-Content -Encoding ASCII -Path $wrapperPath
    Write-Ok "Wrapper created: $wrapperPath"
} finally {
    if ($CleanupRepo -and (Test-Path $RepoDir)) {
        Remove-Item -Recurse -Force $RepoDir -ErrorAction SilentlyContinue
    }
}

# -------------------------------------------------------------------------
# PATH
# -------------------------------------------------------------------------
Write-Header 'Configuring PATH'

$regPath = if ($System) {
    'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Environment'
} else {
    'HKCU:\Environment'
}
$scopeLabel = if ($System) { 'Machine' } else { 'User' }

$current = (Get-ItemProperty -Path $regPath -Name Path -ErrorAction SilentlyContinue).Path
if (-not $current) { $current = '' }

if ($current -notlike "*$BinDir*") {
    $updated = if ($current) { "$BinDir;$current" } else { $BinDir }
    Set-ItemProperty -Path $regPath -Name Path -Value $updated
    Write-Ok "Added $BinDir to $scopeLabel PATH"
    # Broadcast the change to running processes
    if ('System.Environment' -as [type]) {
        [System.Environment]::SetEnvironmentVariable('Path', $updated, $scopeLabel)
    }
} else {
    Write-Info "$BinDir already in PATH"
}

# -------------------------------------------------------------------------
# Done
# -------------------------------------------------------------------------
Write-Header 'Installation complete!'
Write-Host "  Wrapper : $wrapperPath"
Write-Host "  Home    : $InstallPrefix"
Write-Host ''
Write-Host 'Open a new terminal and run ' -NoNewline
Write-Host 'zest --help' -ForegroundColor Cyan -NoNewline
Write-Host ' to get started.'
Write-Host ''
