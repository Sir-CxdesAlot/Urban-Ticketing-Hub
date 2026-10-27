import ballerina/time;

public isolated function utcSeconds(string value) returns int|error {
    time:Utc|time:Error parsed = time:utcFromString(value);
    if parsed is time:Error { return problem(400, "Use an ISO 8601 timestamp with a timezone."); }
    return <int>parsed[0];
}

public isolated function routeFields(Document body) returns Document|error {
    check only(body, ["name", "startLocation", "endLocation", "intermediateStops", "transportType", "baseFareMinor"]);
    string transportType = check required(body, "transportType");
    if transportType != "BUS" && transportType != "TRAIN" && transportType != "SHUTTLE" { return problem(400, "transportType must be BUS, TRAIN, or SHUTTLE."); }
    int fare = check integer(body, "baseFareMinor");
    if fare < 1 || fare > 1000000 { return problem(400, "baseFareMinor must be between 1 and 1000000."); }
    json stops = body.hasKey("intermediateStops") ? body["intermediateStops"] : [];
    if stops is () { stops = []; }
    string[]|error checkedStops = stops.cloneWithType();
    if checkedStops is error { return problem(400, "intermediateStops must be a list of names."); }
    if checkedStops.length() > 30 { return problem(400, "A route can have at most 30 intermediate stops."); }
    foreach string stop in checkedStops {
        if stop.length() < 1 || stop.length() > 120 { return problem(400, "Stop names must contain 1–120 characters."); }
    }
    string name = check required(body, "name", 1, 120);
    string originName = check required(body, "startLocation", 1, 120);
    string destinationName = check required(body, "endLocation", 1, 120);
    return {name, startLocation: originName, endLocation: destinationName,
        searchName: name.toLowerAscii(), searchStart: originName.toLowerAscii(), searchEnd: destinationName.toLowerAscii(),
        transportType, baseFareMinor: fare, intermediateStops: checkedStops};
}

public isolated function saveRoute(Document actor, Document body, string requestedId = "") returns Document|error {
    string id = requestedId;
    check authorize(actor, ["TRANSPORT_MANAGER", "SUPER_ADMIN"]);
    Document fields = check routeFields(body);
    if id == "" {
        id = identifier();
        fields["id"] = id; fields["active"] = true; fields["version"] = 1; fields["createdAt"] = timestamp();
        check transact([insert("routes", fields), audit(actor, "route.create", id)]);
    } else {
        Document route = check one("routes", {id, active: true});
        fields["version"] = (check integer(route, "version")) + 1;
        check transact([update("routes", check guard(route), fields), audit(actor, "route.update", id)]);
    }
    return one("routes", {id});
}

public isolated function retireRoute(Document actor, string id) returns Document|error {
    check authorize(actor, ["TRANSPORT_MANAGER", "SUPER_ADMIN"]);
    Document route = check one("routes", {id, active: true});
    if (check count("trips", {routeId: id, status: "SCHEDULED", departureTime: {"$gt": timestamp()}})) > 0 {
        return problem(409, "Cancel this route's future trips before retiring it.");
    }
    check transact([update("routes", check guard(route), {active: false, version: (check integer(route, "version")) + 1}),
        audit(actor, "route.retire", id)]);
    return {success: true};
}

public isolated function tripFields(Document body) returns Document|error {
    check only(body, ["routeId", "departureTime", "arrivalTime", "capacity", "operatorId"]);
    string departure = check required(body, "departureTime");
    string arrival = check required(body, "arrivalTime");
    int departureSeconds = check utcSeconds(departure);
    int arrivalSeconds = check utcSeconds(arrival);
    if departureSeconds <= now() || arrivalSeconds <= departureSeconds || arrivalSeconds - departureSeconds > 86400 {
        return problem(400, "Trips must depart in the future and arrive within 24 hours after departure.");
    }
    int capacity = check integer(body, "capacity");
    if capacity < 1 || capacity > 200 { return problem(400, "capacity must be between 1 and 200."); }
    string operatorId = check required(body, "operatorId");
    _ = check one("accounts", {id: operatorId, role: "ROUTE_OPERATOR", active: true});
    return {routeId: check required(body, "routeId"), departureTime: timestamp(departureSeconds),
        arrivalTime: timestamp(arrivalSeconds), capacity, operatorId};
}

public isolated function saveTrip(Document actor, Document body, string requestedId = "") returns Document|error {
    string id = requestedId;
    check authorize(actor, ["TRANSPORT_MANAGER", "SUPER_ADMIN"]);
    Document fields = check tripFields(body);
    Document route = check one("routes", {id: fields["routeId"], active: true});
    // Optimistic concurrency: route changes cannot race this trip's creation or update.
    Document[] changes = [update("routes", check guard(route), {version: (check integer(route, "version")) + 1})];
    if id == "" {
        id = identifier(); fields["id"] = id; fields["status"] = "SCHEDULED";
        fields["reservedSeats"] = 0; fields["version"] = 1; fields["createdAt"] = timestamp();
        changes.push(insert("trips", fields));
    } else {
        Document trip = check one("trips", {id, status: "SCHEDULED"});
        if fields["routeId"] != trip["routeId"] { return problem(409, "A scheduled trip cannot change routes."); }
        if (check integer(fields, "capacity")) < (check integer(trip, "reservedSeats")) {
            return problem(409, "Capacity cannot be lower than the number of reserved seats.");
        }
        fields["version"] = (check integer(trip, "version")) + 1;
        changes.push(update("trips", check guard(trip), fields));
        changes.push(event("TRIP_UPDATED", "", {tripId: id, routeId: trip["routeId"],
            message: "Your trip schedule has changed. Check its departure time."}));
    }
    changes.push(audit(actor, "trip.save", id));
    check transact(changes);
    return displayTrip(check one("trips", {id}));
}

public isolated function displayTrip(Document trip) returns Document|error {
    trip["availableSeats"] = (check integer(trip, "capacity")) - (check integer(trip, "reservedSeats"));
    return trip;
}

public isolated function listTrips(Document filter, int 'limit, int offset) returns Document|error {
    // Join: indexed left outer join retains a trip even if its route is missing; page before joining.
    Document[] trips = check aggregate("trips", [{"$match": filter}, {"$sort": {departureTime: 1, id: 1}},
        {"$skip": offset}, {"$limit": 'limit},
        {"$lookup": {"from": "routes", localField: "routeId", foreignField: "id", 'as: "route"}},
        {"$unwind": {path: "$route", preserveNullAndEmptyArrays: true}}, {"$project": {_id: 0, "route._id": 0}}]);
    foreach Document trip in trips { _ = check displayTrip(trip); }
    return {items: trips, 'limit, offset, total: check count("trips", filter)};
}

public isolated function report(Document actor) returns Document|error {
    check authorize(actor, ["TRANSPORT_MANAGER", "SUPER_ADMIN"]);
    // Aggregation, not a join: group payment records by status and sum integer minor units.
    Document[] payments = check aggregate("payments", [{"$group": {_id: "$status", count: {"$sum": 1},
        totalMinor: {"$sum": "$amountMinor"}}}, {"$project": {_id: 0, status: "$_id", count: 1, totalMinor: 1}}]);
    return {payments, accounts: check count("accounts", {active: true}), routes: check count("routes", {active: true}),
        trips: check count("trips", {status: "SCHEDULED"}), activeBookings: check count("bookings", {active: true}),
        pendingEvents: check count("outbox", {published: false})};
}
