import ballerina/http;

public isolated function errorStatus(error failure) returns int {
    var details = failure.detail();
    if details.hasKey("status") {
        var status = details["status"];
        if status is int { return status; }
    }
    return 500;
}

isolated function header(http:Request request, string name) returns string {
    string|http:HeaderNotFoundError value = request.getHeader(name);
    return value is string ? value : "";
}

isolated function query(http:Request request, string name, string fallback = "") returns string {
    return request.getQueryParamValue(name) ?: fallback;
}

isolated function page(http:Request request) returns [int, int]|error {
    int|error 'limit = int:fromString(query(request, "limit", "20"));
    int|error offset = int:fromString(query(request, "offset", "0"));
    if 'limit is error || offset is error { return problem(400, "limit and offset must be integers."); }
    if 'limit < 1 || 'limit > 100 || offset < 0 || offset > 10000 { return problem(400, "Use limit 1–100 and offset 0–10000."); }
    return ['limit, offset];
}

isolated function listing(string collection, Document filter, int 'limit, int offset) returns Document|error {
    Document[] items = [];
    if collection == "tickets" || collection == "bookings" {
        // Join: left outer lookup supplies display data without one browser request per record.
        Document[] pipeline = [{"$match": filter}, {"$sort": {createdAt: -1, id: 1}},
            {"$skip": offset}, {"$limit": 'limit},
            {"$lookup": {"from": "routes", localField: "routeId", foreignField: "id", 'as: "route"}},
            {"$unwind": {path: "$route", preserveNullAndEmptyArrays: true}}];
        if collection == "bookings" {
            pipeline.push({"$lookup": {"from": "trips", localField: "tripId", foreignField: "id", 'as: "trip"}});
            pipeline.push({"$unwind": {path: "$trip", preserveNullAndEmptyArrays: true}});
        }
        pipeline.push({"$project": {_id: 0, "route._id": 0, "trip._id": 0}});
        items = check aggregate(collection, pipeline);
    } else { items = check find(collection, filter, 'limit, offset, {createdAt: -1, id: 1}); }
    return {items,
        'limit, offset, total: check count(collection, filter)};
}

public isolated function respond(string serviceName, string method, string[] path, http:Request request) returns http:Response {
    http:Response response = new;
    do {
        Document body = {};
        if method == "POST" || method == "PUT" {
            json|error payload = request.getJsonPayload();
            if payload is error { return errorResponse(400, "Send a JSON object body."); }
            Document|error decoded = payload.cloneWithType();
            if decoded is error { return errorResponse(400, "Send a JSON object body."); }
            body = decoded;
        }
        json|error result = dispatch(serviceName, method, path, request, body);
        // Optimistic retry: re-read state after a transaction conflict, including completed idempotent requests.
        foreach int attempt in 1 ... 2 {
            if result is error && errorStatus(result) == 409 {
                result = dispatch(serviceName, method, path, request, body);
            }
        }
        json data = check result;
        response.setJsonPayload(data);
        response.statusCode = 200;
    } on fail error failure {
        int status = errorStatus(failure);
        return errorResponse(status, status == 500 ? "The request could not be completed." : failure.message());
    }
    response.setHeader("Cache-Control", "no-store");
    return response;
}

isolated function errorResponse(int status, string message) returns http:Response {
    http:Response response = new;
    response.statusCode = status;
    response.setJsonPayload({"error": {code: status.toString(), message}});
    response.setHeader("Cache-Control", "no-store");
    return response;
}

isolated function dispatch(string serviceName, string method, string[] path, http:Request request, Document body) returns json|error {
    [int, int] pagination = check page(request);
    int 'limit = pagination[0]; int offset = pagination[1];
    string resourceName = path.length() > 0 ? path[0] : "";
    string id = path.length() > 1 ? path[1] : "";
    string action = path.length() > 2 ? path[2] : "";
    if path.length() > 3 { return problem(404, "Endpoint not found."); }
    if resourceName == "health" && method == "GET" && path.length() == 1 { return health(); }
    if (serviceName == "passenger" || serviceName == "admin") && method == "POST" && path.length() == 1 {
        if resourceName == "login" { return login(body, serviceName == "admin"); }
        if serviceName == "passenger" && resourceName == "register" { return register(body); }
    }
    if serviceName == "transport" && method == "GET" && action == "" {
        if resourceName == "routes" {
            if id != "" { return one("routes", {id, active: true}); }
            Document filter = {active: true};
            string search = query(request, "q").trim().toLowerAscii();
            if search.length() > 80 { return problem(400, "Search must contain at most 80 characters."); }
            if search != "" {
                // Time: each prefix branch can use its index; matching/sorting costs depend on returned candidates.
                Document prefix = {"$gte": search, "$lt": search + "\u{10FFFF}"};
                filter["$or"] = [{searchName: prefix}, {searchStart: prefix}, {searchEnd: prefix}];
            }
            string transportType = query(request, "transportType");
            if transportType != "" { filter["transportType"] = transportType; }
            return listing("routes", filter, 'limit, offset);
        }
        if resourceName == "trips" {
            if id != "" { return displayTrip(check one("trips", {id})); }
            Document filter = {status: "SCHEDULED", departureTime: {"$gt": timestamp()}};
            string routeId = query(request, "routeId");
            if routeId != "" { filter["routeId"] = routeId; }
            string tripId = query(request, "tripId");
            if tripId != "" { filter["id"] = tripId; }
            return listTrips(filter, 'limit, offset);
        }
    }
    Document actor = check authenticate(header(request, "Authorization"));
    if serviceName == "passenger" {
        if resourceName == "logout" && method == "POST" && id == "" { check only(body, []); return logout(actor); }
        if resourceName == "me" && id == "" {
            if method == "GET" { return publicAccount(actor); }
            if method == "PUT" { return changeProfile(actor, body); }
            if method == "DELETE" { return deactivateSelf(actor); }
        }
    }
    if serviceName == "transport" {
        if resourceName == "routes" && action == "" {
            if method == "POST" && id == "" { return saveRoute(actor, body); }
            if method == "PUT" && id != "" { return saveRoute(actor, body, id); }
            if method == "DELETE" && id != "" { return retireRoute(actor, id); }
        }
        if resourceName == "trips" {
            if method == "POST" && id == "" { return saveTrip(actor, body); }
            if method == "PUT" && id != "" && action == "" { return saveTrip(actor, body, id); }
            if method == "POST" && id != "" && action == "cancel" { check only(body, []); return cancelTrip(actor, id); }
        }
    }
    if serviceName == "ticketing" {
        if resourceName == "checkout" && method == "POST" && id == "" { return checkout(actor, body); }
        if resourceName == "tickets" && method == "GET" && action == "" {
            check authorize(actor, ["PASSENGER"]);
            if id == "" { return listing("tickets", {userId: actor["id"]}, 'limit, offset); }
            Document ticket = check one("tickets", {id}); check owner(actor, ticket); return ticket;
        }
        if resourceName == "bookings" {
            if method == "POST" && id == "" { return book(actor, body); }
            if method == "POST" && id != "" && action == "cancel" { check only(body, []); return cancelBooking(actor, id); }
            if method == "POST" && id != "" && action == "validate" { check only(body, []); return validateBooking(actor, id); }
            if method == "GET" && action == "" {
                if actor["role"] == "PASSENGER" {
                    if id == "" { return listing("bookings", {userId: actor["id"]}, 'limit, offset); }
                    Document booking = check one("bookings", {id}); check owner(actor, booking); return booking;
                }
                check authorize(actor, ["ROUTE_OPERATOR", "TRANSPORT_MANAGER", "SUPER_ADMIN"]);
                string tripId = check required({tripId: query(request, "tripId")}, "tripId");
                Document trip = check one("trips", {id: tripId});
                if actor["role"] == "ROUTE_OPERATOR" && trip["operatorId"] != actor["id"] {
                    return problem(403, "This trip is assigned to another operator.");
                }
                return listing("bookings", {tripId}, 'limit, offset);
            }
        }
    }
    if serviceName == "payment" {
        if resourceName == "payments" && action == "" {
            if method == "POST" && id == "" { return pay(actor, body); }
            if method == "GET" {
                check authorize(actor, ["PASSENGER"]);
                if id == "" { return listing("payments", {userId: actor["id"]}, 'limit, offset); }
                Document payment = check one("payments", {id}); check owner(actor, payment); return payment;
            }
        }
        if resourceName == "refunds" && method == "POST" && id == "" { return refund(actor, body); }
    }
    if serviceName == "notification" {
        if resourceName == "notifications" {
            if method == "GET" && action == "" && id == "" {
                return listing("notifications", {userId: actor["id"]}, 'limit, offset);
            }
            if method == "POST" && action == "read" && id != "" { check only(body, []); return markRead(actor, id); }
            if method == "DELETE" && action == "" && id != "" { return deleteNotification(actor, id); }
        }
        if resourceName == "broadcasts" && method == "POST" && id == "" { return broadcast(actor, body); }
    }
    if serviceName == "admin" {
        if resourceName == "assigned-trips" && method == "GET" && id == "" {
            check authorize(actor, ["ROUTE_OPERATOR", "TRANSPORT_MANAGER", "SUPER_ADMIN"]);
            Document filter = {status: "SCHEDULED", arrivalTime: {"$gte": timestamp(now() - 7200)}};
            if actor["role"] == "ROUTE_OPERATOR" { filter["operatorId"] = actor["id"]; }
            return listTrips(filter, 'limit, offset);
        }
        if resourceName == "operators" && method == "GET" && id == "" {
            check authorize(actor, ["TRANSPORT_MANAGER", "SUPER_ADMIN"]);
            Document result = check listing("accounts", {role: "ROUTE_OPERATOR", active: true}, 'limit, offset);
            Document[] accounts = check result["items"].cloneWithType();
            result["items"] = accounts.map(account => publicAccount(account));
            return result;
        }
        if resourceName == "reports" && method == "GET" && id == "" { return report(actor); }
        check authorize(actor, ["SUPER_ADMIN"]);
        if resourceName == "accounts" {
            if method == "GET" && id == "" {
                Document result = check listing("accounts", {}, 'limit, offset);
                Document[] accounts = check result["items"].cloneWithType();
                result["items"] = accounts.map(account => publicAccount(account));
                return result;
            }
            if method == "POST" && id == "" {
                Role|error role = (check text(body, "role")).cloneWithType();
                if role is error || role == "PASSENGER" { return problem(400, "Choose a valid staff role."); }
                return register(body, role, actor);
            }
            if method == "PUT" && id != "" { return changeAccount(actor, id, body); }
        }
        if resourceName == "audit" && method == "GET" && id == "" { return listing("audit", {}, 'limit, offset); }
        if resourceName == "events" && method == "GET" && id == "" { return listing("outbox", {published: false}, 'limit, offset); }
        if resourceName == "delivery-failures" && method == "GET" && id == "" {
            return listing("delivery_failures", {status: "FAILED"}, 'limit, offset);
        }
        if resourceName == "delivery-failures" && method == "POST" && id != "" && action == "retry" {
            check only(body, []); return retryDelivery(actor, id);
        }
    }
    return problem(404, "Endpoint not found.");
}
