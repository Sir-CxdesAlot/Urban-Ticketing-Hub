#!/usr/bin/env bash
# Windhoek Ticketing Platform - Admin CLI
BASE_URL="${1:-http://localhost}"
ADMIN_SERVICE="${BASE_URL}:8086"
TRANSPORT_SERVICE="${BASE_URL}:8082"
SESSION_FILE="/tmp/admin-session-${USER}.txt"
LOGGED_IN=false
TOKEN=""
USERNAME=""
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'
write_header() {
    clear
    echo -e "${CYAN}================================================================================${NC}"
    echo -e "${YELLOW}  🏛️  WINDHOEK TICKETING - ADMIN PORTAL${NC}"
    echo -e "${CYAN}================================================================================${NC}"
    [ "$LOGGED_IN" = true ] && echo -e "${GREEN}  👤 ${USERNAME}${NC}" || echo -e "${YELLOW}  👤 Not logged in${NC}"
    echo -e "${CYAN}================================================================================${NC}"
}
write_success() { echo -e "${GREEN}✅ $1${NC}"; }
write_error() { echo -e "${RED}❌ $1${NC}"; }
pause_screen() { read -n 1 -s -p "Press any key..."; }
invoke_api() {
    local url="$1" method="${2:-GET}" body="$3" use_auth="${4:-false}"
    local headers="-H 'Content-Type: application/json'"
    [ "$use_auth" = true ] && [ -n "$TOKEN" ] && headers="$headers -H 'Authorization: Bearer $TOKEN'"
    [ "$method" = "POST" ] && [ -n "$body" ] && eval curl -s -X POST "$url" $headers -d "'$body'" || eval curl -s -X "$method" "$url" $headers
}
load_session() { [ -f "$SESSION_FILE" ] && source "$SESSION_FILE" && LOGGED_IN=true; }
save_session() { echo "TOKEN=\"$TOKEN\"" > "$SESSION_FILE"; echo "USERNAME=\"$USERNAME\"" >> "$SESSION_FILE"; }
clear_session() { rm -f "$SESSION_FILE"; LOGGED_IN=false; TOKEN=""; USERNAME=""; }
show_login_menu() {
    write_header; echo "ADMIN LOGIN"; read -p "Username: " username; read -s -p "Password: " password; echo ""
    body="{\"username\":\"$username\",\"password\":\"$password\"}"
    response=$(invoke_api "${ADMIN_SERVICE}/api/v1/admin/login" "POST" "$body")
    if echo "$response" | grep -q "token"; then
        TOKEN=$(echo "$response" | grep -o '"token":"[^"]*' | cut -d'"' -f4)
        USERNAME="$username"; LOGGED_IN=true; save_session; write_success "Login successful!"; sleep 2
    else write_error "Login failed"; pause_screen; fi
}
show_dashboard() {
    write_header; [ "$LOGGED_IN" != true ] && write_error "Login required" && pause_screen && return
    dashboard=$(invoke_api "${ADMIN_SERVICE}/api/v1/admin/dashboard" "GET" "" true)
    echo "DASHBOARD:"; echo "$dashboard" | python3 -m json.tool 2>/dev/null || echo "$dashboard"; pause_screen
}
show_routes() {
    write_header; echo "ROUTES"; routes=$(invoke_api "${TRANSPORT_SERVICE}/api/v1/transport/routes")
    echo "$routes" | python3 -m json.tool 2>/dev/null || echo "$routes"; pause_screen
}
show_create_route() {
    write_header; [ "$LOGGED_IN" != true ] && write_error "Login required" && pause_screen && return
    echo "CREATE ROUTE"; read -p "Name: " name; read -p "Start: " start; read -p "End: " end
    read -p "Type (BUS/TRAIN): " type; read -p "Price: " price
    body="{\"name\":\"$name\",\"startLocation\":\"$start\",\"endLocation\":\"$end\",\"transportType\":\"${type^^}\",\"basePrice\":$price,\"isActive\":true}"
    response=$(invoke_api "${TRANSPORT_SERVICE}/api/v1/transport/routes" "POST" "$body")
    write_success "Route created"; pause_screen
}
show_trips() {
    write_header; echo "TRIPS"; trips=$(invoke_api "${TRANSPORT_SERVICE}/api/v1/transport/trips")
    echo "$trips" | python3 -m json.tool 2>/dev/null || echo "$trips"; pause_screen
}
show_create_trip() {
    write_header; [ "$LOGGED_IN" != true ] && write_error "Login required" && pause_screen && return
    echo "CREATE TRIP"; read -p "Route ID: " routeId; read -p "Departure: " dep; read -p "Arrival: " arr; read -p "Seats: " seats
    body="{\"routeId\":\"$routeId\",\"departureTime\":\"$dep\",\"arrivalTime\":\"$arr\",\"totalSeats\":$seats,\"availableSeats\":$seats,\"status\":\"SCHEDULED\"}"
    response=$(invoke_api "${TRANSPORT_SERVICE}/api/v1/transport/trips" "POST" "$body")
    write_success "Trip created"; pause_screen
}
show_disruptions() {
    write_header; [ "$LOGGED_IN" != true ] && write_error "Login required" && pause_screen && return
    disruptions=$(invoke_api "${ADMIN_SERVICE}/api/v1/admin/disruptions" "GET" "" true)
    echo "DISRUPTIONS:"; echo "$disruptions" | python3 -m json.tool 2>/dev/null || echo "$disruptions"; pause_screen
}
show_create_disruption() {
    write_header; [ "$LOGGED_IN" != true ] && write_error "Login required" && pause_screen && return
    echo "CREATE DISRUPTION"; read -p "Route ID: " routeId; read -p "Title: " title; read -p "Description: " desc
    echo "Type: 1=DELAY 2=MAINTENANCE 3=CANCELLATION"; read -p "Type: " typeChoice
    case $typeChoice in 1) type="DELAY";; 2) type="MAINTENANCE";; 3) type="CANCELLATION";; *) type="DELAY";; esac
    body="{\"routeId\":\"$routeId\",\"type\":\"$type\",\"title\":\"$title\",\"description\":\"$desc\"}"
    response=$(invoke_api "${ADMIN_SERVICE}/api/v1/admin/disruptions" "POST" "$body")
    write_success "Disruption created"; pause_screen
}
show_reports() {
    write_header; [ "$LOGGED_IN" != true ] && write_error "Login required" && pause_screen && return
    report=$(invoke_api "${ADMIN_SERVICE}/api/v1/admin/reports/usage" "GET" "" true)
    echo "USAGE REPORT:"; echo "$report" | python3 -m json.tool 2>/dev/null || echo "$report"; pause_screen
}
show_main_menu() {
    while true; do
        write_header
        if [ "$LOGGED_IN" = true ]; then
            echo "  1. Dashboard  2. Routes  3. Create Route  4. Trips  5. Create Trip"
            echo "  6. Disruptions  7. Create Disruption  8. Reports  9. Logout  0. Exit"
        else
            echo "  1. Login  0. Exit"
        fi
        read -p "Option: " choice
        case $choice in
            1) [ "$LOGGED_IN" = true ] && show_dashboard || show_login_menu ;;
            2) [ "$LOGGED_IN" = true ] && show_routes ;;
            3) [ "$LOGGED_IN" = true ] && show_create_route ;;
            4) [ "$LOGGED_IN" = true ] && show_trips ;;
            5) [ "$LOGGED_IN" = true ] && show_create_trip ;;
            6) [ "$LOGGED_IN" = true ] && show_disruptions ;;
            7) [ "$LOGGED_IN" = true ] && show_create_disruption ;;
            8) [ "$LOGGED_IN" = true ] && show_reports ;;
            9) [ "$LOGGED_IN" = true ] && clear_session && write_success "Logged out" && sleep 1 ;;
            0) echo ""; echo "Goodbye!"; exit 0 ;;
            *) write_error "Invalid"; sleep 1 ;;
        esac
    done
}
load_session; echo "Starting Admin CLI..."; sleep 1; show_main_menu