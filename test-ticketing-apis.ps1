#!/usr/bin/env pwsh

param([string]$BaseUrl = "http://localhost:8083", [switch]$Verbose = $false)
function Write-TestHeader { param([string]$T) Write-Host "`n" -NoNewline; Write-Host ("="*60) -ForegroundColor Cyan; Write-Host " 🧪 $T" -ForegroundColor Yellow; Write-Host ("="*60) -ForegroundColor Cyan }
function Write-TestStep { param([string]$M) Write-Host "🔍 $M" -ForegroundColor Blue }
function Write-TestSuccess { param([string]$M) Write-Host "✅ $M" -ForegroundColor Green }
function Write-TestError { param([string]$M) Write-Host "❌ $M" -ForegroundColor Red }
function Invoke-CurlTest { param([string]$Method,[string]$Url,[string]$Body="",[hashtable]$Headers=@{},[switch]$RawResponse=$false)
  $a=@("-X",$Method,"-H","Content-Type: application/json"); foreach($h in $Headers.GetEnumerator()){ $a+="-H"; $a+="$($h.Key): $($h.Value)"}
  if($Body){$a+="-d";$a+=$Body}; $a+=$Url; if($Verbose){Write-Host "curl $($a -join ' ')" -ForegroundColor Gray}
  try{ $r=& curl @a 2>$null; if($RawResponse){return $r}; return $r|ConvertFrom-Json }catch{ Write-TestError "CURL failed: $_"; return $null }
}

Write-TestHeader "Ticketing Health"; Write-TestStep "Health";
$health = Invoke-CurlTest -Method GET -Url "$BaseUrl/api/v1/ticketing/health" -RawResponse
if($health -ne "Ticketing Service is running"){ Write-TestError "Health failed"; exit 1 } else { Write-TestSuccess "Health OK" }

Write-TestHeader "Ticketing CRUD"
# Create ticket
Write-TestStep "Create ticket"
$create = @{ passengerId="p-1"; routeId="r-1"; tripId="tr-1"; ticketType="single"; price=5.0 } | ConvertTo-Json
$ticket = Invoke-CurlTest -Method POST -Url "$BaseUrl/api/v1/ticketing/tickets" -Body $create
if(-not $ticket -or -not $ticket.id){ Write-TestError "Create failed"; exit 1 } else { $tid=$ticket.id; Write-TestSuccess "Created $tid" }

# Get by id
Write-TestStep "Get by id"; $got = Invoke-CurlTest -Method GET -Url "$BaseUrl/api/v1/ticketing/tickets/$tid"; if(-not $got -or $got.id -ne $tid){ Write-TestError "Get failed" } else { Write-TestSuccess "Get OK" }

# Update
Write-TestStep "Update"; $updBody=@{ price=6.0 }|ConvertTo-Json; $upd=Invoke-CurlTest -Method PUT -Url "$BaseUrl/api/v1/ticketing/tickets/$tid" -Body $updBody; if(-not $upd -or -not $upd.success){ Write-TestError "Update failed" } else { Write-TestSuccess "Update OK" }

# Validate (will fail unless paid)
Write-TestStep "Validate"; $val=Invoke-CurlTest -Method PUT -Url "$BaseUrl/api/v1/ticketing/tickets/$tid/validate"; if($val -and $val.success){ Write-TestSuccess "Validate OK" } else { Write-Host "(Info) Validate not applicable yet" -ForegroundColor DarkYellow }

# Stats
Write-TestStep "Stats"; $stats=Invoke-CurlTest -Method GET -Url "$BaseUrl/api/v1/ticketing/statistics"; if(-not $stats -or -not $stats.total){ Write-TestError "Stats failed" } else { Write-TestSuccess "Stats OK" }

# Delete
Write-TestStep "Delete"; $del=Invoke-CurlTest -Method DELETE -Url "$BaseUrl/api/v1/ticketing/tickets/$tid"; if(-not $del -or -not $del.success){ Write-TestError "Delete failed" } else { Write-TestSuccess "Delete OK" }

Write-Host "`n" -NoNewline; Write-Host ("="*60) -ForegroundColor Green; Write-Host " 🎉 Ticketing tests completed" -ForegroundColor Green; Write-Host ("="*60) -ForegroundColor Green
