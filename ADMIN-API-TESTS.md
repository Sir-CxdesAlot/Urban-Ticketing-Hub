# Admin Service API Tests

This directory contains test scripts for validating the Admin Service CRUD operations.

## Files

- `test-admin-apis.ps1` - PowerShell script for testing all admin service endpoints
- `test-admin-apis.sh` - Bash script for testing all admin service endpoints (Linux/Mac)

## Prerequisites

1. Admin Service must be running on `http://localhost:8086`
2. MongoDB and Kafka must be running
3. Test data should be initialized (run `initialize-test-data.ps1` or `initialize-test-data.sh`)

## Running the Tests

### PowerShell (Windows)

```powershell
# Run with default settings
.\test-admin-apis.ps1

# Run with custom base URL
.\test-admin-apis.ps1 -BaseUrl "http://localhost:8086"

# Run with verbose output
.\test-admin-apis.ps1 -Verbose
```

### Bash (Linux/Mac)

```bash
# Make executable and run
chmod +x test-admin-apis.sh
./test-admin-apis.sh

# Run with custom base URL
BASE_URL="http://localhost:8086" ./test-admin-apis.sh

# Run with verbose output
VERBOSE=true ./test-admin-apis.sh
```

## Test Coverage

The test scripts cover all CRUD operations:

### Admin Users

- ✅ Create (POST /api/v1/admin/admin-users)
- ✅ Read (GET /api/v1/admin/admin-users)
- ✅ Update (PUT /api/v1/admin/admin-users/{id})
- ✅ Delete (DELETE /api/v1/admin/admin-users/{id})

### Service Disruptions

- ✅ Create (POST /api/v1/admin/disruptions)
- ✅ Read (GET /api/v1/admin/disruptions)
- ✅ Update (PUT /api/v1/admin/disruptions/{id})
- ✅ Update Status (PUT /api/v1/admin/disruptions/{id}/status)
- ✅ Delete (DELETE /api/v1/admin/disruptions/{id})

### Other Endpoints

- ✅ Health Check (GET /api/v1/admin/health)
- ✅ Login (POST /api/v1/admin/login)
- ✅ Dashboard (GET /api/v1/admin/dashboard)
- ✅ Usage Reports (GET /api/v1/admin/reports/usage)

## Manual Testing with curl

If you prefer to test individual endpoints manually:

### Health Check

```bash
curl -X GET http://localhost:8086/api/v1/admin/health
```

### Create Admin User

```bash
curl -X POST http://localhost:8086/api/v1/admin/admin-users \
  -H "Content-Type: application/json" \
  -d '{
    "username": "testadmin",
    "email": "testadmin@example.com",
    "password": "TestAdmin123!",
    "role": "SUPER_ADMIN"
  }'
```

### Get All Admin Users

```bash
curl -X GET http://localhost:8086/api/v1/admin/admin-users
```

### Update Admin User

```bash
curl -X PUT http://localhost:8086/api/v1/admin/admin-users/{adminId} \
  -H "Content-Type: application/json" \
  -d '{
    "username": "updatedadmin",
    "role": "TRANSPORT_ADMIN"
  }'
```

### Delete Admin User

```bash
curl -X DELETE http://localhost:8086/api/v1/admin/admin-users/{adminId}
```

### Create Disruption

```bash
curl -X POST http://localhost:8086/api/v1/admin/disruptions \
  -H "Content-Type: application/json" \
  -d '{
    "routeId": "route-001",
    "type": "DELAY",
    "title": "Test Delay",
    "description": "Testing disruption",
    "startTime": "2025-10-11T10:00:00Z",
    "endTime": "2025-10-11T12:00:00Z"
  }'
```

### Get All Disruptions

```bash
curl -X GET http://localhost:8086/api/v1/admin/disruptions
```

### Update Disruption

```bash
curl -X PUT http://localhost:8086/api/v1/admin/disruptions/{disruptionId} \
  -H "Content-Type: application/json" \
  -d '{
    "title": "Updated Delay",
    "status": "RESOLVED"
  }'
```

### Delete Disruption

```bash
curl -X DELETE http://localhost:8086/api/v1/admin/disruptions/{disruptionId}
```

## Expected Responses

All successful operations return JSON with `"success": true`. Failed operations return appropriate error messages.

## Troubleshooting

1. **Service not running**: Ensure the admin service is started with `start.ps1` or `start.sh`
2. **Database connection**: Check MongoDB is running and accessible
3. **Test data**: Run initialization scripts if admin users don't exist
4. **Port conflicts**: Verify port 8086 is available
