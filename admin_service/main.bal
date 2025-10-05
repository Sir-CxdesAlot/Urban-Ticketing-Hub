import ballerina/http;
import ballerina/log;
import ballerina/uuid;
import ballerina/time;
import ballerinax/mongodb;
import ballerinax/kafka;

// MongoDB configuration
configurable string mongoHost = ?;
configurable int mongoPort = ?;
configurable string databaseName = ?;

// Kafka configuration
configurable string kafkaBootstrapServers = ?;

// Data types
type AdminUser record {
    string id?;
    string username;
    string email;
    string password; // In production, this should be hashed
    string role; // "SUPER_ADMIN", "TRANSPORT_ADMIN", "ANALYTICS_ADMIN"
    time:Utc createdAt;
    time:Utc? lastLogin?;
};

type ServiceDisruption record {
    string id?;
    string routeId;
    string 'type; // "DELAY", "CANCELLATION", "MAINTENANCE", "EMERGENCY"
    string title;
    string description;
    time:Utc startTime;
    time:Utc? endTime?;
    string status; // "ACTIVE", "RESOLVED", "SCHEDULED"
    time:Utc createdAt;
    string createdBy; // admin user ID
};

type DisruptionRequest record {
    string routeId;
    string 'type;
    string title;
    string description;
    string startTime; // ISO 8601 format
    string? endTime?; // ISO 8601 format
};

type UsageReport record {
    string period; // "daily", "weekly", "monthly"
    time:Utc startDate;
    time:Utc endDate;
    int totalTickets;
    int validatedTickets;
    decimal totalRevenue;
    json routeStats;
    json ticketTypeStats;
    json hourlyStats?;
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

kafka:Producer kafkaProducer = check new (kafkaBootstrapServers);

// Service definition
@http:ServiceConfig {
    cors: {
        allowOrigins: ["*"],
        allowCredentials: false,
        allowHeaders: ["*"],
        allowMethods: ["GET", "POST", "PUT", "DELETE", "OPTIONS"]
    }
}
service /api/v1/admin on new http:Listener(8086) {

    // Simple health endpoint for uniform checks
    resource function get health() returns string|error {
        // Light-touch DB ping to confirm connectivity without projections
        mongodb:Database database = check mongoClient->getDatabase(databaseName);
        // Count admin users to ensure collection is accessible (no projections)
        mongodb:Collection collection = check database->getCollection("admin_users");
        _ = check collection->countDocuments({});
        return "Admin Service is running";
    }

    // Admin login (simplified - no JWT for now)
    resource function post login(record {string username; string password;} credentials) returns json|error {
        mongodb:Database database = check mongoClient->getDatabase(databaseName);
        mongodb:Collection collection = check database->getCollection("admin_users");
        
        // Find admin user with matching credentials via aggregation to avoid projection pitfalls
    map<json> matchStage = {"$match": {"username": credentials.username, "password": credentials.password}};
    map<json> projectStage = {"$project": {"id": 1, "username": 1, "email": 1, "password": 1, "role": 1, "createdAt": 1, "lastLogin": 1}};
    map<json> limitStage = {"$limit": 1};
    map<json>[] pipeline = [matchStage, projectStage, limitStage];
        stream<map<json>, error?> findStream = check collection->aggregate(pipeline);
        map<json>[] adminArray = check from map<json> doc in findStream select doc;
        check findStream.close();
        if adminArray.length() == 0 {
            return {"success": false, "message": "Invalid credentials"};
        }
        map<json> adminResult = adminArray[0];
        
        // Convert map<json> to AdminUser manually to avoid type conversion issues
        time:Utc createdAtTime = time:utcNow(); // Default fallback
        if adminResult.hasKey("createdAt") && adminResult["createdAt"] is json[] {
            json[] timeArray = <json[]>adminResult["createdAt"];
            if timeArray.length() >= 2 {
                createdAtTime = [<int>timeArray[0], <decimal>timeArray[1]];
            }
        }
        
        time:Utc? lastLoginTime = ();
        if adminResult.hasKey("lastLogin") && adminResult["lastLogin"] is string {
            string lastLoginStr = adminResult["lastLogin"].toString();
            lastLoginTime = check time:utcFromString(lastLoginStr);
        }
        
        AdminUser admin = {
            id: adminResult["id"].toString(),
            username: adminResult["username"].toString(),
            email: adminResult["email"].toString(),
            password: adminResult["password"].toString(),
            role: adminResult["role"].toString(),
            createdAt: createdAtTime,
            lastLogin: lastLoginTime
        };
        
        // Update last login
        map<json> updateFilter = {"id": admin.id};
        mongodb:Update updateDoc = {"set": {"lastLogin": time:utcToString(time:utcNow())}};
        _ = check collection->updateOne(updateFilter, updateDoc);
        
        log:printInfo("Admin login successful: " + admin.username);
        return {
            "success": true,
            "adminId": admin.id,
            "username": admin.username,
            "role": admin.role
        };
    }

    // Create service disruption
    resource function post disruptions(DisruptionRequest request) returns ServiceDisruption|error {
        string disruptionId = uuid:createType4AsString();
        
        // Parse time strings
        time:Utc startTime = check time:utcFromString(request.startTime);
        time:Utc? endTime = request?.endTime is string ? check time:utcFromString(<string>request?.endTime) : ();
        
        ServiceDisruption disruption = {
            id: disruptionId,
            routeId: request.routeId,
            'type: request.'type,
            title: request.title,
            description: request.description,
            startTime: startTime,
            endTime: endTime,
            status: "ACTIVE",
            createdAt: time:utcNow(),
            createdBy: "admin-user" // In production, get from JWT token
        };

        // Save disruption to database
        mongodb:Database database = check mongoClient->getDatabase(databaseName);
        mongodb:Collection collection = check database->getCollection("service_disruptions");
        
        _ = check collection->insertOne(disruption);
        
        // Publish disruption event
        json disruptionEvent = {
            "disruptionId": disruptionId,
            "routeId": request.routeId,
            "type": request.'type,
            "title": request.title,
            "description": request.description,
            "startTime": request.startTime,
            "endTime": request?.endTime,
            "status": "ACTIVE",
            "updateType": "DISRUPTION"
        };
        
        _ = check kafkaProducer->send({
            topic: "schedule.updates",
            value: disruptionEvent.toString()
        });
        
        log:printInfo("Service disruption created: " + disruptionId);
        return disruption;
    }

    // Get all disruptions
    resource function get disruptions() returns ServiceDisruption[]|error {
        mongodb:Database database = check mongoClient->getDatabase(databaseName);
        mongodb:Collection collection = check database->getCollection("service_disruptions");
        
        stream<ServiceDisruption, error?> findStream = check collection->find({});
        
        ServiceDisruption[] disruptions = [];
        check from ServiceDisruption disruption in findStream
            do {
                disruptions.push(disruption);
            };
        check findStream.close();
        
        return disruptions;
    }

    // Update disruption status
    resource function put disruptions/[string disruptionId]/status(record {string status;} statusUpdate) returns json|error {
        mongodb:Database database = check mongoClient->getDatabase(databaseName);
        mongodb:Collection collection = check database->getCollection("service_disruptions");
        
        map<json> filter = {"id": disruptionId};
        mongodb:Update update = {"$set": {"status": statusUpdate.status}};
        
        mongodb:UpdateResult result = check collection->updateOne(filter, update);
        
        if (result.matchedCount == 0) {
            return error("Disruption not found");
        }
        
        log:printInfo("Disruption status updated: " + disruptionId + " -> " + statusUpdate.status);
        return {"success": true, "message": "Disruption status updated"};
    }

    // Generate usage report
    resource function get reports/usage(string period = "daily", string? startDate = (), string? endDate = ()) returns UsageReport|error {
        time:Utc currentTime = time:utcNow();
        time:Utc reportStartDate;
        time:Utc reportEndDate = currentTime;
        
        // Calculate date range based on period
        if (period == "daily") {
            reportStartDate = time:utcAddSeconds(currentTime, -86400); // 24 hours ago
        } else if (period == "weekly") {
            reportStartDate = time:utcAddSeconds(currentTime, -604800); // 7 days ago
        } else if (period == "monthly") {
            reportStartDate = time:utcAddSeconds(currentTime, -2592000); // 30 days ago
        } else {
            reportStartDate = time:utcAddSeconds(currentTime, -86400); // Default to daily
        }
        
        // Override with custom dates if provided
        if (startDate is string) {
            reportStartDate = check time:utcFromString(startDate);
        }
        if (endDate is string) {
            reportEndDate = check time:utcFromString(endDate);
        }
        
        mongodb:Database database = check mongoClient->getDatabase(databaseName);
        
        // Get ticket statistics
        mongodb:Collection ticketCollection = check database->getCollection("tickets");
        map<json> dateFilter = {
            "createdAt": {
                "$gte": time:utcToString(reportStartDate),
                "$lte": time:utcToString(reportEndDate)
            }
        };
        
        int totalTickets = check ticketCollection->countDocuments(dateFilter);
        
        map<json> validatedFilter = dateFilter.clone();
        validatedFilter["status"] = "VALIDATED";
        int validatedTickets = check ticketCollection->countDocuments(validatedFilter);
        
        // Get payment statistics
        mongodb:Collection paymentCollection = check database->getCollection("payments");
        map<json> successfulPaymentFilter = {
            "createdAt": {
                "$gte": time:utcToString(reportStartDate),
                "$lte": time:utcToString(reportEndDate)
            },
            "status": "SUCCESS"
        };
        
        // Calculate total revenue (simplified - in production use aggregation)
        stream<record {decimal amount;}, error?> paymentStream = check paymentCollection->find(successfulPaymentFilter);
        decimal totalRevenue = 0.0;
        
        check from record {decimal amount;} payment in paymentStream
            do {
                totalRevenue += payment.amount;
            };
        check paymentStream.close();
        
        // Generate route statistics (simplified)
        json routeStats = {
            "totalRoutes": 0,
            "activeRoutes": 0,
            "topRoutes": []
        };
        
        // Generate ticket type statistics (simplified)
        json ticketTypeStats = {
            "single": 0,
            "multiple": 0,
            "pass": 0
        };
        
        UsageReport report = {
            period: period,
            startDate: reportStartDate,
            endDate: reportEndDate,
            totalTickets: totalTickets,
            validatedTickets: validatedTickets,
            totalRevenue: totalRevenue,
            routeStats: routeStats,
            ticketTypeStats: ticketTypeStats
        };
        
        log:printInfo("Usage report generated for period: " + period);
        return report;
    }

    // Get system statistics dashboard
    resource function get dashboard() returns json|error {
        mongodb:Database database = check mongoClient->getDatabase(databaseName);
        
        // Get current counts
        mongodb:Collection userCollection = check database->getCollection("users");
        int totalUsers = check userCollection->countDocuments({});
        
        mongodb:Collection routeCollection = check database->getCollection("routes");
        int totalRoutes = check routeCollection->countDocuments({});
        
        mongodb:Collection ticketCollection = check database->getCollection("tickets");
        int totalTickets = check ticketCollection->countDocuments({});
        
        map<json> activeTicketsFilter = {"status": {"$in": ["CREATED", "PAID"]}};
        int activeTickets = check ticketCollection->countDocuments(activeTicketsFilter);
        
        mongodb:Collection paymentCollection = check database->getCollection("payments");
        map<json> successfulPaymentsFilter = {"status": "SUCCESS"};
        int successfulPayments = check paymentCollection->countDocuments(successfulPaymentsFilter);
        
        mongodb:Collection disruptionCollection = check database->getCollection("service_disruptions");
        map<json> activeDisruptionsFilter = {"status": "ACTIVE"};
        int activeDisruptions = check disruptionCollection->countDocuments(activeDisruptionsFilter);
        
        return {
            "totalUsers": totalUsers,
            "totalRoutes": totalRoutes,
            "totalTickets": totalTickets,
            "activeTickets": activeTickets,
            "successfulPayments": successfulPayments,
            "activeDisruptions": activeDisruptions,
            "systemStatus": "OPERATIONAL"
        };
    }

    // Publish schedule update
    resource function post routes/[string routeId]/'schedule\-update(record {string updateType; string? message; int? delayMinutes;} updateRequest) returns json|error {
        // Publish schedule update event
        map<json> scheduleUpdate = {
            "routeId": routeId,
            "updateType": updateRequest.updateType,
            "timestamp": time:utcToString(time:utcNow()),
            "message": updateRequest?.message ?: "Schedule updated"
        };
        
        if (updateRequest?.delayMinutes is int) {
            scheduleUpdate["delayMinutes"] = updateRequest?.delayMinutes;
        }
        
        _ = check kafkaProducer->send({
            topic: "schedule.updates",
            value: scheduleUpdate.toString()
        });
        
        log:printInfo("Schedule update published for route: " + routeId);
        return {"success": true, "message": "Schedule update published"};
    }

    // Create admin user (for initial setup)
    resource function post admin\-users(record {string username; string email; string password; string role;} adminRequest) returns json|error {
        string adminId = uuid:createType4AsString();
        
        AdminUser admin = {
            id: adminId,
            username: adminRequest.username,
            email: adminRequest.email,
            password: adminRequest.password, // In production, hash this
            role: adminRequest.role,
            createdAt: time:utcNow()
        };

        mongodb:Database database = check mongoClient->getDatabase(databaseName);
        mongodb:Collection collection = check database->getCollection("admin_users");
        
        _ = check collection->insertOne(admin);
        
        log:printInfo("Admin user created: " + adminRequest.username);
        return {"success": true, "adminId": adminId, "username": adminRequest.username};
    }

    // Get all admin users
    resource function get admin\-users() returns AdminUser[]|error {
        mongodb:Database database = check mongoClient->getDatabase(databaseName);
        mongodb:Collection collection = check database->getCollection("admin_users");
        
        stream<AdminUser, error?> findStream = check collection->find({});
        
        AdminUser[] admins = [];
        check from AdminUser admin in findStream
            do {
                // Don't return password in response
                AdminUser safeAdmin = {
                    id: admin.id,
                    username: admin.username,
                    email: admin.email,
                    password: "***",
                    role: admin.role,
                    createdAt: admin.createdAt,
                    lastLogin: admin?.lastLogin
                };
                admins.push(safeAdmin);
            };
        check findStream.close();
        
        return admins;
    }
}

public function main() returns error? {
    log:printInfo("Admin Service started on port 8086");
}
