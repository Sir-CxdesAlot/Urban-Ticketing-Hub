# Debug passenger flow: register -> login -> buy ticket -> get tickets (raw)
$base = 'http://localhost:8081/api/v1/passenger'
$email = 'debuguser@example.com'
$password = 'debugpass123'

# Register (ignore if already exists)
$regBody = @{ email = $email; password = $password; firstName='Debug'; lastName='User'; phone='+10000000000' } | ConvertTo-Json
$reg = & curl.exe -s -X POST "$base/register" -H "Content-Type: application/json" -d $regBody
Write-Host "Register response:`n$reg`n"

# Login
$loginBody = @{ email = $email; password = $password } | ConvertTo-Json
$loginResp = & curl.exe -s -X POST "$base/login" -H "Content-Type: application/json" -d $loginBody
Write-Host "Login response (raw):`n$loginResp`n"
try { $loginJson = $loginResp | ConvertFrom-Json } catch { Write-Host "Login response not JSON"; exit 1 }
$token = $loginJson.token
Write-Host "Token sample: $($token.Substring(0,20))...`n"

# Buy ticket
$ticketBody = @{ routeId = 'route-debug'; ticketType='SINGLE' } | ConvertTo-Json
$buyResp = & curl.exe -s -X POST "$base/tickets" -H "Content-Type: application/json" -H "Authorization: Bearer $token" -d $ticketBody
Write-Host "Buy ticket response:`n$buyResp`n"

# Get tickets (raw, include headers)
$ticketsRaw = & curl.exe -i -s -X GET "$base/tickets" -H "Authorization: Bearer $token"
Write-Host "GET /tickets raw response:`n$ticketsRaw`n"
