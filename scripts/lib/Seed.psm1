#Requires -Version 7.2
Import-Module (Join-Path $PSScriptRoot 'Common.psm1') -DisableNameChecking
Import-Module (Join-Path $PSScriptRoot 'Operations.psm1') -DisableNameChecking

function Initialize-UthDemo {
    param($Context)
    $root = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
    $environment = Get-UthEnvironment
    $adminLogin = (Invoke-UthRequest -Context $Context -Service passenger -Path /login -Method POST -Body @{
        email = $environment.UTH_ADMIN_EMAIL; password = $environment.UTH_ADMIN_PASSWORD
    }).Data
    $adminToken = $adminLogin['token']
    $credentialsPath = Join-Path $root '.runtime/demo-credentials.json'
    if (Test-Path -LiteralPath $credentialsPath) {
        $credentials = Get-Content -LiteralPath $credentialsPath -Raw | ConvertFrom-Json -AsHashtable
    } else {
        $credentials = @()
        foreach ($spec in @(
            @('operator','ROUTE_OPERATOR'), @('operator2','ROUTE_OPERATOR'), @('manager','TRANSPORT_MANAGER'),
            @('john','PASSENGER'), @('jane','PASSENGER'), @('mike','PASSENGER'), @('sarah','PASSENGER'), @('david','PASSENGER')
        )) {
            $credentials += @{
                email = "$($spec[0])@uth.local"; role = $spec[1]; firstName = $spec[0]; lastName = 'Demo'
                phone = '+264810000000'; password = [Convert]::ToHexString([Security.Cryptography.RandomNumberGenerator]::GetBytes(18))
            }
        }
        $credentials | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $credentialsPath -Encoding utf8
    }
    $accounts = @(Get-UthItems -Context $Context -Service admin -Path /accounts -Token $adminToken)
    $passengers = @()
    foreach ($account in $credentials) {
        $match = @($accounts | Where-Object { $_['email'] -eq $account['email'] })
        if ($match.Count -eq 0) {
            $body = $account.Clone()
            if ($account['role'] -eq 'PASSENGER') {
                $body.Remove('role')
                $created = (Invoke-UthRequest -Context $Context -Service passenger -Path /register -Method POST -Body $body).Data
            } else {
                $created = (Invoke-UthRequest -Context $Context -Service admin -Path /accounts -Method POST -Token $adminToken -Body $body).Data
            }
            $accounts += $created
        }
        if ($account['role'] -eq 'PASSENGER') {
            $login = (Invoke-UthRequest -Context $Context -Service passenger -Path /login -Method POST -Body @{
                email = $account['email']; password = $account['password']
            }).Data
            $passengers += $login
        }
    }
    $operator = @($accounts | Where-Object { $_['email'] -eq 'operator@uth.local' })[0]
    $fixtures = Get-Content (Join-Path $PSScriptRoot '../demo-data.json') -Raw | ConvertFrom-Json -AsHashtable
    $existingRoutes = @(Get-UthItems -Context $Context -Service transport -Path /routes)
    $routes = @()
    foreach ($body in $fixtures['routes']) {
        $matches = @($existingRoutes | Where-Object { $_['name'] -eq $body['name'] })
        $route = if ($matches.Count) { $matches[0] } else {
            (Invoke-UthRequest -Context $Context -Service transport -Path /routes -Method POST -Token $adminToken -Body $body).Data
        }
        $routes += $route
    }
    $existingTrips = @(Get-UthItems -Context $Context -Service transport -Path /trips)
    $trips = @()
    $newTrips = 0
    $day = [datetime]::UtcNow.Date.AddDays(1)
    foreach ($route in $routes) {
        foreach ($hour in 8,10,12,32,56) {
            $departure = $day.AddHours($hour)
            $matches = @($existingTrips | Where-Object {
                $_['routeId'] -eq $route['id'] -and ([datetimeoffset]$_['departureTime']).UtcDateTime.Ticks -eq $departure.Ticks
            })
            $trip = if ($matches.Count) { $matches[0] } else {
                $newTrips++
                (Invoke-UthRequest -Context $Context -Service transport -Path /trips -Method POST -Token $adminToken -Body @{
                    routeId = $route['id']; operatorId = $operator['id']; capacity = 40
                    departureTime = $departure.ToString('yyyy-MM-ddTHH:mm:ssZ'); arrivalTime = $departure.AddHours(1).ToString('yyyy-MM-ddTHH:mm:ssZ')
                }).Data
            }
            $trips += $trip
        }
    }
    $index = 0
    foreach ($product in 'SINGLE','TEN_RIDE','MONTHLY') {
        $passenger = $passengers[$index]
        $checkout = (Invoke-UthRequest -Context $Context -Service ticketing -Path /checkout -Method POST -Token $passenger['token'] -Body @{
            tripId = $trips[$index]['id']; ticketType = $product; requestKey = "seed-v2-$($day.ToString('yyyyMMdd'))-$product"
        }).Data
        Invoke-UthRequest -Context $Context -Service payment -Path /payments -Method POST -Token $passenger['token'] -Body @{
            ticketId = $checkout['ticket']['id']; requestKey = "seed-pay-v2-$($day.ToString('yyyyMMdd'))-$product"
        } | Out-Null
        $index++
    }
    if ($newTrips -gt 0) {
        Invoke-UthRequest -Context $Context -Service notification -Path /broadcasts -Method POST -Token $adminToken -Body @{
            message = 'Welcome to Windhoek Ticketing. Demo routes and trips are ready.'
        } | Out-Null
    }
    Write-Host "Demo ready: $($routes.Count) routes, $($trips.Count) trips, three ticket product fixtures. Existing ticket states were preserved."
    Write-Host "Generated passenger/staff credentials: $credentialsPath"
    Write-Host 'Bootstrap administrator credentials remain in .env. No account passwords were reset.'
}

Export-ModuleMember -Function Initialize-UthDemo
