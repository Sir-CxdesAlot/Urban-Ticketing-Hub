#!/usr/bin/env pwsh

# =============================================================================
# Urban Ticketing Hub - Admin Service API Test Script
# =============================================================================
# This script tests all CRUD operations for the Admin Service
# =============================================================================

param(
    [string]$BaseUrl = "http://localhost:8086",
    [switch]$Verbose = $false
)

# Configuration
$script:config = @{
    AdminUser  = @{
        username = "testadmin"
        email    = "testadmin@example.com"
        password = "TestAdmin123!"
        role     = "SUPER_ADMIN"
    }
    Disruption = @{
        routeId     = "route-001"
        type        = "DELAY"
        title       = "Test Delay"
        description = "Testing disruption creation"
        startTime   = "2025-10-11T10:00:00Z"
        endTime     = "2025-10-11T12:00:00Z"
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

function Invoke-CurlTest {
    param(
        [string]$Method,
        [string]$Url,
        [string]$Body = "",
        [hashtable]$Headers = @{},
        [switch]$RawResponse = $false
    )

    $curlArgs = @("-X", $Method, "-H", "Content-Type: application/json")

    foreach ($header in $Headers.GetEnumerator()) {
        $curlArgs += "-H"
        $curlArgs += "$($header.Key): $($header.Value)"
    }

    if ($Body) {
        $curlArgs += "-d"
        $curlArgs += $Body
    }

    $curlArgs += $Url

    if ($Verbose) {
        Write-Host "curl $($curlArgs -join ' ')" -ForegroundColor Gray
    }

    try {
        $result = & curl @curlArgs 2>$null
        if ($RawResponse) {
            return $result
        }
        return $result | ConvertFrom-Json
    }
    catch {
        Write-TestError "CURL command failed: $_"
        return $null
    }
}

# Test Health Check
Write-TestHeader "Testing Admin Service Health"
Write-TestStep "Testing health endpoint"
$healthResult = Invoke-CurlTest -Method GET -Url "$BaseUrl/api/v1/admin/health" -RawResponse
if ($healthResult -and $healthResult -eq "Admin Service is running") {
    Write-TestSuccess "Health check passed"
}
else {
    Write-TestError "Health check failed"
    exit 1
}

# Test Admin User CRUD
Write-TestHeader "Testing Admin User CRUD Operations"

# Create Admin User
Write-TestStep "Creating admin user"
$createAdminBody = @{
    username = $config.AdminUser.username
    email    = $config.AdminUser.email
    password = $config.AdminUser.password
    role     = $config.AdminUser.role
} | ConvertTo-Json

$createResult = Invoke-CurlTest -Method POST -Url "$BaseUrl/api/v1/admin/admin-users" -Body $createAdminBody
if ($createResult -and $createResult.success) {
    Write-TestSuccess "Admin user created successfully"
    $adminId = $createResult.adminId
}
else {
    Write-TestError "Failed to create admin user"
    exit 1
}

# Read Admin Users
Write-TestStep "Reading all admin users"
$readResult = Invoke-CurlTest -Method GET -Url "$BaseUrl/api/v1/admin/admin-users"
if ($readResult -and $readResult -is [array] -and $readResult.Count -gt 0) {
    Write-TestSuccess "Admin users retrieved successfully"
    $foundAdmin = $readResult | Where-Object { $_.id -eq $adminId }
    if ($foundAdmin) {
        Write-TestSuccess "Created admin user found in list"
    }
    else {
        Write-TestError "Created admin user not found in list"
    }
}
else {
    Write-TestError "Failed to read admin users"
}

# Update Admin User
Write-TestStep "Updating admin user"
$updateAdminBody = @{
    username = "updatedadmin"
    email    = "updatedadmin@example.com"
    role     = "TRANSPORT_ADMIN"
} | ConvertTo-Json

$updateResult = Invoke-CurlTest -Method PUT -Url "$BaseUrl/api/v1/admin/admin-users/$adminId" -Body $updateAdminBody
if ($updateResult -and $updateResult.success) {
    Write-TestSuccess "Admin user updated successfully"
}
else {
    Write-TestError "Failed to update admin user"
}

# Delete Admin User
Write-TestStep "Deleting admin user"
$deleteResult = Invoke-CurlTest -Method DELETE -Url "$BaseUrl/api/v1/admin/admin-users/$adminId"
if ($deleteResult -and $deleteResult.success) {
    Write-TestSuccess "Admin user deleted successfully"
}
else {
    Write-TestError "Failed to delete admin user"
}

# Test Service Disruption CRUD
Write-TestHeader "Testing Service Disruption CRUD Operations"

# Create Disruption
Write-TestStep "Creating service disruption"
$createDisruptionBody = @{
    routeId     = $config.Disruption.routeId
    type        = $config.Disruption.type
    title       = $config.Disruption.title
    description = $config.Disruption.description
    startTime   = $config.Disruption.startTime
    endTime     = $config.Disruption.endTime
} | ConvertTo-Json

$createDisruptionResult = Invoke-CurlTest -Method POST -Url "$BaseUrl/api/v1/admin/disruptions" -Body $createDisruptionBody
if ($createDisruptionResult -and $createDisruptionResult.id) {
    Write-TestSuccess "Service disruption created successfully"
    $disruptionId = $createDisruptionResult.id
}
else {
    Write-TestError "Failed to create service disruption"
    exit 1
}

# Read Disruptions
Write-TestStep "Reading all disruptions"
$readDisruptionsResult = Invoke-CurlTest -Method GET -Url "$BaseUrl/api/v1/admin/disruptions"
if ($readDisruptionsResult -and $readDisruptionsResult -is [array]) {
    Write-TestSuccess "Disruptions retrieved successfully"
    $foundDisruption = $readDisruptionsResult | Where-Object { $_.id -eq $disruptionId }
    if ($foundDisruption) {
        Write-TestSuccess "Created disruption found in list"
    }
    else {
        Write-TestError "Created disruption not found in list"
    }
}
else {
    Write-TestError "Failed to read disruptions"
}

# Update Disruption
Write-TestStep "Updating service disruption"
$updateDisruptionBody = @{
    title       = "Updated Test Delay"
    description = "Updated testing disruption"
    status      = "RESOLVED"
} | ConvertTo-Json

$updateDisruptionResult = Invoke-CurlTest -Method PUT -Url "$BaseUrl/api/v1/admin/disruptions/$disruptionId" -Body $updateDisruptionBody
if ($updateDisruptionResult -and $updateDisruptionResult.success) {
    Write-TestSuccess "Service disruption updated successfully"
}
else {
    Write-TestError "Failed to update service disruption"
}

# Update Disruption Status (existing endpoint)
Write-TestStep "Updating disruption status"
$statusUpdateBody = @{
    status = "ACTIVE"
} | ConvertTo-Json

$statusUpdateResult = Invoke-CurlTest -Method PUT -Url "$BaseUrl/api/v1/admin/disruptions/$disruptionId/status" -Body $statusUpdateBody
if ($statusUpdateResult -and $statusUpdateResult.success) {
    Write-TestSuccess "Disruption status updated successfully"
}
else {
    Write-TestError "Failed to update disruption status"
}

# Delete Disruption
Write-TestStep "Deleting service disruption"
$deleteDisruptionResult = Invoke-CurlTest -Method DELETE -Url "$BaseUrl/api/v1/admin/disruptions/$disruptionId"
if ($deleteDisruptionResult -and $deleteDisruptionResult.success) {
    Write-TestSuccess "Service disruption deleted successfully"
}
else {
    Write-TestError "Failed to delete service disruption"
}

# Test Other Endpoints
Write-TestHeader "Testing Other Admin Endpoints"

# Test Dashboard
Write-TestStep "Testing dashboard endpoint"
$dashboardResult = Invoke-CurlTest -Method GET -Url "$BaseUrl/api/v1/admin/dashboard"
if ($dashboardResult -and $dashboardResult.systemStatus) {
    Write-TestSuccess "Dashboard retrieved successfully"
}
else {
    Write-TestError "Failed to retrieve dashboard"
}

# Test Usage Report
Write-TestStep "Testing usage report endpoint"
$reportResult = Invoke-CurlTest -Method GET -Url "$BaseUrl/api/v1/admin/reports/usage?period=daily"
if ($reportResult -and $reportResult.period) {
    Write-TestSuccess "Usage report generated successfully"
}
else {
    Write-TestError "Failed to generate usage report"
}

# Test Login
Write-TestStep "Testing admin login"
$loginBody = @{
    username = "admin"
    password = "Admin123!"
} | ConvertTo-Json

$loginResult = Invoke-CurlTest -Method POST -Url "$BaseUrl/api/v1/admin/login" -Body $loginBody
if ($loginResult -and $loginResult.success) {
    Write-TestSuccess "Admin login successful"
}
else {
    Write-TestError "Admin login failed"
}

Write-Host "`n" -NoNewline
Write-Host "="*60 -ForegroundColor Green
Write-Host " 🎉 All Admin Service CRUD Tests Completed!" -ForegroundColor Green
Write-Host "="*60 -ForegroundColor Green