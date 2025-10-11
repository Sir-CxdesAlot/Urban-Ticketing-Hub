$ErrorActionPreference = 'Stop'
$base = 'http://localhost:8081/api/v1/passenger'
try {
    $regBody = @{ email = 'test.user+dbg@example.com'; password = 'Test123!'; firstName = 'Dbg'; lastName = 'User'; phone = '555-0200' }
    $reg = Invoke-RestMethod -Method Post -Uri "$base/register" -ContentType 'application/json' -Body ($regBody | ConvertTo-Json -Depth 5)
    Write-Host 'REGISTER:'
    $reg | ConvertTo-Json -Depth 5 | Write-Host

    $login = Invoke-RestMethod -Method Post -Uri "$base/login" -ContentType 'application/json' -Body ((@{ email = $regBody.email; password = $regBody.password }) | ConvertTo-Json -Depth 5)
    Write-Host 'LOGIN:'
    $login | ConvertTo-Json -Depth 5 | Write-Host
    $token = if ($login.token) { $login.token } elseif ($login.data -and $login.data.token) { $login.data.token } else { $null }
    Write-Host "TOKEN: $token"

    $routes = Invoke-RestMethod -Method Get -Uri 'http://localhost:8082/api/v1/transport/routes'
    Write-Host 'ROUTES COUNT:' ($routes.Count)
    $firstRoute = if ($routes -is [array]) { $routes[0] } else { $routes }
    Write-Host '--- First Route JSON ---'
    $firstRoute | ConvertTo-Json -Depth 5 | Write-Host
    Write-Host '--- First Route Property Names ---'
    $firstRoute.PSObject.Properties.Name | ForEach-Object { Write-Host "PROP: $_" }
    Write-Host 'Access attempts:'
    Write-Host "firstRoute.id = " -NoNewline; try { Write-Host $firstRoute.id } catch { Write-Host '(error)' }
    Write-Host "firstRoute._id = " -NoNewline; try { Write-Host $firstRoute._id } catch { Write-Host '(error)' }
    Write-Host "firstRoute['id'] = " -NoNewline; try { Write-Host $firstRoute['id'] } catch { Write-Host '(error)' }
    Write-Host "firstRoute['_id'] = " -NoNewline; try { Write-Host $firstRoute['_id'] } catch { Write-Host '(error)' }

    $trips = Invoke-RestMethod -Method Get -Uri 'http://localhost:8082/api/v1/transport/trips'
    Write-Host 'TRIPS COUNT:' ($trips.Count)
    $firstTrip = if ($trips -is [array]) { $trips[0] } else { $trips }
    Write-Host '--- First Trip JSON ---'
    $firstTrip | ConvertTo-Json -Depth 5 | Write-Host
    Write-Host '--- First Trip Property Names ---'
    $firstTrip.PSObject.Properties.Name | ForEach-Object { Write-Host "PROP: $_" }
    Write-Host 'Trip access attempts:'
    Write-Host "firstTrip.id = " -NoNewline; try { Write-Host $firstTrip.id } catch { Write-Host '(error)' }
    Write-Host "firstTrip._id = " -NoNewline; try { Write-Host $firstTrip._id } catch { Write-Host '(error)' }
    Write-Host "firstTrip.routeId = " -NoNewline; try { Write-Host $firstTrip.routeId } catch { Write-Host '(error)' }
    Write-Host "firstTrip['_id'] = " -NoNewline; try { Write-Host $firstTrip['_id'] } catch { Write-Host '(error)' }

}
catch {
    Write-Host 'DEBUG ERROR:'
    Write-Host $_.Exception.ToString()
    if ($_.Exception.Response) {
        try { $sr = $_.Exception.Response.GetResponseStream(); if ($sr) { $r = New-Object System.IO.StreamReader($sr); $s=$r.ReadToEnd(); Write-Host 'RESPONSE BODY:'; Write-Host $s }} catch {}
    }
    exit 1
}
