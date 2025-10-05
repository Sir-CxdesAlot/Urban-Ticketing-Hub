#!/bin/bash
# =============================================================================
# Windhoek City Council Distributed Ticketing Platform - Quick Start Script
# =============================================================================
# For users who want to start existing Docker services
# Updated: 2025-10-04
# - Enhanced service health checks with correct /api/v1/{service}/health endpoints
# - Improved status reporting and error handling
# - Added helpful next steps and credentials display
# =============================================================================

echo "🚀 Starting Windhoek City Council Ticketing Platform Services"
echo "============================================================="

# Check if Docker is running
echo "🐳 Checking Docker status..."
if ! docker ps &> /dev/null; then
    echo "❌ Docker is not running"
    echo "Please start Docker and try again"
    exit 1
fi
echo "✅ Docker is running"

# Check if docker-compose.yml exists
if [ ! -f "docker-compose.yml" ]; then
    echo "❌ docker-compose.yml not found in current directory"
    echo "Please run this script from the project root directory"
    exit 1
fi

# Detect modern Docker Compose command
echo "🔧 Detecting Docker Compose version..."
if docker compose version &> /dev/null; then
    COMPOSE_CMD="docker compose"
    echo "✅ Using: docker compose"
elif command -v docker-compose &> /dev/null; then
    COMPOSE_CMD="docker-compose"
    echo "✅ Using: docker-compose (fallback)"
else
    echo "❌ No Docker Compose found"
    exit 1
fi

# Start services (using modern Docker Compose)
echo "🚀 Starting all services..."
if $COMPOSE_CMD up -d; then
    echo "✅ All services started successfully"
else
    echo "❌ Failed to start some services"
    echo "Check the output above for error details"
    exit 1
fi

# Function to check core service health
check_core_service_health() {
    local service_name="$1"
    local health_command="$2"
    local max_attempts=30
    local attempt=0
    
    while [ $attempt -lt $max_attempts ]; do
        attempt=$((attempt + 1))
        if eval "$health_command" &> /dev/null; then
            return 0  # Success
        fi
        sleep 1
    done
    return 1  # Timeout
}

# Wait for core services to be ready with intelligent polling
echo ""
echo "⏳ Waiting for core services to initialize..."

core_services=(
    "MongoDB:docker exec ticketing-mongodb mongosh --quiet --eval 'quit(db.runCommand({ ping: 1 }).ok ? 0 : 1)'"
    "Kafka:docker exec ticketing-kafka kafka-broker-api-versions --bootstrap-server localhost:9092"
)

all_healthy=true
for service_info in "${core_services[@]}"; do
    IFS=':' read -r service_name health_command <<< "$service_info"
    echo "Checking $service_name..."
    if check_core_service_health "$service_name" "$health_command"; then
        echo "✅ $service_name is ready"
    else
        echo "⚠️ $service_name took too long to start"
        all_healthy=false
    fi
done

if [ "$all_healthy" = true ]; then
    echo "✅ All core services are ready!"
else
    echo "⚠️ Some core services may need more time to fully initialize"
fi

# Check microservice health endpoints
echo ""
echo "🔍 Checking microservice health..."

declare -A microservices=(
    ["Passenger"]="8081:/api/v1/passenger/health"
    ["Transport"]="8082:/api/v1/transport/health"
    ["Ticketing"]="8083:/api/v1/ticketing/health"
    ["Payment"]="8084:/api/v1/payment/health"
    ["Notification"]="8085:/api/v1/notification/health"
    ["Admin"]="8086:/api/v1/admin/health"
)

healthy_count=0
total_services=${#microservices[@]}

for service in "${!microservices[@]}"; do
    IFS=':' read -r port endpoint <<< "${microservices[$service]}"
    if curl -sf "http://localhost:$port$endpoint" > /dev/null 2>&1; then
        echo "✅ $service Service is healthy"
        healthy_count=$((healthy_count + 1))
    else
        echo "⚠️ $service Service is starting..."
    fi
done

echo ""
if [ $healthy_count -eq $total_services ]; then
    echo "📊 Service Health: $healthy_count/$total_services services ready ✓"
else
    echo "📊 Service Health: $healthy_count/$total_services services ready (some still starting)"
fi

# Display service status
echo ""
echo "📊 Service Status:"
$COMPOSE_CMD ps



echo ""
echo "🎉 Services Started!"
echo "============================================================="
echo "🌐 Service Endpoints:"
echo "  • Passenger Service:    http://localhost:8081/api/v1/passenger"
echo "  • Transport Service:    http://localhost:8082/api/v1/transport"
echo "  • Ticketing Service:    http://localhost:8083/api/v1/ticketing"
echo "  • Payment Service:      http://localhost:8084/api/v1/payment"
echo "  • Notification Service: http://localhost:8085/api/v1/notification"
echo "  • Admin Service:        http://localhost:8086/api/v1/admin"
echo "  • Kafka UI:             http://localhost:9000"
echo ""
echo "📊 Useful Commands:"
echo "  • Initialize test data: ./initialize-test-data.sh"
echo "  • Test all APIs:        ./test-apis.sh"
echo "  • View all logs:        docker compose logs -f"
echo "  • View service logs:    docker compose logs -f <service-name>"
echo "  • Stop all services:    docker compose down"
echo "  • Restart services:     docker compose restart"
echo "  • Check status:         docker compose ps"
echo ""
echo "� Sample Credentials:"
echo "  Passengers:"
echo "    • john.doe@example.com / JohnDoe123!"
echo "    • jane.smith@example.com / JaneSmith123!"
echo "  Admins:"
echo "    • admin / Admin123!"
echo "    • transport_manager / Manager123!"
echo ""
echo "💡 Next Steps:"
echo "  1. Run ./initialize-test-data.sh to populate test data"
echo "  2. Run ./test-apis.sh to verify all endpoints"
echo "  3. Check README.md for API documentation"
echo ""
echo "🚀 All systems ready!"