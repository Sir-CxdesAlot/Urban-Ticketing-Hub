import ballerina/http;
import ballerina/log;
import ballerina/uuid;
import ballerina/time;
import ballerina/random;
import ballerina/lang.runtime;
import ballerinax/mongodb;
import ballerinax/kafka;

// MongoDB configuration
configurable string mongoHost = ?;
configurable int mongoPort = ?;
configurable string databaseName = ?;

// Kafka configuration
configurable string kafkaBootstrapServers = ?;

// Data types
type Payment record {
    string id?;
    string ticketId;
    string passengerId;
    decimal amount;
    string method; // "CARD", "DIGITAL_WALLET", "BANK_TRANSFER"
    string status; // "PENDING", "SUCCESS", "FAILED"
    time:Utc createdAt;
    time:Utc? processedAt?;
    string? transactionId?;
    string? failureReason?;
};

type PaymentRequest record {
    string ticketId;
    string passengerId;
    decimal amount;
    string method;
    PaymentDetails paymentDetails;
};

type PaymentDetails record {
    string? cardNumber?;
    string? expiryMonth?;
    string? expiryYear?;
    string? cvv?;
    string? walletId?;
    string? bankAccount?;
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
service /api/v1/payment on new http:Listener(8084) {

    // Simple health endpoint for uniform checks
    resource function get health() returns string|error {
        // Light-touch DB ping to confirm connectivity without projections
        mongodb:Database database = check mongoClient->getDatabase(databaseName);
        // Count payments to ensure collection is accessible (no projections)
        mongodb:Collection collection = check database->getCollection("payments");
        _ = check collection->countDocuments({});
        return "Payment Service is running";
    }

    // Process a payment
    resource function post payments(PaymentRequest request) returns Payment|error {
        string paymentId = uuid:createType4AsString();
        
        Payment payment = {
            id: paymentId,
            ticketId: request.ticketId,
            passengerId: request.passengerId,
            amount: request.amount,
            method: request.method,
            status: "PENDING",
            createdAt: time:utcNow()
        };

        // Save payment to database
        mongodb:Database database = check mongoClient->getDatabase(databaseName);
        mongodb:Collection collection = check database->getCollection("payments");
        
        _ = check collection->insertOne(payment);
        
        log:printInfo("Payment created with ID: " + paymentId);
        
        // Simulate payment processing
        _ = start processPaymentAsync(paymentId, request);
        
        return payment;
    }

    // List all payments (optional filter by status)
    resource function get payments(string? status = ()) returns Payment[]|error {
        mongodb:Database database = check mongoClient->getDatabase(databaseName);
        mongodb:Collection collection = check database->getCollection("payments");

        map<json> filter = {};
        if status is string { filter["status"] = status; }

        stream<Payment, error?> findStream = check collection->find(filter);
        Payment[] items = [];
        check from Payment p in findStream do { items.push(p); };
        check findStream.close();
        return items;
    }

    // Get payment by ID
    resource function get payments/[string paymentId]() returns Payment|error {
        mongodb:Database database = check mongoClient->getDatabase(databaseName);
        mongodb:Collection collection = check database->getCollection("payments");
        
        map<json> filter = {"id": paymentId};
        stream<Payment, error?> findStream = check collection->find(filter);
        
        record {|Payment value;|}? result = check findStream.next();
        check findStream.close();
        
        if result is () {
            return error("Payment not found");
        }
        
        return result.value;
    }

    // Update a payment by ID (only certain fields are updatable)
    resource function put payments/[string paymentId](record {| string? status?; string? failureReason?; string? method?; |} updateReq)
            returns json|error {
        mongodb:Database database = check mongoClient->getDatabase(databaseName);
        mongodb:Collection collection = check database->getCollection("payments");

        map<json> updateFields = {};
        if (updateReq?.status is string) { updateFields["status"] = updateReq?.status; }
        if (updateReq?.failureReason is string) { updateFields["failureReason"] = updateReq?.failureReason; }
        if (updateReq?.method is string) { updateFields["method"] = updateReq?.method; }

        if (updateFields.length() == 0) {
            return error("No fields provided for update");
        }

        map<json> filter = {"id": paymentId};
        mongodb:Update update = {"set": updateFields};
        mongodb:UpdateResult result = check collection->updateOne(filter, update);

        if (result.matchedCount == 0) {
            return error("Payment not found");
        }

        return {"success": true, "message": "Payment updated successfully"};
    }

    // Delete a payment by ID
    resource function delete payments/[string paymentId]() returns json|error {
        mongodb:Database database = check mongoClient->getDatabase(databaseName);
        mongodb:Collection collection = check database->getCollection("payments");

        map<json> filter = {"id": paymentId};
        mongodb:DeleteResult result = check collection->deleteOne(filter);
        if (result.deletedCount == 0) {
            return error("Payment not found");
        }
        return {"success": true, "message": "Payment deleted successfully"};
    }

    // Get payments by passenger ID
    resource function get passengers/[string passengerId]/payments() returns Payment[]|error {
        mongodb:Database database = check mongoClient->getDatabase(databaseName);
        mongodb:Collection collection = check database->getCollection("payments");
        
        map<json> filter = {"passengerId": passengerId};
        stream<Payment, error?> findStream = check collection->find(filter);
        
        Payment[] payments = [];
        check from Payment payment in findStream
            do {
                payments.push(payment);
            };
        check findStream.close();
        
        return payments;
    }

    // Get payment statistics
    resource function get statistics() returns json {
        int pendingCount = 0;
        int successCount = 0;
        int failedCount = 0;
        decimal totalRevenue = 0.0;
        
        do {
            mongodb:Database database = check mongoClient->getDatabase(databaseName);
            mongodb:Collection collection = check database->getCollection("payments");
            // Iterate all payments to compute stats
            stream<map<json>, error?> all = check collection->find({});
            check from map<json> doc in all do {
                string status = "";
                json? s = doc["status"];
                if s is string { status = s; }
                if (status == "PENDING") { pendingCount += 1; }
                else if (status == "SUCCESS") { successCount += 1; }
                else if (status == "FAILED") { failedCount += 1; }

                if (status == "SUCCESS") {
                    json? a = doc["amount"];
                    if a is decimal { totalRevenue += a; }
                    else if a is float { totalRevenue += <decimal>a; }
                    else if a is int { totalRevenue += <decimal>a; }
                }
            };
            check all.close();
        } on fail error e {
            log:printError("Error computing payment statistics: " + e.message());
        }

        return {
            "total": pendingCount + successCount + failedCount,
            "pending": pendingCount,
            "successful": successCount,
            "failed": failedCount,
            "totalRevenue": totalRevenue
        };
    }

    // Refund a payment
    resource function post payments/[string paymentId]/refund() returns json|error {
        mongodb:Database database = check mongoClient->getDatabase(databaseName);
        mongodb:Collection collection = check database->getCollection("payments");
        
        map<json> filter = {"id": paymentId};
        stream<Payment, error?> findStream = check collection->find(filter);
        
        record {|Payment value;|}? result = check findStream.next();
        check findStream.close();
        
        if result is () {
            return error("Payment not found");
        }
        
        Payment payment = result.value;
        
        if (payment.status != "SUCCESS") {
            return {"success": false, "message": "Cannot refund non-successful payment"};
        }
        
        // Create refund record
        string refundId = uuid:createType4AsString();
        Payment refund = {
            id: refundId,
            ticketId: payment.ticketId,
            passengerId: payment.passengerId,
            amount: -payment.amount, // Negative amount for refund
            method: payment.method,
            status: "SUCCESS",
            createdAt: time:utcNow(),
            processedAt: time:utcNow(),
            transactionId: "REFUND-" + payment.id.toString()
        };
        
        _ = check collection->insertOne(refund);
        
        log:printInfo("Refund processed for payment: " + paymentId);
        return {"success": true, "refundId": refundId, "amount": payment.amount};
    }
}

// Async function to simulate payment processing
function processPaymentAsync(string paymentId, PaymentRequest request) returns error? {
    // Simulate processing delay (2-5 seconds)
    int delay = check random:createIntInRange(2, 6);
    
    // Simulate payment gateway processing
    runtime:sleep(<decimal>delay);
    
    // Simulate success/failure (90% success rate)
    int successChance = check random:createIntInRange(1, 11);
    boolean isSuccess = successChance <= 9;
    
    string status = isSuccess ? "SUCCESS" : "FAILED";
    string? failureReason = isSuccess ? () : "Insufficient funds";
    string? transactionId = isSuccess ? "TXN-" + uuid:createType4AsString() : ();
    
    // Update payment in database
    mongodb:Database database = check mongoClient->getDatabase(databaseName);
    mongodb:Collection collection = check database->getCollection("payments");
    
    map<json> filter = {"id": paymentId};
    map<json> updateData = {
        "status": status,
        "processedAt": time:utcToString(time:utcNow())
    };
    
    if (transactionId is string) {
        updateData["transactionId"] = transactionId;
    }
    
    if (failureReason is string) {
        updateData["failureReason"] = failureReason;
    }
    
    // Use typed operator key 'set' which the connector maps to $set
    mongodb:Update update = {"set": updateData};
    _ = check collection->updateOne(filter, update);
    
    // Publish payment processed event
    map<json> paymentEvent = {
        "paymentId": paymentId,
        "ticketId": request.ticketId,
        "passengerId": request.passengerId,
        "status": status,
        "amount": request.amount,
        "processedAt": time:utcToString(time:utcNow())
    };
    
    if (transactionId is string) {
        paymentEvent["transactionId"] = transactionId;
    }
    
    if (failureReason is string) {
        paymentEvent["failureReason"] = failureReason;
    }
    
    _ = check kafkaProducer->send({
        topic: "payments.processed",
        value: paymentEvent.toString()
    });
    
    log:printInfo("Payment processed: " + paymentId + " - Status: " + status);
}

public function main() returns error? {
    log:printInfo("Payment Service started on port 8084");
}
