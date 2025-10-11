# Test PUT profile endpoint
$baseUrl = "http://localhost:8081"
$loginUrl = "$baseUrl/api/v1/passenger/login"
$profileUrl = "$baseUrl/api/v1/passenger/profile"

# Login first
$loginBody = @{
    email = "john.doe@example.com"
    password = "JohnDoe123!"
} | ConvertTo-Json

Write-Host "Logging in..." -ForegroundColor Yellow
$loginResponse = Invoke-RestMethod -Uri $loginUrl -Method POST -Body $loginBody -ContentType "application/json"
$token = $loginResponse.token
$userId = $loginResponse.user.id

Write-Host "Login successful. User ID: $userId" -ForegroundColor Green

# Test PUT profile update
$updateBody = @{
    firstName = "John"
    lastName = "Updated"
    phone = "+264812345678"
} | ConvertTo-Json

$headers = @{
    "Authorization" = "Bearer $token"
    "Content-Type" = "application/json"
}

Write-Host "Testing PUT profile update..." -ForegroundColor Yellow
try {
    $updateResponse = Invoke-RestMethod -Uri $profileUrl -Method PUT -Body $updateBody -Headers $headers
    Write-Host "PUT profile update successful!" -ForegroundColor Green
    Write-Host "Response:" -ForegroundColor Cyan
    $updateResponse | ConvertTo-Json
} catch {
    Write-Host "PUT profile update failed:" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
}