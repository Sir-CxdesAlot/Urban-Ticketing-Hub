#!/usr/bin/env pwsh
#Requires -Version 7.2
<#
.SYNOPSIS
One entry point for Urban Ticketing Hub development helpers.
.EXAMPLE
pwsh ./uth.ps1 cli
.EXAMPLE
pwsh ./uth.ps1 test -Service passenger -Suite crud
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [ValidateSet('help', 'setup', 'build', 'start', 'stop', 'backup', 'restore-check', 'cli', 'seed', 'test', 'health')]
    [string]$Command = 'help',
    [ValidateSet('all', 'passenger', 'transport', 'ticketing', 'payment', 'notification', 'admin')]
    [string]$Service = 'all',
    [ValidateSet('smoke', 'crud', 'unit', 'integration', 'browser')]
    [string]$Suite = 'smoke',
    [ValidateSet('menu', 'passenger', 'admin')]
    [string]$Role = 'menu',
    [string]$BaseUrl = 'http://localhost:8080',
    [string]$BackupPath = '',
    [ValidateRange(1, 300)]
    [int]$TimeoutSec = 15
)

$ErrorActionPreference = 'Stop'
try {
    if ($Command -eq 'help') {
        Write-Host @'
Urban Ticketing Hub helpers (PowerShell 7.2+, Windows/Linux/macOS)

  pwsh ./uth.ps1 setup                       Generate ignored local secrets
  pwsh ./uth.ps1 start                       Build and start the local application
  pwsh ./uth.ps1 stop                        Stop the demo stack and preserve volumes
  pwsh ./uth.ps1 build                       Build application and infrastructure images
  pwsh ./uth.ps1 backup                      Save a consistent database archive
  pwsh ./uth.ps1 restore-check -BackupPath X  Verify X in an isolated temporary container
  pwsh ./uth.ps1 cli                         Passenger/staff interactive menu
  pwsh ./uth.ps1 cli -Role admin             Use the same sign-in for staff accounts
  pwsh ./uth.ps1 seed                        Create/reuse demo data (writes data)
  pwsh ./uth.ps1 health                      Check all six service health routes
  pwsh ./uth.ps1 test                        Read-only smoke checks
  pwsh ./uth.ps1 test -Service transport      Select one service
  pwsh ./uth.ps1 test -Suite unit             Native tests without Docker
  pwsh ./uth.ps1 test -Suite integration      Real API/recovery fixtures (writes data)
  pwsh ./uth.ps1 test -Suite browser          Browser workflows and accessibility
  pwsh ./uth.ps1 test -Suite crud             Alias for integration tests

Options: -BaseUrl http://localhost:8080 -TimeoutSec 15
Without a port, BaseUrl uses service ports 8081–8086. A nondefault port routes
all services through that port, for a gateway or local test server.
Tests exit 1 on any failed assertion or cleanup. See scripts/README.md.
'@
        exit 0
    }
    $lib = Join-Path $PSScriptRoot 'scripts/lib'
    Import-Module (Join-Path $lib 'Operations.psm1') -Force -DisableNameChecking
    switch ($Command) {
        'setup' { New-UthSecrets; exit 0 }
        'build' { Invoke-UthCompose -Arguments @('build'); exit 0 }
        'start' {
            New-UthSecrets
            Invoke-UthCompose -Arguments @('up','-d','--build','--wait','--wait-timeout','180')
            Write-Host 'Application ready at http://localhost:8080.'
            exit 0
        }
        'stop' { Invoke-UthCompose -Arguments @('stop'); exit 0 }
        'backup' { Backup-UthDatabase; exit 0 }
        'restore-check' { Test-UthRestore -BackupPath $BackupPath; exit 0 }
    }
    Import-Module (Join-Path $lib 'Common.psm1') -Force -DisableNameChecking
    $context = New-UthContext -BaseUrl $BaseUrl -TimeoutSec $TimeoutSec
    switch ($Command) {
        'cli' {
            Import-Module (Join-Path $lib 'Cli.psm1') -Force -DisableNameChecking
            Start-UthCli -Context $context -Role $Role
        }
        'seed' {
            Import-Module (Join-Path $lib 'Seed.psm1') -Force -DisableNameChecking
            Initialize-UthDemo -Context $context
        }
        { $_ -in 'test', 'health' } {
            Import-Module (Join-Path $lib 'Tests.psm1') -Force -DisableNameChecking
            $results = @(Invoke-UthTests -Context $context -Service $Service -Suite $Suite -HealthOnly:($Command -eq 'health'))
            $results | Format-Table Service, Check, Passed, Error -Wrap -AutoSize | Out-Host
            $failed = @($results | Where-Object { -not $_.Passed }).Count
            Write-Host ("{0} checks; {1} passed; {2} failed." -f $results.Count, ($results.Count - $failed), $failed)
            if ($failed -gt 0) { exit 1 }
        }
    }
    exit 0
} catch {
    Write-Error $_ -ErrorAction Continue
    exit 1
}
