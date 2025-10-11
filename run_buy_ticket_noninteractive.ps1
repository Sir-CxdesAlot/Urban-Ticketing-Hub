# Non-interactive script to register/login and buy a ticket
$ErrorActionPreference = 'Stop'
$base = 'http://localhost:8081/api/v1/passenger'
try {
    $regBody = @{ email = 'test.user+cli@example.com'; password = 'Test123!'; firstName = 'Test'; lastName = 'User'; phone = '555-0100' }
    $reg = Invoke-RestMethod -Method Post -Uri "$base/register" -ContentType 'application/json' -Body ($regBody | ConvertTo-Json -Depth 5)
    Write-Host 'REGISTER:'
    $reg | ConvertTo-Json -Depth 5 | Write-Host

    $loginBody = @{ email = $regBody.email; password = $regBody.password }
    $login = Invoke-RestMethod -Method Post -Uri "$base/login" -ContentType 'application/json' -Body ($loginBody | ConvertTo-Json -Depth 5)
    Write-Host 'LOGIN:'
    $login | ConvertTo-Json -Depth 5 | Write-Host

    $token = $null
    if ($login.token) { $token = $login.token }
    elseif ($login.data -and $login.data.token) { $token = $login.data.token }
    if (-not $token) { Write-Host 'Failed to obtain token'; exit 2 }
    Write-Host "TOKEN: $token"

    $routes = Invoke-RestMethod -Method Get -Uri 'http://localhost:8082/api/v1/transport/routes'
    Write-Host 'ROUTES:'
    $routes | ConvertTo-Json -Depth 5 | Write-Host
    if (-not $routes -or $routes.Count -eq 0) { Write-Host 'No routes found'; exit 3 }
    $firstRoute = if ($routes -is [array]) { $routes[0] } else { $routes }
    # Diagnostic: show properties and JSON of the selected route so we can see why ID extraction may fail
    Write-Host '--- Selected route object raw ---' -ForegroundColor DarkYellow
    try { $firstRoute | ConvertTo-Json -Depth 5 | Write-Host } catch { Write-Host $firstRoute }
    Write-Host '--- Selected route property names ---' -ForegroundColor DarkYellow
    Write-Host ($firstRoute.PSObject.Properties.Name -join ', ')

    # Support APIs that return either 'id' or '_id'
    $routeId = $null
    if ($firstRoute.PSObject.Properties.Name -contains 'id') { $routeId = $firstRoute.id }
    elseif ($firstRoute.PSObject.Properties.Name -contains '_id') { $routeId = $firstRoute._id }
    Write-Host "Using route ID: $routeId"

    # If routeId is empty, fetch trips unfiltered and pick the first available
    $tripsUri = if ($routeId) { "http://localhost:8082/api/v1/transport/trips?routeId=$routeId" } else { 'http://localhost:8082/api/v1/transport/trips' }
    $trips = Invoke-RestMethod -Method Get -Uri $tripsUri
    Write-Host 'TRIPS:'
    $trips | ConvertTo-Json -Depth 5 | Write-Host
    $trip = if ($trips -is [array]) { $trips[0] } else { $trips }
    # Diagnostic: show selected trip raw and property names
    Write-Host '--- Selected trip object raw ---' -ForegroundColor DarkYellow
    try { $trip | ConvertTo-Json -Depth 5 | Write-Host } catch { Write-Host $trip }
    Write-Host '--- Selected trip property names ---' -ForegroundColor DarkYellow
    Write-Host ($trip.PSObject.Properties.Name -join ', ')

    $tripId = $null
    if ($trip.PSObject.Properties.Name -contains 'id') { $tripId = $trip.id }
    elseif ($trip.PSObject.Properties.Name -contains '_id') { $tripId = $trip._id }
    Write-Host "Using trip ID: $tripId"

    # The Passenger service expects a TicketPurchase record with only routeId, ticketType and optional quantity.
    # Do not send tripId in the payload (closed record). Use the trip's routeId when available.
    $routeIdFromTrip = $null
    if ($trip.PSObject.Properties.Name -contains 'routeId') { $routeIdFromTrip = $trip.routeId }
    if (-not $routeIdFromTrip -and $routeId) { $routeIdFromTrip = $routeId }
    if (-not $routeIdFromTrip) { Write-Host 'No route id available to purchase for.' -ForegroundColor Red; exit 4 }
    $buyBody = @{ routeId = $routeIdFromTrip; ticketType = 'SINGLE' }
    $buy = Invoke-RestMethod -Method Post -Uri "$base/tickets" -Headers @{ Authorization = "Bearer $token" } -ContentType 'application/json' -Body ($buyBody | ConvertTo-Json -Depth 5)
    Write-Host 'BUY RESULT:'
    $buy | ConvertTo-Json -Depth 5 | Write-Host
}
catch {
    Write-Host 'ERROR:'
    Write-Host $_.Exception.ToString()
    if ($_.Exception.Response) {
        try {
            $sr = $_.Exception.Response.GetResponseStream()
            if ($sr) {
                $r = New-Object System.IO.StreamReader($sr)
                $s = $r.ReadToEnd()
                Write-Host 'RESPONSE BODY:'
                Write-Host $s
            }
        }
        catch {}
    }
    exit 1
}
