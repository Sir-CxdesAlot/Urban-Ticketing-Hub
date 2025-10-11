# Debug: login via curl, then call the CLI function to view tickets
$base = 'http://localhost:8081/api/v1/passenger'
$loginResp = & curl.exe -s -X POST "$base/login" -H "Content-Type: application/json" -d '{"email":"testuser@example.com","password":"password123"}'
try { $loginJson = $loginResp | ConvertFrom-Json } catch { Write-Host "Login failed or non-json:`n$loginResp"; exit 1 }
$token = $loginJson.token
Write-Host "Token sample: $($token.Substring(0,20))..."
. "c:\\Users\\AceHo\\Documents\\GitHub\\Urban-Ticketing-Hub\\urban-ticketing-cli.ps1"
$script:passengerToken = $token
View-PassengerTickets
