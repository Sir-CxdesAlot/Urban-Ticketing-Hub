#!/bin/bash

# Passenger Service CRUD Operations Test Script
# This script tests all CRUD operations for the passenger service

echo "Testing Passenger Service CRUD Operations"
echo "=========================================="

BASE_URL="http://localhost:8081/api/v1/passenger"
TEST_USER_EMAIL="testuser@example.com"
TEST_USER_PASSWORD="password123"
TEST_USER_TOKEN=""

# Function to make HTTP requests
make_request() {
    local method=$1
    local url=$2
    local body=$3
    local token=$4

    local headers="-H 'Content-Type: application/json'"
    if [ -n "$token" ]; then
        headers="$headers -H 'Authorization: Bearer $token'"
    fi

    if [ -n "$body" ]; then
        curl -s -X $method "$url" $headers -d "$body"
    else
        curl -s -X $method "$url" $headers
    fi
}

echo ""
echo "1. Testing User Registration (CREATE)"
REGISTER_BODY='{
    "email": "'$TEST_USER_EMAIL'",
    "password": "'$TEST_USER_PASSWORD'",
    "firstName": "Test",
    "lastName": "User",
    "phone": "+1234567890"
}'

response=$(make_request POST "$BASE_URL/register" "$REGISTER_BODY")
if echo "$response" | jq -e '.email' >/dev/null 2>&1; then
    echo "✓ User registration successful"
    firstName=$(echo "$response" | jq -r '.firstName')
    lastName=$(echo "$response" | jq -r '.lastName')
    email=$(echo "$response" | jq -r '.email')
    echo "  User registered: $firstName $lastName ($email)"
elif echo "$response" | jq -e '.message' >/dev/null 2>&1 && echo "$response" | jq -r '.message' | grep -q "already exists"; then
    echo "  User already exists, proceeding with login..."
else
    echo "✗ User registration failed: $response"
    exit 1
fi

# Now login to get the token
echo ""
echo "  Logging in to get authentication token..."
LOGIN_BODY='{
    "email": "'$TEST_USER_EMAIL'",
    "password": "'$TEST_USER_PASSWORD'"
}'

login_response=$(make_request POST "$BASE_URL/login" "$LOGIN_BODY")
if echo "$login_response" | jq -e '.token' >/dev/null 2>&1; then
    echo "✓ User login successful"
    TEST_USER_TOKEN=$(echo "$login_response" | jq -r '.token')
    echo "  Token received: ${TEST_USER_TOKEN:0:20}..."
else
    echo "✗ User login failed: $login_response"
    exit 1
fi

echo ""
echo "2. Testing User Profile Retrieval (READ)"
response=$(make_request GET "$BASE_URL/profile" "" "$TEST_USER_TOKEN")
if echo "$response" | jq -e '.email' >/dev/null 2>&1; then
    echo "✓ Profile retrieval successful"
    firstName=$(echo "$response" | jq -r '.firstName')
    lastName=$(echo "$response" | jq -r '.lastName')
    email=$(echo "$response" | jq -r '.email')
    echo "  User: $firstName $lastName ($email)"
else
    echo "✗ Profile retrieval failed: $response"
fi

echo ""
echo "3. Testing User Profile Update (UPDATE)"
UPDATE_BODY='{
    "firstName": "UpdatedTest",
    "lastName": "UpdatedUser",
    "phone": "+0987654321"
}'

response=$(make_request PUT "$BASE_URL/profile" "$UPDATE_BODY" "$TEST_USER_TOKEN")
if echo "$response" | jq -e '.firstName' >/dev/null 2>&1; then
    echo "✓ Profile update successful"
    firstName=$(echo "$response" | jq -r '.firstName')
    lastName=$(echo "$response" | jq -r '.lastName')
    echo "  Updated user: $firstName $lastName"
else
    echo "✗ Profile update failed: $response"
fi

echo ""
echo "4. Testing Ticket Purchase (CREATE)"
TICKET_BODY='{
    "routeId": "route-123",
    "ticketType": "SINGLE"
}'

response=$(make_request POST "$BASE_URL/tickets" "$TICKET_BODY" "$TEST_USER_TOKEN")
if echo "$response" | jq -e '.id' >/dev/null 2>&1; then
    echo "✓ Ticket purchase successful"
    ticketId=$(echo "$response" | jq -r '.id')
    ticketType=$(echo "$response" | jq -r '.ticketType')
    price=$(echo "$response" | jq -r '.price')
    echo "  Ticket ID: $ticketId, Type: $ticketType, Price: $price"
else
    echo "✗ Ticket purchase failed: $response"
    ticketId=""
fi

echo ""
echo "5. Testing Tickets Retrieval (READ)"
response=$(make_request GET "$BASE_URL/tickets" "" "$TEST_USER_TOKEN")
if echo "$response" | jq -e '.[0]' >/dev/null 2>&1; then
    echo "✓ Tickets retrieval successful"
    ticketCount=$(echo "$response" | jq length)
    echo "  Found $ticketCount ticket(s)"
    if [ "$ticketCount" -gt 0 ]; then
        firstTicket=$(echo "$response" | jq '.[0]')
        ticketId=$(echo "$firstTicket" | jq -r '.id')
        ticketType=$(echo "$firstTicket" | jq -r '.ticketType')
        status=$(echo "$firstTicket" | jq -r '.status')
        echo "  First ticket: ID=$ticketId, Type=$ticketType, Status=$status"
    fi
else
    echo "✗ Tickets retrieval failed: $response"
fi

if [ -n "$ticketId" ]; then
    echo ""
    echo "6. Testing Ticket Update (UPDATE)"
    TICKET_UPDATE_BODY='{
        "status": "PAID"
    }'

    response=$(make_request PUT "$BASE_URL/tickets/$ticketId" "$TICKET_UPDATE_BODY" "$TEST_USER_TOKEN")
    if echo "$response" | jq -e '.success' >/dev/null 2>&1; then
        echo "✓ Ticket update successful"
    else
        echo "✗ Ticket update failed: $response"
    fi

    echo ""
    echo "7. Testing Ticket Deletion (DELETE)"
    response=$(make_request DELETE "$BASE_URL/tickets/$ticketId" "" "$TEST_USER_TOKEN")
    if echo "$response" | jq -e '.success' >/dev/null 2>&1; then
        echo "✓ Ticket deletion successful"
    else
        echo "✗ Ticket deletion failed: $response"
    fi
else
    echo ""
    echo "6-7. Skipping ticket update/delete tests (no ticket created)"
fi

echo ""
echo "8. Testing User Account Deletion (DELETE)"
response=$(make_request DELETE "$BASE_URL/profile" "" "$TEST_USER_TOKEN")
if echo "$response" | jq -e '.success' >/dev/null 2>&1; then
    echo "✓ Account deletion successful"
else
    echo "✗ Account deletion failed: $response"
fi

echo ""
echo "=========================================="
echo "Passenger Service CRUD Tests Completed"
echo "=========================================="