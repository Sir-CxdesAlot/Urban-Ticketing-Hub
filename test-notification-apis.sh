#!/bin/bash

# =============================================================================
# Urban Ticketing Hub - Notification Service API Test Script (Bash/CURL)
# =============================================================================
# This script tests all CRUD operations for the Notification Service using curl
# =============================================================================

BASE_URL="${BASE_URL:-http://localhost:8085}"
VERBOSE="${VERBOSE:-false}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Test data
NOTIFICATION_DATA='{
  "recipientId": "user-001",
  "type": "TEST_NOTIFICATION",
  "title": "Test Notification",
  "message": "This is a test notification message",
  "metadata": {
    "testKey": "testValue"
  }
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
print_header "Testing Notification Service Health"
print_step "Testing health endpoint"
health_response=$(curl_test "GET" "$BASE_URL/api/v1/notification/health")
if echo "$health_response" | grep -q "Notification Service is running"; then
    print_success "Health check passed"
else
    print_error "Health check failed"
    exit 1
fi

# Test Notification CRUD
print_header "Testing Notification CRUD Operations"

# Create Notification
print_step "Creating notification"
create_response=$(curl_test "POST" "$BASE_URL/api/v1/notification/notifications" "$NOTIFICATION_DATA")
notification_id=$(echo "$create_response" | grep -o '"id":"[^"]*' | cut -d'"' -f4)
if [ -n "$notification_id" ]; then
    print_success "Notification created successfully (ID: $notification_id)"
else
    print_error "Failed to create notification"
    exit 1
fi

# Read Notification by ID
print_step "Reading notification by ID"
read_response=$(curl_test "GET" "$BASE_URL/api/v1/notification/notifications/$notification_id")
if echo "$read_response" | grep -q "$notification_id"; then
    print_success "Notification retrieved successfully"
else
    print_error "Failed to read notification by ID"
fi

# Read Notifications for User
print_step "Reading notifications for user"
user_notifications_response=$(curl_test "GET" "$BASE_URL/api/v1/notification/users/user-001/notifications")
if echo "$user_notifications_response" | grep -q "$notification_id"; then
    print_success "User notifications retrieved successfully"
else
    print_error "Failed to read user notifications or created notification not found"
fi

# Update Notification
print_step "Updating notification"
update_data='{
  "title": "Updated Test Notification",
  "message": "This is an updated test notification message",
  "status": "DELIVERED"
}'
update_response=$(curl_test "PUT" "$BASE_URL/api/v1/notification/notifications/$notification_id" "$update_data")
if echo "$update_response" | grep -q '"success":true'; then
    print_success "Notification updated successfully"
else
    print_error "Failed to update notification"
fi

# Mark Notification as Read
print_step "Marking notification as read"
read_response=$(curl_test "PUT" "$BASE_URL/api/v1/notification/notifications/$notification_id/read")
if echo "$read_response" | grep -q '"success":true'; then
    print_success "Notification marked as read successfully"
else
    print_error "Failed to mark notification as read"
fi

# Delete Notification
print_step "Deleting notification"
delete_response=$(curl_test "DELETE" "$BASE_URL/api/v1/notification/notifications/$notification_id")
if echo "$delete_response" | grep -q '"success":true'; then
    print_success "Notification deleted successfully"
else
    print_error "Failed to delete notification"
fi

# Test Statistics
print_header "Testing Other Notification Endpoints"

# Test Statistics
print_step "Testing statistics endpoint"
stats_response=$(curl_test "GET" "$BASE_URL/api/v1/notification/statistics")
if echo "$stats_response" | grep -q '"total":'; then
    print_success "Notification statistics retrieved successfully"
else
    print_error "Failed to retrieve notification statistics"
fi

echo -e "\n${GREEN}$(printf '%.0s=' {1..60})${NC}"
echo -e "${GREEN} 🎉 All Notification Service CRUD Tests Completed!${NC}"
echo -e "${GREEN}$(printf '%.0s=' {1..60})${NC}"