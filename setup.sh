#!/bin/bash
# =============================================================================
# Windhoek City Council Distributed Ticketing Platform - Initial Setup Script
# =============================================================================
# For users who just cloned the repository
# Updated: 2025-10-04
# - Enhanced health checks with correct /api/v1/{service}/health endpoints
# - Improved build process with better error handling
# - Added helpful next steps and credentials
# =============================================================================

echo "🚀 Windhoek City Council Distributed Ticketing Platform - Initial Setup"
echo "================================================================="

# Check if Docker is installed and running
echo "🐳 Checking Docker installation..."
if ! command -v docker &> /dev/null; then
    echo "❌ Docker is not installed or not in PATH"
    echo "Please install Docker from https://www.docker.com/get-started"
    exit 1
fi

docker_version=$(docker --version)
echo "✅ Docker found: $docker_version"

# Check if Docker is running
echo "🔍 Checking if Docker is running..."
if ! docker ps &> /dev/null; then
    echo "❌ Docker is not running"
    echo "Please start Docker and try again"
    exit 1
fi
echo "✅ Docker is running"

# Check if Ballerina is installed
echo "🔧 Checking Ballerina installation..."
if ! command -v bal &> /dev/null; then
    echo "❌ Ballerina is not installed or not in PATH"
    echo "Please install Ballerina from https://ballerina.io/downloads/"
    exit 1
fi

bal_version=$(bal version)
echo "✅ Ballerina found: $bal_version"

# Check if Docker Compose plugin is available (modern integrated version)
echo "🔧 Checking Docker Compose..."
if docker compose version &> /dev/null; then
    compose_version=$(docker compose version)
    echo "✅ Docker Compose plugin found: $compose_version"
    COMPOSE_CMD="docker compose"
elif command -v docker-compose &> /dev/null; then
    compose_version=$(docker-compose --version)
    echo "✅ Legacy Docker Compose found: $compose_version"
    echo "⚠️  Consider upgrading to Docker Compose plugin (docker compose)"
    COMPOSE_CMD="docker-compose"
else
    echo "❌ Docker Compose not found"
    echo "Please install Docker Desktop with Compose plugin or standalone docker-compose"
    exit 1
fi

# Build all Ballerina services
echo ""
echo "🏗️ Building Ballerina microservices..."
services=("passenger_service" "transport_service" "ticketing_service" "payment_service" "notification_service" "admin_service")

for service in "${services[@]}"; do
    echo "Building $service..."
    cd "$service" || exit 1
    
    if bal build; then
        echo "✅ $service built successfully"
    else
        echo "❌ Failed to build $service"
        cd ..
        exit 1
    fi
    
    cd ..
done

# Build Docker images and start services (using modern Docker Compose)
echo ""
echo "🐳 Building Docker images and starting services..."
if $COMPOSE_CMD up -d --build; then
    echo "✅ All services started successfully"
else
    echo "❌ Failed to start services"
    exit 1
fi

# Function to wait for service health with intelligent polling
wait_for_health() {
    local service_name="$1"
    local url="$2"
    local max_attempts=30
    local attempt=0
    
    while [ $attempt -lt $max_attempts ]; do
        attempt=$((attempt + 1))
        if curl -sf "$url" > /dev/null 2>&1; then
            return 0  # Success
        fi
        sleep 1
    done
    return 1  # Timeout
}

# Wait for services to be ready with intelligent polling
echo ""
echo "⏳ Waiting for services to initialize..."

declare -A service_urls=(
    ["Passenger Service"]="8081:/api/v1/passenger/health"
    ["Transport Service"]="8082:/api/v1/transport/health"
    ["Ticketing Service"]="8083:/api/v1/ticketing/health"
    ["Payment Service"]="8084:/api/v1/payment/health"
    ["Notification Service"]="8085:/api/v1/notification/health"
    ["Admin Service"]="8086:/api/v1/admin/health"
)

echo "🔍 Polling service health (max 30 seconds)..."

# Track overall progress
total_services=${#service_urls[@]}
ready_services=0
attempt=0
max_attempts=30

while [ $ready_services -lt $total_services ] && [ $attempt -lt $max_attempts ]; do
    attempt=$((attempt + 1))
    ready_services=0
    
    # Check each service
    for service in "${!service_urls[@]}"; do
        IFS=':' read -r port endpoint <<< "${service_urls[$service]}"
        url="http://localhost:$port$endpoint"
        if curl -sf "$url" > /dev/null 2>&1; then
            ready_services=$((ready_services + 1))
        fi
    done
    
    # Calculate progress percentage
    progress=$((ready_services * 100 / total_services))
    echo "Attempt $attempt: $ready_services/$total_services services ready ($progress%)"
    
    if [ $ready_services -eq $total_services ]; then
        echo "✅ All services are healthy!"
        break
    fi
    
    sleep 1
done

# Final health check with detailed results
echo ""
echo "📋 Final service health status:"
for service in "${!service_urls[@]}"; do
    IFS=':' read -r port endpoint <<< "${service_urls[$service]}"
    url="http://localhost:$port$endpoint"
    if curl -sf "$url" > /dev/null 2>&1; then
        echo "✅ $service is healthy"
    else
        echo "❌ $service is not responding"
    fi
done

# Display service status
echo ""
echo "📊 Checking container status..."
$COMPOSE_CMD ps

echo ""
echo "🎉 Setup Complete!"
echo "================================================================="
echo "🌐 Service Endpoints:"
echo "  • Passenger Service:    http://localhost:8081/api/v1/passenger"
echo "  • Transport Service:    http://localhost:8082/api/v1/transport"
echo "  • Ticketing Service:    http://localhost:8083/api/v1/ticketing"
echo "  • Payment Service:      http://localhost:8084/api/v1/payment"
echo "  • Notification Service: http://localhost:8085/api/v1/notification"
echo "  • Admin Service:        http://localhost:8086/api/v1/admin"
echo "  • Kafka UI:             http://localhost:9000"
echo ""
echo "� Useful Scripts:"
echo "  • Initialize test data: ./initialize-test-data.sh"
echo "  • Test all APIs:        ./test-apis.sh"
echo "  • Quick start (future): ./start.sh"
echo ""
echo "📊 Docker Commands:"
echo "  • View logs:            docker compose logs -f"
echo "  • Stop services:        docker compose down"
echo "  • Restart services:     docker compose restart"
echo ""
echo "📝 Sample Credentials:"
echo "  Passengers:"
echo "    • john.doe@example.com / JohnDoe123!"
echo "    • jane.smith@example.com / JaneSmith123!"
echo "  Admins:"
echo "    • admin / Admin123!"
echo "    • transport_manager / Manager123!"
echo ""
echo "💡 Recommended Next Steps:"
echo "  1. Run ./initialize-test-data.sh to populate test data"
echo "  2. Run ./test-apis.sh to verify all endpoints"
echo "  3. Check README.md for detailed API documentation"
echo ""
echo "🚀 Happy coding!"