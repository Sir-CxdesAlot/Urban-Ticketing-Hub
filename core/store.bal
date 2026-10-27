import ballerina/crypto;
import ballerina/jballerina.java;
import ballerina/time;
import ballerina/uuid;

public configurable string mongoUri = "mongodb://localhost:27017/?replicaSet=rs0&directConnection=true&serverSelectionTimeoutMS=5000";
public configurable string databaseName = "uth_demo_v2";

isolated function executeDatabase(handle uri, handle database, handle command) returns handle = @java:Method {
    'class: "uth.MongoStore", name: "execute"
} external;

isolated function secureRandomToken() returns handle = @java:Method {
    'class: "uth.MongoStore", name: "randomToken"
} external;

public type Document map<json>;

public isolated function problem(int status, string message) returns error {
    return error(message, status = status);
}

public isolated function now() returns int {
    return <int>time:utcNow()[0];
}

public isolated function timestamp(int seconds = now()) returns string {
    return time:utcToString([seconds, 0]);
}

public isolated function identifier() returns string {
    return uuid:createType4AsString();
}

isolated function db(Document command) returns json|error {
    handle result = executeDatabase(java:fromString(mongoUri), java:fromString(databaseName),
        java:fromString(command.toJsonString()));
    json decoded = check (java:toString(result) ?: "{}").fromJsonString();
    Document response = check decoded.cloneWithType();
    if response["ok"] != true {
        if response["code"] == "CONFLICT" {
            return problem(409, "The record changed or already exists. Refresh and retry.");
        }
        return problem(503, "The database is temporarily unavailable.");
    }
    return response["data"];
}

// Time: approximately O(log N + k) with the matching index; k includes skipped and returned records.
public isolated function find(string collection, Document filter = {}, int 'limit = 100,
        int offset = 0, Document sort = {id: 1}) returns Document[]|error {
    json result = check db({op: "find", collection, filter, 'limit, skip: offset, sort});
    return result.cloneWithType();
}

public isolated function one(string collection, Document filter) returns Document|error {
    Document[] records = check find(collection, filter, 1);
    if records.length() == 0 {
        return problem(404, "Record not found.");
    }
    return records[0];
}

public isolated function count(string collection, Document filter = {}) returns int|error {
    json result = check db({op: "count", collection, filter});
    return result.cloneWithType();
}

public isolated function aggregate(string collection, Document[] pipeline) returns Document[]|error {
    json result = check db({op: "aggregate", collection, pipeline});
    return result.cloneWithType();
}

// ACID: every conditional change and its outbox/audit records commit together or none do.
public isolated function transact(Document[] changes) returns error? {
    _ = check db({op: "transaction", changes});
}

public isolated function insert(string collection, Document document) returns Document {
    return {op: "insert", collection, document};
}

public isolated function update(string collection, Document filter, Document fields) returns Document {
    return {op: "update", collection, filter, update: {"$set": fields}, expected: 1};
}

public isolated function remove(string collection, Document filter) returns Document {
    return {op: "delete", collection, filter, expected: 1};
}

public isolated function guard(Document document) returns Document|error {
    return {id: check text(document, "id"), version: check integer(document, "version")};
}

public isolated function text(Document value, string fieldName) returns string|error {
    if !value.hasKey(fieldName) { return problem(400, "Missing " + fieldName + "."); }
    json item = value[fieldName];
    if item is string { return item; }
    return problem(400, "Invalid or missing " + fieldName + ".");
}

public isolated function integer(Document value, string fieldName) returns int|error {
    if !value.hasKey(fieldName) { return problem(400, "Missing " + fieldName + "."); }
    json item = value[fieldName];
    if item is int { return item; }
    return problem(400, "Invalid or missing " + fieldName + ".");
}

public isolated function required(Document value, string fieldName, int minimum = 1, int maximum = 160) returns string|error {
    string item = (check text(value, fieldName)).trim();
    if item.length() < minimum || item.length() > maximum {
        return problem(400, fieldName + " must contain " + minimum.toString() + "–" + maximum.toString() + " characters.");
    }
    return item;
}

// Allowlisting: unknown fields cannot overwrite server-owned identity, prices, or state.
public isolated function only(Document value, string[] allowed) returns error? {
    foreach string fieldName in value.keys() {
        if allowed.indexOf(fieldName) is () { return problem(400, "Unexpected field: " + fieldName + "."); }
    }
}

public isolated function sha256(string value) returns string {
    return crypto:hashSha256(value.toBytes()).toBase16();
}

public isolated function audit(Document actor, string action, string subject) returns Document {
    return insert("audit", {id: identifier(), actorId: actor["id"], action, subjectId: subject,
        createdAt: timestamp()});
}

public isolated function event(string kind, string recipient, Document data) returns Document {
    return insert("outbox", {id: identifier(), kind, recipient, data, createdAt: timestamp(),
        published: false, attempts: 0});
}

public isolated function health() returns Document|error {
    _ = check db({op: "ping"});
    return {status: "ready", database: "reachable"};
}

public isolated function initializeIndexes() returns error? {
    foreach string collection in ["accounts", "sessions", "routes", "trips", "tickets", "bookings", "payments",
            "operations", "outbox", "notifications", "deliveries", "delivery_failures", "audit", "login_limits"] {
        _ = check db({op: "index", collection, keys: {id: 1}, unique: true});
    }
    Document[] indexes = [
        {collection: "accounts", keys: {email: 1}, unique: true},
        {collection: "accounts", keys: {role: 1, active: 1, id: 1}},
        {collection: "routes", keys: {active: 1, createdAt: -1, id: 1}},
        {collection: "routes", keys: {active: 1, searchName: 1}},
        {collection: "routes", keys: {active: 1, searchStart: 1}},
        {collection: "routes", keys: {active: 1, searchEnd: 1}},
        {collection: "sessions", keys: {tokenHash: 1}, unique: true},
        {collection: "operations", keys: {userId: 1, requestKey: 1}, unique: true},
        {collection: "trips", keys: {routeId: 1, departureTime: 1}},
        {collection: "trips", keys: {operatorId: 1, departureTime: 1}},
        {collection: "bookings", keys: {userId: 1, tripId: 1, active: 1}},
        {collection: "bookings", keys: {ticketId: 1, status: 1}},
        {collection: "bookings", keys: {status: 1, holdUntil: 1}},
        {collection: "tickets", keys: {userId: 1, createdAt: -1}},
        {collection: "payments", keys: {userId: 1, createdAt: -1}},
        {collection: "notifications", keys: {userId: 1, createdAt: -1}},
        {collection: "outbox", keys: {published: 1, createdAt: 1}},
        {collection: "audit", keys: {createdAt: -1}},
        {collection: "sessions", keys: {userId: 1}}
    ];
    foreach Document index in indexes { index["op"] = "index"; _ = check db(index); }
}
