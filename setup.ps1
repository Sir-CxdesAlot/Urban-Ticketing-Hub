# =============================================================================
# Windhoek City Council Distributed Ticketing Platform - Initial Setup Script
# =============================================================================
# For users who just cloned the repository
# Updated: 2025-10-04
# - Enhanced health checks with correct /api/v1/{service}/health endpoints
# - Improved build process with better error handling
# - Added helpful next steps and credentials
# =============================================================================

Write-Host "🚀 Windhoek City Council Distributed Ticketing Platform - Initial Setup" -ForegroundColor Cyan
Write-Host "=================================================================" -ForegroundColor Cyan

# Check if Docker is installed and running
Write-Host "🐳 Checking Docker installation..." -ForegroundColor Yellow
try {
    $dockerVersion = docker --version
    Write-Host "✅ Docker found: $dockerVersion" -ForegroundColor Green
} catch {
    Write-Host "❌ Docker is not installed or not in PATH" -ForegroundColor Red
    Write-Host "Please install Docker Desktop from https://www.docker.com/products/docker-desktop" -ForegroundColor Red
    exit 1
}

# Check if Docker is running
Write-Host "🔍 Checking if Docker is running..." -ForegroundColor Yellow
try {
    docker ps | Out-Null
    Write-Host "✅ Docker is running" -ForegroundColor Green
} catch {
    Write-Host "❌ Docker is not running" -ForegroundColor Red
    Write-Host "Please start Docker Desktop and try again" -ForegroundColor Red
    exit 1
}

# Check if Docker Compose plugin is available (modern integrated version)
Write-Host "🔧 Checking Docker Compose..." -ForegroundColor Yellow
try {
    $composeVersion = docker compose version 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Docker Compose plugin found: $composeVersion" -ForegroundColor Green
    } else {
        # Fallback to legacy docker-compose if plugin not available
        $composeVersion = docker-compose --version 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✅ Legacy Docker Compose found: $composeVersion" -ForegroundColor Green
            Write-Host "⚠️  Consider upgrading to Docker Compose plugin (docker compose)" -ForegroundColor Yellow
        } else {
            throw "Docker Compose not available"
        }
    }
} catch {
    Write-Host "❌ Docker Compose not found" -ForegroundColor Red
    Write-Host "Please install Docker Desktop with Compose plugin or standalone docker-compose" -ForegroundColor Red
    exit 1
}

# Build all Ballerina services
Write-Host "`n🏗️ Building Ballerina microservices..." -ForegroundColor Yellow
$services = @("passenger_service", "transport_service", "ticketing_service", "payment_service", "notification_service", "admin_service")

foreach ($service in $services) {
    Write-Host "Building $service..." -ForegroundColor Cyan
    Set-Location $service
    
    # Use ErrorAction Stop to turn non-zero exit codes into terminating errors
    try {
        bal build
        Write-Host "✅ $service built successfully" -ForegroundColor Green
    } catch {
        Write-Host "❌ Failed to build $service" -ForegroundColor Red
        Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
        Set-Location ..
        exit 1
    }
    
    Set-Location ..
}

# Build Docker images and start services (using modern Docker Compose)
Write-Host "`n🐳 Building Docker images and starting services..." -ForegroundColor Yellow
try {
    # Try modern Docker Compose plugin first, fallback to legacy if needed
    docker compose version 2>$null
    $composeCmd = if ($LASTEXITCODE -eq 0) { "docker compose" } else { "docker-compose" }
    
    Invoke-Expression "$composeCmd up -d --build"
    Write-Host "✅ All services started successfully" -ForegroundColor Green
} catch {
    Write-Host "❌ Failed to start services" -ForegroundColor Red
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Wait for services to be ready with intelligent polling
Write-Host "`n⏳ Waiting for services to initialize..." -ForegroundColor Yellow

$services_health = @{
    "Passenger Service" = @{ Port = "8081"; Endpoint = "/api/v1/passenger/health" }
    "Transport Service" = @{ Port = "8082"; Endpoint = "/api/v1/transport/health" }
    "Ticketing Service" = @{ Port = "8083"; Endpoint = "/api/v1/ticketing/health" }
    "Payment Service" = @{ Port = "8084"; Endpoint = "/api/v1/payment/health" }
    "Notification Service" = @{ Port = "8085"; Endpoint = "/api/v1/notification/health" }
    "Admin Service" = @{ Port = "8086"; Endpoint = "/api/v1/admin/health" }
}

$maxAttempts = 30  # 30 attempts = ~30 seconds with 1-second intervals
$attempt = 0
$allHealthy = $false

Write-Host "🔍 Polling service health (max 30 seconds)..." -ForegroundColor Yellow

while (-not $allHealthy -and $attempt -lt $maxAttempts) {
    $attempt++
    $healthyServices = 0
    
    foreach ($service in $services_health.GetEnumerator()) {
        try {
            $url = "http://localhost:$($service.Value.Port)$($service.Value.Endpoint)"
            $response = Invoke-WebRequest -Uri $url -Method GET -TimeoutSec 2 -UseBasicParsing -ErrorAction SilentlyContinue
            if ($response.StatusCode -eq 200 -or $response) {
                $healthyServices++
            }
        } catch {
            # Service not ready yet, continue polling
        }
    }
    
    $progress = [math]::Round(($healthyServices / $services_health.Count) * 100)
    Write-Host "Attempt $attempt`: $healthyServices/$($services_health.Count) services ready ($progress%)" -ForegroundColor Cyan
    
    if ($healthyServices -eq $services_health.Count) {
        $allHealthy = $true
        Write-Host "✅ All services are healthy!" -ForegroundColor Green
    } else {
        Start-Sleep -Seconds 1
    }
}

# Final health check with detailed results
Write-Host "`n📋 Final service health status:" -ForegroundColor Yellow
foreach ($service in $services_health.GetEnumerator()) {
    try {
        $url = "http://localhost:$($service.Value.Port)$($service.Value.Endpoint)"
        $response = Invoke-WebRequest -Uri $url -Method GET -TimeoutSec 5 -UseBasicParsing
        if ($response.StatusCode -eq 200 -or $response) {
            Write-Host "✅ $($service.Key) is healthy" -ForegroundColor Green
        } else {
            Write-Host "⚠️ $($service.Key) returned unexpected response" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "❌ $($service.Key) is not responding" -ForegroundColor Red
    }
}

# Display service status
Write-Host "`n📊 Checking container status..." -ForegroundColor Yellow
docker compose version 2>$null
$composeCmd = if ($LASTEXITCODE -eq 0) { "docker compose" } else { "docker-compose" }
Invoke-Expression "$composeCmd ps"

Write-Host "`n🎉 Setup Complete!" -ForegroundColor Green
Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host "🌐 Service Endpoints:" -ForegroundColor Cyan
Write-Host "  • Passenger Service:    http://localhost:8081/api/v1/passenger" -ForegroundColor White
Write-Host "  • Transport Service:    http://localhost:8082/api/v1/transport" -ForegroundColor White
Write-Host "  • Ticketing Service:    http://localhost:8083/api/v1/ticketing" -ForegroundColor White
Write-Host "  • Payment Service:      http://localhost:8084/api/v1/payment" -ForegroundColor White
Write-Host "  • Notification Service: http://localhost:8085/api/v1/notification" -ForegroundColor White
Write-Host "  • Admin Service:        http://localhost:8086/api/v1/admin" -ForegroundColor White
Write-Host "  • Kafka UI:             http://localhost:9000" -ForegroundColor White

Write-Host "`n� Useful Scripts:" -ForegroundColor Cyan
Write-Host "  • Initialize test data: " -NoNewline -ForegroundColor White
Write-Host ".\initialize-test-data.ps1" -ForegroundColor Green
Write-Host "  • Test all APIs:        " -NoNewline -ForegroundColor White
Write-Host ".\test-apis.ps1" -ForegroundColor Green
Write-Host "  • Monitor status:       " -NoNewline -ForegroundColor White
Write-Host ".\status-monitor.ps1" -ForegroundColor Green
Write-Host "  • Quick start (future): " -NoNewline -ForegroundColor White
Write-Host ".\start.ps1" -ForegroundColor Green

Write-Host "`n📊 Docker Commands:" -ForegroundColor Cyan
Write-Host "  • View logs:            " -NoNewline -ForegroundColor White
Write-Host "docker compose logs -f" -ForegroundColor Green
Write-Host "  • Stop services:        " -NoNewline -ForegroundColor White
Write-Host "docker compose down" -ForegroundColor Green
Write-Host "  • Restart services:     " -NoNewline -ForegroundColor White
Write-Host "docker compose restart" -ForegroundColor Green

Write-Host "`n📝 Sample Credentials:" -ForegroundColor Cyan
Write-Host "  Passengers:" -ForegroundColor Yellow
Write-Host "    • john.doe@example.com / JohnDoe123!" -ForegroundColor White
Write-Host "    • jane.smith@example.com / JaneSmith123!" -ForegroundColor White
Write-Host "  Admins:" -ForegroundColor Yellow
Write-Host "    • admin / Admin123!" -ForegroundColor White
Write-Host "    • transport_manager / Manager123!" -ForegroundColor White

Write-Host "`n💡 Recommended Next Steps:" -ForegroundColor Cyan
Write-Host "  1. Run " -NoNewline -ForegroundColor White
Write-Host ".\initialize-test-data.ps1" -NoNewline -ForegroundColor Green
Write-Host " to populate test data" -ForegroundColor White
Write-Host "  2. Run " -NoNewline -ForegroundColor White
Write-Host ".\test-apis.ps1" -NoNewline -ForegroundColor Green
Write-Host " to verify all endpoints" -ForegroundColor White
Write-Host "  3. Check " -NoNewline -ForegroundColor White
Write-Host "README.md" -NoNewline -ForegroundColor Green
Write-Host " for detailed API documentation" -ForegroundColor White

Write-Host "`n🚀 Happy coding!" -ForegroundColor Green