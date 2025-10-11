# Passenger Service CRUD Operations Test Script
# This script tests all CRUD operations for the passenger service

Write-Host "Testing Passenger Service CRUD Operations" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green

$baseUrl = "http://localhost:8081/api/v1/passenger"
$testUserEmail = "testuser@example.com"
$testUserPassword = "password123"
$testUserToken = ""

# Function to make HTTP requests using curl
function Invoke-HttpRequest {
    param(
        [string]$Method,
        [string]$Url,
        [string]$Body = "",
        [string]$Token = ""
    )

    $headers = @()
    if ($Token) {
        $headers += "-H", "Authorization: Bearer $Token"
    }

    $curlCmd = "curl -s -X $Method '$Url' -H 'Content-Type: application/json'"
    if ($Body) {
        $curlCmd += " -d '$Body'"
    }
    if ($Token) {
        $curlCmd += " -H 'Authorization: Bearer $Token'"
    }

    try {
        $response = Invoke-Expression $curlCmd
        if ($LASTEXITCODE -eq 0) {
            try {
                # Try to parse as JSON
                $jsonResponse = $response | ConvertFrom-Json
                return @{Success = $true; Data = $jsonResponse}
            } catch {
                # If JSON parsing fails, return the raw response
                Write-Host "JSON parsing failed, raw response: $response" -ForegroundColor Yellow
                return @{Success = $false; Error = "Invalid JSON response: $response"; StatusCode = 500}
            }
        } else {
            return @{Success = $false; Error = "Curl failed with exit code $LASTEXITCODE. Response: $response"; StatusCode = 500}
        }
    } catch {
        return @{Success = $false; Error = $_.Exception.Message; StatusCode = 500}
    }
}

Write-Host "`n1. Testing User Registration (CREATE)" -ForegroundColor Yellow
$registerBody = @{
    email = $testUserEmail
    password = $testUserPassword
    firstName = "Test"
    lastName = "User"
    phone = "+1234567890"
} | ConvertTo-Json

$result = Invoke-HttpRequest -Method POST -Url "$baseUrl/register" -Body $registerBody
if ($result.Success) {
    if ($result.Data.message -and $result.Data.message -match "already exists") {
        Write-Host "  User already exists, proceeding with login..." -ForegroundColor Yellow
    } else {
        Write-Host "✓ User registration successful" -ForegroundColor Green
        Write-Host "  User registered: $($result.Data.firstName) $($result.Data.lastName) ($($result.Data.email))"
    }
} else {
    Write-Host "✗ User registration failed: $($result.Error)" -ForegroundColor Red
    exit 1
}

# Now login to get the token
Write-Host "`n  Logging in to get authentication token..." -ForegroundColor Yellow
$loginBody = @{
    email = $testUserEmail
    password = $testUserPassword
} | ConvertTo-Json

$loginResult = Invoke-HttpRequest -Method POST -Url "$baseUrl/login" -Body $loginBody
if ($loginResult.Success) {
    Write-Host "✓ User login successful" -ForegroundColor Green
    $testUserToken = $loginResult.Data.token
    Write-Host "  Token received: $($testUserToken.Substring(0, 20))..."
} else {
    Write-Host "✗ User login failed: $($loginResult.Error)" -ForegroundColor Red
    exit 1
}

Write-Host "`n2. Testing User Profile Retrieval (READ)" -ForegroundColor Yellow
$result = Invoke-HttpRequest -Method GET -Url "$baseUrl/profile" -Token $testUserToken
if ($result.Success) {
    Write-Host "✓ Profile retrieval successful" -ForegroundColor Green
    Write-Host "  User: $($result.Data.firstName) $($result.Data.lastName) ($($result.Data.email))"
} else {
    Write-Host "✗ Profile retrieval failed: $($result.Error)" -ForegroundColor Red
}

Write-Host "`n3. Testing User Profile Update (UPDATE)" -ForegroundColor Yellow
$updateBody = @{
    firstName = "UpdatedTest"
    lastName = "UpdatedUser"
    phone = "+0987654321"
} | ConvertTo-Json

$result = Invoke-HttpRequest -Method PUT -Url "$baseUrl/profile" -Body $updateBody -Token $testUserToken
Write-Host "  Raw response data: $($result.Data | ConvertTo-Json)" -ForegroundColor Cyan
if ($result.Success -and -not $result.Data.message) {
    Write-Host "✓ Profile update successful" -ForegroundColor Green
    Write-Host "  Updated user: $($result.Data.firstName) $($result.Data.lastName)"
} elseif ($result.Data.message -and $result.Data.message -notmatch "failed") {
    Write-Host "✓ Profile update successful" -ForegroundColor Green
    Write-Host "  Updated user: $($result.Data.firstName) $($result.Data.lastName)"
} else {
    Write-Host "✗ Profile update failed: $($result.Data.message)" -ForegroundColor Red
}

Write-Host "`n4. Testing Ticket Purchase (CREATE)" -ForegroundColor Yellow
$ticketBody = @{
    routeId = "route-123"
    ticketType = "SINGLE"
} | ConvertTo-Json

$result = Invoke-HttpRequest -Method POST -Url "$baseUrl/tickets" -Body $ticketBody -Token $testUserToken
if ($result.Success) {
    Write-Host "✓ Ticket purchase successful" -ForegroundColor Green
    Write-Host "  Response data: $($result.Data | ConvertTo-Json)" -ForegroundColor Cyan
    Write-Host "  Ticket ID: $($result.Data.id), Type: $($result.Data.ticketType), Price: $($result.Data.price)"
    $ticketId = $result.Data.id
} else {
    Write-Host "✗ Ticket purchase failed: $($result.Error)" -ForegroundColor Red
    $ticketId = $null
}

Write-Host "`n5. Testing Tickets Retrieval (READ)" -ForegroundColor Yellow
$result = Invoke-HttpRequest -Method GET -Url "$baseUrl/tickets" -Token $testUserToken
if ($result.Success) {
    Write-Host "✓ Tickets retrieval successful" -ForegroundColor Green
    Write-Host "  Found $($result.Data.Count) ticket(s)"
    if ($result.Data.Count -gt 0) {
        $firstTicket = $result.Data[0]
        Write-Host "  First ticket: ID=$($firstTicket.id), Type=$($firstTicket.ticketType), Status=$($firstTicket.status)"
    }
} else {
    Write-Host "✗ Tickets retrieval failed: $($result.Error)" -ForegroundColor Red
}

if ($ticketId) {
    Write-Host "`n6. Testing Ticket Update (UPDATE)" -ForegroundColor Yellow
    $ticketUpdateBody = @{
        status = "PAID"
    } | ConvertTo-Json

    $result = Invoke-HttpRequest -Method PUT -Url "$baseUrl/tickets/$ticketId" -Body $ticketUpdateBody -Token $testUserToken
    if ($result.Success) {
        Write-Host "✓ Ticket update successful" -ForegroundColor Green
    } else {
        Write-Host "✗ Ticket update failed: $($result.Error)" -ForegroundColor Red
    }

    Write-Host "`n7. Testing Ticket Deletion (DELETE)" -ForegroundColor Yellow
    $result = Invoke-HttpRequest -Method DELETE -Url "$baseUrl/tickets/$ticketId" -Token $testUserToken
    if ($result.Success) {
        Write-Host "✓ Ticket deletion successful" -ForegroundColor Green
    } else {
        Write-Host "✗ Ticket deletion failed: $($result.Error)" -ForegroundColor Red
    }
} else {
    Write-Host "`n6-7. Skipping ticket update/delete tests (no ticket created)" -ForegroundColor Yellow
}

Write-Host "`n8. Testing User Account Deletion (DELETE)" -ForegroundColor Yellow
$result = Invoke-HttpRequest -Method DELETE -Url "$baseUrl/profile" -Token $testUserToken
if ($result.Success) {
    Write-Host "✓ Account deletion successful" -ForegroundColor Green
} else {
    Write-Host "✗ Account deletion failed: $($result.Error)" -ForegroundColor Red
}

Write-Host "`n==========================================" -ForegroundColor Green
Write-Host "Passenger Service CRUD Tests Completed" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green