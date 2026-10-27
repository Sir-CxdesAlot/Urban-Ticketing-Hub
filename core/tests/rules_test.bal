import ballerina/crypto;
import ballerina/test;

@test:Config {}
function testPricesUseMinorUnits() {
    test:assertEquals(price(1250, "SINGLE"), 1250);
    test:assertEquals(price(1250, "TEN_RIDE"), 10000);
    test:assertEquals(price(1250, "MONTHLY"), 25000);
}

@test:Config {}
function testRideEntitlements() {
    test:assertEquals(rideLimit("SINGLE"), 1);
    test:assertEquals(rideLimit("TEN_RIDE"), 10);
    test:assertEquals(rideLimit("MONTHLY"), -1);
}

@test:Config {}
function testRejectsServerOwnedFields() {
    test:assertTrue(only({tripId: "trip", amountMinor: 1}, ["tripId", "ticketType", "requestKey"]) is error);
    test:assertTrue(only({role: "SUPER_ADMIN"}, ["email", "password"]) is error);
}

@test:Config {}
function testUnknownRolesAreDenied() {
    test:assertTrue(authorize({role: "OPERATOR"}, ["ROUTE_OPERATOR"]) is error);
    test:assertTrue(authorize({role: "PASSENGER"}, ["SUPER_ADMIN"]) is error);
    test:assertEquals(authorize({role: "ROUTE_OPERATOR"}, ["ROUTE_OPERATOR"]), ());
}

@test:Config {}
function testRecordOwnership() {
    test:assertTrue(owner({id: "a"}, {userId: "b"}) is error);
    test:assertEquals(owner({id: "a"}, {userId: "a"}), ());
}

@test:Config {}
function testTimestampNormalization() returns error? {
    int local = check utcSeconds("2026-10-27T12:00:00+02:00");
    int utc = check utcSeconds("2026-10-27T10:00:00Z");
    test:assertEquals(local, utc);
    test:assertTrue(utcSeconds("Updated: 12:00") is error);
}

@test:Config {}
function testPasswordHashing() returns error? {
    string first = check passwordHash({password: "A long demo password!"});
    string second = check passwordHash({password: "A long demo password!"});
    test:assertNotEquals(first, second);
    test:assertTrue(first.startsWith("$argon2id$"));
    test:assertTrue(check crypto:verifyArgon2("A long demo password!", first));
    test:assertFalse(check crypto:verifyArgon2("Incorrect password", first));
    test:assertTrue(passwordHash({password: "short"}) is error);
}

@test:Config {}
function testPublicAccountHidesSecrets() {
    Document result = publicAccount({id: "a", passwordHash: "secret", sessionId: "secret", authVersion: 1});
    test:assertFalse(result.hasKey("passwordHash"));
    test:assertFalse(result.hasKey("sessionId"));
    test:assertFalse(result.hasKey("authVersion"));
    test:assertEquals(publicAccount({id: "a"}), {id: "a"});
}

@test:Config {}
function testMissingFieldsReturnValidationErrors() {
    test:assertTrue(text({}, "email") is error);
    test:assertTrue(integer({}, "capacity") is error);
    test:assertEquals(errorStatus(error("Unexpected failure")), 500);
    test:assertEquals(errorStatus(problem(400, "Invalid request")), 400);
}

@test:Config {}
function testEmailValidation() returns error? {
    test:assertEquals(check emailAddress({email: " Passenger@Example.Test "}), "passenger@example.test");
    foreach string value in ["@example.test", "a@@example.test", "a@example.", "a\n@example.test", "a@example..test"] {
        test:assertTrue(emailAddress({email: value}) is error);
    }
}
