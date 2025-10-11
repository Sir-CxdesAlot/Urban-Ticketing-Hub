# Notification Service API Tests

This directory contains test scripts for validating the Notification Service CRUD operations.

## Files

- `test-notification-apis.ps1` - PowerShell script for testing all notification service endpoints
- `test-notification-apis.sh` - Bash script for testing all notification service endpoints (Linux/Mac)

## Prerequisites

1. Notification Service must be running on `http://localhost:8085`
2. MongoDB and Kafka must be running
3. Test data should be initialized (run `initialize-test-data.ps1` or `initialize-test-data.sh`)

## Running the Tests

### PowerShell (Windows)

```powershell
# Run with default settings
.\test-notification-apis.ps1

# Run with custom base URL
.\test-notification-apis.ps1 -BaseUrl "http://localhost:8085"

# Run with verbose output
.\test-notification-apis.ps1 -Verbose
```

### Bash (Linux/Mac)

```bash
# Make executable and run
chmod +x test-notification-apis.sh
./test-notification-apis.sh

# Run with custom base URL
BASE_URL="http://localhost:8085" ./test-notification-apis.sh

# Run with verbose output
VERBOSE=true ./test-notification-apis.sh
```

## Test Coverage

The test scripts cover all CRUD operations:

### Notifications

- ✅ Create (POST /api/v1/notification/notifications)
- ✅ Read (GET /api/v1/notification/notifications/{id})
- ✅ Read User Notifications (GET /api/v1/notification/users/{userId}/notifications)
- ✅ Update (PUT /api/v1/notification/notifications/{id})
- ✅ Update Status - Mark as Read (PUT /api/v1/notification/notifications/{id}/read)
- ✅ Delete (DELETE /api/v1/notification/notifications/{id})

### Other Endpoints

- ✅ Health Check (GET /api/v1/notification/health)
- ✅ Statistics (GET /api/v1/notification/statistics)

## Manual Testing with curl

If you prefer to test individual endpoints manually:

### Health Check

```bash
curl -X GET http://localhost:8085/api/v1/notification/health
```

### Create Notification

```bash
curl -X POST http://localhost:8085/api/v1/notification/notifications \
  -H "Content-Type: application/json" \
  -d '{
    "recipientId": "user-001",
    "type": "TEST_NOTIFICATION",
    "title": "Test Notification",
    "message": "This is a test notification",
    "metadata": {
      "testKey": "testValue"
    }
  }'
```

### Get Notification by ID

```bash
curl -X GET http://localhost:8085/api/v1/notification/notifications/{notificationId}
```

### Get User Notifications

```bash
curl -X GET http://localhost:8085/api/v1/notification/users/{userId}/notifications
```

### Update Notification

```bash
curl -X PUT http://localhost:8085/api/v1/notification/notifications/{notificationId} \
  -H "Content-Type: application/json" \
  -d '{
    "title": "Updated Notification",
    "message": "Updated message",
    "status": "DELIVERED"
  }'
```

### Mark as Read

```bash
curl -X PUT http://localhost:8085/api/v1/notification/notifications/{notificationId}/read
```

### Delete Notification

```bash
curl -X DELETE http://localhost:8085/api/v1/notification/notifications/{notificationId}
```

### Get Statistics

```bash
curl -X GET http://localhost:8085/api/v1/notification/statistics
```

## Expected Responses

All successful operations return appropriate JSON responses. Create operations return the full notification object, while update/delete operations return `{"success": true, "message": "..."}`.

## Kafka Integration

The notification service automatically creates notifications from Kafka events:

- **schedule.updates** topic → Creates SCHEDULE_UPDATE notifications
- **ticket.validations** topic → Creates TICKET_VALIDATION notifications
- **payments.processed** topic → Creates PAYMENT_CONFIRMATION notifications

## Troubleshooting

1. **Service not running**: Ensure the notification service is started with `start.ps1` or `start.sh`
2. **Database connection**: Check MongoDB is running and accessible
3. **Kafka connection**: Verify Kafka is running for automatic notification creation
4. **Port conflicts**: Verify port 8085 is available
