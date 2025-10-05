#!/usr/bin/env pwsh

# =============================================================================
# Windhoek Ticketing Platform - Passenger CLI
# =============================================================================
# Interactive command-line interface for passengers
# Features: Account creation, login, route browsing, ticket purchase, validation
# =============================================================================

param(
    [string]$BaseUrl = "http://localhost"
)

# Configuration
$script:Config = @{
    PassengerService = "${BaseUrl}:8081"
    TransportService = "${BaseUrl}:8082"
    TicketingService = "${BaseUrl}:8083"
    PaymentService = "${BaseUrl}:8084"
}

# Session state
$script:Session = @{
    LoggedIn = $false
    Token = $null
    User = $null
    Email = $null
}

# Colors
function Write-Header {
    param([string]$Text)
    Clear-Host
    Write-Host ""
    Write-Host "="*80 -ForegroundColor Cyan
    Write-Host "  🎫 WINDHOEK TICKETING PLATFORM - PASSENGER PORTAL" -ForegroundColor Yellow
    Write-Host "="*80 -ForegroundColor Cyan
    if ($script:Session.LoggedIn) {
        Write-Host "  👤 Logged in as: $($script:Session.User.firstName) $($script:Session.User.lastName) ($($script:Session.Email))" -ForegroundColor Green
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

# Authentication Functions
function Show-RegisterMenu {
    Write-Header "REGISTER NEW ACCOUNT"
    
    Write-Host "Please enter your details:" -ForegroundColor Cyan
    Write-Host ""
    
    $firstName = Read-Host "First Name"
    $lastName = Read-Host "Last Name"
    $email = Read-Host "Email"
    $phone = Read-Host "Phone (e.g., +264811234567)"
    $password = Read-Host "Password" -AsSecureString
    $passwordPlain = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto(
        [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($password)
    )
    
    Write-Host ""
    Write-Host "Creating account..." -ForegroundColor Yellow
    
    try {
        $body = @{
            firstName = $firstName
            lastName = $lastName
            email = $email
            phone = $phone
            password = $passwordPlain
        }
        
        $response = Invoke-API -Url "$($script:Config.PassengerService)/api/v1/passenger/register" `
                               -Method "POST" -Body $body
        
        Write-Success "Account created successfully!"
        Write-Info "You can now log in with your email and password"
        Pause-Screen
    }
    catch {
        Write-Error "Registration failed: $_"
        Pause-Screen
    }
}

function Show-LoginMenu {
    Write-Header "LOGIN"
    
    $email = Read-Host "Email"
    $password = Read-Host "Password" -AsSecureString
    $passwordPlain = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto(
        [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($password)
    )
    
    Write-Host ""
    Write-Host "Logging in..." -ForegroundColor Yellow
    
    try {
        $body = @{
            email = $email
            password = $passwordPlain
        }
        
        $response = Invoke-API -Url "$($script:Config.PassengerService)/api/v1/passenger/login" `
                               -Method "POST" -Body $body
        
        $script:Session.LoggedIn = $true
        $script:Session.Token = $response.token
        $script:Session.User = $response.user
        $script:Session.Email = $email
        
        Write-Success "Login successful! Welcome, $($response.user.firstName)!"
        Start-Sleep -Seconds 2
    }
    catch {
        Write-Error "Login failed: $_"
        Pause-Screen
    }
}

function Show-Profile {
    Write-Header "MY PROFILE"
    
    if (-not $script:Session.LoggedIn) {
        Write-Error "You must be logged in to view your profile"
        Pause-Screen
        return
    }
    
    try {
        $profile = Invoke-API -Url "$($script:Config.PassengerService)/api/v1/passenger/profile" `
                              -UseAuth $true
        
        Write-Host "📋 Profile Information:" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "  Name:  $($profile.firstName) $($profile.lastName)" -ForegroundColor White
        Write-Host "  Email: $($profile.email)" -ForegroundColor White
        Write-Host "  Phone: $($profile.phone)" -ForegroundColor White
        Write-Host ""
        
        Pause-Screen
    }
    catch {
        Write-Error "Failed to load profile: $_"
        Pause-Screen
    }
}

# Route & Trip Functions
function Show-Routes {
    Write-Header "BROWSE ROUTES"
    
    try {
        $routes = Invoke-API -Url "$($script:Config.TransportService)/api/v1/transport/routes"
        
        if ($routes.Count -eq 0) {
            Write-Info "No routes available at this time"
        } else {
            Write-Host "🚌 Available Routes:" -ForegroundColor Cyan
            Write-Host ""
            
            $index = 1
            foreach ($route in $routes) {
                Write-Host "  [$index] $($route.name)" -ForegroundColor Yellow
                Write-Host "      From: $($route.startLocation)" -ForegroundColor White
                Write-Host "      To:   $($route.endLocation)" -ForegroundColor White
                Write-Host "      Type: $($route.transportType)" -ForegroundColor White
                Write-Host "      Price: N`$$($route.basePrice)" -ForegroundColor Green
                if ($route.intermediateStops -and $route.intermediateStops.Count -gt 0) {
                    Write-Host "      Stops: $($route.intermediateStops -join ', ')" -ForegroundColor Gray
                }
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

function Show-Trips {
    Write-Header "VIEW TRIP SCHEDULES"
    
    try {
        # Fetch trips and routes
        $trips = Invoke-API -Url "$($script:Config.TransportService)/api/v1/transport/trips"
        $routes = Invoke-API -Url "$($script:Config.TransportService)/api/v1/transport/routes"
        
        if ($trips.Count -eq 0) {
            Write-Info "No trips scheduled at this time"
        } else {
            Write-Host "🕐 Scheduled Trips by Route:" -ForegroundColor Cyan
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
                
                # Also try to map by name as fallback
                if ($route.name) {
                    $routeMap["name:$($route.name)"] = $route
                }
            }
            
            # Group trips by routeId
            $groupedTrips = $trips | Group-Object -Property routeId
            
            foreach ($group in $groupedTrips) {
                $routeId = $group.Name
                $route = $routeMap[$routeId]
                
                if ($route) {
                    # Display route header
                    Write-Host "  🚌 $($route.name)" -ForegroundColor Yellow
                    Write-Host "     $($route.startLocation) → $($route.endLocation)" -ForegroundColor Cyan
                    Write-Host "     Transport: $($route.transportType) | Base Fare: N`$$($route.basePrice)" -ForegroundColor Gray
                    Write-Host ""
                    
                    # Display trips for this route
                    $tripIndex = 1
                    foreach ($trip in $group.Group) {
                        $status = switch ($trip.status) {
                            "SCHEDULED" { "🟢 Scheduled" }
                            "IN_PROGRESS" { "🟡 In Progress" }
                            "COMPLETED" { "⚪ Completed" }
                            "CANCELLED" { "🔴 Cancelled" }
                            default { $trip.status }
                        }
                        
                        $availability = if ($trip.availableSeats -gt 0) {
                            "$($trip.availableSeats)/$($trip.totalSeats) available"
                        } else {
                            "SOLD OUT"
                        }
                        
                        Write-Host "     [$tripIndex] Trip at $($trip.departureTime)" -ForegroundColor White
                        Write-Host "         Arrival: $($trip.arrivalTime)" -ForegroundColor Gray
                        Write-Host "         Seats: $availability" -ForegroundColor $(if ($trip.availableSeats -gt 0) { "Green" } else { "Red" })
                        Write-Host "         Status: $status" -ForegroundColor Gray
                        Write-Host ""
                        $tripIndex++
                    }
                } else {
                    # Fallback if route not found - display without route details
                    Write-Host "  📍 Route ID: $routeId" -ForegroundColor Yellow
                    Write-Host ""
                    
                    $tripIndex = 1
                    foreach ($trip in $group.Group) {
                        $status = switch ($trip.status) {
                            "SCHEDULED" { "🟢 Scheduled" }
                            "IN_PROGRESS" { "🟡 In Progress" }
                            "COMPLETED" { "⚪ Completed" }
                            "CANCELLED" { "🔴 Cancelled" }
                            default { $trip.status }
                        }
                        
                        Write-Host "     [$tripIndex] Trip at $($trip.departureTime) - $($trip.arrivalTime)" -ForegroundColor White
                        Write-Host "         Seats: $($trip.availableSeats)/$($trip.totalSeats) | Status: $status" -ForegroundColor Gray
                        Write-Host ""
                        $tripIndex++
                    }
                }
                
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

# Ticket Functions
function Show-PurchaseTicket {
    Write-Header "PURCHASE TICKET"
    
    if (-not $script:Session.LoggedIn) {
        Write-Error "You must be logged in to purchase tickets"
        Pause-Screen
        return
    }
    
    Write-Info "This feature requires selecting a route and trip"
    Write-Info "Please use the API or web interface for ticket purchases"
    Write-Host ""
    Write-Host "Steps to purchase:" -ForegroundColor Cyan
    Write-Host "1. Browse routes to find your destination"
    Write-Host "2. Check trip schedules for available times"
    Write-Host "3. Note the route ID and trip ID"
    Write-Host "4. Use the test-apis.ps1 script or direct API calls"
    Write-Host ""
    
    Pause-Screen
}

function Show-MyTickets {
    Write-Header "MY TICKETS"
    
    if (-not $script:Session.LoggedIn) {
        Write-Error "You must be logged in to view your tickets"
        Pause-Screen
        return
    }
    
    try {
        $tickets = Invoke-API -Url "$($script:Config.PassengerService)/api/v1/passenger/tickets" `
                              -UseAuth $true
        
        if ($tickets.Count -eq 0) {
            Write-Info "You have no tickets yet"
        } else {
            Write-Host "🎫 Your Tickets:" -ForegroundColor Cyan
            Write-Host ""
            
            foreach ($ticket in $tickets) {
                $status = switch ($ticket.status) {
                    "ACTIVE" { "🟢 Active" }
                    "USED" { "⚪ Used" }
                    "EXPIRED" { "🔴 Expired" }
                    "CANCELLED" { "🔴 Cancelled" }
                    default { $ticket.status }
                }
                
                Write-Host "  Ticket ID: $($ticket.id)" -ForegroundColor Yellow
                Write-Host "  Type: $($ticket.ticketType)" -ForegroundColor White
                Write-Host "  Price: N`$$($ticket.price)" -ForegroundColor Green
                Write-Host "  Status: $status" -ForegroundColor White
                if ($ticket.purchaseDate) {
                    Write-Host "  Purchased: $($ticket.purchaseDate)" -ForegroundColor Gray
                }
                Write-Host ""
            }
        }
        
        Pause-Screen
    }
    catch {
        Write-Error "Failed to load tickets: $_"
        Pause-Screen
    }
}

# Main Menu
function Show-MainMenu {
    while ($true) {
        Write-Header
        
        if ($script:Session.LoggedIn) {
            Write-Host "  1. View My Profile" -ForegroundColor White
            Write-Host "  2. Browse Routes" -ForegroundColor White
            Write-Host "  3. View Trip Schedules" -ForegroundColor White
            Write-Host "  4. Purchase Ticket" -ForegroundColor White
            Write-Host "  5. My Tickets" -ForegroundColor White
            Write-Host "  6. Logout" -ForegroundColor White
            Write-Host "  0. Exit" -ForegroundColor Red
        } else {
            Write-Host "  1. Register New Account" -ForegroundColor White
            Write-Host "  2. Login" -ForegroundColor White
            Write-Host "  3. Browse Routes (Guest)" -ForegroundColor White
            Write-Host "  4. View Trip Schedules (Guest)" -ForegroundColor White
            Write-Host "  0. Exit" -ForegroundColor Red
        }
        
        Write-Host ""
        $choice = Read-Host "Select an option"
        
        switch ($choice) {
            "1" {
                if ($script:Session.LoggedIn) {
                    Show-Profile
                } else {
                    Show-RegisterMenu
                }
            }
            "2" {
                if ($script:Session.LoggedIn) {
                    Show-Routes
                } else {
                    Show-LoginMenu
                }
            }
            "3" {
                if ($script:Session.LoggedIn) {
                    Show-Trips
                } else {
                    Show-Routes
                }
            }
            "4" {
                if ($script:Session.LoggedIn) {
                    Show-PurchaseTicket
                } else {
                    Show-Trips
                }
            }
            "5" {
                if ($script:Session.LoggedIn) {
                    Show-MyTickets
                }
            }
            "6" {
                if ($script:Session.LoggedIn) {
                    $script:Session.LoggedIn = $false
                    $script:Session.Token = $null
                    $script:Session.User = $null
                    $script:Session.Email = $null
                    Write-Success "Logged out successfully"
                    Start-Sleep -Seconds 1
                }
            }
            "0" {
                Write-Host ""
                Write-Host "Thank you for using Windhoek Ticketing Platform!" -ForegroundColor Green
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
Write-Host "🚀 Starting Passenger CLI..." -ForegroundColor Cyan
Start-Sleep -Seconds 1
Show-MainMenu
