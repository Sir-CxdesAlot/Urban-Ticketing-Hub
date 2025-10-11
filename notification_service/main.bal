import ballerina/http;
import ballerina/log;
import ballerina/uuid;
import ballerina/time;
import ballerina/io;
import ballerinax/mongodb;
import ballerinax/kafka;

// MongoDB configuration
configurable string mongoHost = ?;
configurable int mongoPort = ?;
configurable string databaseName = ?;

// Kafka configuration
configurable string kafkaBootstrapServers = ?;

// Data types
type Notification record {
    string id?;
    string recipientId; // passenger ID or "ALL" for broadcast
    string 'type; // "SCHEDULE_UPDATE", "TICKET_VALIDATION", "PAYMENT_CONFIRMATION", "SERVICE_DISRUPTION"
    string title;
    string message;
    string status; // "SENT", "DELIVERED", "READ"
    time:Utc createdAt;
    time:Utc? sentAt?;
    json? metadata?;
};

type NotificationRequest record {
    string recipientId;
    string 'type;
    string title;
    string message;
    json? metadata?;
};

type NotificationUpdate record {
    string? recipientId?;
    string? 'type?;
    string? title?;
    string? message?;
    string? status?;
    json? metadata?;
};

// Global variables
mongodb:Client mongoClient = check new ({
    connection: {
        serverAddress: {
            host: mongoHost,
            port: mongoPort
        }
    }
});

// Service definition
@http:ServiceConfig {
    cors: {
        allowOrigins: ["*"],
        allowCredentials: false,
        allowHeaders: ["*"],
        allowMethods: ["GET", "POST", "PUT", "DELETE", "OPTIONS"]
    }
}
service /api/v1/notification on new http:Listener(8085) {

    /// Health check endpoint for the notification service.
    ///
    /// + return - String indicating service health or error
    resource function get health() returns json|error {
        // Light-touch DB ping to confirm connectivity without projections
        mongodb:Database database = check mongoClient->getDatabase(databaseName);
        // Count notifications to ensure collection is accessible (no projections)
        mongodb:Collection collection = check database->getCollection("notifications");
        _ = check collection->countDocuments({});
        // Return as JSON string so clients using JSON parsers can handle it consistently
        return "Notification Service is running";
    }

    /// Sends a new notification to a recipient.
    ///
    /// + request - The notification details to send
    /// + return - The created notification or error
    resource function post notifications(NotificationRequest request) returns Notification|error {
        string notificationId = uuid:createType4AsString();
        
        Notification notification = {
            id: notificationId,
            recipientId: request.recipientId,
            'type: request.'type,
            title: request.title,
            message: request.message,
            status: "SENT",
            createdAt: time:utcNow(),
            sentAt: time:utcNow(),
            metadata: request?.metadata
        };

        // Save notification to database
        mongodb:Database database = check mongoClient->getDatabase(databaseName);
        mongodb:Collection collection = check database->getCollection("notifications");
        
        _ = check collection->insertOne(notification);
        
        // Send notification (simulate via console output)
        sendNotification(notification);
        
        log:printInfo("Notification sent with ID: " + notificationId);
        return notification;
    }

    /// Retrieves all notifications for a specific user, including broadcast notifications.
    ///
    /// + userId - The unique identifier of the user
    /// + return - Array of notifications or error
    resource function get users/[string userId]/notifications() returns Notification[]|error {
        mongodb:Database database = check mongoClient->getDatabase(databaseName);
        mongodb:Collection collection = check database->getCollection("notifications");
        
        // Get notifications for specific user or broadcast notifications
        map<json> filter = {
            "$or": [
                {"recipientId": userId},
                {"recipientId": "ALL"}
            ]
        };
        
        stream<Notification, error?> findStream = check collection->find(filter);
        
        Notification[] notifications = [];
        check from Notification notification in findStream
            do {
                notifications.push(notification);
            };
        check findStream.close();
        
        return notifications;
    }

    /// Marks a notification as read by updating its status.
    ///
    /// + notificationId - The unique identifier of the notification to mark as read
    /// + return - JSON response indicating success or error
    resource function put notifications/[string notificationId]/read() returns json|error {
        mongodb:Database database = check mongoClient->getDatabase(databaseName);
        mongodb:Collection collection = check database->getCollection("notifications");
        
        map<json> filter = {"id": notificationId};
    // Use typed operator key 'set' which the connector maps to $set
    mongodb:Update update = {"set": {"status": "READ"}};
        
        mongodb:UpdateResult result = check collection->updateOne(filter, update);
        
        if (result.matchedCount == 0) {
            return error("Notification not found");
        }
        
        log:printInfo("Notification marked as read: " + notificationId);
        return {"success": true, "message": "Notification marked as read"};
    }

    /// Retrieves notification statistics including counts by status and type.
    ///
    /// + return - JSON object containing notification statistics or error
    resource function get statistics() returns json|error {
        mongodb:Database database = check mongoClient->getDatabase(databaseName);
        mongodb:Collection collection = check database->getCollection("notifications");
        
        // Count notifications by status
        map<json> sentFilter = {"status": "SENT"};
        int sentCount = check collection->countDocuments(sentFilter);
        
        map<json> deliveredFilter = {"status": "DELIVERED"};
        int deliveredCount = check collection->countDocuments(deliveredFilter);
        
        map<json> readFilter = {"status": "READ"};
        int readCount = check collection->countDocuments(readFilter);
        
        // Count by type
        map<json> scheduleFilter = {"type": "SCHEDULE_UPDATE"};
        int scheduleCount = check collection->countDocuments(scheduleFilter);
        
        map<json> ticketFilter = {"type": "TICKET_VALIDATION"};
        int ticketCount = check collection->countDocuments(ticketFilter);
        
        map<json> paymentFilter = {"type": "PAYMENT_CONFIRMATION"};
        int paymentCount = check collection->countDocuments(paymentFilter);
        
        map<json> disruptionFilter = {"type": "SERVICE_DISRUPTION"};
        int disruptionCount = check collection->countDocuments(disruptionFilter);
        
        return {
            "total": sentCount + deliveredCount + readCount,
            "sent": sentCount,
            "delivered": deliveredCount,
            "read": readCount,
            "byType": {
                "scheduleUpdates": scheduleCount,
                "ticketValidations": ticketCount,
                "paymentConfirmations": paymentCount,
                "serviceDisruptions": disruptionCount
            }
        };
    }

    /// Retrieves a specific notification by its ID.
    ///
    /// + notificationId - The unique identifier of the notification
    /// + return - The notification object or error if not found
    resource function get notifications/[string notificationId]() returns Notification|error {
        mongodb:Database database = check mongoClient->getDatabase(databaseName);
        mongodb:Collection collection = check database->getCollection("notifications");
        
        map<json> filter = {"id": notificationId};
        stream<Notification, error?> findStream = check collection->find(filter);
        
        record {|Notification value;|}? result = check findStream.next();
        check findStream.close();
        
        if result is () {
            return error("Notification not found");
        }
        
        return result.value;
    }

    /// Updates an existing notification by ID.
    ///
    /// + notificationId - The unique identifier of the notification to update
    /// + updateRequest - The fields to update for the notification
    /// + return - JSON response indicating success or error
    resource function put notifications/[string notificationId](NotificationUpdate updateRequest) returns json|error {
        mongodb:Database database = check mongoClient->getDatabase(databaseName);
        mongodb:Collection collection = check database->getCollection("notifications");
        
        map<json> filter = {"id": notificationId};
        map<json> updateFields = {};
        
        if (updateRequest?.recipientId is string) {
            updateFields["recipientId"] = updateRequest?.recipientId;
        }
        if (updateRequest?.'type is string) {
            updateFields["type"] = updateRequest?.'type;
        }
        if (updateRequest?.title is string) {
            updateFields["title"] = updateRequest?.title;
        }
        if (updateRequest?.message is string) {
            updateFields["message"] = updateRequest?.message;
        }
        if (updateRequest?.status is string) {
            updateFields["status"] = updateRequest?.status;
        }
        if (updateRequest?.metadata is json) {
            updateFields["metadata"] = updateRequest?.metadata;
        }
        
        if (updateFields.length() == 0) {
            return error("No fields provided for update");
        }
        
    // Use typed operator key 'set' which the connector maps to $set
    mongodb:Update update = {"set": updateFields};
        mongodb:UpdateResult result = check collection->updateOne(filter, update);
        
        if (result.matchedCount == 0) {
            return error("Notification not found");
        }
        
        log:printInfo("Notification updated: " + notificationId);
        return {"success": true, "message": "Notification updated successfully"};
    }

    /// Deletes a notification by ID.
    ///
    /// + notificationId - The unique identifier of the notification to delete
    /// + return - JSON response indicating success or error
    resource function delete notifications/[string notificationId]() returns json|error {
        mongodb:Database database = check mongoClient->getDatabase(databaseName);
        mongodb:Collection collection = check database->getCollection("notifications");
        
        map<json> filter = {"id": notificationId};
        mongodb:DeleteResult result = check collection->deleteOne(filter);
        
        if (result.deletedCount == 0) {
            return error("Notification not found");
        }
        
        log:printInfo("Notification deleted: " + notificationId);
        return {"success": true, "message": "Notification deleted successfully"};
    }
}

// Function to send notification (simulate via console)
function sendNotification(Notification notification) {
    string separator = "============================================================";
    io:println(separator);
    io:println("📢 NEW NOTIFICATION");
    io:println(separator);
    io:println("To: " + (notification.recipientId == "ALL" ? "All Users" : "User " + notification.recipientId));
    io:println("Type: " + notification.'type);
    io:println("Title: " + notification.title);
    io:println("Message: " + notification.message);
    io:println("Time: " + time:utcToString(notification.createdAt));
    if (notification?.metadata is json) {
        io:println("Metadata: " + notification?.metadata.toString());
    }
    io:println(separator);
}

// Kafka consumer for schedule updates
listener kafka:Listener scheduleListener = new (kafkaBootstrapServers, {
    groupId: "notification-schedule-group",
    topics: ["schedule.updates"]
});

service kafka:Service on scheduleListener {
    remote function onConsumerRecord(kafka:Caller caller, kafka:BytesConsumerRecord[] records) returns error? {
        foreach var kafkaRecord in records {
            string message = check string:fromBytes(kafkaRecord.value);
            log:printInfo("Received schedule update: " + message);
            
            json scheduleUpdate = check message.fromJsonString();
            
            // Create notification for schedule update
            string notificationId = uuid:createType4AsString();
            string routeId = check scheduleUpdate.routeId;
            string updateType = check scheduleUpdate.updateType;
            
            string title = "Schedule Update - Route " + routeId;
            string notificationMessage = "";
            
            if (updateType == "DELAY") {
                int delayMinutes = check scheduleUpdate.delayMinutes;
                notificationMessage = "Route " + routeId + " is delayed by " + delayMinutes.toString() + " minutes.";
            } else if (updateType == "CANCELLATION") {
                notificationMessage = "Route " + routeId + " has been cancelled.";
            } else if (updateType == "SCHEDULE_CHANGE") {
                notificationMessage = "Schedule for route " + routeId + " has been updated. Please check new timings.";
            } else {
                notificationMessage = "Route " + routeId + " has been updated.";
            }
            
            Notification notification = {
                id: notificationId,
                recipientId: "ALL", // Broadcast to all users
                'type: "SCHEDULE_UPDATE",
                title: title,
                message: notificationMessage,
                status: "SENT",
                createdAt: time:utcNow(),
                sentAt: time:utcNow(),
                metadata: scheduleUpdate
            };
            
            // Save to database
            mongodb:Database database = check mongoClient->getDatabase(databaseName);
            mongodb:Collection collection = check database->getCollection("notifications");
            _ = check collection->insertOne(notification);
            
            // Send notification
            sendNotification(notification);
            
            log:printInfo("Schedule update notification sent: " + notificationId);
        }
    }
}

// Kafka consumer for ticket validations
listener kafka:Listener ticketValidationListener = new (kafkaBootstrapServers, {
    groupId: "notification-validation-group",
    topics: ["ticket.validations"]
});

service kafka:Service on ticketValidationListener {
    remote function onConsumerRecord(kafka:Caller caller, kafka:BytesConsumerRecord[] records) returns error? {
        foreach var kafkaRecord in records {
            string message = check string:fromBytes(kafkaRecord.value);
            log:printInfo("Received ticket validation: " + message);
            
            json ticketValidation = check message.fromJsonString();
            
            // Create notification for ticket validation
            string notificationId = uuid:createType4AsString();
            string passengerId = check ticketValidation.passengerId;
            string ticketId = check ticketValidation.ticketId;
            string routeId = check ticketValidation.routeId;
            
            Notification notification = {
                id: notificationId,
                recipientId: passengerId,
                'type: "TICKET_VALIDATION",
                title: "Ticket Validated",
                message: "Your ticket " + ticketId + " for route " + routeId + " has been validated successfully.",
                status: "SENT",
                createdAt: time:utcNow(),
                sentAt: time:utcNow(),
                metadata: ticketValidation
            };
            
            // Save to database
            mongodb:Database database = check mongoClient->getDatabase(databaseName);
            mongodb:Collection collection = check database->getCollection("notifications");
            _ = check collection->insertOne(notification);
            
            // Send notification
            sendNotification(notification);
            
            log:printInfo("Ticket validation notification sent: " + notificationId);
        }
    }
}

// Kafka consumer for payment confirmations
listener kafka:Listener paymentListener = new (kafkaBootstrapServers, {
    groupId: "notification-payment-group",
    topics: ["payments.processed"]
});

service kafka:Service on paymentListener {
    remote function onConsumerRecord(kafka:Caller caller, kafka:BytesConsumerRecord[] records) returns error? {
        foreach var kafkaRecord in records {
            string message = check string:fromBytes(kafkaRecord.value);
            log:printInfo("Received payment processed: " + message);
            
            json paymentEvent = check message.fromJsonString();
            
            // Create notification for payment confirmation
            string notificationId = uuid:createType4AsString();
            string passengerId = check paymentEvent.passengerId;
            string ticketId = check paymentEvent.ticketId;
            string status = check paymentEvent.status;
            decimal amount = check paymentEvent.amount;
            
            string title = status == "SUCCESS" ? "Payment Confirmed" : "Payment Failed";
            string notificationMessage = "";
            
            if (status == "SUCCESS") {
                notificationMessage = "Your payment of $" + amount.toString() + " for ticket " + ticketId + " has been processed successfully.";
            } else {
                string reason = "Unknown error";
                if (paymentEvent is map<json>) {
                    json? failureReasonJson = paymentEvent["failureReason"];
                    if (failureReasonJson is json) {
                        reason = failureReasonJson.toString();
                    }
                }
                notificationMessage = "Payment for ticket " + ticketId + " failed. Reason: " + reason;
            }
            
            Notification notification = {
                id: notificationId,
                recipientId: passengerId,
                'type: "PAYMENT_CONFIRMATION",
                title: title,
                message: notificationMessage,
                status: "SENT",
                createdAt: time:utcNow(),
                sentAt: time:utcNow(),
                metadata: paymentEvent
            };
            
            // Save to database
            mongodb:Database database = check mongoClient->getDatabase(databaseName);
            mongodb:Collection collection = check database->getCollection("notifications");
            _ = check collection->insertOne(notification);
            
            // Send notification
            sendNotification(notification);
            
            log:printInfo("Payment notification sent: " + notificationId);
        }
    }
}

public function main() returns error? {
    log:printInfo("Notification Service started on port 8085");
}
