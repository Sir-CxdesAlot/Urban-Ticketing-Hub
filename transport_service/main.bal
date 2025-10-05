import ballerina/http;
import ballerina/log;
import ballerina/time;
import ballerinax/mongodb;
import ballerinax/kafka;

// MongoDB client configuration
configurable string mongoHost = ?;
configurable int mongoPort = ?;
configurable string databaseName = ?;

mongodb:Client mongoClient = check new ({
    connection: {
        serverAddress: {
            host: mongoHost,
            port: mongoPort
        }
    }
});

// Kafka producer configuration
configurable string kafkaBootstrapServers = ?;

kafka:ProducerConfiguration producerConfig = {
    clientId: "transport-service-producer",
    acks: "all",
    retryCount: 3
};

kafka:Producer kafkaProducer = check new (kafkaBootstrapServers, producerConfig);

// Data types
public type Route record {|
    string name;
    string startLocation;
    string endLocation;
    string[] intermediateStops;
    string transportType; // BUS, TRAIN
    decimal basePrice;
    boolean isActive;
    string createdAt;
    string updatedAt?;
|};

// MongoDB-compatible Route type (includes _id and other potential fields)
public type RouteDb record {|
    string name;
    string startLocation;
    string endLocation;
    string[] intermediateStops;
    string transportType;
    decimal basePrice;
    boolean isActive;
    string createdAt;
    string updatedAt?;
    anydata...; // Allow extra fields like _id
|};

public type Trip record {|
    string routeId;
    string departureTime;
    string arrivalTime;
    int availableSeats;
    int totalSeats;
    string status; // SCHEDULED, IN_PROGRESS, COMPLETED, CANCELLED, DELAYED
    string? delayReason?;
    int? delayMinutes?;
    string createdAt;
    string updatedAt?;
|};

// MongoDB-compatible Trip type (open record to allow _id and other fields)
public type TripDb record {
    string routeId;
    string departureTime;
    string arrivalTime;
    int availableSeats;
    int totalSeats;
    string status;
    string? delayReason?;
    int? delayMinutes?;
    string createdAt;
    string updatedAt?;
    // Open record allows _id and other MongoDB fields
};

public type ScheduleUpdate record {|
    string tripId;
    string routeId;
    string updateType; // DELAY, CANCELLATION, SCHEDULE_CHANGE
    string message;
    string timestamp;
    int? delayMinutes?;
    string? newDepartureTime?;
    string? newArrivalTime?;
|};

// Service configuration
listener http:Listener httpListener = new(8081);

service /api/v1/transport on httpListener {
    
    // Create new route
    resource function post routes(@http:Payload Route routeData) returns map<json>|http:BadRequest|http:InternalServerError {
        do {
            mongodb:Database database = check mongoClient->getDatabase(databaseName);
            mongodb:Collection routesCollection = check database->getCollection("routes");
            
            map<json> newRoute = {
                "name": routeData.name,
                "startLocation": routeData.startLocation,
                "endLocation": routeData.endLocation,
                "intermediateStops": routeData.intermediateStops,
                "transportType": routeData.transportType,
                "basePrice": routeData.basePrice,
                "isActive": true,
                "createdAt": time:utcNow().toString(),
                "updatedAt": time:utcNow().toString()
            };
            
            check routesCollection->insertOne(newRoute);
            
            log:printInfo("New route created: " + routeData.name);
            return newRoute;
            
        } on fail error e {
            log:printError("Error creating route: " + e.message());
            return <http:InternalServerError>{
                body: {message: "Route creation failed"}
            };
        }
    }
    
    // Get all routes
    resource function get routes(string? transportType = ()) returns map<json>[]|http:InternalServerError {
        do {
            mongodb:Database database = check mongoClient->getDatabase(databaseName);
            mongodb:Collection routesCollection = check database->getCollection("routes");
            
            map<json> filter = {"isActive": true};
            if transportType is string {
                filter["transportType"] = transportType;
            }
            
            // Try using aggregate with explicit $project to include _id
            map<json>[] pipeline = [
                {"$match": filter},
                {
                    "$project": {
                        "_id": {"$toString": "$_id"},
                        "name": 1,
                        "startLocation": 1,
                        "endLocation": 1,
                        "intermediateStops": 1,
                        "transportType": 1,
                        "basePrice": 1,
                        "isActive": 1,
                        "createdAt": 1,
                        "updatedAt": 1
                    }
                }
            ];
            
            stream<record {}, error?> routeStream = check routesCollection->aggregate(pipeline);
            
            map<json>[] routeArray = [];
            check from record {} route in routeStream
                do {
                    map<anydata> routeMap = route;
                    
                    // Build JSON response with proper field handling
                    map<json> jsonRoute = {};
                    foreach var [k, v] in routeMap.entries() {
                        if v is json {
                            jsonRoute[k] = v;
                        } else if v is anydata[] {
                            // Convert arrays to JSON arrays
                            json[] jsonArray = from var item in v select <json>item;
                            jsonRoute[k] = jsonArray;
                        } else if v is record {} {
                            // Convert records/objects to JSON
                            jsonRoute[k] = v.toJson();
                        } else {
                            // For other types, use toString
                            jsonRoute[k] = v.toString();
                        }
                    }
                    
                    routeArray.push(jsonRoute);
                };
            
            log:printInfo("Retrieved routes, count: " + routeArray.length().toString());
            return routeArray;
            
        } on fail error e {
            log:printError("Error getting routes: " + e.message());
            return <http:InternalServerError>{
                body: {message: "Route retrieval failed"}
            };
        }
    }
    
    // Get route by ID
    resource function get routes/[string routeId]() returns map<json>|http:NotFound|http:InternalServerError {
        do {
            mongodb:Database database = check mongoClient->getDatabase(databaseName);
            mongodb:Collection routesCollection = check database->getCollection("routes");
            
            // MongoDB expects ObjectId in BSON format: {"$oid": "stringvalue"}
            map<json> objectIdFilter = {
                "_id": {
                    "$oid": routeId
                }
            };
            
            // Use aggregate with $project to ensure _id is included
            map<json>[] pipeline = [
                {"$match": objectIdFilter},
                {
                    "$project": {
                        "_id": {"$toString": "$_id"},
                        "name": 1,
                        "startLocation": 1,
                        "endLocation": 1,
                        "intermediateStops": 1,
                        "transportType": 1,
                        "basePrice": 1,
                        "isActive": 1,
                        "createdAt": 1,
                        "updatedAt": 1
                    }
                }
            ];
            
            stream<record {}, error?> routeStream = check routesCollection->aggregate(pipeline);
            
            record {}[] routes = check from record {} r in routeStream select r;
            
            if routes.length() > 0 {
                map<anydata> routeMap = routes[0];
                
                // Build JSON response
                map<json> jsonRoute = {};
                foreach var [k, v] in routeMap.entries() {
                    if v is json {
                        jsonRoute[k] = v;
                    } else if v is anydata[] {
                        json[] jsonArray = from var item in v select <json>item;
                        jsonRoute[k] = jsonArray;
                    } else if v is record {} {
                        jsonRoute[k] = v.toJson();
                    } else {
                        jsonRoute[k] = v.toString();
                    }
                }
                
                return jsonRoute;
            } else {
                return <http:NotFound>{
                    body: {message: "Route not found"}
                };
            }
            
        } on fail error e {
            log:printError("Error getting route: " + e.message());
            return <http:InternalServerError>{
                body: {message: "Route retrieval failed"}
            };
        }
    }
    
    // Update route
    resource function put routes/[string routeId](@http:Payload Route routeData) returns map<json>|http:NotFound|http:InternalServerError {
        do {
            mongodb:Database database = check mongoClient->getDatabase(databaseName);
            mongodb:Collection routesCollection = check database->getCollection("routes");
            
            map<json> updatedRoute = {
                "name": routeData.name,
                "startLocation": routeData.startLocation,
                "endLocation": routeData.endLocation,
                "intermediateStops": routeData.intermediateStops,
                "transportType": routeData.transportType,
                "basePrice": routeData.basePrice,
                "isActive": routeData.isActive,
                "updatedAt": time:utcNow().toString()
            };
            
            mongodb:UpdateResult updateResult = check routesCollection->updateOne(
                {"_id": routeId}, 
                {"$set": updatedRoute}
            );
            
            if updateResult.modifiedCount > 0 {
                log:printInfo("Route updated: " + routeId);
                updatedRoute["_id"] = routeId;
                return updatedRoute;
            } else {
                return <http:NotFound>{
                    body: {message: "Route not found"}
                };
            }
            
        } on fail error e {
            log:printError("Error updating route: " + e.message());
            return <http:InternalServerError>{
                body: {message: "Route update failed"}
            };
        }
    }
    
    // Get all trips
    resource function get trips(string? status = ()) returns map<json>[]|http:InternalServerError {
        do {
            mongodb:Database database = check mongoClient->getDatabase(databaseName);
            mongodb:Collection tripsCollection = check database->getCollection("trips");
            
            map<json> filter = {};
            if status is string {
                filter["status"] = status;
            }
            
            stream<TripDb, error?> resultStream = check tripsCollection->find(filter);
            map<json>[] trips = [];
            
            check from TripDb tripDb in resultStream
                do {
                    map<json> trip = {
                        "routeId": tripDb.routeId,
                        "departureTime": tripDb.departureTime,
                        "arrivalTime": tripDb.arrivalTime,
                        "availableSeats": tripDb.availableSeats,
                        "totalSeats": tripDb.totalSeats,
                        "status": tripDb.status
                    };
                    if tripDb["_id"] is string {
                        trip["_id"] = <string>tripDb["_id"];
                    }
                    trips.push(trip);
                };
            
            log:printInfo("Retrieved " + trips.length().toString() + " trips");
            return trips;
            
        } on fail error e {
            log:printError("Error retrieving trips: " + e.message());
            return <http:InternalServerError>{
                body: {message: "Failed to retrieve trips"}
            };
        }
    }
    
    // Create new trip
    resource function post trips(@http:Payload Trip tripData) returns map<json>|http:BadRequest|http:InternalServerError {
        do {
            mongodb:Database database = check mongoClient->getDatabase(databaseName);
            mongodb:Collection tripsCollection = check database->getCollection("trips");
            
            map<json> newTrip = {
                "routeId": tripData.routeId,
                "departureTime": tripData.departureTime,
                "arrivalTime": tripData.arrivalTime,
                "availableSeats": tripData.totalSeats,
                "totalSeats": tripData.totalSeats,
                "status": "SCHEDULED",
                "createdAt": time:utcNow().toString(),
                "updatedAt": time:utcNow().toString()
            };
            
            check tripsCollection->insertOne(newTrip);
            
            log:printInfo("New trip created for route: " + tripData.routeId);
            return newTrip;
            
        } on fail error e {
            log:printError("Error creating trip: " + e.message());
            return <http:InternalServerError>{
                body: {message: "Trip creation failed"}
            };
        }
    }
    
    // Get trips by route
    resource function get routes/[string routeId]/trips(string? status = ()) returns map<json>[]|http:InternalServerError {
        do {
            mongodb:Database database = check mongoClient->getDatabase(databaseName);
            mongodb:Collection tripsCollection = check database->getCollection("trips");
            
            map<json> filter = {"routeId": routeId};
            if status is string {
                filter["status"] = status;
            }
            
            // Use typed stream to avoid projection issues, then manually build response
            stream<TripDb, error?> tripStream = check tripsCollection->find(filter);
            
            map<json>[] tripArray = [];
            check from TripDb trip in tripStream
                do {
                    map<json> tripJson = {
                        "routeId": trip.routeId,
                        "departureTime": trip.departureTime,
                        "arrivalTime": trip.arrivalTime,
                        "availableSeats": trip.availableSeats,
                        "totalSeats": trip.totalSeats,
                        "status": trip.status,
                        "createdAt": trip.createdAt
                    };
                    
                    // Add optional fields
                    if trip?.delayReason is string {
                        tripJson["delayReason"] = <string>trip?.delayReason;
                    }
                    if trip?.delayMinutes is int {
                        tripJson["delayMinutes"] = <int>trip?.delayMinutes;
                    }
                    if trip?.updatedAt is string {
                        tripJson["updatedAt"] = trip.updatedAt;
                    }
                    
                    tripArray.push(tripJson);
                };
            
            log:printInfo("Retrieved trips for route: " + routeId + ", count: " + tripArray.length().toString());
            return tripArray;
            
        } on fail error e {
            log:printError("Error getting trips: " + e.message());
            return <http:InternalServerError>{
                body: {message: "Trip retrieval failed"}
            };
        }
    }
    
    // Update trip status (delay, cancel, etc.)
    resource function put trips/[string tripId]/status(@http:Payload record {|string status; string? reason?; int? delayMinutes?;|} statusUpdate) returns map<json>|http:NotFound|http:InternalServerError {
        do {
            mongodb:Database database = check mongoClient->getDatabase(databaseName);
            mongodb:Collection tripsCollection = check database->getCollection("trips");
            
            // Get existing trip
            map<json>? existingTrip = check tripsCollection->findOne({"_id": tripId});
            
            if existingTrip is map<json> {
                // Calculate new times if delayed
                string? newDepartureTime = ();
                string? newArrivalTime = ();
                
                if statusUpdate.status == "DELAYED" && statusUpdate?.delayMinutes is int {
                    // For simplicity, we'll update the time as string
                    newDepartureTime = "Updated: " + (<string>existingTrip["departureTime"]);
                    newArrivalTime = "Updated: " + (<string>existingTrip["arrivalTime"]);
                }
                
                // Update trip
                map<json> updateData = {
                    "status": statusUpdate.status,
                    "updatedAt": time:utcNow().toString()
                };
                
                if statusUpdate?.reason is string {
                    updateData["delayReason"] = <string>statusUpdate?.reason;
                }
                
                if statusUpdate?.delayMinutes is int {
                    updateData["delayMinutes"] = <int>statusUpdate?.delayMinutes;
                }
                
                if newDepartureTime is string {
                    updateData["departureTime"] = newDepartureTime;
                }
                
                if newArrivalTime is string {
                    updateData["arrivalTime"] = newArrivalTime;
                }
                
                mongodb:UpdateResult updateResult = check tripsCollection->updateOne(
                    {"_id": tripId},
                    {"$set": updateData}
                );
                
                if updateResult.modifiedCount > 0 {
                    // Publish schedule update to Kafka
                    ScheduleUpdate scheduleUpdate = {
                        tripId: tripId,
                        routeId: <string>existingTrip["routeId"],
                        updateType: statusUpdate.status == "CANCELLED" ? "CANCELLATION" : 
                                   statusUpdate.status == "DELAYED" ? "DELAY" : "SCHEDULE_CHANGE",
                        message: statusUpdate?.reason ?: ("Trip status updated to: " + statusUpdate.status),
                        timestamp: time:utcNow().toString(),
                        delayMinutes: statusUpdate?.delayMinutes,
                        newDepartureTime: newDepartureTime,
                        newArrivalTime: newArrivalTime
                    };
                    
                    check kafkaProducer->send({
                        topic: "schedule.updates",
                        value: scheduleUpdate
                    });
                    
                    log:printInfo("Schedule update published for trip: " + tripId);
                    
                    // Return updated trip
                    foreach var [key, value] in updateData.entries() {
                        existingTrip[key] = value;
                    }
                    
                    return existingTrip;
                }
            }
            
            return <http:NotFound>{
                body: {message: "Trip not found"}
            };
            
        } on fail error e {
            log:printError("Error updating trip status: " + e.message());
            return <http:InternalServerError>{
                body: {message: "Trip status update failed"}
            };
        }
    }
    
    // Health check
    resource function get health() returns string {
        return "Transport Service is running";
    }
}

public function main() returns error? {
    log:printInfo("Transport Service started on port 8081");
}
