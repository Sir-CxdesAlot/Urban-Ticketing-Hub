#!/usr/bin/env pwsh

param([string]$BaseUrl="http://localhost:8082",[switch]$Verbose=$false)
function Write-TestHeader{param([string]$T)Write-Host "`n" -NoNewline;Write-Host ("="*60) -ForegroundColor Cyan;Write-Host " 🧪 $T" -ForegroundColor Yellow;Write-Host ("="*60) -ForegroundColor Cyan}
function Write-TestStep{param([string]$M)Write-Host "🔍 $M" -ForegroundColor Blue}
function Write-TestSuccess{param([string]$M)Write-Host "✅ $M" -ForegroundColor Green}
function Write-TestError{param([string]$M)Write-Host "❌ $M" -ForegroundColor Red}
function Invoke-CurlTest{param([string]$Method,[string]$Url,[string]$Body="",[hashtable]$Headers=@{},[switch]$RawResponse=$false);$a=@("-X",$Method,"-H","Content-Type: application/json");foreach($h in $Headers.GetEnumerator()){ $a+="-H"; $a+="$($h.Key): $($h.Value)"}; if($Body){$a+="-d";$a+=$Body}; $a+=$Url; if($Verbose){Write-Host "curl $($a -join ' ')" -ForegroundColor Gray}; try{ $r=& curl @a 2>$null; if($RawResponse){return $r}; return $r|ConvertFrom-Json }catch{ Write-TestError "CURL failed: $_"; return $null }}

Write-TestHeader "Transport Health"; Write-TestStep "Health";
$health = Invoke-CurlTest -Method GET -Url "$BaseUrl/api/v1/transport/health" -RawResponse
if($health -ne "Transport Service is running"){ Write-TestError "Health failed"; exit 1 } else { Write-TestSuccess "Health OK" }

# Routes CRUD
Write-TestHeader "Routes CRUD"
Write-TestStep "Create route"
$routeBody = @{ name="Route A"; startLocation="A"; endLocation="B"; intermediateStops=@("S1","S2"); transportType="BUS"; basePrice=2.5 } | ConvertTo-Json -Depth 5
# Create route and capture ID (supports _id or id)
$route = Invoke-CurlTest -Method POST -Url "$BaseUrl/api/v1/transport/routes" -Body $routeBody
if(-not $route){ Write-TestError "Create route failed"; exit 1 }
# Try to get created id (accept either _id or id)
$routeId = $null
if ($route -is [string]) { # some endpoints may return raw strings
	$routeId = $route
} else {
	if ($route._id) { $routeId = $route._id }
	elseif ($route.id) { $routeId = $route.id }
}
Write-TestStep "List routes"; $routes = Invoke-CurlTest -Method GET -Url "$BaseUrl/api/v1/transport/routes"; if(-not $routes -or $routes.Count -lt 1){ Write-TestError "List routes failed" } else { Write-TestSuccess "List routes OK" }
if($routeId){ Write-TestStep "Get route by id"; $r = Invoke-CurlTest -Method GET -Url "$BaseUrl/api/v1/transport/routes/$routeId"; if($r){ Write-TestSuccess "Get route OK" } else { Write-TestError "Get route failed" } }
Write-TestStep "Update route"; $upd=@{ name="Route A1"; startLocation="A"; endLocation="B1"; intermediateStops=@("S1","S3"); transportType="BUS"; basePrice=3.0; isActive=$true }|ConvertTo-Json -Depth 5; if($routeId){ $u=Invoke-CurlTest -Method PUT -Url "$BaseUrl/api/v1/transport/routes/$routeId" -Body $upd; if(-not $u){ Write-TestError "Update route failed" } else { Write-TestSuccess "Update route OK" } } else { Write-Host "(Info) Skipping route id-specific tests" -ForegroundColor DarkYellow }
if($routeId){ Write-TestStep "Delete route"; $d=Invoke-CurlTest -Method DELETE -Url "$BaseUrl/api/v1/transport/routes/$routeId"; if(-not $d -or -not $d.success){ Write-TestError "Delete route failed" } else { Write-TestSuccess "Delete route OK" } }

## Trips CRUD
Write-TestHeader "Trips CRUD"

# Determine a valid routeId to use for trip creation. Prefer the route created in the Routes CRUD section.
$routeIdForTrip = $routeId
if (-not $routeIdForTrip) {
	Write-TestStep "No routeId captured from create route response; fetching first available route"
	$all = Invoke-CurlTest -Method GET -Url "$BaseUrl/api/v1/transport/routes"
	if ($all) {
		if ($all -is [array]) { $first = $all[0] } else { $first = $all }
		if ($first) {
			if ($first._id) { $routeIdForTrip = $first._id } elseif ($first.id) { $routeIdForTrip = $first.id } else { $routeIdForTrip = $null }
		}
	}
}

if (-not $routeIdForTrip) { Write-TestError "No route available to create trip"; exit 1 }

Write-TestStep "Create trip using routeId: $routeIdForTrip"
$tripBody=@{ routeId=$routeIdForTrip; departureTime="2025-10-11T10:00:00Z"; arrivalTime="2025-10-11T12:00:00Z"; totalSeats=40 }|ConvertTo-Json
$trip=Invoke-CurlTest -Method POST -Url "$BaseUrl/api/v1/transport/trips" -Body $tripBody
if(-not $trip){ Write-TestError "Create trip failed"; exit 1 }

# Extract tripId from response (support string, _id, or id)
$tripId = $null
if ($trip -is [string]) { $tripId = $trip } else { if ($trip._id) { $tripId = $trip._id } elseif ($trip.id) { $tripId = $trip.id } }
Write-TestStep "List trips"; $trips = Invoke-CurlTest -Method GET -Url "$BaseUrl/api/v1/transport/trips"; if(-not $trips){ Write-TestError "List trips failed" } else { Write-TestSuccess "List trips OK" }
if($tripId){ Write-TestStep "Get trip by id"; $tg=Invoke-CurlTest -Method GET -Url "$BaseUrl/api/v1/transport/trips/$tripId"; if($tg){ Write-TestSuccess "Get trip OK" } else { Write-TestError "Get trip failed" } }
if($tripId){ Write-TestStep "Update trip"; $tupd=@{ availableSeats=35 }|ConvertTo-Json; $tu=Invoke-CurlTest -Method PUT -Url "$BaseUrl/api/v1/transport/trips/$tripId" -Body $tupd; if(-not $tu -or -not $tu.success){ Write-TestError "Update trip failed" } else { Write-TestSuccess "Update trip OK" } }
if($tripId){ Write-TestStep "Update trip status"; $sbody=@{ status="DELAYED"; delayMinutes=10; reason="Traffic" }|ConvertTo-Json; $ts=Invoke-CurlTest -Method PUT -Url "$BaseUrl/api/v1/transport/trips/$tripId/status" -Body $sbody; if(-not $ts){ Write-TestError "Update status failed" } else { Write-TestSuccess "Update status OK" } }
if($tripId){ Write-TestStep "Delete trip"; $td=Invoke-CurlTest -Method DELETE -Url "$BaseUrl/api/v1/transport/trips/$tripId"; if(-not $td -or -not $td.success){ Write-TestError "Delete trip failed" } else { Write-TestSuccess "Delete trip OK" } }

Write-Host "`n" -NoNewline; Write-Host ("="*60) -ForegroundColor Green; Write-Host " 🎉 Transport tests completed" -ForegroundColor Green; Write-Host ("="*60) -ForegroundColor Green
