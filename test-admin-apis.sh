#!/bin/bash

# =============================================================================
# Urban Ticketing Hub - Admin Service API Test Script (Bash/CURL)
# =============================================================================
# This script tests all CRUD operations for the Admin Service using curl
# =============================================================================

BASE_URL="${BASE_URL:-http://localhost:8086}"
VERBOSE="${VERBOSE:-false}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Test data
ADMIN_USER='{
  "username": "testadmin",
  "email": "testadmin@example.com",
  "password": "TestAdmin123!",
  "role": "SUPER_ADMIN"
}'

DISRUPTION_DATA='{
  "routeId": "route-001",
  "type": "DELAY",
  "title": "Test Delay",
  "description": "Testing disruption creation",
  "startTime": "2025-10-11T10:00:00Z",
  "endTime": "2025-10-11T12:00:00Z"
}'

print_header() {
    echo -e "\n${CYAN}$(printf '%.0s=' {1..60})${NC}"
    echo -e "${YELLOW} 🧪 $1${NC}"
    echo -e "${CYAN}$(printf '%.0s=' {1..60})${NC}"
}

print_step() {
    echo -e "${BLUE}🔍 $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

curl_test() {
    local method=$1
    local url=$2
    local data=$3

    local curl_cmd="curl -s -X $method -H 'Content-Type: application/json'"

    if [ -n "$data" ]; then
        curl_cmd="$curl_cmd -d '$data'"
    fi

    curl_cmd="$curl_cmd $url"

    if [ "$VERBOSE" = "true" ]; then
        echo "$curl_cmd"
    fi

    eval "$curl_cmd"
}

# Test Health Check
print_header "Testing Admin Service Health"
print_step "Testing health endpoint"
health_response=$(curl_test "GET" "$BASE_URL/api/v1/admin/health")
if echo "$health_response" | grep -q "Admin Service is running"; then
    print_success "Health check passed"
else
    print_error "Health check failed"
    exit 1
fi

# Test Admin User CRUD
print_header "Testing Admin User CRUD Operations"

# Create Admin User
print_step "Creating admin user"
create_response=$(curl_test "POST" "$BASE_URL/api/v1/admin/admin-users" "$ADMIN_USER")
admin_id=$(echo "$create_response" | grep -o '"adminId":"[^"]*' | cut -d'"' -f4)
if [ -n "$admin_id" ]; then
    print_success "Admin user created successfully (ID: $admin_id)"
else
    print_error "Failed to create admin user"
    exit 1
fi

# Read Admin Users
print_step "Reading all admin users"
read_response=$(curl_test "GET" "$BASE_URL/api/v1/admin/admin-users")
if echo "$read_response" | grep -q "$admin_id"; then
    print_success "Admin users retrieved successfully"
else
    print_error "Failed to read admin users or created user not found"
fi

# Update Admin User
print_step "Updating admin user"
update_data='{
  "username": "updatedadmin",
  "email": "updatedadmin@example.com",
  "role": "TRANSPORT_ADMIN"
}'
update_response=$(curl_test "PUT" "$BASE_URL/api/v1/admin/admin-users/$admin_id" "$update_data")
if echo "$update_response" | grep -q '"success":true'; then
    print_success "Admin user updated successfully"
else
    print_error "Failed to update admin user"
fi

# Delete Admin User
print_step "Deleting admin user"
delete_response=$(curl_test "DELETE" "$BASE_URL/api/v1/admin/admin-users/$admin_id")
if echo "$delete_response" | grep -q '"success":true'; then
    print_success "Admin user deleted successfully"
else
    print_error "Failed to delete admin user"
fi

# Test Service Disruption CRUD
print_header "Testing Service Disruption CRUD Operations"

# Create Disruption
print_step "Creating service disruption"
create_disruption_response=$(curl_test "POST" "$BASE_URL/api/v1/admin/disruptions" "$DISRUPTION_DATA")
disruption_id=$(echo "$create_disruption_response" | grep -o '"id":"[^"]*' | cut -d'"' -f4)
if [ -n "$disruption_id" ]; then
    print_success "Service disruption created successfully (ID: $disruption_id)"
else
    print_error "Failed to create service disruption"
    exit 1
fi

# Read Disruptions
print_step "Reading all disruptions"
read_disruptions_response=$(curl_test "GET" "$BASE_URL/api/v1/admin/disruptions")
if echo "$read_disruptions_response" | grep -q "$disruption_id"; then
    print_success "Disruptions retrieved successfully"
else
    print_error "Failed to read disruptions or created disruption not found"
fi

# Update Disruption
print_step "Updating service disruption"
update_disruption_data='{
  "title": "Updated Test Delay",
  "description": "Updated testing disruption",
  "status": "RESOLVED"
}'
update_disruption_response=$(curl_test "PUT" "$BASE_URL/api/v1/admin/disruptions/$disruption_id" "$update_disruption_data")
if echo "$update_disruption_response" | grep -q '"success":true'; then
    print_success "Service disruption updated successfully"
else
    print_error "Failed to update service disruption"
fi

# Update Disruption Status
print_step "Updating disruption status"
status_update_data='{"status": "ACTIVE"}'
status_update_response=$(curl_test "PUT" "$BASE_URL/api/v1/admin/disruptions/$disruption_id/status" "$status_update_data")
if echo "$status_update_response" | grep -q '"success":true'; then
    print_success "Disruption status updated successfully"
else
    print_error "Failed to update disruption status"
fi

# Delete Disruption
print_step "Deleting service disruption"
delete_disruption_response=$(curl_test "DELETE" "$BASE_URL/api/v1/admin/disruptions/$disruption_id")
if echo "$delete_disruption_response" | grep -q '"success":true'; then
    print_success "Service disruption deleted successfully"
else
    print_error "Failed to delete service disruption"
fi

# Test Other Endpoints
print_header "Testing Other Admin Endpoints"

# Test Dashboard
print_step "Testing dashboard endpoint"
dashboard_response=$(curl_test "GET" "$BASE_URL/api/v1/admin/dashboard")
if echo "$dashboard_response" | grep -q "systemStatus"; then
    print_success "Dashboard retrieved successfully"
else
    print_error "Failed to retrieve dashboard"
fi

# Test Usage Report
print_step "Testing usage report endpoint"
report_response=$(curl_test "GET" "$BASE_URL/api/v1/admin/reports/usage?period=daily")
if echo "$report_response" | grep -q "period"; then
    print_success "Usage report generated successfully"
else
    print_error "Failed to generate usage report"
fi

# Test Login
print_step "Testing admin login"
login_data='{
  "username": "admin",
  "password": "Admin123!"
}'
login_response=$(curl_test "POST" "$BASE_URL/api/v1/admin/login" "$login_data")
if echo "$login_response" | grep -q '"success":true'; then
    print_success "Admin login successful"
else
    print_error "Admin login failed"
fi

echo -e "\n${GREEN}$(printf '%.0s=' {1..60})${NC}"
echo -e "${GREEN} 🎉 All Admin Service CRUD Tests Completed!${NC}"
echo -e "${GREEN}$(printf '%.0s=' {1..60})${NC}"