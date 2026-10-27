public type Product "SINGLE"|"TEN_RIDE"|"MONTHLY";

public isolated function price(int baseFareMinor, Product product) returns int {
    // Time: O(1); pricing uses one of three fixed server-owned multipliers.
    return baseFareMinor * (product == "TEN_RIDE" ? 8 : product == "MONTHLY" ? 20 : 1);
}

public isolated function rideLimit(Product product) returns int {
    return product == "TEN_RIDE" ? 10 : product == "MONTHLY" ? -1 : 1;
}

isolated function requestKey(Document body) returns string|error {
    return required(body, "requestKey", 8, 100);
}

// Idempotency: a matching request key returns its original result; a different payload is rejected.
isolated function previous(Document actor, string key, string fingerprint) returns Document?|error {
    Document[] operations = check find("operations", {userId: actor["id"], requestKey: key}, 1);
    if operations.length() == 0 { return (); }
    if operations[0]["fingerprint"] != fingerprint { return problem(409, "This request key was already used for a different operation."); }
    return operations[0]["response"].cloneWithType();
}

isolated function remember(Document actor, string key, string fingerprint, Document response) returns Document {
    return insert("operations", {id: identifier(), userId: actor["id"], requestKey: key,
        fingerprint, response, createdAt: timestamp()});
}

isolated function availableTrip(string tripId) returns Document|error {
    Document trip = check one("trips", {id: tripId, status: "SCHEDULED"});
    if (check utcSeconds(check text(trip, "departureTime"))) <= now() {
        return problem(409, "This trip has already departed.");
    }
    if (check integer(trip, "reservedSeats")) >= (check integer(trip, "capacity")) {
        return problem(409, "This trip is full.");
    }
    return trip;
}

isolated function bookingAllowed(Document actor, string tripId) returns error? {
    if (check count("bookings", {userId: actor["id"], tripId,
            status: {"$in": ["HELD", "CONFIRMED", "VALIDATED"]}})) > 0 {
        return problem(409, "You already have a booking for this trip.");
    }
    if (check count("bookings", {userId: actor["id"], active: true})) >= 100 {
        return problem(409, "Cancel or complete existing bookings before making more.");
    }
}

isolated function reserveSeat(Document trip, int change) returns Document|error {
    int seats = (check integer(trip, "reservedSeats")) + change;
    if seats < 0 || seats > (check integer(trip, "capacity")) { return problem(409, "The trip inventory changed."); }
    return update("trips", check guard(trip), {reservedSeats: seats, version: (check integer(trip, "version")) + 1});
}

public isolated function checkout(Document actor, Document body) returns Document|error {
    check authorize(actor, ["PASSENGER"]);
    check only(body, ["tripId", "ticketType", "requestKey"]);
    string key = check requestKey(body);
    string tripId = check required(body, "tripId");
    Product|error parsed = (check text(body, "ticketType")).cloneWithType();
    if parsed is error { return problem(400, "ticketType must be SINGLE, TEN_RIDE, or MONTHLY."); }
    Product product = parsed;
    string fingerprint = "checkout|" + tripId + "|" + product;
    Document? prior = check previous(actor, key, fingerprint);
    if prior is Document { return prior; }
    check bookingAllowed(actor, tripId);
    Document trip = check availableTrip(tripId);
    Document route = check one("routes", {id: trip["routeId"], active: true});
    int expiry = product == "SINGLE" ? (check utcSeconds(check text(trip, "arrivalTime"))) + 7200 : now() + 30 * 86400;
    if (check utcSeconds(check text(trip, "departureTime"))) > expiry {
        return problem(409, "Choose a trip within this ticket's 30-day validity.");
    }
    string ticketId = identifier();
    string bookingId = identifier();
    Document ticket = {id: ticketId, userId: actor["id"], routeId: route["id"], originalTripId: tripId,
        ticketType: product, status: "PENDING", amountMinor: price(check integer(route, "baseFareMinor"), product),
        currency: "NAD", totalRides: rideLimit(product), usedRides: 0, reservedRides: 1,
        validUntil: timestamp(expiry), createdAt: timestamp(), version: 1};
    Document booking = {id: bookingId, ticketId, userId: actor["id"], tripId, routeId: route["id"],
        status: "HELD", active: true, holdUntil: now() + 600, createdAt: timestamp(), version: 1};
    Document response = {ticket, booking};
    // ACID: the seat, entitlement, booking, and retry result are committed in one transaction.
    check transact([update("accounts", check guard(actor), {version: (check integer(actor, "version")) + 1}),
        check reserveSeat(trip, 1),
        update("routes", check guard(route), {version: (check integer(route, "version")) + 1}),
        insert("tickets", ticket), insert("bookings", booking), remember(actor, key, fingerprint, response),
        audit(actor, "ticket.checkout", ticketId)]);
    return response;
}

public isolated function pay(Document actor, Document body) returns Document|error {
    check authorize(actor, ["PASSENGER"]);
    check only(body, ["ticketId", "requestKey", "outcome"]);
    string key = check requestKey(body);
    string ticketId = check required(body, "ticketId");
    string outcome = body.hasKey("outcome") ? check text(body, "outcome") : "SUCCESS";
    if outcome != "SUCCESS" && outcome != "FAILED" { return problem(400, "The demo outcome must be SUCCESS or FAILED."); }
    string fingerprint = "pay|" + ticketId + "|" + outcome;
    Document? prior = check previous(actor, key, fingerprint);
    if prior is Document { return prior; }
    Document ticket = check one("tickets", {id: ticketId});
    check owner(actor, ticket);
    if ticket["status"] != "PENDING" { return problem(409, "Only an unpaid ticket can be paid."); }
    Document booking = check one("bookings", {ticketId, status: "HELD"});
    if (check integer(booking, "holdUntil")) <= now() { return problem(409, "The reservation expired. Start a new purchase."); }
    Document trip = check one("trips", {id: booking["tripId"], status: "SCHEDULED"});
    if (check utcSeconds(check text(trip, "departureTime"))) <= now() { return problem(409, "This trip has departed."); }
    string paymentId = identifier();
    Document payment = {id: paymentId, ticketId, userId: actor["id"], amountMinor: ticket["amountMinor"],
        currency: "NAD", status: outcome, simulated: true, createdAt: timestamp(), version: 1};
    Document[] changes = [insert("payments", payment)];
    if outcome == "SUCCESS" {
        changes.push(update("tickets", check guard(ticket), {status: "ACTIVE", paymentId,
            version: (check integer(ticket, "version")) + 1}));
        changes.push(update("bookings", check guard(booking), {status: "CONFIRMED",
            version: (check integer(booking, "version")) + 1}));
        changes.push(update("trips", check guard(trip), {version: (check integer(trip, "version")) + 1}));
        changes.push(event("PAYMENT_SUCCESS", check text(actor, "id"),
            {ticketId, message: "Payment received. Your booking is confirmed."}));
    } else {
        // Optimistic concurrency: even failed attempts must not race a successful ticket transition.
        changes.push(update("tickets", check guard(ticket), {version: (check integer(ticket, "version")) + 1}));
    }
    changes.push(remember(actor, key, fingerprint, payment));
    changes.push(audit(actor, "payment." + outcome.toLowerAscii(), paymentId));
    check transact(changes);
    return payment;
}

public isolated function book(Document actor, Document body) returns Document|error {
    check authorize(actor, ["PASSENGER"]);
    check only(body, ["ticketId", "tripId", "requestKey"]);
    string key = check requestKey(body);
    string ticketId = check required(body, "ticketId");
    string tripId = check required(body, "tripId");
    string fingerprint = "book|" + ticketId + "|" + tripId;
    Document? prior = check previous(actor, key, fingerprint);
    if prior is Document { return prior; }
    Document ticket = check one("tickets", {id: ticketId});
    check owner(actor, ticket);
    Document trip = check availableTrip(tripId);
    if ticket["status"] != "ACTIVE" || ticket["routeId"] != trip["routeId"] ||
            (check utcSeconds(check text(ticket, "validUntil"))) < (check utcSeconds(check text(trip, "departureTime"))) {
        return problem(409, "This ticket is not valid for that trip.");
    }
    if ticket["ticketType"] == "SINGLE" && ticket["originalTripId"] != tripId {
        return problem(409, "A single-trip ticket can only book its original trip.");
    }
    int total = check integer(ticket, "totalRides");
    int reserved = check integer(ticket, "reservedRides");
    if total >= 0 && (check integer(ticket, "usedRides")) + reserved >= total {
        return problem(409, "This ticket has no unreserved rides remaining.");
    }
    check bookingAllowed(actor, tripId);
    Document booking = {id: identifier(), ticketId, tripId, userId: actor["id"], routeId: ticket["routeId"],
        status: "CONFIRMED", active: true, createdAt: timestamp(), version: 1};
    check transact([update("accounts", check guard(actor), {version: (check integer(actor, "version")) + 1}),
        check reserveSeat(trip, 1),
        update("tickets", check guard(ticket), {reservedRides: reserved + 1, version: (check integer(ticket, "version")) + 1}),
        insert("bookings", booking), remember(actor, key, fingerprint, booking),
        audit(actor, "booking.create", check text(booking, "id"))]);
    return booking;
}

public isolated function cancelBooking(Document actor, string id, boolean expired = false) returns Document|error {
    Document booking = check one("bookings", {id});
    if !expired { check owner(actor, booking); }
    if booking["status"] == "CANCELLED" || booking["status"] == "EXPIRED" { return booking; }
    if booking["active"] != true { return problem(409, "A validated booking cannot be cancelled."); }
    Document trip = check one("trips", {id: booking["tripId"]});
    if !expired && (check utcSeconds(check text(trip, "departureTime"))) <= now() {
        return problem(409, "A booking cannot be cancelled after departure.");
    }
    Document ticket = check one("tickets", {id: booking["ticketId"]});
    if expired {
        if booking["status"] == "HELD" {
            if (check integer(booking, "holdUntil")) > now() { return booking; }
        } else if booking["status"] == "CONFIRMED" {
            if (check utcSeconds(check text(trip, "arrivalTime"))) + 7200 >= now() &&
                    (check utcSeconds(check text(ticket, "validUntil"))) >= now() { return booking; }
        } else { return booking; }
    }
    Document fields = {reservedRides: (check integer(ticket, "reservedRides")) - 1,
        version: (check integer(ticket, "version")) + 1};
    if ticket["status"] == "PENDING" { fields["status"] = "EXPIRED"; }
    check transact([check reserveSeat(trip, -1), update("tickets", check guard(ticket), fields),
        update("bookings", check guard(booking), {status: expired ? "EXPIRED" : "CANCELLED", active: false,
            version: (check integer(booking, "version")) + 1}),
        audit(actor, expired ? "booking.expire" : "booking.cancel", id)]);
    return one("bookings", {id});
}

public isolated function validateBooking(Document actor, string id) returns Document|error {
    check authorize(actor, ["ROUTE_OPERATOR", "TRANSPORT_MANAGER", "SUPER_ADMIN"]);
    Document booking = check one("bookings", {id});
    Document trip = check one("trips", {id: booking["tripId"], status: "SCHEDULED"});
    if actor["role"] == "ROUTE_OPERATOR" && trip["operatorId"] != actor["id"] {
        return problem(403, "This trip is assigned to another operator.");
    }
    if booking["status"] == "VALIDATED" { return booking; }
    int departure = check utcSeconds(check text(trip, "departureTime"));
    int arrival = check utcSeconds(check text(trip, "arrivalTime"));
    if now() < departure - 1800 || now() > arrival + 7200 {
        return problem(409, "Validation opens 30 minutes before departure and closes two hours after arrival.");
    }
    Document ticket = check one("tickets", {id: booking["ticketId"]});
    if booking["status"] != "CONFIRMED" || ticket["status"] != "ACTIVE" ||
            (check utcSeconds(check text(ticket, "validUntil"))) < now() {
        return problem(409, "This booking is not valid for travel.");
    }
    // ACID: consume exactly one reserved ride and validate the booking in the same transaction.
    check transact([update("bookings", check guard(booking), {status: "VALIDATED", active: false,
        validatedAt: timestamp(), validatedBy: actor["id"], version: (check integer(booking, "version")) + 1}),
        update("tickets", check guard(ticket), {usedRides: (check integer(ticket, "usedRides")) + 1,
            reservedRides: (check integer(ticket, "reservedRides")) - 1, version: (check integer(ticket, "version")) + 1}),
        update("trips", check guard(trip), {version: (check integer(trip, "version")) + 1}),
        audit(actor, "booking.validate", id)]);
    return one("bookings", {id});
}

public isolated function refund(Document actor, Document body) returns Document|error {
    check authorize(actor, ["PASSENGER"]);
    check only(body, ["ticketId", "requestKey"]);
    string key = check requestKey(body);
    string ticketId = check required(body, "ticketId");
    string fingerprint = "refund|" + ticketId;
    Document? prior = check previous(actor, key, fingerprint);
    if prior is Document { return prior; }
    Document ticket = check one("tickets", {id: ticketId});
    check owner(actor, ticket);
    if ticket["status"] != "ACTIVE" || (check integer(ticket, "usedRides")) != 0 {
        return problem(409, "Only an unused paid ticket can be refunded, once.");
    }
    Document payment = check one("payments", {id: ticket["paymentId"], status: "SUCCESS"});
    Document[] bookings = check find("bookings", {ticketId, active: true}, 100);
    Document[] changes = [];
    // Time: O(b log T) indexed trip lookups for b bookings and T trips; b is capped at 100.
    foreach Document booking in bookings {
        Document trip = check one("trips", {id: booking["tripId"]});
        changes.push(check reserveSeat(trip, -1));
        changes.push(update("bookings", check guard(booking), {status: "CANCELLED", active: false,
            version: (check integer(booking, "version")) + 1}));
    }
    changes.push(update("tickets", check guard(ticket), {status: "REFUNDED", reservedRides: 0,
        version: (check integer(ticket, "version")) + 1}));
    changes.push(update("payments", check guard(payment), {status: "REFUNDED", refundedAt: timestamp(),
        version: (check integer(payment, "version")) + 1}));
    Document response = {id: payment["id"], ticketId, status: "REFUNDED", amountMinor: payment["amountMinor"], currency: "NAD"};
    changes.push(remember(actor, key, fingerprint, response));
    changes.push(event("REFUND", check text(actor, "id"), {ticketId, message: "Your unused ticket has been refunded."}));
    changes.push(audit(actor, "ticket.refund", ticketId));
    check transact(changes);
    return response;
}

public isolated function expireHolds() returns error? {
    Document[] bookings = check find("bookings", {status: "HELD", holdUntil: {"$lte": now()}}, 100);
    foreach Document booking in bookings {
        _ = check cancelBooking({id: "system", role: "SUPER_ADMIN"}, check text(booking, "id"), true);
    }
    // Inner joins: current trip/ticket dates avoid stale duplicated deadlines; O(c(log T + log K)) lookups for c candidates.
    Document[] overdue = check aggregate("bookings", [{"$match": {status: "CONFIRMED", active: true}},
        {"$lookup": {"from": "trips", localField: "tripId", foreignField: "id", 'as: "trip"}},
        {"$unwind": "$trip"},
        {"$lookup": {"from": "tickets", localField: "ticketId", foreignField: "id", 'as: "ticket"}},
        {"$unwind": "$ticket"},
        {"$match": {"$or": [{"trip.arrivalTime": {"$lt": timestamp(now() - 7200)}},
            {"ticket.validUntil": {"$lt": timestamp()}}]}}, {"$limit": 100}, {"$project": {_id: 0, id: 1}}]);
    foreach Document booking in overdue {
        _ = check cancelBooking({id: "system", role: "SUPER_ADMIN"}, check text(booking, "id"), true);
    }
}

public isolated function cancelTrip(Document actor, string id) returns Document|error {
    check authorize(actor, ["TRANSPORT_MANAGER", "SUPER_ADMIN"]);
    Document trip = check one("trips", {id});
    if trip["status"] == "CANCELLED" { return trip; }
    Document[] bookings = check find("bookings", {tripId: id, active: true}, 200);
    Document[] changes = [];
    foreach Document booking in bookings {
        Document ticket = check one("tickets", {id: booking["ticketId"]});
        Document fields = {reservedRides: (check integer(ticket, "reservedRides")) - 1,
            version: (check integer(ticket, "version")) + 1};
        if ticket["status"] == "PENDING" { fields["status"] = "EXPIRED"; }
        changes.push(update("tickets", check guard(ticket), fields));
        changes.push(update("bookings", check guard(booking), {status: "CANCELLED", active: false,
            version: (check integer(booking, "version")) + 1}));
        changes.push(event("TRIP_CANCELLED", check text(booking, "userId"),
            {tripId: id, routeId: trip["routeId"], message: "Your trip was cancelled. You can refund an unused paid ticket."}));
    }
    changes.push(update("trips", check guard(trip), {status: "CANCELLED",
        reservedSeats: (check integer(trip, "reservedSeats")) - bookings.length(), version: (check integer(trip, "version")) + 1}));
    changes.push(audit(actor, "trip.cancel", id));
    check transact(changes);
    return one("trips", {id});
}
