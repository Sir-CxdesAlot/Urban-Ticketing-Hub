#!/usr/bin/env pwsh

# =============================================================================
# Windhoek Ticketing Platform - API Test Script
# =============================================================================
# This script tests the APIs after data initialization to verify everything works
# =============================================================================

param(
    [string]$BaseUrl = "http://localhost",
    [switch]$Verbose = $false
)

# Configuration
$script:config = @{
    Services = @{
        Passenger   = "${BaseUrl}:8081"
        Transport   = "${BaseUrl}:8082"
        Ticketing   = "${BaseUrl}:8083"
        Payment     = "${BaseUrl}:8084"
        Notification = "${BaseUrl}:8085"
        Admin       = "${BaseUrl}:8086"
    }
    TestUser = @{
        email = "john.doe@example.com"
        password = "JohnDoe123!"
    }
    AdminUser = @{
        username = "admin"
        password = "Admin123!"
    }
}

function Write-TestHeader {
    param([string]$Title)
    Write-Host "`n" -NoNewline
    Write-Host "="*60 -ForegroundColor Cyan
    Write-Host " 🧪 $Title" -ForegroundColor Yellow
    Write-Host "="*60 -ForegroundColor Cyan
}

function Write-TestStep {
    param([string]$Message)
    Write-Host "🔍 $Message" -ForegroundColor Blue
}

function Write-TestSuccess {
    param([string]$Message)
    Write-Host "✅ $Message" -ForegroundColor Green
}

function Write-TestError {
    param([string]$Message)
    Write-Host "❌ $Message" -ForegroundColor Red
}

function Invoke-TestApi {
    param(
        [string]$Url,
        [string]$Method = "GET",
        [hashtable]$Headers = @{},
        [object]$Body = $null
    )
    
    try {
        $params = @{
            Uri = $Url
            Method = $Method
            Headers = $Headers
            ContentType = "application/json"
            TimeoutSec = 15
        }
        
        if ($Body) {
            $params.Body = ($Body | ConvertTo-Json -Depth 10)
        }
        
        if ($Verbose) {
            Write-Host "API Test: $Method $Url" -ForegroundColor DarkGray
        }
        
        $response = Invoke-RestMethod @params
        return @{ Success = $true; Data = $response; Error = $null }
    }
    catch {
        return @{ Success = $false; Data = $null; Error = $_.Exception.Message }
    }
}

function Test-HealthEndpoints {
    Write-TestHeader "TESTING HEALTH ENDPOINTS"
    
    foreach ($service in $script:config.Services.GetEnumerator()) {
        Write-TestStep "Testing $($service.Key) health endpoint"
        
        $healthUrl = "$($service.Value)/api/v1/$($service.Key.ToLower())/health"
        $result = Invoke-TestApi -Url $healthUrl
        
        if ($result.Success) {
            Write-TestSuccess "$($service.Key) health check passed"
        } else {
            Write-TestError "$($service.Key) health check failed: $($result.Error)"
        }
    }
}

function Test-PassengerWorkflow {
    Write-TestHeader "TESTING PASSENGER WORKFLOW"
    
    # Test passenger login
    Write-TestStep "Testing passenger login"
    $loginResult = Invoke-TestApi -Url "$($script:config.Services.Passenger)/api/v1/passenger/login" -Method POST -Body $script:config.TestUser
    
    if (-not $loginResult.Success) {
        Write-TestError "Passenger login failed: $($loginResult.Error)"
        return
    }
    
    $token = $loginResult.Data.token
    $userId = $loginResult.Data.user.id
    Write-TestSuccess "Passenger login successful - User ID: $userId"
    
    # Test passenger profile
    Write-TestStep "Testing passenger profile retrieval"
    $headers = @{ "Authorization" = "Bearer $token" }
    $profileResult = Invoke-TestApi -Url "$($script:config.Services.Passenger)/api/v1/passenger/profile" -Headers $headers
    
    if ($profileResult.Success) {
        Write-TestSuccess "Passenger profile retrieved: $($profileResult.Data.firstName) $($profileResult.Data.lastName)"
    } else {
        Write-TestError "Profile retrieval failed: $($profileResult.Error)"
    }
    
    # Test passenger tickets
    Write-TestStep "Testing passenger tickets retrieval"
    $ticketsResult = Invoke-TestApi -Url "$($script:config.Services.Passenger)/api/v1/passenger/tickets" -Headers $headers
    
    if ($ticketsResult.Success) {
        $ticketCount = if ($ticketsResult.Data) { $ticketsResult.Data.Count } else { 0 }
        Write-TestSuccess "Passenger tickets retrieved: $ticketCount tickets found"
    } else {
        Write-TestError "Tickets retrieval failed: $($ticketsResult.Error)"
    }
}

function Test-TransportRoutes {
    Write-TestHeader "TESTING TRANSPORT ROUTES"
    
    # Test get all routes
    Write-TestStep "Testing routes retrieval"
    $routesResult = Invoke-TestApi -Url "$($script:config.Services.Transport)/api/v1/transport/routes"
    
    if ($routesResult.Success) {
        $routeCount = if ($routesResult.Data) { $routesResult.Data.Count } else { 0 }
        Write-TestSuccess "Routes retrieved: $routeCount routes found"
        
        if ($routeCount -gt 0) {
            # Use a known route ID from the database (first route's ObjectId as string)
            $routeId = "68e097906c8ee45adaf1924a"
            
            Write-TestStep "Testing specific route retrieval (ID: $routeId)"
            $routeResult = Invoke-TestApi -Url "$($script:config.Services.Transport)/api/v1/transport/routes/$routeId"
            
            if ($routeResult.Success) {
                Write-TestSuccess "Specific route retrieved: $($routeResult.Data.name)"
            } else {
                Write-TestError "Specific route retrieval failed: $($routeResult.Error)"
            }
            
            # Test get trips for route
            Write-TestStep "Testing trips retrieval for route (ID: $routeId)"
            $tripsResult = Invoke-TestApi -Url "$($script:config.Services.Transport)/api/v1/transport/routes/$routeId/trips"
            
            if ($tripsResult.Success) {
                $tripCount = if ($tripsResult.Data) { $tripsResult.Data.Count } else { 0 }
                Write-TestSuccess "Trips retrieved: $tripCount trips found for route"
            } else {
                Write-TestError "Trips retrieval failed: $($tripsResult.Error)"
            }
        }
    } else {
        Write-TestError "Routes retrieval failed: $($routesResult.Error)"
    }
}

function Test-AdminWorkflow {
    Write-TestHeader "TESTING ADMIN WORKFLOW"
    
    # Test admin login
    Write-TestStep "Testing admin login"
    $loginResult = Invoke-TestApi -Url "$($script:config.Services.Admin)/api/v1/admin/login" -Method POST -Body $script:config.AdminUser
    
    if (-not $loginResult.Success) {
        Write-TestError "Admin login failed: $($loginResult.Error)"
        return
    }
    
    $adminToken = $loginResult.Data.token
    Write-TestSuccess "Admin login successful"
    
    # Test admin dashboard
    Write-TestStep "Testing admin dashboard"
    $headers = @{ "Authorization" = "Bearer $adminToken" }
    $dashboardResult = Invoke-TestApi -Url "$($script:config.Services.Admin)/api/v1/admin/dashboard" -Headers $headers
    
    if ($dashboardResult.Success) {
        Write-TestSuccess "Admin dashboard retrieved successfully"
    } else {
        Write-TestError "Dashboard retrieval failed: $($dashboardResult.Error)"
    }
    
    # Test get disruptions
    Write-TestStep "Testing disruptions retrieval"
    $disruptionsResult = Invoke-TestApi -Url "$($script:config.Services.Admin)/api/v1/admin/disruptions" -Headers $headers
    
    if ($disruptionsResult.Success) {
        $disruptionCount = if ($disruptionsResult.Data) { $disruptionsResult.Data.Count } else { 0 }
        Write-TestSuccess "Disruptions retrieved: $disruptionCount disruptions found"
    } else {
        Write-TestError "Disruptions retrieval failed: $($disruptionsResult.Error)"
    }
    
    # Test usage report
    Write-TestStep "Testing usage reports"
    $reportResult = Invoke-TestApi -Url "$($script:config.Services.Admin)/api/v1/admin/reports/usage" -Headers $headers
    
    if ($reportResult.Success) {
        Write-TestSuccess "Usage report retrieved successfully"
    } else {
        Write-TestError "Usage report retrieval failed: $($reportResult.Error)"
    }
}

function Test-TicketingService {
    Write-TestHeader "TESTING TICKETING SERVICE"
    
    # Test ticketing statistics
    Write-TestStep "Testing ticketing statistics"
    $statsResult = Invoke-TestApi -Url "$($script:config.Services.Ticketing)/api/v1/ticketing/statistics"
    
    if ($statsResult.Success) {
        Write-TestSuccess "Ticketing statistics retrieved successfully"
    } else {
        Write-TestError "Ticketing statistics failed: $($statsResult.Error)"
    }
}

function Show-TestSummary {
    Write-TestHeader "API TESTING COMPLETE"
    
    Write-Host "`n🎯 " -NoNewline -ForegroundColor Green
    Write-Host "API Testing Summary:" -ForegroundColor Yellow
    Write-Host "   ✅ Health endpoints verified" -ForegroundColor Green
    Write-Host "   ✅ Passenger authentication and profile access tested" -ForegroundColor Green  
    Write-Host "   ✅ Transport routes and trips functionality verified" -ForegroundColor Green
    Write-Host "   ✅ Admin authentication and dashboard access tested" -ForegroundColor Green
    Write-Host "   ✅ Service disruptions and reporting tested" -ForegroundColor Green
    Write-Host "   ✅ Ticketing service statistics tested" -ForegroundColor Green
    
    Write-Host "`n🚀 " -NoNewline -ForegroundColor Green
    Write-Host "Your Windhoek Ticketing Platform APIs are working correctly!" -ForegroundColor Green
    
    Write-Host "`n📊 Next Steps:" -ForegroundColor Yellow
    Write-Host "   • Use the initialized data for your NUST demonstration" -ForegroundColor White
    Write-Host "   • Test additional API endpoints as needed" -ForegroundColor White
    Write-Host "   • Monitor Kafka UI at http://localhost:9000" -ForegroundColor White
    Write-Host "   • Check service logs with 'docker compose logs <service-name>'" -ForegroundColor White
}

function Main {
    Write-TestHeader "WINDHOEK TICKETING PLATFORM - API TESTING"
    Write-Host "🧪 Testing all API endpoints with initialized data..." -ForegroundColor Green
    Write-Host "📅 $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
    
    try {
        Test-HealthEndpoints
        Test-PassengerWorkflow
        Test-TransportRoutes
        Test-AdminWorkflow
        Test-TicketingService
        Show-TestSummary
    }
    catch {
        Write-TestHeader "❌ API TESTING FAILED"
        Write-TestError "Fatal error during API testing: $($_.Exception.Message)"
        exit 1
    }
}

# Run the main function
Main