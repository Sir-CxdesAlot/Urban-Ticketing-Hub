# Windhoek City Council Distributed Ticketing Platform

A modern, scalable distributed ticketing system for public transport in Windhoek, built with Ballerina microservices, Kafka for event-driven communication, and MongoDB for persistence.

## 🏗️ System Architecture

The system consists of 6 microservices:

1. **Passenger Service** (Port 8081) - User registration, login, account management (`/api/v1/passenger`)
2. **Transport Service** (Port 8082) - Routes and trips management (`/api/v1/transport`)
3. **Ticketing Service** (Port 8083) - Ticket lifecycle management (`/api/v1/ticketing`)
4. **Payment Service** (Port 8084) - Payment processing simulation (`/api/v1/payment`)
5. **Notification Service** (Port 8085) - Real-time notifications (`/api/v1/notification`)
6. **Admin Service** (Port 8086) - Administrative functions and reporting (`/api/v1/admin`)

## 🛠️ Technology Stack

- **Backend**: Ballerina 2201.12.10 (Swan Lake Update 12)
- **Message Broker**: Apache Kafka 4.1.0 with Zookeeper
- **Database**: MongoDB 6.0
- **Containerization**: Docker & Docker Compose
- **API**: RESTful services with JSON

## 📋 Prerequisites

Before running the system, ensure you have:

- Docker Desktop
- Docker Compose
- Git

## 🚀 Quick Start

### Option 1: Automated Setup (Recommended for first-time users)

**Windows (PowerShell):**

```powershell
git clone <repository-url>
cd assignment2
.\setup.ps1
```

**Linux/Mac (Bash):**

```bash
git clone <repository-url>
cd assignment2
chmod +x setup.sh
./setup.sh
```

### Option 2: Manual Setup

### 1. Clone the Repository

```bash
git clone <repository-url>
cd assignment2
```

### 2. Start the System

```bash
docker-compose up -d
```

This command will:

- Start MongoDB, Kafka, and Zookeeper
- Build and run all 6 microservices
- Initialize the database with sample data
- Start Kafka UI for monitoring on port 9000 (optional)

### 3. Verify Services

Check that all services are running:

```bash
docker-compose ps
```

You should see all services in "Up" state.

### Option 3: Quick Start (For subsequent runs)

If you've already set up the project and just want to start the services:

**Windows:**

```powershell
.\start.ps1
```

**Linux/Mac:**

```bash
./start.sh
```

### 4. Initialize Test Data (Recommended)

**Windows:**
```powershell
.\initialize-test-data.ps1
```

**Linux/Mac:**
```bash
./initialize-test-data.sh
```

This will populate the system with sample passengers, routes, trips, tickets, and admin users.

### 5. Test the APIs (Optional)

**Windows:**
```powershell
.\test-apis.ps1
```

**Linux/Mac:**
```bash
./test-apis.sh
```

### 6. Monitor System Status

**Windows:**
```powershell
.\status-monitor.ps1          # One-time check
.\status-monitor.ps1 -Watch   # Continuous monitoring
```

### 7. Access Services

- **Passenger Service**: <http://localhost:8081/api/v1/passenger>
- **Transport Service**: <http://localhost:8082/api/v1/transport>
- **Ticketing Service**: <http://localhost:8083/api/v1/ticketing>
- **Payment Service**: <http://localhost:8084/api/v1/payment>
- **Notification Service**: <http://localhost:8085/api/v1/notification>
- **Admin Service**: <http://localhost:8086/api/v1/admin>
- **Kafka UI**: <http://localhost:9000> (optional)

## 📊 Sample Data & Credentials

After running `initialize-test-data.ps1` or `initialize-test-data.sh`, the system will have:

### 👤 Passenger Accounts

- **Email**: `john.doe@example.com` | **Password**: `JohnDoe123!`
- **Email**: `jane.smith@example.com` | **Password**: `JaneSmith123!`
- **Email**: `mike.johnson@example.com` | **Password**: `MikeJohnson123!`
- **Email**: `sarah.wilson@example.com` | **Password**: `SarahWilson123!`
- **Email**: `david.brown@example.com` | **Password**: `DavidBrown123!`

### 🏛️ Admin Accounts

- **Username**: `admin` | **Password**: `Admin123!` | **Role**: SUPER_ADMIN
- **Username**: `transport_manager` | **Password**: `Manager123!` | **Role**: TRANSPORT_MANAGER
- **Username**: `route_operator` | **Password**: `Operator123!` | **Role**: ROUTE_OPERATOR

### 🚌 Sample Routes (5 routes, 35 trips)

- **City Center - Katutura** (BUS) - N$15.50
- **Windhoek Central - Airport** (TRAIN) - N$45.00
- **Khomasdal Circuit** (BUS) - N$12.00
- **Northern Express** (TRAIN) - N$120.00
- **University Shuttle** (BUS) - N$8.50

## 🎯 Core Workflows

### 1. Passenger Registration & Login

```bash
# Register new passenger
curl -X POST http://localhost:8081/api/v1/passenger/register \
  -H "Content-Type: application/json" \
  -d '{
    "firstName": "Jane",
    "lastName": "Smith", 
    "email": "jane.smith@example.com",
    "password": "JaneSmith123!",
    "phone": "+264811234569"
  }'

# Login
curl -X POST http://localhost:8081/api/v1/passenger/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "jane.smith@example.com",
    "password": "JaneSmith123!"
  }'
```

### 2. Browse Routes & Trips

```bash
# Get all routes
curl http://localhost:8082/api/v1/transport/routes

# Get specific route by ID
curl http://localhost:8082/api/v1/transport/routes/{routeId}

# Get all trips
curl http://localhost:8082/api/v1/transport/trips
```

### 3. Purchase Ticket

```bash
# Create ticket
curl -X POST http://localhost:8083/api/v1/ticketing/tickets \
  -H "Content-Type: application/json" \
  -d '{
    "passengerId": "passenger-id-from-login",
    "routeId": "68e097906c8ee45adaf1924a", 
    "tripId": "trip-id-from-trips-endpoint",
    "ticketType": "single",
    "price": 15.50
  }'

# Process payment
curl -X POST http://localhost:8084/api/v1/payment/process \
  -H "Content-Type: application/json" \
  -d '{
    "ticketId": "ticket-id-from-above",
    "passengerId": "passenger-id",
    "amount": 15.50,
    "method": "CARD",
    "cardNumber": "4532123456789012",
    "expiryMonth": "12",
    "expiryYear": "2026", 
    "cvv": "123"
  }'
```

### 4. Validate Ticket

```bash
# Validate ticket on boarding
curl -X PUT http://localhost:8083/api/v1/ticketing/tickets/{ticketId}/validate

# Check ticket status
curl http://localhost:8083/api/v1/ticketing/tickets/{ticketId}
```

### 5. Admin Functions

```bash
# Admin login
curl -X POST http://localhost:8086/api/v1/admin/login \
  -H "Content-Type: application/json" \
  -d '{
    "username": "admin",
    "password": "Admin123!"
  }'

# Get admin dashboard
curl http://localhost:8086/api/v1/admin/dashboard

# Create service disruption
curl -X POST http://localhost:8086/api/v1/admin/disruptions \
  -H "Content-Type: application/json" \
  -d '{
    "routeId": "68e097906c8ee45adaf1924a",
    "type": "MAINTENANCE",
    "title": "Route Maintenance",
    "description": "Scheduled maintenance on route. Expect delays.",
    "startTime": "2025-10-05T14:00:00Z",
    "endTime": "2025-10-05T18:00:00Z"
  }'

# Get usage statistics
curl http://localhost:8086/api/v1/admin/reports/usage
```

## � User Interaction Guide

### 🎫 Passenger Interactions

**What Passengers Can Do:**

- Create accounts and manage profiles
- Browse available routes and schedules  
- Purchase different types of tickets (single, multiple, pass)
- View their ticket history and status
- Receive notifications about delays and disruptions
- Validate tickets when boarding transport

#### **Passenger Service API (Port 8081):**

| Action | Method | Endpoint | Description |
|--------|--------|----------|-------------|
| Register | POST | `/api/v1/passenger/register` | Create new account |
| Login | POST | `/api/v1/passenger/login` | Get JWT token |
| View Profile | GET | `/api/v1/passenger/profile` | Get account details |
| View Tickets | GET | `/api/v1/passenger/tickets` | See purchased tickets |

#### **Complete Passenger Journey:**

```bash
# 1. Register as new passenger
curl -X POST http://localhost:8081/api/v1/passenger/register \
  -H "Content-Type: application/json" \
  -d '{
    "firstName": "Alice",
    "lastName": "Johnson", 
    "email": "alice@example.com",
    "password": "secure123",
    "phone": "+264-61-555123"
  }'

# 2. Login to get JWT token
curl -X POST http://localhost:8081/api/v1/passenger/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "alice@example.com",
    "password": "secure123"
  }'

# 3. Browse available routes
curl http://localhost:8082/api/v1/transport/routes

# 4. Check trip schedules for a route
curl http://localhost:8082/api/v1/transport/routes/route-001/trips

# 5. Purchase a ticket
curl -X POST http://localhost:8083/ticketing/tickets \
  -H "Content-Type: application/json" \
  -d '{
    "passengerId": "passenger-id-from-login",
    "routeId": "route-001",
    "tripId": "trip-001", 
    "ticketType": "single",
    "price": 15.00
  }'

# 6. Make payment
curl -X POST http://localhost:8084/payment/payments \
  -H "Content-Type: application/json" \
  -d '{
    "ticketId": "ticket-id-from-step-5",
    "passengerId": "passenger-id",
    "amount": 15.00,
    "method": "CARD",
    "paymentDetails": {
      "cardNumber": "4532123456789012",
      "expiryMonth": "12", 
      "expiryYear": "2026",
      "cvv": "123"
    }
  }'

# 7. View ticket history (requires JWT token)
curl -H "Authorization: Bearer <jwt-token>" \
  http://localhost:8081/api/v1/passenger/tickets

# 8. Validate ticket when boarding (done by conductor/validator)
curl -X PUT http://localhost:8083/ticketing/tickets/<ticket-id>/validate
```

### 🏛️ Admin Interactions

**What Admins Can Do:**

- Manage routes and trip schedules
- Monitor system usage and generate reports
- Create and manage service disruptions
- View real-time system statistics
- Publish schedule updates and announcements
- Manage other admin users

#### **Admin Service API (Port 8086):**

| Action | Method | Endpoint | Description |
|--------|--------|----------|-------------|
| Login | POST | `/api/v1/admin/login` | Admin authentication |
| Dashboard | GET | `/api/v1/admin/dashboard` | System overview |
| Usage Reports | GET | `/api/v1/admin/reports/usage` | Analytics & statistics |
| Create Disruption | POST | `/api/v1/admin/disruptions` | Service alerts |
| List Disruptions | GET | `/api/v1/admin/disruptions` | View all disruptions |
| Manage Users | POST | `/api/v1/admin/admin-users` | Create admin users |

#### **Complete Admin Journey:**

```bash
# 1. Admin login
curl -X POST http://localhost:8086/api/v1/admin/login \
  -H "Content-Type: application/json" \
  -d '{
    "username": "admin",
    "password": "Admin123!"
  }'

# 2. View system dashboard
curl http://localhost:8086/api/v1/admin/dashboard

# 3. Create new route (via Transport Service)
curl -X POST http://localhost:8082/api/v1/transport/routes \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Airport Shuttle",
    "startLocation": "City Center",
    "endLocation": "Hosea Kutako Airport",
    "intermediateStops": ["Windhoek Mall", "Klein Windhoek"],
    "transportType": "BUS",
    "basePrice": 25.0,
    "isActive": true
  }'

# 4. Add trip schedule 
curl -X POST http://localhost:8082/api/v1/transport/trips \
  -H "Content-Type: application/json" \
  -d '{
    "routeId": "route-003",
    "departureTime": "2025-10-05T08:00:00Z",
    "arrivalTime": "2025-10-05T08:45:00Z", 
    "availableSeats": 30,
    "totalSeats": 30,
    "status": "SCHEDULED"
  }'

# 5. Create service disruption alert
curl -X POST http://localhost:8086/api/v1/admin/disruptions \
  -H "Content-Type: application/json" \
  -d '{
    "routeId": "68e097906c8ee45adaf1924a",
    "type": "DELAY",
    "title": "Construction Delay",
    "description": "Road construction causing 20-minute delays",
    "startTime": "2025-10-05T07:00:00Z",
    "endTime": "2025-10-05T19:00:00Z"
  }'

# 6. Generate usage report
curl http://localhost:8086/api/v1/admin/reports/usage

# 7. View all service disruptions
curl http://localhost:8086/api/v1/admin/disruptions

# 8. Create new admin user
curl -X POST http://localhost:8086/api/v1/admin/admin-users \
  -H "Content-Type: application/json" \
  -d '{
    "username": "transport_admin",
    "email": "transport@windhoek.gov.na",
    "password": "TransportAdmin123!",
    "role": "TRANSPORT_MANAGER"
  }'
```

### 🔄 Real-Time Event Flow

The system uses Kafka for real-time communication:

1. **Ticket Purchase** → Triggers payment processing → Updates ticket status
2. **Payment Success** → Activates ticket → Sends confirmation notification  
3. **Schedule Changes** → Publishes to Kafka → Notifies all affected passengers
4. **Service Disruptions** → Broadcasts alerts → Updates passenger apps
5. **Ticket Validation** → Records usage → Updates analytics

### 📱 Notification System

Passengers automatically receive notifications for:

- Payment confirmations
- Ticket activation
- Schedule delays/changes  
- Service disruptions
- Route cancellations

Admins receive alerts for:

- System performance issues
- High traffic periods
- Payment failures
- Service disruptions needing attention

## �📈 Kafka Topics

The system uses these Kafka topics for event-driven communication:

- **ticket.requests** - Ticket purchase requests
- **payments.processed** - Payment confirmations/failures  
- **schedule.updates** - Route schedule changes
- **ticket.validations** - Ticket validation events

Monitor these topics via Kafka UI at <http://localhost:9000>

## 🗄️ Database Schema

### Collections

- `users` - Passenger accounts
- `routes` - Bus/train routes
- `trips` - Scheduled departures
- `tickets` - Ticket records and lifecycle
- `payments` - Payment transactions
- `notifications` - User notifications
- `service_disruptions` - Service alerts
- `admin_users` - Administrative users

## 🔧 Development

### Building Individual Services

```bash
# Navigate to service directory
cd passenger_service

# Build Ballerina project  
bal build

# Run locally
bal run .
```

### Environment Variables

Services can be configured via environment variables:

- `MONGO_HOST` - MongoDB host (default: localhost)
- `MONGO_PORT` - MongoDB port (default: 27017)
- `DATABASE_NAME` - Database name (default: ticketing_platform)
- `KAFKA_BOOTSTRAP_SERVERS` - Kafka servers (default: localhost:9092)

## 🧪 Testing

### Automated API Testing

**Windows:**
```powershell
.\test-apis.ps1
```

**Linux/Mac:**
```bash
./test-apis.sh
```

This comprehensive test script validates:
- All 6 service health endpoints
- Passenger registration and login
- Route and trip retrieval
- Ticket creation and payment processing
- Admin authentication and dashboard
- Service disruption creation

### Manual Testing

You can also test individual endpoints using the curl commands shown in the workflows above, or use tools like:
- **Postman** - Import the API collection
- **Thunder Client** (VS Code extension)
- **HTTPie** - Command-line HTTP client

## 📊 Monitoring & Observability

### Health Checks

Each service exposes health endpoints:

```bash
curl http://localhost:8081/api/v1/passenger/health
curl http://localhost:8082/api/v1/transport/health
curl http://localhost:8083/api/v1/ticketing/health
curl http://localhost:8084/api/v1/payment/health
curl http://localhost:8085/api/v1/notification/health
curl http://localhost:8086/api/v1/admin/health
```

### Status Monitor Script

**Windows:**
```powershell
.\status-monitor.ps1          # One-time status check
.\status-monitor.ps1 -Watch   # Continuous monitoring (refreshes every 5 seconds)
```

The status monitor provides:
- Real-time service health status
- MongoDB and Kafka connectivity
- Docker container status
- Quick action commands

### Logs

View service logs:

```bash
# All services
docker-compose logs -f

# Specific service
docker-compose logs -f passenger-service
```

### Metrics

- **Kafka UI**: <http://localhost:9000> - Monitor topics, consumers, lag
- **MongoDB**: Use MongoDB Compass to connect to `mongodb://localhost:27017`

## 🛑 Stopping the System

```bash
# Stop all services
docker-compose down

# Stop and remove volumes (clears data)
docker-compose down -v
```

## 📁 Project Structure

```text
assignment2/
├── passenger_service/
│   ├── main.bal
│   ├── Ballerina.toml
│   ├── Config.toml
│   └── Dockerfile
├── transport_service/
│   ├── main.bal
│   ├── Ballerina.toml
│   ├── Config.toml  
│   └── Dockerfile
├── ticketing_service/
│   ├── main.bal
│   ├── Ballerina.toml
│   ├── Config.toml
│   └── Dockerfile
├── payment_service/
│   ├── main.bal
│   ├── Ballerina.toml
│   ├── Config.toml
│   └── Dockerfile
├── notification_service/
│   ├── main.bal
│   ├── Ballerina.toml
│   ├── Config.toml
│   └── Dockerfile
├── admin_service/
│   ├── main.bal
│   ├── Ballerina.toml
│   ├── Config.toml
│   └── Dockerfile
├── docker-compose.yml
├── init-mongo.js
├── setup.ps1                    # Initial setup (Windows)
├── setup.sh                     # Initial setup (Linux/Mac)
├── start.ps1                    # Quick start (Windows)
├── start.sh                     # Quick start (Linux/Mac)
├── status-monitor.ps1           # Status monitoring (Windows)
├── initialize-test-data.ps1     # Populate sample data (Windows)
├── initialize-test-data.sh      # Populate sample data (Linux/Mac)
├── test-apis.ps1                # API testing (Windows)
├── test-apis.sh                 # API testing (Linux/Mac)
└── README.md
```

## 🔐 Security Considerations

This is a development/demo system. For production deployment:

- ✅ Implement proper JWT authentication
- ✅ Hash passwords using bcrypt
- ✅ Add input validation and sanitization
- ✅ Use HTTPS/TLS encryption  
- ✅ Implement rate limiting
- ✅ Add comprehensive logging and monitoring
- ✅ Use secrets management for sensitive data

## 🚀 Scaling & Production Deployment

For production environments:

- Use Kubernetes instead of Docker Compose
- Implement horizontal pod autoscaling
- Add load balancers (NGINX, HAProxy)
- Use managed MongoDB (MongoDB Atlas)
- Use managed Kafka (Confluent Cloud, Amazon MSK)
- Implement distributed tracing (Jaeger, Zipkin)
- Add comprehensive monitoring (Prometheus, Grafana)

## �️ Helper Scripts Reference

| Script | Platform | Purpose |
|--------|----------|---------|
| `setup.ps1` / `setup.sh` | Win / Unix | First-time setup - builds all services and starts containers |
| `start.ps1` / `start.sh` | Win / Unix | Quick start for existing installations |
| `status-monitor.ps1` | Windows | Real-time system health monitoring |
| `initialize-test-data.ps1` / `.sh` | Win / Unix | Populate database with sample data |
| `test-apis.ps1` / `test-apis.sh` | Win / Unix | Comprehensive API endpoint testing |

### Quick Reference

```powershell
# Windows - Complete Setup Flow
.\setup.ps1                      # 1. Initial setup
.\initialize-test-data.ps1       # 2. Add sample data
.\test-apis.ps1                  # 3. Verify all endpoints
.\status-monitor.ps1 -Watch      # 4. Monitor system

# Linux/Mac - Complete Setup Flow
./setup.sh                       # 1. Initial setup
./initialize-test-data.sh        # 2. Add sample data
./test-apis.sh                   # 3. Verify all endpoints
```

## 📞 Troubleshooting

### Common Issues

**Passenger Login Returns 401 Unauthorized:**

This is the most common issue on fresh installations. It occurs when `setup.ps1` is run but test data wasn't initialized.

**Quick Fix:**
```powershell
# Windows
.\fix-login.ps1

# OR manually run:
.\initialize-test-data.ps1
```

```bash
# Linux/Mac
./fix-login.sh

# OR manually run:
./initialize-test-data.sh
```

**Diagnose the Issue:**
```powershell
# Windows - Check what's wrong
.\diagnose-login.ps1
```

**Root Cause:** The `setup.ps1` script builds and starts services but does NOT automatically create test users. You must run `initialize-test-data.ps1` separately to create:
- Test passenger users (john.doe@example.com, jane.smith@example.com, etc.)
- Admin users (admin, transport_manager, etc.)
- Routes, trips, and sample tickets

**Services not starting:**
- Check Docker is running: `docker ps`
- View logs: `docker compose logs -f <service-name>`
- Verify ports 8081-8086, 9000, 9092, 27017 are available

**Health checks failing:**
- Wait 30-60 seconds for services to fully initialize
- Check Kafka and MongoDB are healthy: `.\status-monitor.ps1`
- Verify containers are running: `docker compose ps`

**API returns 404:**
- Ensure you're using correct endpoints with `/api/v1/` prefix
- Check service logs for errors
- Verify the service container is running

**Database connection issues:**
- Ensure MongoDB container is running
- Check connection string in Config.toml files
- Verify network connectivity: `docker network ls`

**For detailed diagnostics:**
- Run `.\status-monitor.ps1` to see overall system health
- Run `.\diagnose-login.ps1` to troubleshoot authentication issues
- Check logs: `docker compose logs -f <service-name>`
- Verify network connectivity between services
- Ensure all required ports are available
- Check MongoDB and Kafka connectivity

## �️ Command-Line Interfaces (CLIs)

The platform includes interactive CLIs for both passengers and administrators, available in both PowerShell and Bash versions for cross-platform support.

### Passenger CLI

Interactive interface for passengers to manage their accounts, browse routes, purchase tickets, and view notifications.

**Features:**
- ✅ Account registration and login
- ✅ Profile management
- ✅ Browse available routes
- ✅ View trip schedules
- ✅ Purchase tickets (single, multiple, passes)
- ✅ View purchased tickets
- ✅ Session management with JWT authentication

**Windows (PowerShell):**
```powershell
.\passenger-cli.ps1              # Uses localhost by default
.\passenger-cli.ps1 -BaseUrl "http://localhost"  # Custom base URL
```

**Linux/Mac (Bash):**
```bash
chmod +x passenger-cli.sh
./passenger-cli.sh               # Uses localhost by default
./passenger-cli.sh http://yourserver  # Custom base URL
```

**Menu Options:**

*Guest Menu:*
1. Register - Create new passenger account
2. Login - Access your account
3. Browse Routes (Guest) - View available routes
4. View Trips (Guest) - See trip schedules
0. Exit

*Logged-in Menu:*
1. View Profile - See your account details
2. Browse Routes - View all available routes with prices
3. View Trips - See trip schedules with availability
4. Purchase Ticket - Buy tickets for trips
5. My Tickets - View your purchased tickets
6. Logout - End your session
0. Exit

**Test Credentials:**
- Email: `john.doe@example.com`
- Password: `JohnDoe123!`

### Admin CLI

Interactive interface for administrators to manage routes, trips, service disruptions, and generate reports.

**Features:**
- ✅ Admin authentication
- ✅ System dashboard with key metrics
- ✅ Route management (create, view, update)
- ✅ Trip management (schedule, monitor)
- ✅ Service disruption alerts
- ✅ Usage reports and analytics
- ✅ Ticket sales monitoring

**Windows (PowerShell):**
```powershell
.\admin-cli.ps1                  # Uses localhost by default
.\admin-cli.ps1 -BaseUrl "http://localhost"  # Custom base URL
```

**Linux/Mac (Bash):**
```bash
chmod +x admin-cli.sh
./admin-cli.sh                   # Uses localhost by default
./admin-cli.sh http://yourserver  # Custom base URL
```

**Menu Options:**

*Before Login:*
1. Admin Login - Authenticate as administrator
0. Exit

*After Login:*
1. View Dashboard - System overview and metrics
2. View All Routes - List all routes in the system
3. Create New Route - Add a new transport route
4. View All Trips - List all scheduled trips
5. Create New Trip - Schedule a new trip
6. View Disruptions - See active service disruptions
7. Create Disruption Alert - Publish service alerts
8. Generate Usage Report - Analytics and statistics
9. Logout - End admin session
0. Exit

**Test Credentials:**
- Username: `admin`
- Password: `Admin123!`

**Other Admin Users:**
- Username: `supervisor` / Password: `Supervisor123!`
- Username: `manager` / Password: `Manager123!`

### CLI Features & Benefits

**Session Management:**
- Both CLIs maintain session state with JWT tokens
- PowerShell version stores session in memory during execution
- Bash version persists session to `/tmp/passenger-session-$USER.txt` or `/tmp/admin-session-$USER.txt`
- Automatic token handling for authenticated requests

**Color-Coded Interface:**
- 🟢 Green - Success messages
- 🔴 Red - Error messages
- 🟡 Yellow - Warnings and prompts
- 🔵 Cyan - Headers and informational text

**Error Handling:**
- Graceful error messages for failed API calls
- Network connectivity checks
- Invalid input validation
- Session timeout handling

**Cross-Platform Support:**
- PowerShell CLIs work on Windows, Linux, and macOS
- Bash CLIs work on Linux, macOS, and WSL
- Consistent functionality across platforms
- Same features in both implementations

## �📜 License

This project is developed for the Windhoek City Council as part of the public transport modernization initiative.

---

---

Built with ❤️ using Ballerina, Kafka, and MongoDB
