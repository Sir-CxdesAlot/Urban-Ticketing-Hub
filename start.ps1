# =============================================================================
# Windhoek City Council Distributed Ticketing Platform - Quick Start Script
# =============================================================================
# For users who want to start existing Docker services
# Updated: 2025-10-04
# - Enhanced service health checks with correct /api/v1/{service}/health endpoints
# - Improved status reporting and error handling
# - Added helpful next steps and credentials display
# =============================================================================

Write-Host "🚀 Starting Windhoek City Council Ticketing Platform Services" -ForegroundColor Cyan
Write-Host "=============================================================" -ForegroundColor Cyan

# Check if Docker is running
Write-Host "🐳 Checking Docker status..." -ForegroundColor Yellow
try {
    docker ps | Out-Null
    Write-Host "✅ Docker is running" -ForegroundColor Green
} catch {
    Write-Host "❌ Docker is not running" -ForegroundColor Red
    Write-Host "Please start Docker Desktop and try again" -ForegroundColor Red
    exit 1
}

# Check if docker-compose.yml exists
if (-not (Test-Path "docker-compose.yml")) {
    Write-Host "❌ docker-compose.yml not found in current directory" -ForegroundColor Red
    Write-Host "Please run this script from the project root directory" -ForegroundColor Red
    exit 1
}

# Detect modern Docker Compose command
Write-Host "� Detecting Docker Compose version..." -ForegroundColor Yellow
try {
    docker compose version 2>$null
    $composeCmd = if ($LASTEXITCODE -eq 0) { "docker compose" } else { "docker-compose" }
    Write-Host "✅ Using: $composeCmd" -ForegroundColor Green
} catch {
    $composeCmd = "docker-compose"
    Write-Host "✅ Using: $composeCmd (fallback)" -ForegroundColor Green
}

# Start services (using modern Docker Compose)
Write-Host "🚀 Starting all services..." -ForegroundColor Yellow
try {
    Invoke-Expression "$composeCmd up -d"
    Write-Host "✅ All services started successfully" -ForegroundColor Green
} catch {
    Write-Host "❌ Error starting services" -ForegroundColor Red
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Function to check core service health
function Test-CoreServiceHealth {
    param($ServiceName, $ContainerName, $HealthCommand)
    
    $maxAttempts = 30
    $attempt = 0
    
    while ($attempt -lt $maxAttempts) {
        $attempt++
        try {
            Invoke-Expression $HealthCommand 2>$null | Out-Null
            if ($LASTEXITCODE -eq 0) {
                return $true
            }
        } catch {
            # Continue polling
        }
        Start-Sleep -Seconds 1
    }
    return $false
}

# Wait for core services to be ready with intelligent polling
Write-Host "`n⏳ Waiting for core services to initialize..." -ForegroundColor Yellow

$coreServices = @(
    @{ Name = "MongoDB"; Container = "ticketing-mongodb"; Command = "docker exec ticketing-mongodb mongosh --quiet --eval 'quit(db.runCommand({ ping: 1 }).ok ? 0 : 1)'" }
    @{ Name = "Kafka"; Container = "ticketing-kafka"; Command = "docker exec ticketing-kafka kafka-broker-api-versions --bootstrap-server localhost:9092" }
)

$allHealthy = $true
foreach ($service in $coreServices) {
    Write-Host "Checking $($service.Name)..." -ForegroundColor Cyan
    if (Test-CoreServiceHealth -ServiceName $service.Name -ContainerName $service.Container -HealthCommand $service.Command) {
        Write-Host "✅ $($service.Name) is ready" -ForegroundColor Green
    } else {
        Write-Host "⚠️ $($service.Name) took too long to start" -ForegroundColor Yellow
        $allHealthy = $false
    }
}

if ($allHealthy) {
    Write-Host "✅ All core services are ready!" -ForegroundColor Green
} else {
    Write-Host "⚠️ Some core services may need more time to fully initialize" -ForegroundColor Yellow
}

# Check microservice health endpoints
Write-Host "`n🔍 Checking microservice health..." -ForegroundColor Yellow
$microservices = @{
    "Passenger" = @{ Port = "8081"; Endpoint = "/api/v1/passenger/health" }
    "Transport" = @{ Port = "8082"; Endpoint = "/api/v1/transport/health" }
    "Ticketing" = @{ Port = "8083"; Endpoint = "/api/v1/ticketing/health" }
    "Payment" = @{ Port = "8084"; Endpoint = "/api/v1/payment/health" }
    "Notification" = @{ Port = "8085"; Endpoint = "/api/v1/notification/health" }
    "Admin" = @{ Port = "8086"; Endpoint = "/api/v1/admin/health" }
}

$healthyCount = 0
foreach ($service in $microservices.GetEnumerator()) {
    try {
        $response = Invoke-WebRequest -Uri "http://localhost:$($service.Value.Port)$($service.Value.Endpoint)" -TimeoutSec 3 -UseBasicParsing -ErrorAction SilentlyContinue
        if ($response) {
            Write-Host "✅ $($service.Key) Service is healthy" -ForegroundColor Green
            $healthyCount++
        } else {
            Write-Host "⚠️ $($service.Key) Service is starting..." -ForegroundColor Yellow
        }
    } catch {
        Write-Host "⚠️ $($service.Key) Service is starting..." -ForegroundColor Yellow
    }
}

Write-Host "`n📊 Service Health: $healthyCount/$($microservices.Count) services ready" -ForegroundColor $(if ($healthyCount -eq $microservices.Count) { "Green" } else { "Yellow" })

# Display service status
Write-Host "`n📊 Service Status:" -ForegroundColor Yellow
Invoke-Expression "$composeCmd ps"

Write-Host "`n🎉 Services Started!" -ForegroundColor Green
Write-Host "=============================================================" -ForegroundColor Cyan
Write-Host "🌐 Service Endpoints:" -ForegroundColor Cyan
Write-Host "  • Passenger Service:    http://localhost:8081/api/v1/passenger" -ForegroundColor White
Write-Host "  • Transport Service:    http://localhost:8082/api/v1/transport" -ForegroundColor White  
Write-Host "  • Ticketing Service:    http://localhost:8083/api/v1/ticketing" -ForegroundColor White
Write-Host "  • Payment Service:      http://localhost:8084/api/v1/payment" -ForegroundColor White
Write-Host "  • Notification Service: http://localhost:8085/api/v1/notification" -ForegroundColor White
Write-Host "  • Admin Service:        http://localhost:8086/api/v1/admin" -ForegroundColor White
Write-Host "  • Kafka UI:             http://localhost:9000" -ForegroundColor White

Write-Host "`n📊 Useful Commands:" -ForegroundColor Cyan
Write-Host "  • Initialize test data: " -NoNewline -ForegroundColor White
Write-Host ".\initialize-test-data.ps1" -ForegroundColor Green
Write-Host "  • Test all APIs:        " -NoNewline -ForegroundColor White
Write-Host ".\test-apis.ps1" -ForegroundColor Green
Write-Host "  • Monitor status:       " -NoNewline -ForegroundColor White
Write-Host ".\status-monitor.ps1" -ForegroundColor Green
Write-Host "  • View all logs:        " -NoNewline -ForegroundColor White
Write-Host "docker compose logs -f" -ForegroundColor Green
Write-Host "  • View service logs:    " -NoNewline -ForegroundColor White
Write-Host "docker compose logs -f <service-name>" -ForegroundColor Green
Write-Host "  • Stop all services:    " -NoNewline -ForegroundColor White
Write-Host "docker compose down" -ForegroundColor Green
Write-Host "  • Restart services:     " -NoNewline -ForegroundColor White
Write-Host "docker compose restart" -ForegroundColor Green
Write-Host "  • Check status:         " -NoNewline -ForegroundColor White
Write-Host "docker compose ps" -ForegroundColor Green

Write-Host "`n� Sample Credentials:" -ForegroundColor Cyan
Write-Host "  Passengers:" -ForegroundColor Yellow
Write-Host "    • john.doe@example.com / JohnDoe123!" -ForegroundColor White
Write-Host "    • jane.smith@example.com / JaneSmith123!" -ForegroundColor White
Write-Host "  Admins:" -ForegroundColor Yellow
Write-Host "    • admin / Admin123!" -ForegroundColor White
Write-Host "    • transport_manager / Manager123!" -ForegroundColor White

Write-Host "`n💡 Next Steps:" -ForegroundColor Cyan
Write-Host "  1. Run " -NoNewline -ForegroundColor White
Write-Host ".\initialize-test-data.ps1" -NoNewline -ForegroundColor Green
Write-Host " to populate test data" -ForegroundColor White
Write-Host "  2. Run " -NoNewline -ForegroundColor White
Write-Host ".\test-apis.ps1" -NoNewline -ForegroundColor Green
Write-Host " to verify all endpoints" -ForegroundColor White
Write-Host "  3. Check " -NoNewline -ForegroundColor White
Write-Host "README.md" -NoNewline -ForegroundColor Green
Write-Host " for API documentation" -ForegroundColor White

Write-Host "`n🚀 All systems ready!" -ForegroundColor Green