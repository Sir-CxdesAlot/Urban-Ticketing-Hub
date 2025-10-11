#!/usr/bin/env pwsh

# =============================================================================
# Urban Ticketing Hub - Notification Service API Test Script
# =============================================================================
# This script tests all CRUD operations for the Notification Service
# =============================================================================

param(
    [string]$BaseUrl = "http://localhost:8085",
    [switch]$Verbose = $false
)

# Configuration
$script:config = @{
    Notification = @{
        recipientId = "user-001"
        type = "TEST_NOTIFICATION"
        title = "Test Notification"
        message = "This is a test notification message"
        metadata = @{
            testKey = "testValue"
        }
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
    if ($RawResponse) { return $result }
    return $result | ConvertFrom-Json
    }
    catch {
        Write-TestError "CURL command failed: $_"
        return $null
    }
}

# Test Health Check
Write-TestHeader "Testing Notification Service Health"
Write-TestStep "Testing health endpoint"
$healthResult = Invoke-CurlTest -Method GET -Url "$BaseUrl/api/v1/notification/health" -RawResponse
if ($healthResult -and $healthResult -eq "Notification Service is running") {
    Write-TestSuccess "Health check passed"
} else {
    Write-TestError "Health check failed"
    exit 1
}

# Test Notification CRUD
Write-TestHeader "Testing Notification CRUD Operations"

# Create Notification
Write-TestStep "Creating notification"
$createBody = @{
    recipientId = $config.Notification.recipientId
    type = $config.Notification.type
    title = $config.Notification.title
    message = $config.Notification.message
    metadata = $config.Notification.metadata
} | ConvertTo-Json

$createResult = Invoke-CurlTest -Method POST -Url "$BaseUrl/api/v1/notification/notifications" -Body $createBody
if ($createResult -and $createResult.id) {
    Write-TestSuccess "Notification created successfully"
    $notificationId = $createResult.id
} else {
    Write-TestError "Failed to create notification"
    exit 1
}

# Read Notification by ID
Write-TestStep "Reading notification by ID"
$readResult = Invoke-CurlTest -Method GET -Url "$BaseUrl/api/v1/notification/notifications/$notificationId"
if ($readResult -and $readResult.id -eq $notificationId) {
    Write-TestSuccess "Notification retrieved successfully"
} else {
    Write-TestError "Failed to read notification by ID"
}

# Read Notifications for User
Write-TestStep "Reading notifications for user"
$userNotificationsResult = Invoke-CurlTest -Method GET -Url "$BaseUrl/api/v1/notification/users/$($config.Notification.recipientId)/notifications"
if ($userNotificationsResult -and $userNotificationsResult -is [array]) {
    Write-TestSuccess "User notifications retrieved successfully"
    $foundNotification = $userNotificationsResult | Where-Object { $_.id -eq $notificationId }
    if ($foundNotification) {
        Write-TestSuccess "Created notification found in user list"
    } else {
        Write-TestError "Created notification not found in user list"
    }
} else {
    Write-TestError "Failed to read user notifications"
}

# Update Notification
Write-TestStep "Updating notification"
$updateBody = @{
    title = "Updated Test Notification"
    message = "This is an updated test notification message"
    status = "DELIVERED"
} | ConvertTo-Json

$updateResult = Invoke-CurlTest -Method PUT -Url "$BaseUrl/api/v1/notification/notifications/$notificationId" -Body $updateBody
if ($updateResult -and $updateResult.success) {
    Write-TestSuccess "Notification updated successfully"
} else {
    Write-TestError "Failed to update notification"
}

# Mark Notification as Read
Write-TestStep "Marking notification as read"
$readResult = Invoke-CurlTest -Method PUT -Url "$BaseUrl/api/v1/notification/notifications/$notificationId/read"
if ($readResult -and $readResult.success) {
    Write-TestSuccess "Notification marked as read successfully"
} else {
    Write-TestError "Failed to mark notification as read"
}

# Delete Notification
Write-TestStep "Deleting notification"
$deleteResult = Invoke-CurlTest -Method DELETE -Url "$BaseUrl/api/v1/notification/notifications/$notificationId"
if ($deleteResult -and $deleteResult.success) {
    Write-TestSuccess "Notification deleted successfully"
} else {
    Write-TestError "Failed to delete notification"
}

# Test Statistics
Write-TestHeader "Testing Other Notification Endpoints"

# Test Statistics
Write-TestStep "Testing statistics endpoint"
$statsResult = Invoke-CurlTest -Method GET -Url "$BaseUrl/api/v1/notification/statistics"
if ($statsResult -and $null -ne $statsResult.total) {
    Write-TestSuccess "Notification statistics retrieved successfully"
} else {
    Write-TestError "Failed to retrieve notification statistics"
}

Write-Host "`n" -NoNewline
Write-Host "="*60 -ForegroundColor Green
Write-Host " 🎉 All Notification Service CRUD Tests Completed!" -ForegroundColor Green
Write-Host "="*60 -ForegroundColor Green