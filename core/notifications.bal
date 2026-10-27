public isolated function broadcast(Document actor, Document body) returns Document|error {
    check authorize(actor, ["TRANSPORT_MANAGER", "SUPER_ADMIN"]);
    check only(body, ["message"]);
    string message = check required(body, "message", 1, 500);
    string id = identifier();
    check transact([insert("outbox", {id, kind: "BROADCAST", recipient: "ALL", data: {message},
        createdAt: timestamp(), published: false, attempts: 0}), audit(actor, "notification.broadcast", id)]);
    return {id, status: "QUEUED"};
}

public isolated function markRead(Document actor, string id) returns Document|error {
    Document notification = check one("notifications", {id});
    check owner(actor, notification);
    check transact([update("notifications", {id, userId: actor["id"]}, {read: true})]);
    return one("notifications", {id});
}

public isolated function deleteNotification(Document actor, string id) returns Document|error {
    Document notification = check one("notifications", {id});
    check owner(actor, notification);
    check transact([remove("notifications", {id, userId: actor["id"]})]);
    return {success: true};
}

// At-least-once delivery: event ID plus recipient prevents a replay from inserting a duplicate.
public isolated function deliver(Document message) returns error? {
    string eventId = check text(message, "id");
    string kind = check required(message, "kind");
    string recipient = check text(message, "recipient");
    if !message.hasKey("data") { return problem(400, "Missing event data."); }
    Document|error decoded = message["data"].cloneWithType();
    if decoded is error { return problem(400, "Invalid event data."); }
    Document payload = decoded;
    _ = check required(payload, "message", 1, 500);
    if recipient == "ALL" {
        string lastId = "";
        // Keyset pagination: O(u log U) indexed delivery lookups for u recipients among U accounts.
        while true {
            Document filter = {active: true, role: "PASSENGER"};
            if lastId != "" { filter["id"] = {"$gt": lastId}; }
            Document[] accounts = check find("accounts", filter, 100);
            foreach Document account in accounts { check deliverTo(eventId, check text(account, "id"), payload); }
            if accounts.length() < 100 { break; }
            lastId = check text(accounts[accounts.length() - 1], "id");
        }
    } else if recipient == "" && kind == "TRIP_UPDATED" {
        string tripId = check required(payload, "tripId");
        Document[] bookings = check find("bookings", {tripId, active: true}, 200);
        foreach Document booking in bookings { check deliverTo(eventId, check text(booking, "userId"), payload); }
    } else {
        if recipient == "" { return problem(400, "Missing event recipient."); }
        check deliverTo(eventId, recipient, payload);
    }
}

isolated function deliverTo(string eventId, string userId, Document payload) returns error? {
    string deliveryId = eventId + "|" + userId;
    if (check count("deliveries", {id: deliveryId})) > 0 { return; }
    error? result = transact([insert("deliveries", {id: deliveryId, createdAt: timestamp()}),
        insert("notifications", {id: identifier(), userId, eventId, message: payload["message"], data: payload,
            read: false, createdAt: timestamp()})]);
    if result is error {
        // A simultaneous replay may have completed the same delivery first.
        if (check count("deliveries", {id: deliveryId})) == 0 { return result; }
    }
}

public isolated function pendingEvents() returns Document[]|error {
    return find("outbox", {published: false}, 50, 0, {createdAt: 1, id: 1});
}

public isolated function publicationResult(Document message, boolean success) returns error? {
    check transact([update("outbox", {id: message["id"], published: false}, {
        published: success, attempts: (check integer(message, "attempts")) + 1,
        lastAttemptAt: timestamp(), lastError: success ? "" : "Kafka publication failed; will retry."})]);
}

public isolated function quarantine(string id, json payload) returns error? {
    if (check count("delivery_failures", {id})) > 0 { return; }
    check transact([insert("delivery_failures", {id, payload, status: "FAILED",
        reason: "Invalid notification event; inspect and retry through the admin API.", createdAt: timestamp()})]);
}

public isolated function retryDelivery(Document actor, string id) returns Document|error {
    check authorize(actor, ["SUPER_ADMIN"]);
    Document failed = check one("delivery_failures", {id, status: "FAILED"});
    Document payload = check failed["payload"].cloneWithType();
    check deliver(payload);
    check transact([update("delivery_failures", {id, status: "FAILED"}, {status: "RESOLVED"}),
        audit(actor, "notification.retry", id)]);
    return {success: true};
}
