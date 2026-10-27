#Requires -Version 7.2
Import-Module (Join-Path $PSScriptRoot 'Common.psm1') -DisableNameChecking

function Add-UthCheck {
    param($Results, [string]$CheckService, [string]$CheckName, [scriptblock]$Action)
    try {
        & $Action | Out-Null
        $Results.Add([pscustomobject]@{ Service=$CheckService; Check=$CheckName; Passed=$true; Error='' })
    } catch {
        $Results.Add([pscustomobject]@{ Service=$CheckService; Check=$CheckName; Passed=$false; Error=$_.Exception.Message })
    }
}

function Invoke-UthTests {
    param($Context, [string]$Service='all', [string]$Suite='smoke', [bool]$HealthOnly=$false)
    $results = [Collections.Generic.List[object]]::new()
    $selected = if ($Service -eq 'all') { @($Context.Urls.Keys) } else { @($Service) }
    foreach ($name in $(if ($Suite -eq 'unit' -and -not $HealthOnly) { @() } else { $selected })) {
        Add-UthCheck $results $name 'Dependency readiness' {
            $health=(Invoke-UthRequest -Context $Context -Service $name -Path /health).Data
            Assert-Uth ($health['status'] -eq 'ready') 'The service is not ready.'
        }
    }
    if ($HealthOnly) { return $results.ToArray() }
    if ($Suite -eq 'smoke' -and $Service -in 'all','transport') {
        foreach ($path in '/routes','/trips') {
            Add-UthCheck $results transport "Public $path" {
                $page=(Invoke-UthRequest -Context $Context -Service transport -Path $path).Data
                Assert-Uth ($page.Contains('items') -and $page['limit'] -le 100) 'Expected a bounded list envelope.'
            }
        }
    } elseif ($Suite -ne 'smoke') {
        $root=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
        Push-Location $root
        try {
            Add-UthCheck $results application $Suite {
                switch ($Suite) {
                    'unit' {
                        $local=Join-Path $root '.tools/ballerina-2201.14.1-swan-lake/distributions/ballerina-2201.14.1/bin/bal.bat'
                        $balTool=if(Test-Path $local) { $local } else { 'bal' }
                        $version=(& $balTool version | Out-String)
                        Assert-Uth ($version -match '2201\.14\.1') 'Native tests require Ballerina 2201.14.1, matching the Docker build.'
                        & $balTool test core | Out-Host
                    }
                    'browser' { & npx playwright test | Out-Host }
                    default {
                        $env:UTH_TEST_BASE_URL=([uri]$Context.Urls['passenger']).GetLeftPart([UriPartial]::Authority)
                        & python -m unittest discover -s tests -p test_application.py -v | Out-Host
                    }
                }
                Assert-Uth ($LASTEXITCODE -eq 0) "The $Suite test suite failed (exit $LASTEXITCODE)."
            }
        } finally { Pop-Location }
    }
    return $results.ToArray()
}

Export-ModuleMember -Function Invoke-UthTests
