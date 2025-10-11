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
type Ticket record {
    string id?;
    string passengerId;
    string routeId;
    string tripId;
    string ticketType; // "single", "multiple", "pass"
    decimal price;
    string status; // "CREATED", "PAID", "VALIDATED", "EXPIRED"
    time:Utc createdAt;
    time:Utc? validatedAt?;
    time:Utc? expiresAt?;
    int? ridesRemaining?;
};

type TicketRequest record {
    string passengerId;
    string routeId;
    string tripId;
    string ticketType;
    decimal price;
};

type PaymentProcessed record {
    string ticketId;
    string paymentId;
    string status; // "SUCCESS", "FAILED"
    decimal amount;
    time:Utc processedAt;
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
service /api/v1/ticketing on new http:Listener(8083) {

    // Simple health endpoint for uniform checks
    resource function get health() returns string|error {
        // Light-touch DB ping to confirm connectivity without projections
        mongodb:Database database = check mongoClient->getDatabase(databaseName);
        // Count tickets to ensure collection is accessible (no projections)
        mongodb:Collection collection = check database->getCollection("tickets");
        _ = check collection->countDocuments({});
        return "Ticketing Service is running";
    }

    // Create a new ticket
    resource function post tickets(TicketRequest request) returns Ticket|error {
        string ticketId = uuid:createType4AsString();
        
        Ticket ticket = {
            id: ticketId,
            passengerId: request.passengerId,
            routeId: request.routeId,
            tripId: request.tripId,
            ticketType: request.ticketType,
            price: request.price,
            status: "CREATED",
            createdAt: time:utcNow(),
            ridesRemaining: request.ticketType == "multiple" ? 10 : (request.ticketType == "pass" ? 30 : 1)
        };

        // Set expiration time based on ticket type
        time:Utc currentTime = time:utcNow();
        if (request.ticketType == "single") {
            ticket.expiresAt = time:utcAddSeconds(currentTime, 86400); // 24 hours
        } else if (request.ticketType == "multiple") {
            ticket.expiresAt = time:utcAddSeconds(currentTime, 2592000); // 30 days
        } else if (request.ticketType == "pass") {
            ticket.expiresAt = time:utcAddSeconds(currentTime, 7776000); // 90 days
        }

        mongodb:Database database = check mongoClient->getDatabase(databaseName);
        mongodb:Collection collection = check database->getCollection("tickets");
        
        _ = check collection->insertOne(ticket);
        
        log:printInfo("Ticket created with ID: " + ticketId);
        return ticket;
    }

    // Get ticket by ID
    resource function get tickets/[string ticketId]() returns Ticket|error {
        mongodb:Database database = check mongoClient->getDatabase(databaseName);
        mongodb:Collection collection = check database->getCollection("tickets");
        
        map<json> filter = {"id": ticketId};
        stream<Ticket, error?> findStream = check collection->find(filter);
        
        record {|Ticket value;|}? result = check findStream.next();
        check findStream.close();
        
        if result is () {
            return error("Ticket not found");
        }
        
        return result.value;
    }

    // Update ticket by ID (only certain fields allowed)
    resource function put tickets/[string ticketId](record {| string? status?; decimal? price?; time:Utc? expiresAt?; int? ridesRemaining?; |} updateReq)
            returns json|error {
        mongodb:Database database = check mongoClient->getDatabase(databaseName);
        mongodb:Collection collection = check database->getCollection("tickets");

        map<json> updateFields = {};
        if (updateReq?.status is string) { updateFields["status"] = updateReq?.status; }
        if (updateReq?.price is decimal) { updateFields["price"] = updateReq?.price; }
        if (updateReq?.expiresAt is time:Utc) { updateFields["expiresAt"] = updateReq?.expiresAt; }
        if (updateReq?.ridesRemaining is int) { updateFields["ridesRemaining"] = updateReq?.ridesRemaining; }

        if (updateFields.length() == 0) { return error("No fields provided for update"); }

        map<json> filter = {"id": ticketId};
        mongodb:Update update = {"set": updateFields};
        mongodb:UpdateResult result = check collection->updateOne(filter, update);
        if (result.matchedCount == 0) { return error("Ticket not found"); }
        return {"success": true, "message": "Ticket updated successfully"};
    }

    // Delete ticket by ID
    resource function delete tickets/[string ticketId]() returns json|error {
        mongodb:Database database = check mongoClient->getDatabase(databaseName);
        mongodb:Collection collection = check database->getCollection("tickets");
        map<json> filter = {"id": ticketId};
        mongodb:DeleteResult result = check collection->deleteOne(filter);
        if (result.deletedCount == 0) { return error("Ticket not found"); }
        return {"success": true, "message": "Ticket deleted successfully"};
    }

    // Get tickets by passenger ID
    resource function get passengers/[string passengerId]/tickets() returns Ticket[]|error {
        mongodb:Database database = check mongoClient->getDatabase(databaseName);
        mongodb:Collection collection = check database->getCollection("tickets");
        
        map<json> filter = {"passengerId": passengerId};
        stream<Ticket, error?> findStream = check collection->find(filter);
        
        Ticket[] tickets = [];
        check from Ticket ticket in findStream
            do {
                tickets.push(ticket);
            };
        check findStream.close();
        
        return tickets;
    }

    // Validate a ticket
    resource function put tickets/[string ticketId]/validate() returns json|error {
        mongodb:Database database = check mongoClient->getDatabase(databaseName);
        mongodb:Collection collection = check database->getCollection("tickets");
        
        map<json> filter = {"id": ticketId};
        stream<Ticket, error?> findStream = check collection->find(filter);
        
        record {|Ticket value;|}? result = check findStream.next();
        check findStream.close();
        
        if result is () {
            return error("Ticket not found");
        }
        
        Ticket ticket = result.value;
        
        // Check if ticket is paid
        if (ticket.status != "PAID") {
            return {"success": false, "message": "Ticket is not paid"};
        }
        
        // Check if ticket is expired
        time:Utc currentTime = time:utcNow();
        if (ticket?.expiresAt is time:Utc) {
            decimal timeDiff = time:utcDiffSeconds(<time:Utc>ticket?.expiresAt, currentTime);
            if (timeDiff <= 0.0d) {
                // Update status to expired
                // Use typed operator key 'set' which the connector maps to $set
                mongodb:Update update = {"set": {"status": "EXPIRED"}};
                _ = check collection->updateOne(filter, update);
                return {"success": false, "message": "Ticket has expired"};
            }
        }
        
        // Check rides remaining for multiple/pass tickets
        if (ticket.ticketType == "multiple" || ticket.ticketType == "pass") {
            if (ticket?.ridesRemaining is int && ticket?.ridesRemaining <= 0) {
                return {"success": false, "message": "No rides remaining"};
            }
        }
        
        // Validate the ticket
        map<json> updateData = {
            "status": "VALIDATED",
            "validatedAt": time:utcToString(currentTime)
        };
        
        // Decrease rides remaining for multiple/pass tickets
        if (ticket.ticketType == "multiple" || ticket.ticketType == "pass") {
            int currentRides = ticket?.ridesRemaining is int ? <int>ticket?.ridesRemaining : 0;
            updateData["ridesRemaining"] = currentRides - 1;
        }
        
    // Use typed operator key 'set' which the connector maps to $set
    mongodb:Update update = {"set": updateData};
        _ = check collection->updateOne(filter, update);
        
        // Publish validation event
        json validationEvent = {
            "ticketId": ticketId,
            "passengerId": ticket.passengerId,
            "validatedAt": time:utcToString(currentTime),
            "routeId": ticket.routeId,
            "tripId": ticket.tripId
        };
        
        _ = check kafkaProducer->send({
            topic: "ticket.validations",
            value: validationEvent.toString()
        });
        
        log:printInfo("Ticket validated: " + ticketId);
        return {"success": true, "message": "Ticket validated successfully"};
    }

    // Get ticket statistics
    resource function get statistics() returns json|error {
        mongodb:Database database = check mongoClient->getDatabase(databaseName);
        mongodb:Collection collection = check database->getCollection("tickets");
        
        // Count tickets by status
        map<json> createdFilter = {"status": "CREATED"};
        int createdCount = check collection->countDocuments(createdFilter);
        
        map<json> paidFilter = {"status": "PAID"};
        int paidCount = check collection->countDocuments(paidFilter);
        
        map<json> validatedFilter = {"status": "VALIDATED"};
        int validatedCount = check collection->countDocuments(validatedFilter);
        
        map<json> expiredFilter = {"status": "EXPIRED"};
        int expiredCount = check collection->countDocuments(expiredFilter);
        
        return {
            "total": createdCount + paidCount + validatedCount + expiredCount,
            "created": createdCount,
            "paid": paidCount,
            "validated": validatedCount,
            "expired": expiredCount
        };
    }
}

// Kafka consumer for ticket requests
listener kafka:Listener ticketRequestListener = new (kafkaBootstrapServers, {
    groupId: "ticketing-service-group",
    topics: ["ticket.requests"]
});

service kafka:Service on ticketRequestListener {
    remote function onConsumerRecord(kafka:Caller caller, kafka:BytesConsumerRecord[] records) returns error? {
        foreach var kafkaRecord in records {
            string message = check string:fromBytes(kafkaRecord.value);
            log:printInfo("Received ticket request: " + message);
            
            // Parse ticket request
            json ticketRequestJson = check message.fromJsonString();
            
            // Create ticket record
            string ticketId = uuid:createType4AsString();
            time:Utc currentTime = time:utcNow();
            
            Ticket ticket = {
                id: ticketId,
                passengerId: check ticketRequestJson.passengerId,
                routeId: check ticketRequestJson.routeId,
                tripId: check ticketRequestJson.tripId,
                ticketType: check ticketRequestJson.ticketType,
                price: check ticketRequestJson.price,
                status: "CREATED",
                createdAt: currentTime
            };
            
            // Set expiration and rides
            string ticketType = check ticketRequestJson.ticketType;
            if (ticketType == "single") {
                ticket.expiresAt = time:utcAddSeconds(currentTime, 86400);
                ticket.ridesRemaining = 1;
            } else if (ticketType == "multiple") {
                ticket.expiresAt = time:utcAddSeconds(currentTime, 2592000);
                ticket.ridesRemaining = 10;
            } else if (ticketType == "pass") {
                ticket.expiresAt = time:utcAddSeconds(currentTime, 7776000);
                ticket.ridesRemaining = 30;
            }
            
            // Save to database
            mongodb:Database database = check mongoClient->getDatabase(databaseName);
            mongodb:Collection collection = check database->getCollection("tickets");
            _ = check collection->insertOne(ticket);
            
            log:printInfo("Ticket created from Kafka request: " + ticketId);
        }
    }
}

// Kafka consumer for payment processing
listener kafka:Listener paymentListener = new (kafka:DEFAULT_URL, {
    groupId: "ticketing-payment-group",
    topics: ["payments.processed"]
});

service kafka:Service on paymentListener {
    remote function onConsumerRecord(kafka:Caller caller, kafka:BytesConsumerRecord[] records) returns error? {
        foreach var kafkaRecord in records {
            string message = check string:fromBytes(kafkaRecord.value);
            log:printInfo("Received payment processed: " + message);
            
            // Parse payment event
            json paymentJson = check message.fromJsonString();
            string ticketId = check paymentJson.ticketId;
            string status = check paymentJson.status;
            
            // Update ticket status based on payment
            mongodb:Database database = check mongoClient->getDatabase(databaseName);
            mongodb:Collection collection = check database->getCollection("tickets");
            
            map<json> filter = {"id": ticketId};
            string newStatus = status == "SUCCESS" ? "PAID" : "CREATED";
            // Use typed operator key 'set' which the connector maps to $set
            mongodb:Update update = {"set": {"status": newStatus}};
            
            _ = check collection->updateOne(filter, update);
            
            log:printInfo("Updated ticket " + ticketId + " status to " + newStatus);
        }
    }
}

public function main() returns error? {
    log:printInfo("Ticketing Service started on port 8083");
}
