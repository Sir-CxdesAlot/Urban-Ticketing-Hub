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
    
    mongodb:Update update = {"$set": updateData};
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