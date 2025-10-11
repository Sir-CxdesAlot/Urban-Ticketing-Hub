# Register a test user
$baseUrl = "http://localhost:8081"
$registerUrl = "$baseUrl/api/v1/passenger/register"

# Register test user
$registerBody = @{
    email = "john.doe@example.com"
    password = "JohnDoe123!"
    firstName = "John"
    lastName = "Doe"
    phone = "+264811234567"
} | ConvertTo-Json

Write-Host "Registering test user..." -ForegroundColor Yellow
try {
    $registerResponse = Invoke-RestMethod -Uri $registerUrl -Method POST -Body $registerBody -ContentType "application/json"
    Write-Host "Registration successful!" -ForegroundColor Green
    Write-Host "Response:" -ForegroundColor Cyan
    $registerResponse | ConvertTo-Json
} catch {
    Write-Host "Registration failed:" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
}