#!/usr/bin/env pwsh

param(
  [string]$BaseUrl = "http://localhost:8084",
  [switch]$Verbose = $false
)

function Write-TestHeader { param([string]$Title) Write-Host "`n" -NoNewline; Write-Host ("="*60) -ForegroundColor Cyan; Write-Host " 🧪 $Title" -ForegroundColor Yellow; Write-Host ("="*60) -ForegroundColor Cyan }
function Write-TestStep { param([string]$Message) Write-Host "🔍 $Message" -ForegroundColor Blue }
function Write-TestSuccess { param([string]$Message) Write-Host "✅ $Message" -ForegroundColor Green }
function Write-TestError { param([string]$Message) Write-Host "❌ $Message" -ForegroundColor Red }
function Invoke-CurlTest {
  param([string]$Method,[string]$Url,[string]$Body = "",[hashtable]$Headers=@{},[switch]$RawResponse=$false)
  $curlArgs = @("-X",$Method,"-H","Content-Type: application/json"); foreach($h in $Headers.GetEnumerator()){ $curlArgs += "-H"; $curlArgs += "$($h.Key): $($h.Value)"}
  if($Body){ $curlArgs += "-d"; $curlArgs += $Body }
  $curlArgs += $Url; if($Verbose){ Write-Host "curl $($curlArgs -join ' ')" -ForegroundColor Gray }
  try{ $result = & curl @curlArgs 2>$null; if($RawResponse){ return $result }; return $result | ConvertFrom-Json } catch { Write-TestError "CURL failed: $_"; return $null }
}

Write-TestHeader "Payment Service Health"; Write-TestStep "Health endpoint";
$health = Invoke-CurlTest -Method GET -Url "$BaseUrl/api/v1/payment/health" -RawResponse
if($health -ne "Payment Service is running"){ Write-TestError "Health failed"; exit 1 } else { Write-TestSuccess "Health OK" }

Write-TestHeader "Payment CRUD"
# Create payment
Write-TestStep "Create payment"
$createBody = @{ ticketId = "t-123"; passengerId = "p-001"; amount = 12.5; method = "CARD"; paymentDetails = @{ cardNumber = "4111111111111111"; expiryMonth = "12"; expiryYear = "30"; cvv = "123" } } | ConvertTo-Json -Depth 5
$created = Invoke-CurlTest -Method POST -Url "$BaseUrl/api/v1/payment/payments" -Body $createBody
if(-not $created -or -not $created.id){ Write-TestError "Create failed"; exit 1 } else { $paymentId = $created.id; Write-TestSuccess "Created payment $paymentId" }

# Get by id
Write-TestStep "Get payment by id"
$got = Invoke-CurlTest -Method GET -Url "$BaseUrl/api/v1/payment/payments/$paymentId"
if(-not $got -or $got.id -ne $paymentId){ Write-TestError "Get by id failed" } else { Write-TestSuccess "Get OK" }

# List payments
Write-TestStep "List payments"
$list = Invoke-CurlTest -Method GET -Url "$BaseUrl/api/v1/payment/payments"
if(-not $list -or $list.Count -lt 1){ Write-TestError "List failed" } else { Write-TestSuccess "List OK ($($list.Count))" }

# Update payment (method)
Write-TestStep "Update payment"
$updateBody = @{ method = "DIGITAL_WALLET" } | ConvertTo-Json
$upd = Invoke-CurlTest -Method PUT -Url "$BaseUrl/api/v1/payment/payments/$paymentId" -Body $updateBody
if(-not $upd -or -not $upd.success){ Write-TestError "Update failed" } else { Write-TestSuccess "Update OK" }

# Refund attempt (will pass only if SUCCESS later)
Write-TestStep "Refund (may be conditioned)"
$ref = Invoke-CurlTest -Method POST -Url "$BaseUrl/api/v1/payment/payments/$paymentId/refund"
if($ref -and $ref.success){ Write-TestSuccess "Refund OK" } else { Write-Host "(Info) Refund not applicable yet" -ForegroundColor DarkYellow }

# Stats
Write-TestStep "Statistics"
$stats = Invoke-CurlTest -Method GET -Url "$BaseUrl/api/v1/payment/statistics"
if(-not $stats -or $null -eq $stats.total){ Write-TestError "Stats failed" } else { Write-TestSuccess "Stats OK" }

# Delete
Write-TestStep "Delete payment"
$del = Invoke-CurlTest -Method DELETE -Url "$BaseUrl/api/v1/payment/payments/$paymentId"
if(-not $del -or -not $del.success){ Write-TestError "Delete failed" } else { Write-TestSuccess "Delete OK" }

Write-Host "`n" -NoNewline; Write-Host ("="*60) -ForegroundColor Green; Write-Host " 🎉 Payment tests completed" -ForegroundColor Green; Write-Host ("="*60) -ForegroundColor Green
