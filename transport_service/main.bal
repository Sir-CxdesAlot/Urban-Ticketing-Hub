import ballerina/http;
import ballerina/log;
import ballerina/uuid;
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

// Input payload for creating a route (no audit fields)
public type RouteInput record {|
    string name;
    string startLocation;
    string endLocation;
    string[] intermediateStops;
    string transportType; // BUS, TRAIN
    decimal basePrice;
    boolean? isActive?;
    string? createdAt?;
    string? updatedAt?;
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

// Input payload for creating a trip (no audit/status fields)
public type TripCreate record {|
    string routeId;
    string departureTime;
    string arrivalTime;
    int totalSeats;
    int? availableSeats?;
    string? status?;
    string? createdAt?;
    string? updatedAt?;
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

// Update payload for trips
public type TripUpdate record {|
    int? availableSeats?;
    int? totalSeats?;
    string? status?;
    string? departureTime?;
    string? arrivalTime?;
    string? delayReason?;
    int? delayMinutes?;
|};

// Service configuration
listener http:Listener httpListener = new(8082);

service /api/v1/transport on httpListener {
    
    // Create new route
    resource function post routes(@http:Payload RouteInput routeData) returns map<json>|http:BadRequest|http:InternalServerError {
        do {
            mongodb:Database database = check mongoClient->getDatabase(databaseName);
            mongodb:Collection routesCollection = check database->getCollection("routes");
            
            map<json> newRoute = {
                // Generate a stable unique id to satisfy DB unique indexes
                "id": uuid:createType4AsString(),
                // Provide a routeNumber to satisfy DB unique index requirements
                "routeNumber": "RN-" + uuid:createType4AsString(),
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
            
            _ = check routesCollection->insertOne(newRoute);

            log:printInfo("New route created: " + routeData.name);

            // Attempt to return the created route including a string _id so clients/tests can consume it
            // Match using the generated id which is unique
            map<json>[] pipeline = [
                {"$match": {"id": newRoute["id"]}},
                {"$project": {
                    "_id": {"$toString": "$_id"},
                    "id": 1,
                    "routeNumber": 1,
                    "name": 1,
                    "startLocation": 1,
                    "endLocation": 1,
                    "intermediateStops": 1,
                    "transportType": 1,
                    "basePrice": 1,
                    "isActive": 1,
                    "createdAt": 1,
                    "updatedAt": 1
                }}
            ];

            // Use aggregate to fetch the created document with _id converted to string
            stream<record {}, error?> routeStream = check routesCollection->aggregate(pipeline);
            record {}[] routes = check from record {} r in routeStream select r;
            check routeStream.close();

            if (routes.length() > 0) {
                map<anydata> routeMap = routes[0];
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
            }

            // Fallback: return the inserted newRoute (without _id) if lookup failed
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
            
            // Use BSON ObjectId filter
            mongodb:UpdateResult updateResult = check routesCollection->updateOne(
                {"_id": {"$oid": routeId}}, 
                {"set": updatedRoute}
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

    // Delete route by ID
    resource function delete routes/[string routeId]() returns json|http:NotFound|http:InternalServerError {
        do {
            mongodb:Database database = check mongoClient->getDatabase(databaseName);
            mongodb:Collection routesCollection = check database->getCollection("routes");

            mongodb:DeleteResult result = check routesCollection->deleteOne({"_id": {"$oid": routeId}});
            if (result.deletedCount == 0) {
                return <http:NotFound>{ body: {message: "Route not found"} };
            }
            return {"success": true, "message": "Route deleted successfully"};
        } on fail error e {
            log:printError("Error deleting route: " + e.message());
            return <http:InternalServerError>{ body: {message: "Route deletion failed"} };
        }
    }
    
    // Get all trips
    resource function get trips(string? status = ()) returns map<json>[]|http:InternalServerError {
        do {
            mongodb:Database database = check mongoClient->getDatabase(databaseName);
            mongodb:Collection tripsCollection = check database->getCollection("trips");

            map<json> matchFilter = {};
            if status is string { matchFilter["status"] = status; }
            map<json>[] pipeline = [
                {"$match": matchFilter},
                {"$project": {
                    "_id": {"$toString": "$_id"},
                    "routeId": 1, "departureTime": 1, "arrivalTime": 1,
                    "availableSeats": 1, "totalSeats": 1, "status": 1
                }}
            ];

            stream<record {}, error?> s = check tripsCollection->aggregate(pipeline);
            map<json>[] trips = [];
            check from record {} r in s do {
                map<anydata> m = r;
                map<json> j = {};
                foreach var [k,v] in m.entries() { j[k] = v is json ? v : v.toJson(); }
                trips.push(j);
            };
            check s.close();
            log:printInfo("Retrieved " + trips.length().toString() + " trips");
            return trips;
        } on fail error e {
            log:printError("Error retrieving trips: " + e.message());
            return <http:InternalServerError>{ body: {message: "Failed to retrieve trips"} };
        }
    }
    
    // Create new trip
    resource function post trips(@http:Payload TripCreate tripData) returns map<json>|http:BadRequest|http:InternalServerError {
        do {
            mongodb:Database database = check mongoClient->getDatabase(databaseName);
            mongodb:Collection tripsCollection = check database->getCollection("trips");
            
            map<json> newTrip = {
                "id": uuid:createType4AsString(),
                "routeId": tripData.routeId,
                "departureTime": tripData.departureTime,
                "arrivalTime": tripData.arrivalTime,
                "availableSeats": tripData.totalSeats,
                "totalSeats": tripData.totalSeats,
                "status": "SCHEDULED",
                "createdAt": time:utcNow().toString(),
                "updatedAt": time:utcNow().toString()
            };

            _ = check tripsCollection->insertOne(newTrip);

            log:printInfo("New trip created for route: " + tripData.routeId);

            // Return created trip with string _id
            map<json>[] pipeline = [
                {"$match": {"id": newTrip["id"]}},
                {"$project": {"_id": {"$toString": "$_id"}, "routeId": 1, "departureTime": 1, "arrivalTime": 1, "availableSeats": 1, "totalSeats": 1, "status": 1, "createdAt": 1, "updatedAt": 1}}
            ];
            stream<record {}, error?> s = check tripsCollection->aggregate(pipeline);
            record {}[] found = check from record {} r in s select r;
            check s.close();
            if (found.length() > 0) {
                map<anydata> m = found[0];
                map<json> j = {};
                foreach var [k, v] in m.entries() {
                    if (v is json) {
                        j[k] = v;
                    } else {
                        j[k] = v.toString();
                    }
                }
                return j;
            }

            return newTrip;
            
        } on fail error e {
            log:printError("Error creating trip: " + e.message());
            return <http:InternalServerError>{
                body: {message: "Trip creation failed"}
            };
        }
    }

    // Get trip by ID
    resource function get trips/[string tripId]() returns map<json>|http:NotFound|http:InternalServerError {
        do {
            mongodb:Database database = check mongoClient->getDatabase(databaseName);
            mongodb:Collection tripsCollection = check database->getCollection("trips");
            map<json>? trip = check tripsCollection->findOne({"_id": {"$oid": tripId}});
            if (trip is map<json>) { return trip; }
            return <http:NotFound>{ body: {message: "Trip not found"} };
        } on fail error e {
            log:printError("Error getting trip: " + e.message());
            return <http:InternalServerError>{ body: {message: "Trip retrieval failed"} };
        }
    }

    // Update trip by ID (general fields)
    resource function put trips/[string tripId](@http:Payload TripUpdate updateReq) returns json|http:NotFound|http:InternalServerError {
        do {
            mongodb:Database database = check mongoClient->getDatabase(databaseName);
            mongodb:Collection tripsCollection = check database->getCollection("trips");
            map<json> updateFields = {};
            if (updateReq?.availableSeats is int) { updateFields["availableSeats"] = updateReq?.availableSeats; }
            if (updateReq?.totalSeats is int) { updateFields["totalSeats"] = updateReq?.totalSeats; }
            if (updateReq?.status is string) { updateFields["status"] = updateReq?.status; }
            if (updateReq?.departureTime is string) { updateFields["departureTime"] = updateReq?.departureTime; }
            if (updateReq?.arrivalTime is string) { updateFields["arrivalTime"] = updateReq?.arrivalTime; }
            if (updateReq?.delayReason is string) { updateFields["delayReason"] = updateReq?.delayReason; }
            if (updateReq?.delayMinutes is int) { updateFields["delayMinutes"] = updateReq?.delayMinutes; }
            updateFields["updatedAt"] = time:utcNow().toString();

            if (updateFields.length() == 0) { return {"success": true, "message": "No fields to update"}; }

            mongodb:UpdateResult result = check tripsCollection->updateOne({"_id": {"$oid": tripId}}, {"set": updateFields});
            if (result.matchedCount == 0) { return <http:NotFound>{ body: {message: "Trip not found"} }; }
            return {"success": true, "message": "Trip updated successfully"};
        } on fail error e {
            log:printError("Error updating trip: " + e.message());
            return <http:InternalServerError>{ body: {message: "Trip update failed"} };
        }
    }

    // Delete trip by ID
    resource function delete trips/[string tripId]() returns json|http:NotFound|http:InternalServerError {
        do {
            mongodb:Database database = check mongoClient->getDatabase(databaseName);
            mongodb:Collection tripsCollection = check database->getCollection("trips");
            mongodb:DeleteResult result = check tripsCollection->deleteOne({"_id": {"$oid": tripId}});
            if (result.deletedCount == 0) { return <http:NotFound>{ body: {message: "Trip not found"} }; }
            return {"success": true, "message": "Trip deleted successfully"};
        } on fail error e {
            log:printError("Error deleting trip: " + e.message());
            return <http:InternalServerError>{ body: {message: "Trip deletion failed"} };
        }
    }
    
    // Get trips by route
    resource function get routes/[string routeId]/trips(string? status = ()) returns map<json>[]|http:InternalServerError {
        do {
            mongodb:Database database = check mongoClient->getDatabase(databaseName);
            mongodb:Collection tripsCollection = check database->getCollection("trips");

            map<json> matchFilter = {"routeId": routeId};
            if status is string { matchFilter["status"] = status; }
            map<json>[] pipeline = [
                {"$match": matchFilter},
                {"$project": {
                    "_id": {"$toString": "$_id"},
                    "routeId": 1, "departureTime": 1, "arrivalTime": 1,
                    "availableSeats": 1, "totalSeats": 1, "status": 1,
                    "delayReason": 1, "delayMinutes": 1, "createdAt": 1, "updatedAt": 1
                }}
            ];
            stream<record {}, error?> s = check tripsCollection->aggregate(pipeline);
            map<json>[] out = [];
            check from record {} r in s do {
                map<anydata> m = r; map<json> j = {};
                foreach var [k,v] in m.entries() { j[k] = v is json ? v : v.toJson(); }
                out.push(j);
            };
            check s.close();
            log:printInfo("Retrieved trips for route: " + routeId + ", count: " + out.length().toString());
            return out;
        } on fail error e {
            log:printError("Error getting trips: " + e.message());
            return <http:InternalServerError>{ body: {message: "Trip retrieval failed"} };
        }
    }
    
    // Update trip status (delay, cancel, etc.)
    resource function put trips/[string tripId]/status(@http:Payload record {|string status; string? reason?; int? delayMinutes?;|} statusUpdate) returns map<json>|http:NotFound|http:InternalServerError {
        do {
            mongodb:Database database = check mongoClient->getDatabase(databaseName);
            mongodb:Collection tripsCollection = check database->getCollection("trips");
            
            // Get existing trip
            map<json>? existingTrip = check tripsCollection->findOne({"_id": {"$oid": tripId}});
            
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
                    {"_id": {"$oid": tripId}},
                    {"set": updateData}
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
    log:printInfo("Transport Service started on port 8082");
}
