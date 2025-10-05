#!/usr/bin/env pwsh

# =============================================================================
# Windhoek Ticketing Platform - Admin CLI
# =============================================================================
# Interactive command-line interface for administrators
# Features: Route/trip management, disruptions, reports, monitoring
# =============================================================================

param(
    [string]$BaseUrl = "http://localhost"
)

# Configuration
$script:Config = @{
    AdminService = "${BaseUrl}:8086"
    TransportService = "${BaseUrl}:8082"
    TicketingService = "${BaseUrl}:8083"
}

# Session state
$script:Session = @{
    LoggedIn = $false
    Token = $null
    Admin = $null
    Username = $null
}

# Colors and UI
function Write-Header {
    param([string]$Text)
    Clear-Host
    Write-Host ""
    Write-Host "="*80 -ForegroundColor Cyan
    Write-Host "  🏛️  WINDHOEK TICKETING PLATFORM - ADMIN PORTAL" -ForegroundColor Yellow
    Write-Host "="*80 -ForegroundColor Cyan
    if ($script:Session.LoggedIn) {
        Write-Host "  👤 Logged in as: $($script:Session.Username) ($($script:Session.Admin.role))" -ForegroundColor Green
    } else {
        Write-Host "  👤 Not logged in" -ForegroundColor Yellow
    }
    Write-Host "="*80 -ForegroundColor Cyan
    if ($Text) {
        Write-Host "  $Text" -ForegroundColor White
        Write-Host ""
    }
}

function Write-Success {
    param([string]$Message)
    Write-Host "✅ $Message" -ForegroundColor Green
}

function Write-Error {
    param([string]$Message)
    Write-Host "❌ $Message" -ForegroundColor Red
}

function Write-Info {
    param([string]$Message)
    Write-Host "ℹ️  $Message" -ForegroundColor Cyan
}

function Pause-Screen {
    Write-Host ""
    Write-Host "Press any key to continue..." -ForegroundColor Gray
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

# API Helpers
function Invoke-API {
    param(
        [string]$Url,
        [string]$Method = "GET",
        [object]$Body = $null,
        [bool]$UseAuth = $false
    )
    
    try {
        $headers = @{
            "Content-Type" = "application/json"
        }
        
        if ($UseAuth -and $script:Session.Token) {
            $headers["Authorization"] = "Bearer $($script:Session.Token)"
        }
        
        $params = @{
            Uri = $Url
            Method = $Method
            Headers = $headers
            TimeoutSec = 30
        }
        
        if ($Body) {
            $params.Body = ($Body | ConvertTo-Json -Depth 10)
        }
        
        $response = Invoke-RestMethod @params
        return $response
    }
    catch {
        throw $_.Exception.Message
    }
}

# Authentication
function Show-LoginMenu {
    Write-Header "ADMIN LOGIN"
    
    $username = Read-Host "Username"
    $password = Read-Host "Password" -AsSecureString
    $passwordPlain = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto(
        [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($password)
    )
    
    Write-Host ""
    Write-Host "Logging in..." -ForegroundColor Yellow
    
    try {
        $body = @{
            username = $username
            password = $passwordPlain
        }
        
        $response = Invoke-API -Url "$($script:Config.AdminService)/api/v1/admin/login" `
                               -Method "POST" -Body $body
        
        $script:Session.LoggedIn = $true
        $script:Session.Token = $response.token
        $script:Session.Admin = $response.admin
        $script:Session.Username = $username
        
        Write-Success "Login successful! Welcome, $username!"
        Start-Sleep -Seconds 2
    }
    catch {
        Write-Error "Login failed: $_"
        Pause-Screen
    }
}

# Dashboard
function Show-Dashboard {
    Write-Header "ADMIN DASHBOARD"
    
    if (-not $script:Session.LoggedIn) {
        Write-Error "You must be logged in"
        Pause-Screen
        return
    }
    
    try {
        $dashboard = Invoke-API -Url "$($script:Config.AdminService)/api/v1/admin/dashboard" `
                                -UseAuth $true
        
        Write-Host "📊 System Overview:" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "  Total Passengers: $($dashboard.totalPassengers)" -ForegroundColor White
        Write-Host "  Active Routes: $($dashboard.activeRoutes)" -ForegroundColor White
        Write-Host "  Tickets Sold Today: $($dashboard.ticketsSoldToday)" -ForegroundColor Green
        Write-Host "  Revenue Today: N`$$($dashboard.revenueToday)" -ForegroundColor Green
        Write-Host "  Active Disruptions: $($dashboard.activeDisruptions)" -ForegroundColor Yellow
        Write-Host ""
        
        Pause-Screen
    }
    catch {
        Write-Error "Failed to load dashboard: $_"
        Pause-Screen
    }
}

# Route Management
function Show-Routes {
    Write-Header "MANAGE ROUTES"
    
    try {
        $routes = Invoke-API -Url "$($script:Config.TransportService)/api/v1/transport/routes"
        
        if ($routes.Count -eq 0) {
            Write-Info "No routes in the system"
        } else {
            Write-Host "🚌 All Routes:" -ForegroundColor Cyan
            Write-Host ""
            
            $index = 1
            foreach ($route in $routes) {
                $status = if ($route.isActive) { "🟢 Active" } else { "🔴 Inactive" }
                
                Write-Host "  [$index] $($route.name)" -ForegroundColor Yellow
                Write-Host "      $($route.startLocation) → $($route.endLocation)" -ForegroundColor White
                Write-Host "      Type: $($route.transportType) | Price: N`$$($route.basePrice)" -ForegroundColor White
                Write-Host "      Status: $status" -ForegroundColor White
                Write-Host ""
                $index++
            }
        }
        
        Pause-Screen
    }
    catch {
        Write-Error "Failed to load routes: $_"
        Pause-Screen
    }
}

function Show-CreateRoute {
    Write-Header "CREATE NEW ROUTE"
    
    if (-not $script:Session.LoggedIn) {
        Write-Error "You must be logged in"
        Pause-Screen
        return
    }
    
    Write-Host "Enter route details:" -ForegroundColor Cyan
    Write-Host ""
    
    $name = Read-Host "Route Name (e.g., 'City Center - Airport')"
    $startLocation = Read-Host "Start Location"
    $endLocation = Read-Host "End Location"
    $stopsInput = Read-Host "Intermediate Stops (comma-separated)"
    $stops = $stopsInput -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ }
    $transportType = Read-Host "Transport Type (BUS/TRAIN)"
    $basePrice = Read-Host "Base Price (N$)"
    
    Write-Host ""
    Write-Host "Creating route..." -ForegroundColor Yellow
    
    try {
        $body = @{
            name = $name
            startLocation = $startLocation
            endLocation = $endLocation
            intermediateStops = $stops
            transportType = $transportType.ToUpper()
            basePrice = [decimal]$basePrice
            isActive = $true
            createdAt = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
        }
        
        $response = Invoke-API -Url "$($script:Config.TransportService)/api/v1/transport/routes" `
                               -Method "POST" -Body $body
        
        Write-Success "Route '$name' created successfully!"
        Pause-Screen
    }
    catch {
        Write-Error "Failed to create route: $_"
        Pause-Screen
    }
}

# Trip Management
function Show-Trips {
    Write-Header "MANAGE TRIPS"
    
    try {
        # Fetch trips and routes
        $trips = Invoke-API -Url "$($script:Config.TransportService)/api/v1/transport/trips"
        $routes = Invoke-API -Url "$($script:Config.TransportService)/api/v1/transport/routes"
        
        if ($trips.Count -eq 0) {
            Write-Info "No trips scheduled"
        } else {
            Write-Host "🕐 All Trips by Route:" -ForegroundColor Cyan
            Write-Host ""
            
            # Create route lookup by checking all possible ID fields
            $routeMap = @{}
            foreach ($route in $routes) {
                # Get all property names
                $props = $route.PSObject.Properties.Name
                
                # Find the ID field (could be _id, id, routeId, etc.)
                $idField = $props | Where-Object { $_ -match '^_?id$|^routeId$' } | Select-Object -First 1
                
                if ($idField) {
                    $id = $route.$idField
                    if ($id) {
                        $routeMap[$id.ToString()] = $route
                    }
                }
            }
            
            # Group trips by routeId
            $grouped = $trips | Group-Object -Property routeId
            
            foreach ($group in $grouped) {
                $routeId = $group.Name
                $route = $routeMap[$routeId]
                
                if ($route) {
                    # Display route header with details
                    Write-Host "  🚌 $($route.name)" -ForegroundColor Yellow
                    Write-Host "     Route: $($route.startLocation) → $($route.endLocation)" -ForegroundColor Cyan
                    Write-Host "     Type: $($route.transportType) | Fare: N`$$($route.basePrice) | Route ID: $routeId" -ForegroundColor Gray
                    Write-Host ""
                } else {
                    # Fallback if route not found
                    Write-Host "  📍 Route ID: $routeId" -ForegroundColor Yellow
                    Write-Host ""
                }
                
                # Display trips for this route
                foreach ($trip in $group.Group) {
                    $status = switch ($trip.status) {
                        "SCHEDULED" { "🟢 Scheduled" }
                        "IN_PROGRESS" { "🟡 In Progress" }
                        "COMPLETED" { "⚪ Completed" }
                        "CANCELLED" { "🔴 Cancelled" }
                        default { $trip.status }
                    }
                    
                    $seatInfo = "$($trip.availableSeats)/$($trip.totalSeats)"
                    $seatColor = if ($trip.availableSeats -eq 0) { "Red" } 
                                 elseif ($trip.availableSeats -lt 10) { "Yellow" } 
                                 else { "Green" }
                    
                    Write-Host "     • $($trip.departureTime) - $($trip.arrivalTime)" -ForegroundColor White
                    Write-Host "       Seats: $seatInfo | Status: $status" -ForegroundColor $seatColor
                }
                Write-Host ""
                Write-Host "  " + ("-" * 76) -ForegroundColor DarkGray
                Write-Host ""
            }
        }
        
        Pause-Screen
    }
    catch {
        Write-Error "Failed to load trips: $_"
        Pause-Screen
    }
}

function Show-CreateTrip {
    Write-Header "CREATE NEW TRIP"
    
    if (-not $script:Session.LoggedIn) {
        Write-Error "You must be logged in"
        Pause-Screen
        return
    }
    
    Write-Host "Enter trip details:" -ForegroundColor Cyan
    Write-Host ""
    
    $routeId = Read-Host "Route ID (from MongoDB)"
    $departureTime = Read-Host "Departure Time (e.g., 08:00)"
    $arrivalTime = Read-Host "Arrival Time (e.g., 09:30)"
    $totalSeats = Read-Host "Total Seats"
    
    Write-Host ""
    Write-Host "Creating trip..." -ForegroundColor Yellow
    
    try {
        $body = @{
            routeId = $routeId
            departureTime = $departureTime
            arrivalTime = $arrivalTime
            availableSeats = [int]$totalSeats
            totalSeats = [int]$totalSeats
            status = "SCHEDULED"
            createdAt = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
        }
        
        $response = Invoke-API -Url "$($script:Config.TransportService)/api/v1/transport/trips" `
                               -Method "POST" -Body $body
        
        Write-Success "Trip created successfully!"
        Pause-Screen
    }
    catch {
        Write-Error "Failed to create trip: $_"
        Pause-Screen
    }
}

# Service Disruptions
function Show-Disruptions {
    Write-Header "SERVICE DISRUPTIONS"
    
    try {
        $disruptions = Invoke-API -Url "$($script:Config.AdminService)/api/v1/admin/disruptions"
        
        if ($disruptions.Count -eq 0) {
            Write-Success "No active disruptions"
        } else {
            Write-Host "⚠️  Active Disruptions:" -ForegroundColor Yellow
            Write-Host ""
            
            foreach ($disruption in $disruptions) {
                $typeIcon = switch ($disruption.type) {
                    "DELAY" { "⏰" }
                    "MAINTENANCE" { "🔧" }
                    "CANCELLATION" { "🚫" }
                    default { "⚠️ " }
                }
                
                Write-Host "  $typeIcon $($disruption.title)" -ForegroundColor Yellow
                Write-Host "      $($disruption.description)" -ForegroundColor White
                Write-Host "      Route ID: $($disruption.routeId)" -ForegroundColor Gray
                if ($disruption.startTime) {
                    Write-Host "      Start: $($disruption.startTime)" -ForegroundColor Gray
                }
                if ($disruption.endTime) {
                    Write-Host "      End: $($disruption.endTime)" -ForegroundColor Gray
                }
                Write-Host ""
            }
        }
        
        Pause-Screen
    }
    catch {
        Write-Error "Failed to load disruptions: $_"
        Pause-Screen
    }
}

function Show-CreateDisruption {
    Write-Header "CREATE SERVICE DISRUPTION"
    
    if (-not $script:Session.LoggedIn) {
        Write-Error "You must be logged in"
        Pause-Screen
        return
    }
    
    Write-Host "Enter disruption details:" -ForegroundColor Cyan
    Write-Host ""
    
    $routeId = Read-Host "Route ID"
    Write-Host ""
    Write-Host "Disruption Types:" -ForegroundColor Yellow
    Write-Host "  1. DELAY"
    Write-Host "  2. MAINTENANCE"
    Write-Host "  3. CANCELLATION"
    $typeChoice = Read-Host "Select type (1-3)"
    
    $type = switch ($typeChoice) {
        "1" { "DELAY" }
        "2" { "MAINTENANCE" }
        "3" { "CANCELLATION" }
        default { "DELAY" }
    }
    
    $title = Read-Host "Title"
    $description = Read-Host "Description"
    $startTime = Read-Host "Start Time (ISO format or leave blank for now)"
    $endTime = Read-Host "End Time (ISO format or leave blank)"
    
    Write-Host ""
    Write-Host "Creating disruption..." -ForegroundColor Yellow
    
    try {
        $body = @{
            routeId = $routeId
            type = $type
            title = $title
            description = $description
        }
        
        if ($startTime) {
            $body.startTime = $startTime
        } else {
            $body.startTime = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
        }
        
        if ($endTime) {
            $body.endTime = $endTime
        }
        
        $response = Invoke-API -Url "$($script:Config.AdminService)/api/v1/admin/disruptions" `
                               -Method "POST" -Body $body
        
        Write-Success "Service disruption created and published!"
        Write-Info "Affected passengers will be notified"
        Pause-Screen
    }
    catch {
        Write-Error "Failed to create disruption: $_"
        Pause-Screen
    }
}

# Reports
function Show-Reports {
    Write-Header "USAGE REPORTS"
    
    if (-not $script:Session.LoggedIn) {
        Write-Error "You must be logged in"
        Pause-Screen
        return
    }
    
    try {
        $report = Invoke-API -Url "$($script:Config.AdminService)/api/v1/admin/reports/usage" `
                             -UseAuth $true
        
        Write-Host "📈 System Usage Report:" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "  Period: $($report.period)" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "  Total Tickets Sold: $($report.totalTickets)" -ForegroundColor White
        Write-Host "  Total Revenue: N`$$($report.totalRevenue)" -ForegroundColor Green
        Write-Host "  Average Ticket Price: N`$$($report.averagePrice)" -ForegroundColor White
        Write-Host "  Peak Hour: $($report.peakHour)" -ForegroundColor White
        Write-Host "  Busiest Route: $($report.busiestRoute)" -ForegroundColor White
        Write-Host ""
        
        if ($report.routeBreakdown) {
            Write-Host "  Route Breakdown:" -ForegroundColor Cyan
            foreach ($route in $report.routeBreakdown) {
                Write-Host "    • $($route.routeName): $($route.tickets) tickets, N`$$($route.revenue)" -ForegroundColor Gray
            }
            Write-Host ""
        }
        
        Pause-Screen
    }
    catch {
        Write-Error "Failed to generate report: $_"
        Pause-Screen
    }
}

# Main Menu
function Show-MainMenu {
    while ($true) {
        Write-Header
        
        if ($script:Session.LoggedIn) {
            Write-Host "  DASHBOARD & MONITORING" -ForegroundColor Cyan
            Write-Host "  1. View Dashboard" -ForegroundColor White
            Write-Host ""
            Write-Host "  ROUTE & TRIP MANAGEMENT" -ForegroundColor Cyan
            Write-Host "  2. View All Routes" -ForegroundColor White
            Write-Host "  3. Create New Route" -ForegroundColor White
            Write-Host "  4. View All Trips" -ForegroundColor White
            Write-Host "  5. Create New Trip" -ForegroundColor White
            Write-Host ""
            Write-Host "  SERVICE DISRUPTIONS" -ForegroundColor Cyan
            Write-Host "  6. View Disruptions" -ForegroundColor White
            Write-Host "  7. Create Disruption Alert" -ForegroundColor White
            Write-Host ""
            Write-Host "  REPORTS & ANALYTICS" -ForegroundColor Cyan
            Write-Host "  8. Generate Usage Report" -ForegroundColor White
            Write-Host ""
            Write-Host "  9. Logout" -ForegroundColor White
            Write-Host "  0. Exit" -ForegroundColor Red
        } else {
            Write-Host "  1. Admin Login" -ForegroundColor White
            Write-Host "  0. Exit" -ForegroundColor Red
        }
        
        Write-Host ""
        $choice = Read-Host "Select an option"
        
        switch ($choice) {
            "1" {
                if ($script:Session.LoggedIn) {
                    Show-Dashboard
                } else {
                    Show-LoginMenu
                }
            }
            "2" { if ($script:Session.LoggedIn) { Show-Routes } }
            "3" { if ($script:Session.LoggedIn) { Show-CreateRoute } }
            "4" { if ($script:Session.LoggedIn) { Show-Trips } }
            "5" { if ($script:Session.LoggedIn) { Show-CreateTrip } }
            "6" { if ($script:Session.LoggedIn) { Show-Disruptions } }
            "7" { if ($script:Session.LoggedIn) { Show-CreateDisruption } }
            "8" { if ($script:Session.LoggedIn) { Show-Reports } }
            "9" {
                if ($script:Session.LoggedIn) {
                    $script:Session.LoggedIn = $false
                    $script:Session.Token = $null
                    $script:Session.Admin = $null
                    $script:Session.Username = $null
                    Write-Success "Logged out successfully"
                    Start-Sleep -Seconds 1
                }
            }
            "0" {
                Write-Host ""
                Write-Host "Thank you for using Windhoek Ticketing Platform Admin Portal!" -ForegroundColor Green
                Write-Host ""
                exit 0
            }
            default {
                Write-Error "Invalid option. Please try again."
                Start-Sleep -Seconds 1
            }
        }
    }
}

# Start the application
Write-Host "🚀 Starting Admin CLI..." -ForegroundColor Cyan
Start-Sleep -Seconds 1
Show-MainMenu
