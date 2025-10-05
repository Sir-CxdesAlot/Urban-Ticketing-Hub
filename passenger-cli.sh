#!/usr/bin/env bash
# Windhoek Ticketing Platform - Passenger CLI
BASE_URL="${1:-http://localhost}"
PASSENGER_SERVICE="${BASE_URL}:8081"
TRANSPORT_SERVICE="${BASE_URL}:8082"
TICKETING_SERVICE="${BASE_URL}:8083"
SESSION_FILE="/tmp/passenger-session-${USER}.txt"
LOGGED_IN=false
TOKEN=""
USER_EMAIL=""
USER_FIRST_NAME=""
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'
write_header() {
    clear
    echo ""
    echo -e "${CYAN}================================================================================${NC}"
    echo -e "${YELLOW}  🎫 WINDHOEK TICKETING PLATFORM${NC}"
    echo -e "${CYAN}================================================================================${NC}"
    [ "$LOGGED_IN" = true ] && echo -e "${GREEN}  👤 ${USER_FIRST_NAME} (${USER_EMAIL})${NC}" || echo -e "${YELLOW}  👤 Guest${NC}"
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
save_session() { echo "TOKEN=\"$TOKEN\"" > "$SESSION_FILE"; echo "USER_EMAIL=\"$USER_EMAIL\"" >> "$SESSION_FILE"; echo "USER_FIRST_NAME=\"$USER_FIRST_NAME\"" >> "$SESSION_FILE"; }
clear_session() { rm -f "$SESSION_FILE"; LOGGED_IN=false; TOKEN=""; USER_EMAIL=""; USER_FIRST_NAME=""; }
show_register_menu() {
    write_header; echo "REGISTRATION"; read -p "First Name: " firstName; read -p "Last Name: " lastName
    read -p "Email: " email; read -p "Phone: " phone; read -s -p "Password: " password; echo ""
    body="{\"firstName\":\"$firstName\",\"lastName\":\"$lastName\",\"email\":\"$email\",\"phone\":\"$phone\",\"password\":\"$password\"}"
    response=$(invoke_api "${PASSENGER_SERVICE}/api/v1/passenger/register" "POST" "$body")
    if echo "$response" | grep -q "token"; then
        TOKEN=$(echo "$response" | grep -o '"token":"[^"]*' | cut -d'"' -f4)
        USER_EMAIL="$email"; USER_FIRST_NAME="$firstName"; LOGGED_IN=true; save_session
        write_success "Registration successful!"; sleep 2
    else write_error "Registration failed"; pause_screen; fi
}
show_login_menu() {
    write_header; echo "LOGIN"; read -p "Email: " email; read -s -p "Password: " password; echo ""
    body="{\"email\":\"$email\",\"password\":\"$password\"}"
    response=$(invoke_api "${PASSENGER_SERVICE}/api/v1/passenger/login" "POST" "$body")
    if echo "$response" | grep -q "token"; then
        TOKEN=$(echo "$response" | grep -o '"token":"[^"]*' | cut -d'"' -f4)
        USER_EMAIL="$email"; USER_FIRST_NAME=$(echo "$response" | grep -o '"firstName":"[^"]*' | cut -d'"' -f4)
        LOGGED_IN=true; save_session; write_success "Login successful!"; sleep 2
    else write_error "Login failed"; pause_screen; fi
}
show_profile() {
    write_header; [ "$LOGGED_IN" != true ] && write_error "Login required" && pause_screen && return
    profile=$(invoke_api "${PASSENGER_SERVICE}/api/v1/passenger/profile" "GET" "" true)
    echo "$profile" | python3 -m json.tool 2>/dev/null || echo "$profile"; pause_screen
}
show_routes() {
    write_header; echo "ROUTES"; routes=$(invoke_api "${TRANSPORT_SERVICE}/api/v1/transport/routes")
    echo "$routes" | python3 -m json.tool 2>/dev/null || echo "$routes"; pause_screen
}
show_trips() {
    write_header; echo "TRIPS"; trips=$(invoke_api "${TRANSPORT_SERVICE}/api/v1/transport/trips")
    echo "$trips" | python3 -m json.tool 2>/dev/null || echo "$trips"; pause_screen
}
show_my_tickets() {
    write_header; [ "$LOGGED_IN" != true ] && write_error "Login required" && pause_screen && return
    tickets=$(invoke_api "${TICKETING_SERVICE}/api/v1/ticketing/tickets/my" "GET" "" true)
    echo "$tickets" | python3 -m json.tool 2>/dev/null || echo "$tickets"; pause_screen
}
show_main_menu() {
    while true; do
        write_header
        if [ "$LOGGED_IN" = true ]; then
            echo "  1. Profile  2. Routes  3. Trips  4. My Tickets  5. Logout  0. Exit"
        else
            echo "  1. Register  2. Login  3. Routes (Guest)  4. Trips (Guest)  0. Exit"
        fi
        read -p "Option: " choice
        case $choice in
            1) [ "$LOGGED_IN" = true ] && show_profile || show_register_menu ;;
            2) [ "$LOGGED_IN" = true ] && show_routes || show_login_menu ;;
            3) [ "$LOGGED_IN" = true ] && show_trips || show_routes ;;
            4) [ "$LOGGED_IN" = true ] && show_my_tickets || show_trips ;;
            5) [ "$LOGGED_IN" = true ] && clear_session && write_success "Logged out" && sleep 1 ;;
            0) echo ""; echo "Goodbye!"; exit 0 ;;
            *) write_error "Invalid"; sleep 1 ;;
        esac
    done
}
load_session; echo "Starting..."; sleep 1; show_main_menu