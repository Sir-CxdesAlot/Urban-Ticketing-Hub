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
    string createdAt;
    string? lastLogin?;
};

type ServiceDisruption record {
    string id?;
    string routeId;
    string 'type; // "DELAY", "CANCELLATION", "MAINTENANCE", "EMERGENCY"
    string title;
    string description;
    string startTime;
    string? endTime?;
    string status; // "ACTIVE", "RESOLVED", "SCHEDULED"
    string createdAt;
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

type DisruptionUpdate record {
    string? routeId?;
    string? 'type?;
    string? title?;
    string? description?;
    string? startTime?; // ISO 8601 format
    string? endTime?; // ISO 8601 format
    string? status?;
};

type AdminUserUpdate record {
    string? username?;
    string? email?;
    string? password?;
    string? role?;
};

type AdminUserRequest record {
    string username;
    string email;
    string password;
    string role;
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

    /// Health check endpoint for the admin service.
    ///
    /// + return - String indicating service health or error
    resource function get health() returns string|error {
        // Light-touch DB ping to confirm connectivity without projections
        mongodb:Database database = check mongoClient->getDatabase(databaseName);
        // Count admin users to ensure collection is accessible (no projections)
        mongodb:Collection collection = check database->getCollection("admin_users");
        _ = check collection->countDocuments({});
        return "Admin Service is running";
    }

    /// Authenticates an admin user.
    ///
    /// + credentials - The login credentials (username and password)
    /// + return - JSON response with login result or error
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
        string createdAtTimeStr = time:utcToString(time:utcNow()); // Default fallback
        if adminResult.hasKey("createdAt") && adminResult["createdAt"] is json[] {
            json[] timeArray = <json[]>adminResult["createdAt"];
            if timeArray.length() >= 2 {
                time:Utc createdAtTime = [<int>timeArray[0], <decimal>timeArray[1]];
                createdAtTimeStr = time:utcToString(createdAtTime);
            }
        } else if adminResult.hasKey("createdAt") && adminResult["createdAt"] is string {
            createdAtTimeStr = adminResult["createdAt"].toString();
        }
        
        string? lastLoginTimeStr = ();
        if adminResult.hasKey("lastLogin") && adminResult["lastLogin"] is json[] {
            json[] timeArray = <json[]>adminResult["lastLogin"];
            if timeArray.length() >= 2 {
                time:Utc lastLoginTime = [<int>timeArray[0], <decimal>timeArray[1]];
                lastLoginTimeStr = time:utcToString(lastLoginTime);
            }
        } else if adminResult.hasKey("lastLogin") && adminResult["lastLogin"] is string {
            lastLoginTimeStr = adminResult["lastLogin"].toString();
        }
        
        AdminUser admin = {
            id: adminResult["id"].toString(),
            username: adminResult["username"].toString(),
            email: adminResult["email"].toString(),
            password: adminResult["password"].toString(),
            role: adminResult["role"].toString(),
            createdAt: createdAtTimeStr,
            lastLogin: lastLoginTimeStr
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

    /// Creates a new service disruption.
    ///
    /// + request - The disruption details to create
    /// + return - The created service disruption or error
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
            startTime: time:utcToString(startTime),
            endTime: endTime is time:Utc ? time:utcToString(endTime) : (),
            status: "ACTIVE",
            createdAt: time:utcToString(time:utcNow()),
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

    /// Retrieves all service disruptions.
    ///
    /// + return - Array of service disruptions or error
    resource function get disruptions() returns json[]|error {
        mongodb:Database database = check mongoClient->getDatabase(databaseName);
        mongodb:Collection collection = check database->getCollection("service_disruptions");

        // Read as raw maps to avoid typed binding issues with time fields
        stream<map<json>, error?> s = check collection->find({});
        map<json>[] rows = check from map<json> m in s select m;
        check s.close();

        json[] out = [];
        foreach map<json> m in rows {
            string startStr = m.hasKey("startTime") && m["startTime"] is json[] ? time:utcToString([<int>(<json[]>m["startTime"])[0], <decimal>(<json[]>m["startTime"])[1]]) : m["startTime"].toString();
            string? endStr = ();
            if m.hasKey("endTime") {
                if m["endTime"] is json[] { json[] ta = <json[]>m["endTime"]; endStr = time:utcToString([<int>ta[0], <decimal>ta[1]]); }
                else if m["endTime"] is string { endStr = m["endTime"].toString(); }
            }
            json j = {
                id: m["id"].toString(),
                routeId: m["routeId"].toString(),
                'type: m["type"].toString(),
                title: m["title"].toString(),
                description: m["description"].toString(),
                startTime: startStr,
                endTime: endStr,
                status: m["status"].toString(),
                createdAt: (m.hasKey("createdAt") && m["createdAt"] is json[]) ? time:utcToString([<int>(<json[]>m["createdAt"])[0], <decimal>(<json[]>m["createdAt"])[1]]) : (m["createdAt"].toString()),
                createdBy: m["createdBy"].toString()
            };
            out.push(j);
        }
        return out;
    }

    /// Updates the status of a service disruption.
    ///
    /// + disruptionId - The unique identifier of the disruption
    /// + statusUpdate - The new status for the disruption
    /// + return - JSON response indicating success or error
    resource function put disruptions/[string disruptionId]/status(record {string status;} statusUpdate) returns json|error {
        mongodb:Database database = check mongoClient->getDatabase(databaseName);
        mongodb:Collection collection = check database->getCollection("service_disruptions");
        
        map<json> filter = {"id": disruptionId};
    // Use the typed update operator key 'set' which the MongoDB connector maps to '$set'
    mongodb:Update update = {"set": {"status": statusUpdate.status}};
        
        mongodb:UpdateResult result = check collection->updateOne(filter, update);
        
        if (result.matchedCount == 0) {
            return error("Disruption not found");
        }
        
        log:printInfo("Disruption status updated: " + disruptionId + " -> " + statusUpdate.status);
        return {"success": true, "message": "Disruption status updated"};
    }

    /// Updates an existing service disruption by ID.
    ///
    /// + disruptionId - The unique identifier of the disruption to update
    /// + updateRequest - The fields to update for the disruption
    /// + return - JSON response indicating success or error
    resource function put disruptions/[string disruptionId](DisruptionUpdate updateRequest) returns json|error {
        mongodb:Database database = check mongoClient->getDatabase(databaseName);
        mongodb:Collection collection = check database->getCollection("service_disruptions");
        
        map<json> filter = {"id": disruptionId};
        map<json> updateFields = {};
        
        if (updateRequest?.routeId is string) {
            updateFields["routeId"] = updateRequest?.routeId;
        }
        if (updateRequest?.'type is string) {
            updateFields["type"] = updateRequest?.'type;
        }
        if (updateRequest?.title is string) {
            updateFields["title"] = updateRequest?.title;
        }
        if (updateRequest?.description is string) {
            updateFields["description"] = updateRequest?.description;
        }
        if (updateRequest?.startTime is string) {
            updateFields["startTime"] = updateRequest?.startTime;
        }
        if (updateRequest?.endTime is string) {
            updateFields["endTime"] = updateRequest?.endTime;
        }
        if (updateRequest?.status is string) {
            updateFields["status"] = updateRequest?.status;
        }
        
        if (updateFields.length() == 0) {
            return error("No fields provided for update");
        }
        
    // Use the typed update operator key 'set' which the MongoDB connector maps to '$set'
    mongodb:Update update = {"set": updateFields};
        mongodb:UpdateResult result = check collection->updateOne(filter, update);
        
        if (result.matchedCount == 0) {
            return error("Disruption not found");
        }
        
        // Publish update event if status changed
        if (updateRequest?.status is string) {
            json disruptionEvent = {
                "disruptionId": disruptionId,
                "status": updateRequest?.status,
                "updateType": "STATUS_UPDATE"
            };
            _ = check kafkaProducer->send({
                topic: "schedule.updates",
                value: disruptionEvent.toString()
            });
        }
        
        log:printInfo("Disruption updated: " + disruptionId);
        return {"success": true, "message": "Disruption updated successfully"};
    }

    /// Deletes a service disruption by ID.
    ///
    /// + disruptionId - The unique identifier of the disruption to delete
    /// + return - JSON response indicating success or error
    resource function delete disruptions/[string disruptionId]() returns json|error {
        mongodb:Database database = check mongoClient->getDatabase(databaseName);
        mongodb:Collection collection = check database->getCollection("service_disruptions");
        
        map<json> filter = {"id": disruptionId};
        mongodb:DeleteResult result = check collection->deleteOne(filter);
        
        if (result.deletedCount == 0) {
            return error("Disruption not found");
        }
        
        // Publish deletion event
        json disruptionEvent = {
            "disruptionId": disruptionId,
            "updateType": "DISRUPTION_DELETED"
        };
        _ = check kafkaProducer->send({
            topic: "schedule.updates",
            value: disruptionEvent.toString()
        });
        
        log:printInfo("Disruption deleted: " + disruptionId);
        return {"success": true, "message": "Disruption deleted successfully"};
    }

    /// Generates a usage report for the specified period.
    ///
    /// + period - The reporting period ("daily", "weekly", "monthly")
    /// + startDate - Optional custom start date (ISO 8601 format)
    /// + endDate - Optional custom end date (ISO 8601 format)
    /// + return - Usage report or error
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

    /// Retrieves system statistics for the admin dashboard.
    ///
    /// + return - JSON object containing dashboard statistics or error
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

    /// Publishes a schedule update for a specific route.
    ///
    /// + routeId - The unique identifier of the route
    /// + updateRequest - The schedule update details
    /// + return - JSON response indicating success or error
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

    /// Creates a new admin user.
    ///
    /// + adminRequest - The admin user details to create
    /// + return - JSON response with the created admin user details or error
    resource function post admin\-users(@http:Payload AdminUserRequest adminRequest) returns json|error {
        string adminId = uuid:createType4AsString();
        
        AdminUser admin = {
            id: adminId,
            username: adminRequest.username,
            email: adminRequest.email,
            password: adminRequest.password, // In production, hash this
            role: adminRequest.role,
            createdAt: time:utcToString(time:utcNow())
        };

        mongodb:Database database = check mongoClient->getDatabase(databaseName);
        mongodb:Collection collection = check database->getCollection("admin_users");
        
        // Attempt to insert; if duplicate, fetch existing and return idempotent success
        var insertResult = collection->insertOne(admin);
        if insertResult is error {
            string errMsg = insertResult.message();
            if errMsg.includes("E11000") { // Duplicate key (username/email)
                // Safely fetch existing record using an aggregation pipeline
                map<json> orClause = {"$or": [{"username": adminRequest.username}, {"email": adminRequest.email}]};
                map<json> matchStage = {"$match": orClause};
                map<json> projectStage = {"$project": {"id": 1, "username": 1}};
                map<json> limitStage = {"$limit": 1};
                map<json>[] pipeline = [matchStage, projectStage, limitStage];
                stream<map<json>, error?> aggStream = check collection->aggregate(pipeline);
                map<json>[] results = check from map<json> doc in aggStream select doc;
                check aggStream.close();
                string existingId = results.length() > 0 && results[0].hasKey("id") ? results[0]["id"].toString() : "";
                log:printInfo("Admin user already exists: " + adminRequest.username + (existingId != "" ? " (" + existingId + ")" : ""));
                return {"success": true, "adminId": existingId, "username": adminRequest.username, "message": "Already exists"};
            }
            // Propagate other errors
            return insertResult;
        }
        
        log:printInfo("Admin user created: " + adminRequest.username);
        return {"success": true, "adminId": adminId, "username": adminRequest.username};
    }

    /// Retrieves all admin users.
    ///
    /// + return - Array of admin users or error
    resource function get admin\-users() returns json[]|error {
        mongodb:Database database = check mongoClient->getDatabase(databaseName);
        mongodb:Collection collection = check database->getCollection("admin_users");

        // Use aggregation with an explicit projection to avoid driver issues
        map<json>[] pipeline = [
            {"$match": {}},
            {"$project": {"id": 1, "username": 1, "email": 1, "role": 1, "createdAt": 1, "lastLogin": 1}}
        ];
        stream<map<json>, error?> s = check collection->aggregate(pipeline);
        map<json>[] docs = check from map<json> d in s select d;
        check s.close();

        json[] admins = [];
        foreach map<json> adminResult in docs {
            // Convert date fields to strings if needed
            string createdAtTimeStr = "";
            if adminResult.hasKey("createdAt") {
                if adminResult["createdAt"] is json[] {
                    json[] timeArray = <json[]>adminResult["createdAt"];
                    if timeArray.length() >= 2 {
                        createdAtTimeStr = time:utcToString([<int>timeArray[0], <decimal>timeArray[1]]);
                    }
                } else if adminResult["createdAt"] is string {
                    createdAtTimeStr = adminResult["createdAt"].toString();
                }
            }

            string? lastLoginTimeStr = ();
            if adminResult.hasKey("lastLogin") {
                if adminResult["lastLogin"] is json[] {
                    json[] timeArray2 = <json[]>adminResult["lastLogin"];
                    if timeArray2.length() >= 2 {
                        lastLoginTimeStr = time:utcToString([<int>timeArray2[0], <decimal>timeArray2[1]]);
                    }
                } else if adminResult["lastLogin"] is string {
                    lastLoginTimeStr = adminResult["lastLogin"].toString();
                }
            }

            json adminJson = {
                id: adminResult["id"].toString(),
                username: adminResult["username"].toString(),
                email: adminResult["email"].toString(),
                password: "***",
                role: adminResult["role"].toString(),
                createdAt: createdAtTimeStr,
                lastLogin: lastLoginTimeStr
            };
            admins.push(adminJson);
        }
        return admins;
    }

    /// Updates an existing admin user by ID.
    ///
    /// + adminId - The unique identifier of the admin user to update
    /// + updateRequest - The fields to update for the admin user
    /// + return - JSON response indicating success or error
    resource function put admin\-users/[string adminId](AdminUserUpdate updateRequest) returns json|error {
        mongodb:Database database = check mongoClient->getDatabase(databaseName);
        mongodb:Collection collection = check database->getCollection("admin_users");
        
        map<json> filter = {"id": adminId};
        map<json> updateFields = {};
        
        if (updateRequest?.username is string) {
            updateFields["username"] = updateRequest?.username;
        }
        if (updateRequest?.email is string) {
            updateFields["email"] = updateRequest?.email;
        }
        if (updateRequest?.password is string) {
            updateFields["password"] = updateRequest?.password; // In production, hash this
        }
        if (updateRequest?.role is string) {
            updateFields["role"] = updateRequest?.role;
        }
        
        if (updateFields.length() == 0) {
            return error("No fields provided for update");
        }
        
    // Use the typed update operator key 'set' which the MongoDB connector maps to '$set'
    mongodb:Update update = {"set": updateFields};
        mongodb:UpdateResult result = check collection->updateOne(filter, update);
        
        if (result.matchedCount == 0) {
            return error("Admin user not found");
        }
        
        log:printInfo("Admin user updated: " + adminId);
        return {"success": true, "message": "Admin user updated successfully"};
    }

    /// Deletes an admin user by ID.
    ///
    /// + adminId - The unique identifier of the admin user to delete
    /// + return - JSON response indicating success or error
    resource function delete admin\-users/[string adminId]() returns json|error {
        mongodb:Database database = check mongoClient->getDatabase(databaseName);
        mongodb:Collection collection = check database->getCollection("admin_users");
        
        map<json> filter = {"id": adminId};
        mongodb:DeleteResult result = check collection->deleteOne(filter);
        
        if (result.deletedCount == 0) {
            return error("Admin user not found");
        }
        
        log:printInfo("Admin user deleted: " + adminId);
        return {"success": true, "message": "Admin user deleted successfully"};
    }
}

public function main() returns error? {
    log:printInfo("Admin Service started on port 8086");
}
