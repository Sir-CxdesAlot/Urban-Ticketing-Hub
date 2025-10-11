#!/usr/bin/env pwsh

# =============================================================================
# Urban Ticketing Hub - Data Initialization Script
# =============================================================================
# This script initializes sample data across all microservices
# =============================================================================

param(
    [string]$BaseUrl = "http://localhost",
    [switch]$Verbose = $false,
    [switch]$CleanStart = $false
)

# Configuration
$script:config = @{
    Services = @{
        Passenger    = "${BaseUrl}:8081"
        Transport    = "${BaseUrl}:8082"
        Ticketing    = "${BaseUrl}:8083"
        Payment      = "${BaseUrl}:8084"
        Notification = "${BaseUrl}:8085"
        Admin        = "${BaseUrl}:8086"
    }
    SampleData = @{
        Passengers = @(
            @{ email = "john.doe@example.com"; password = "JohnDoe123!"; firstName = "John"; lastName = "Doe"; phone = "+264811234567" }
            @{ email = "jane.smith@example.com"; password = "JaneSmith123!"; firstName = "Jane"; lastName = "Smith"; phone = "+264811234568" }
            @{ email = "mike.wilson@example.com"; password = "MikeWilson123!"; firstName = "Mike"; lastName = "Wilson"; phone = "+264811234569" }
            @{ email = "sarah.brown@example.com"; password = "SarahBrown123!"; firstName = "Sarah"; lastName = "Brown"; phone = "+264811234570" }
            @{ email = "david.jones@example.com"; password = "DavidJones123!"; firstName = "David"; lastName = "Jones"; phone = "+264811234571" }
        )
        AdminUsers = @(
            @{ username = "admin"; email = "admin@urbanticketing.com"; password = "Admin123!"; role = "SUPER_ADMIN" }
            @{ username = "transport_admin"; email = "transport@urbanticketing.com"; password = "Transport123!"; role = "TRANSPORT_ADMIN" }
            @{ username = "support_staff"; email = "support@urbanticketing.com"; password = "Support123!"; role = "SUPPORT_STAFF" }
        )
        Routes = @(
            @{ name = "Route 101: CBD to Katutura"; startLocation = "Independence Avenue"; endLocation = "Katutura"; intermediateStops = @("Wernhil Park", "Grove Mall", "Katutura Hospital"); transportType = "BUS"; basePrice = 8.50; isActive = $true }
            @{ name = "Route 202: Windhoek to Rehoboth"; startLocation = "Windhoek CBD"; endLocation = "Rehoboth"; intermediateStops = @("Brakwater", "Daan Viljoen"); transportType = "BUS"; basePrice = 35.00; isActive = $true }
            @{ name = "Route 303: Windhoek to Okahandja"; startLocation = "Windhoek CBD"; endLocation = "Okahandja"; intermediateStops = @("Hosea Kutako Airport", "Okahandja Park"); transportType = "BUS"; basePrice = 45.00; isActive = $true }
            @{ name = "Route 404: Klein Windhoek Circuit"; startLocation = "Klein Windhoek"; endLocation = "Klein Windhoek"; intermediateStops = @("Robert Mugabe Ave", "Nelson Mandela Ave", "Sam Nujoma Drive"); transportType = "BUS"; basePrice = 10.00; isActive = $true }
            @{ name = "Route 505: Airport Express"; startLocation = "Windhoek CBD"; endLocation = "Hosea Kutako Airport"; intermediateStops = @(); transportType = "SHUTTLE"; basePrice = 120.00; isActive = $true }
        )
        Disruptions = @(
            @{ routeId = ""; type = "DELAY"; title = "Traffic Congestion on Independence Avenue"; description = "Heavy traffic expected during morning rush hour"; startTime = "2025-10-11T07:00:00Z"; endTime = "2025-10-11T09:00:00Z" }
            @{ routeId = ""; type = "CANCELLATION"; title = "Route Maintenance"; description = "Scheduled maintenance on Rehoboth route"; startTime = "2025-10-12T10:00:00Z"; endTime = "2025-10-12T14:00:00Z" }
        )
    }
    CreatedIds = @{
        Passengers = @()
        Routes = @()
        Trips = @()
        Tickets = @()
        Payments = @()
        AdminUsers = @()
        Disruptions = @()
    }
}

# =============================================================================
# Utility Functions
# =============================================================================

function Write-Banner {
    param([string]$Title, [string]$Color = "Cyan")
    Write-Host "`n" -NoNewline
    Write-Host "="*70 -ForegroundColor $Color
    Write-Host " 🚀 $Title" -ForegroundColor Yellow
    Write-Host "="*70 -ForegroundColor $Color
}

function Write-Section {
    param([string]$Title)
    Write-Host "`n" -NoNewline
    Write-Host "─"*70 -ForegroundColor DarkCyan
    Write-Host " 📋 $Title" -ForegroundColor Cyan
    Write-Host "─"*70 -ForegroundColor DarkCyan
}

function Write-Step {
    param([string]$Message)
    Write-Host "  🔹 $Message" -ForegroundColor Blue
}

function Write-Success {
    param([string]$Message)
    Write-Host "  ✅ $Message" -ForegroundColor Green
}

function Write-Error {
    param([string]$Message)
    Write-Host "  ❌ $Message" -ForegroundColor Red
}

function Write-Info {
    param([string]$Message)
    Write-Host "  ℹ️  $Message" -ForegroundColor Gray
}

function Invoke-ApiCall {
    param(
        [string]$Method,
        [string]$Url,
        [object]$Body = $null,
        [hashtable]$Headers = @{},
        [switch]$RawResponse = $false
    )

    $curlArgs = @("-s", "-X", $Method, "-H", "Content-Type: application/json")

    foreach ($header in $Headers.GetEnumerator()) {
        $curlArgs += "-H"
        $curlArgs += "$($header.Key): $($header.Value)"
    }

    if ($Body) {
        $jsonBody = $Body | ConvertTo-Json -Depth 10 -Compress
        $curlArgs += "-d"
        $curlArgs += $jsonBody
    }

    $curlArgs += $Url

    if ($Verbose) {
        Write-Host "    curl $($curlArgs -join ' ')" -ForegroundColor DarkGray
    }

    try {
        $result = & curl @curlArgs 2>$null
        if ($RawResponse) {
            return @{ Success = $true; Data = $result; Raw = $true }
        }
        $jsonResult = $result | ConvertFrom-Json
        return @{ Success = $true; Data = $jsonResult }
    }
    catch {
        return @{ Success = $false; Error = $_.Exception.Message }
    }
}

# =============================================================================
# Health Check Functions
# =============================================================================

function Test-ServiceHealth {
    Write-Section "HEALTH CHECKS"
    
    $allHealthy = $true
    foreach ($service in $script:config.Services.GetEnumerator()) {
        Write-Step "Checking $($service.Key) service health"
        
        $healthUrl = "$($service.Value)/api/v1/$($service.Key.ToLower())/health"
        $result = Invoke-ApiCall -Method GET -Url $healthUrl -RawResponse
        
        if ($result.Success) {
            Write-Success "$($service.Key) service is healthy"
        } else {
            Write-Error "$($service.Key) service is not responding"
            $allHealthy = $false
        }
    }
    
    if (-not $allHealthy) {
        Write-Error "Some services are not healthy. Please ensure all services are running."
        exit 1
    }
}

# =============================================================================
# Data Initialization Functions
# =============================================================================

function Initialize-Passengers {
    Write-Section "INITIALIZING PASSENGERS"
    
    foreach ($passenger in $script:config.SampleData.Passengers) {
        Write-Step "Creating passenger: $($passenger.email)"
        
        $result = Invoke-ApiCall -Method POST -Url "$($script:config.Services.Passenger)/api/v1/passenger/register" -Body $passenger
        
        if ($result.Success) {
            if ($result.Data.id) {
                $script:config.CreatedIds.Passengers += @{
                    Id = $result.Data.id
                    Email = $passenger.email
                    Name = "$($passenger.firstName) $($passenger.lastName)"
                    Password = $passenger.password
                }
                Write-Success "Passenger created: $($passenger.firstName) $($passenger.lastName) (ID: $($result.Data.id))"
            } elseif ($result.Data.message -match "already exists") {
                Write-Info "Passenger already exists: $($passenger.email) - attempting login to get ID"
                
                # Try to login to get the user ID
                $loginResult = Invoke-ApiCall -Method POST -Url "$($script:config.Services.Passenger)/api/v1/passenger/login" -Body @{
                    email = $passenger.email
                    password = $passenger.password
                }
                
                if ($loginResult.Success -and $loginResult.Data.user.id) {
                    $script:config.CreatedIds.Passengers += @{
                        Id = $loginResult.Data.user.id
                        Email = $passenger.email
                        Name = "$($passenger.firstName) $($passenger.lastName)"
                        Password = $passenger.password
                    }
                    Write-Success "Retrieved existing passenger: $($passenger.firstName) $($passenger.lastName) (ID: $($loginResult.Data.user.id))"
                }
            } else {
                Write-Success "Passenger registered: $($passenger.firstName) $($passenger.lastName)"
            }
        } else {
            Write-Error "Failed to create passenger: $($result.Error)"
        }
    }
    
    Write-Info "Total passengers initialized: $($script:config.CreatedIds.Passengers.Count)"
}

function Initialize-AdminUsers {
    Write-Section "INITIALIZING ADMIN USERS"
    
    foreach ($admin in $script:config.SampleData.AdminUsers) {
        Write-Step "Creating admin user: $($admin.username)"
        
        $result = Invoke-ApiCall -Method POST -Url "$($script:config.Services.Admin)/api/v1/admin/admin-users" -Body $admin
        
        if ($result.Success) {
            if ($result.Data.adminId) {
                $script:config.CreatedIds.AdminUsers += @{
                    Id = $result.Data.adminId
                    Username = $admin.username
                    Role = $admin.role
                }
                Write-Success "Admin user created: $($admin.username) (Role: $($admin.role))"
            } else {
                Write-Info "Admin user response: $($result.Data.message)"
            }
        } else {
            Write-Error "Failed to create admin user: $($result.Error)"
        }
    }
    
    Write-Info "Total admin users initialized: $($script:config.CreatedIds.AdminUsers.Count)"
}

function Initialize-Routes {
    Write-Section "INITIALIZING TRANSPORT ROUTES"
    
    # First, get existing routes to avoid duplicates
    $existingRoutes = Invoke-ApiCall -Method GET -Url "$($script:config.Services.Transport)/api/v1/transport/routes"
    $existingRouteNames = @()
    
    if ($existingRoutes.Success -and $existingRoutes.Data) {
        $existingRouteNames = $existingRoutes.Data | ForEach-Object { $_.name }
        Write-Info "Found $($existingRouteNames.Count) existing routes in system"
        if ($Verbose) {
            Write-Host "    Existing routes: $($existingRouteNames -join ', ')" -ForegroundColor DarkGray
        }
    }
    
    $createdCount = 0
    $createdRouteIds = @()
    
    foreach ($route in $script:config.SampleData.Routes) {
        # Skip if route already exists
        if ($existingRouteNames -contains $route.name) {
            Write-Info "Route already exists, skipping: $($route.name)"
            continue
        }
        
        Write-Step "Creating route: $($route.name)"

        # Build explicit route payload including fields expected by the transport service
        $routePayload = @{
            name = $route.name
            startLocation = $route.startLocation
            endLocation = $route.endLocation
            intermediateStops = $route.intermediateStops
            transportType = $route.transportType
            basePrice = $route.basePrice
            isActive = $true
            createdAt = (Get-Date).ToUniversalTime().ToString("o")
            updatedAt = (Get-Date).ToUniversalTime().ToString("o")
        }

        $result = Invoke-ApiCall -Method POST -Url "$($script:config.Services.Transport)/api/v1/transport/routes" -Body $routePayload
        
            if ($result.Success -and $result.Data) {
            $createdCount++
            
            if ($Verbose) {
                Write-Host "    Create response: $($result.Data | ConvertTo-Json -Compress)" -ForegroundColor DarkGray
            }
            
            # Try multiple possible ID fields and store immediately
            $routeId = $null
            if ($result.Data._id) { 
                $routeId = $result.Data._id.ToString()
            } elseif ($result.Data.id) { 
                $routeId = $result.Data.id.ToString()
            } elseif ($result.Data.routeId) { 
                $routeId = $result.Data.routeId.ToString()
            }
            
            if ($routeId) {
                $createdRouteIds += $routeId
                Write-Success "Route created: $($route.name) (ID: $routeId)"
                
                # Immediately try to fetch this specific route to verify it exists
                if ($Verbose) {
                    $verifyResult = Invoke-ApiCall -Method GET -Url "$($script:config.Services.Transport)/api/v1/transport/routes/$routeId"
                    if ($verifyResult.Success) {
                        Write-Host "    ✓ Verified route exists in database" -ForegroundColor DarkGreen
                    } else {
                        Write-Host "    ✗ Could not verify route in database" -ForegroundColor DarkRed
                    }
                }
            } else {
                Write-Info "Route created but ID not returned: $($route.name) -- attempting to resolve by name"

                # Fallback: fetch all routes and try to find the created route by name (service returns full list with _id)
                $resolveResult = Invoke-ApiCall -Method GET -Url "$($script:config.Services.Transport)/api/v1/transport/routes"
                if ($resolveResult.Success -and $resolveResult.Data) {
                    $candidates = if ($resolveResult.Data -is [array]) { $resolveResult.Data } else { @($resolveResult.Data) }
                    $matching = $candidates | Where-Object { ($_.'name' -eq $route.name) -or ($_['name'] -eq $route.name) }
                    if ($matching -and $matching.Count -gt 0) {
                        # Prefer _id, then id, then routeId
                        $found = $matching[0]
                        $foundId = $null
                        if ($found._id) { $foundId = $found._id }
                        elseif ($found.id) { $foundId = $found.id }
                        elseif ($found.routeId) { $foundId = $found.routeId }

                        if ($foundId) {
                            $createdRouteIds += $foundId
                            Write-Success "Resolved route by name: $($route.name) (ID: $foundId)"
                        } else {
                            Write-Info "Could not extract ID from resolved route for: $($route.name)"
                        }
                    } else {
                        Write-Info "Could not find created route by name in GET /routes response: $($route.name)"
                    }
                } else {
                    Write-Info "Failed to fetch routes to resolve ID for: $($route.name)"
                }
            }
        } else {
            Write-Error "Failed to create route: $($result.Error)"
        }
        
        # Delay to ensure MongoDB has time to persist
        Start-Sleep -Milliseconds 300
    }
    
    if ($createdCount -gt 0) {
        Write-Info "Created $createdCount new routes with IDs: $($createdRouteIds -join ', ')"
        Write-Info "Waiting for database sync..."
        Start-Sleep -Seconds 2
    }
    
    # Strategy 1: Try to fetch all routes
    Write-Info "Fetching all routes from service..."
    $allRoutes = Invoke-ApiCall -Method GET -Url "$($script:config.Services.Transport)/api/v1/transport/routes"
    
    if ($Verbose -and $allRoutes.Success) {
        Write-Host "    Raw routes response type: $($allRoutes.Data.GetType().Name)" -ForegroundColor DarkGray
        Write-Host "    Is array: $($allRoutes.Data -is [array])" -ForegroundColor DarkGray
        Write-Host "    Raw routes response: $($allRoutes.Data | ConvertTo-Json -Depth 5)" -ForegroundColor DarkGray
    }
    
    # Clear route list
    $script:config.CreatedIds.Routes = @()
    
    if ($allRoutes.Success -and $allRoutes.Data) {
        # Handle both array and single object responses
        $routeData = if ($allRoutes.Data -is [array]) { $allRoutes.Data } else { @($allRoutes.Data) }
        
        Write-Info "Processing $($routeData.Count) routes from GET /routes response..."
        
        foreach ($fetchedRoute in $routeData) {
            $routeId = if ($fetchedRoute._id) { $fetchedRoute._id } elseif ($fetchedRoute.id) { $fetchedRoute.id } else { $null }
            
            if ($routeId) {
                $script:config.CreatedIds.Routes += @{
                    Id = $routeId
                    Name = $fetchedRoute.name
                    StartLocation = $fetchedRoute.startLocation
                    EndLocation = $fetchedRoute.endLocation
                }
                
                if ($Verbose) {
                    Write-Host "    Added route: $($fetchedRoute.name) (ID: $routeId)" -ForegroundColor DarkGray
                }
            }
        }
    }
    
    # Strategy 2: If GET all routes didn't work well, try individual GET requests for created IDs
    if ($script:config.CreatedIds.Routes.Count -lt $createdRouteIds.Count) {
        Write-Info "GET all routes returned fewer routes than created. Trying individual fetches..."
        
        foreach ($routeId in $createdRouteIds) {
            # Skip if we already have this route
            if ($script:config.CreatedIds.Routes | Where-Object { $_.Id -eq $routeId }) {
                continue
            }
            
            $individualRoute = Invoke-ApiCall -Method GET -Url "$($script:config.Services.Transport)/api/v1/transport/routes/$routeId"
            
            if ($individualRoute.Success -and $individualRoute.Data) {
                $script:config.CreatedIds.Routes += @{
                    Id = $routeId
                    Name = $individualRoute.Data.name
                    StartLocation = $individualRoute.Data.startLocation
                    EndLocation = $individualRoute.Data.endLocation
                }
                Write-Success "Fetched route individually: $($individualRoute.Data.name)"
            }
            
            Start-Sleep -Milliseconds 100
        }
    }
    
    Write-Success "Successfully collected $($script:config.CreatedIds.Routes.Count) routes"
    Write-Info "Total routes available: $($script:config.CreatedIds.Routes.Count)"
}

function Initialize-Trips {
    Write-Section "INITIALIZING TRIPS"
    
    if ($script:config.CreatedIds.Routes.Count -eq 0) {
        Write-Info "No routes available. Skipping trip initialization."
        return
    }
    
    $now = Get-Date
    $tripTimes = @(
        @{ Offset = 0; Label = "Current time" }
        @{ Offset = 2; Label = "2 hours from now" }
        @{ Offset = 4; Label = "4 hours from now" }
        @{ Offset = 24; Label = "Tomorrow" }
        @{ Offset = 48; Label = "Day after tomorrow" }
    )
    
    foreach ($route in $script:config.CreatedIds.Routes) {
        Write-Step "Creating trips for route: $($route.Name)"
        
        $tripCount = 0
        foreach ($time in $tripTimes) {
            $departureTime = $now.AddHours($time.Offset).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
            $arrivalTime = $now.AddHours($time.Offset + 2).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
            
            $trip = @{
                routeId = $route.Id
                departureTime = $departureTime
                arrivalTime = $arrivalTime
                totalSeats = 40
                availableSeats = 40
            }
            
            $result = Invoke-ApiCall -Method POST -Url "$($script:config.Services.Transport)/api/v1/transport/trips" -Body $trip
            
            if ($result.Success -and $result.Data) {
                $tripId = if ($result.Data._id) { $result.Data._id } elseif ($result.Data.id) { $result.Data.id } else { $null }
                
                if ($tripId) {
                    $script:config.CreatedIds.Trips += @{
                        Id = $tripId
                        RouteId = $route.Id
                        RouteName = $route.Name
                        DepartureTime = $departureTime
                    }
                    $tripCount++
                }
            } else {
                if ($Verbose) {
                    Write-Host "    Trip creation failed: $($result.Error)" -ForegroundColor DarkGray
                }
            }
            
            # Small delay between trip creations
            Start-Sleep -Milliseconds 50
        }
        
        if ($tripCount -gt 0) {
            Write-Success "Created $tripCount trips for $($route.Name)"
        } else {
            Write-Info "No trips created for $($route.Name)"
        }
    }
    
    Write-Info "Total trips initialized: $($script:config.CreatedIds.Trips.Count)"
}

function Initialize-Tickets {
    Write-Section "INITIALIZING SAMPLE TICKETS"
    
    if ($script:config.CreatedIds.Passengers.Count -eq 0 -or $script:config.CreatedIds.Routes.Count -eq 0) {
        Write-Info "No passengers or routes available. Skipping ticket initialization."
        return
    }
    
    $ticketTypes = @("SINGLE", "RETURN", "MONTHLY_PASS")
    
    for ($i = 0; $i -lt [Math]::Min(10, $script:config.CreatedIds.Passengers.Count * 2); $i++) {
        $passenger = $script:config.CreatedIds.Passengers[$i % $script:config.CreatedIds.Passengers.Count]
        $route = $script:config.CreatedIds.Routes[$i % $script:config.CreatedIds.Routes.Count]
        $trip = if ($script:config.CreatedIds.Trips.Count -gt 0) { 
            $script:config.CreatedIds.Trips[$i % $script:config.CreatedIds.Trips.Count] 
        } else { 
            $null 
        }
        
        Write-Step "Creating ticket for: $($passenger.Name)"
        
        $ticket = @{
            passengerId = $passenger.Id
            routeId = $route.Id
            tripId = if ($trip) { $trip.Id } else { "trip-default" }
            ticketType = $ticketTypes[$i % $ticketTypes.Count]
            price = [Math]::Round((Get-Random -Minimum 50 -Maximum 200) / 10.0, 2)
        }
        
        $result = Invoke-ApiCall -Method POST -Url "$($script:config.Services.Ticketing)/api/v1/ticketing/tickets" -Body $ticket
        
        if ($result.Success -and $result.Data -and $result.Data.id) {
            $script:config.CreatedIds.Tickets += @{
                Id = $result.Data.id
                PassengerId = $passenger.Id
                RouteId = $route.Id
                Type = $ticket.ticketType
            }
            Write-Success "Ticket created: $($ticket.ticketType) for $($passenger.Name)"
        }
    }
    
    Write-Info "Total tickets initialized: $($script:config.CreatedIds.Tickets.Count)"
}

function Initialize-Payments {
    Write-Section "INITIALIZING SAMPLE PAYMENTS"
    
    if ($script:config.CreatedIds.Tickets.Count -eq 0) {
        Write-Info "No tickets available. Skipping payment initialization."
        return
    }
    
    $paymentMethods = @("CARD", "MOBILE_MONEY", "CASH", "DIGITAL_WALLET")
    
    foreach ($ticket in $script:config.CreatedIds.Tickets) {
        Write-Step "Creating payment for ticket: $($ticket.Id)"
        
        $paymentAmount = [Math]::Round((Get-Random -Minimum 50 -Maximum 200) / 10.0, 2)
        
        $payment = @{
            ticketId = $ticket.Id
            passengerId = $ticket.PassengerId
            amount = $paymentAmount
            method = $paymentMethods[(Get-Random -Minimum 0 -Maximum $paymentMethods.Count)]
            paymentDetails = @{
                cardNumber = "4111111111111111"
                expiryMonth = "12"
                expiryYear = "30"
                cvv = "123"
            }
        }
        
        $result = Invoke-ApiCall -Method POST -Url "$($script:config.Services.Payment)/api/v1/payment/payments" -Body $payment
        
        if ($result.Success -and $result.Data -and $result.Data.id) {
            $script:config.CreatedIds.Payments += @{
                Id = $result.Data.id
                TicketId = $ticket.Id
                Amount = $paymentAmount
                Method = $payment.method
            }
            Write-Success "Payment created: $($payment.method) - N`$paymentAmount"
        }
    }
    
    Write-Info "Total payments initialized: $($script:config.CreatedIds.Payments.Count)"
}

function Initialize-Disruptions {
    Write-Section "INITIALIZING SERVICE DISRUPTIONS"
    
    if ($script:config.CreatedIds.Routes.Count -eq 0) {
        Write-Info "No routes available. Creating disruptions without specific routes."
    }
    
    foreach ($disruption in $script:config.SampleData.Disruptions) {
        if ($script:config.CreatedIds.Routes.Count -gt 0) {
            $disruption.routeId = $script:config.CreatedIds.Routes[0].Id
        } else {
            $disruption.routeId = "route-default"
        }
        
        Write-Step "Creating disruption: $($disruption.title)"
        
        $result = Invoke-ApiCall -Method POST -Url "$($script:config.Services.Admin)/api/v1/admin/disruptions" -Body $disruption
        
        if ($result.Success -and $result.Data -and $result.Data.id) {
            $script:config.CreatedIds.Disruptions += @{
                Id = $result.Data.id
                Title = $disruption.title
                Type = $disruption.type
            }
            Write-Success "Disruption created: $($disruption.title)"
        }
    }
    
    Write-Info "Total disruptions initialized: $($script:config.CreatedIds.Disruptions.Count)"
}

function Initialize-Notifications {
    Write-Section "INITIALIZING SAMPLE NOTIFICATIONS"
    
    if ($script:config.CreatedIds.Passengers.Count -eq 0) {
        Write-Info "No passengers available. Skipping notification initialization."
        return
    }
    
    $notificationTypes = @("TICKET_CONFIRMATION", "PAYMENT_RECEIVED", "TRIP_REMINDER", "SERVICE_DISRUPTION", "PROMOTION")
    $notificationCount = 0
    
    foreach ($passenger in $script:config.CreatedIds.Passengers) {
        for ($i = 0; $i -lt 2; $i++) {
            $type = $notificationTypes[(Get-Random -Minimum 0 -Maximum $notificationTypes.Count)]
            
            $notification = @{
                recipientId = $passenger.Id
                type = $type
                title = "Notification for $($passenger.Name)"
                message = "This is a sample $type notification"
                metadata = @{
                    source = "DataInit"
                    timestamp = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ssZ")
                }
            }
            
            $result = Invoke-ApiCall -Method POST -Url "$($script:config.Services.Notification)/api/v1/notification/notifications" -Body $notification
            
            if ($result.Success -and $result.Data -and $result.Data.id) {
                $notificationCount++
            }
        }
    }
    
    Write-Info "Total notifications initialized: $notificationCount"
}

# =============================================================================
# Summary Function
# =============================================================================

function Show-Summary {
    Write-Banner "DATA INITIALIZATION COMPLETE" "Green"
    
    Write-Host "`n📊 " -NoNewline -ForegroundColor Green
    Write-Host "Initialization Summary:" -ForegroundColor Yellow
    Write-Host "   👥 Passengers:        $($script:config.CreatedIds.Passengers.Count)" -ForegroundColor White
    Write-Host "   👨‍💼 Admin Users:       $($script:config.CreatedIds.AdminUsers.Count)" -ForegroundColor White
    Write-Host "   🚌 Routes:            $($script:config.CreatedIds.Routes.Count)" -ForegroundColor White
    Write-Host "   🚏 Trips:             $($script:config.CreatedIds.Trips.Count)" -ForegroundColor White
    Write-Host "   🎫 Tickets:           $($script:config.CreatedIds.Tickets.Count)" -ForegroundColor White
    Write-Host "   💳 Payments:          $($script:config.CreatedIds.Payments.Count)" -ForegroundColor White
    Write-Host "   ⚠️  Disruptions:       $($script:config.CreatedIds.Disruptions.Count)" -ForegroundColor White
    
    Write-Host "`n🎯 " -NoNewline -ForegroundColor Green
    Write-Host "Sample Credentials:" -ForegroundColor Yellow
    Write-Host "   Passenger: john.doe@example.com / JohnDoe123!" -ForegroundColor Cyan
    Write-Host "   Admin:     admin / Admin123!" -ForegroundColor Cyan
    
    Write-Host "`n🚀 " -NoNewline -ForegroundColor Green
    Write-Host "Next Steps:" -ForegroundColor Yellow
    Write-Host "   • Run './test-apis.ps1' to test all APIs" -ForegroundColor White
    Write-Host "   • Access service health endpoints to verify status" -ForegroundColor White
    Write-Host "   • Check Kafka UI at http://localhost:9000" -ForegroundColor White
    Write-Host "   • Monitor logs: docker compose logs -f <service-name>" -ForegroundColor White
    
    Write-Host "`n" -NoNewline
    Write-Host "="*70 -ForegroundColor Green
}

# =============================================================================
# Main Execution
# =============================================================================

function Main {
    Write-Banner "URBAN TICKETING HUB - DATA INITIALIZATION"
    Write-Host "🎬 Starting data initialization process..." -ForegroundColor Green
    Write-Host "📅 $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
    Write-Host "🌍 Base URL: $BaseUrl" -ForegroundColor Gray
    
    try {
        # Check health of all services
        Test-ServiceHealth
        
        # Initialize data in proper order
        Initialize-AdminUsers
        Initialize-Passengers
        Initialize-Routes
        Initialize-Trips
        Initialize-Tickets
        Initialize-Payments
        Initialize-Disruptions
        Initialize-Notifications
        
        # Show summary
        Show-Summary
        
        Write-Host "`n✨ Data initialization completed successfully!" -ForegroundColor Green
    }
    catch {
        Write-Banner "DATA INITIALIZATION FAILED" "Red"
        Write-Error "Fatal error during data initialization: $($_.Exception.Message)"
        Write-Host $_.ScriptStackTrace -ForegroundColor Red
        exit 1
    }
}

# Run main function
Main