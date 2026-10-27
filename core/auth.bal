import ballerina/crypto;
import ballerina/jballerina.java;

public type Role "PASSENGER"|"ROUTE_OPERATOR"|"TRANSPORT_MANAGER"|"SUPER_ADMIN";
configurable string bootstrapEmail = "";
configurable string bootstrapPassword = "";

public isolated function emailAddress(Document body) returns string|error {
    string email = (check required(body, "email", 3, 254)).toLowerAscii();
    int? separator = email.indexOf("@");
    if separator is () { return problem(400, "Enter a valid email address."); }
    string domain = email.substring(separator + 1);
    if separator == 0 || domain.includes("@") || !domain.includes(".") ||
            domain.startsWith(".") || domain.endsWith(".") || email.includes("..") {
        return problem(400, "Enter a valid email address.");
    }
    foreach string whitespace in [" ", "\t", "\n", "\r"] {
        if email.includes(whitespace) { return problem(400, "Enter a valid email address."); }
    }
    return email;
}

public isolated function passwordHash(Document body) returns string|error {
    string password = check text(body, "password");
    if password.length() < 12 || password.length() > 128 {
        return problem(400, "Use a password containing 12–128 characters.");
    }
    // Password hashing: Argon2id deliberately uses memory and CPU to slow password guessing.
    return crypto:hashArgon2(password);
}

public isolated function publicAccount(Document account) returns Document {
    Document safe = account.clone();
    _ = safe.removeIfHasKey("passwordHash");
    _ = safe.removeIfHasKey("authVersion");
    _ = safe.removeIfHasKey("sessionId");
    return safe;
}

public isolated function register(Document body, Role role = "PASSENGER", Document? actor = ()) returns Document|error {
    check only(body, ["email", "password", "firstName", "lastName", "phone", "role"]);
    if role == "PASSENGER" && body.hasKey("role") { return problem(400, "Registration cannot assign a role."); }
    Document account = {
        id: identifier(), email: check emailAddress(body), passwordHash: check passwordHash(body),
        firstName: check required(body, "firstName", 1, 80), lastName: check required(body, "lastName", 1, 80),
        phone: check required(body, "phone", 3, 30), role, active: true, authVersion: 1, version: 1,
        createdAt: timestamp()
    };
    Document[] changes = [insert("accounts", account)];
    if actor is Document { changes.push(audit(actor, "account.create", check text(account, "id"))); }
    check transact(changes);
    return publicAccount(account);
}

public isolated function login(Document body, boolean staffOnly = false) returns Document|error {
    check only(body, ["email", "password"]);
    string email = check emailAddress(body);
    string password = check text(body, "password");
    if password.length() < 1 || password.length() > 128 { return problem(400, "Invalid password length."); }
    string bucketId = sha256(email);
    Document[] buckets = check find("login_limits", {id: bucketId}, 1);
    int failures = 0;
    int windowStart = now();
    if buckets.length() > 0 && (check integer(buckets[0], "windowStart")) > now() - 900 {
        failures = check integer(buckets[0], "failures");
        windowStart = check integer(buckets[0], "windowStart");
    }
    if failures >= 10 { return problem(429, "Too many login attempts. Try again in 15 minutes."); }
    // Atomic rate-limit increment: concurrent guesses cannot all pass a stale counter.
    Document[] limitChanges = [];
    if buckets.length() == 0 {
        limitChanges.push(insert("login_limits", {id: bucketId, failures: 1, windowStart, version: 1}));
    } else {
        limitChanges.push(update("login_limits", check guard(buckets[0]),
            {failures: failures + 1, windowStart, version: (check integer(buckets[0], "version")) + 1}));
    }
    check transact(limitChanges);
    Document[] users = check find("accounts", {email, active: true}, 1);
    // Constant-work failure: unknown accounts also perform an expensive Argon2 operation.
    boolean valid = false;
    if users.length() == 1 {
        valid = check crypto:verifyArgon2(password, check text(users[0], "passwordHash"));
    } else {
        _ = check crypto:hashArgon2(password);
    }
    if !valid || (staffOnly && users[0]["role"] == "PASSENGER") {
        return problem(401, "Email or password is incorrect.");
    }
    Document account = users[0];
    Document currentLimit = check one("login_limits", {id: bucketId});
    check transact([update("login_limits", check guard(currentLimit), {failures: 0,
        windowStart: now(), version: (check integer(currentLimit, "version")) + 1})]);
    string token = java:toString(secureRandomToken()) ?: "";
    Document session = {id: identifier(), tokenHash: sha256(token), userId: account["id"],
        authVersion: account["authVersion"], createdAt: now(), lastSeen: now()};
    check transact([insert("sessions", session), audit(account, "session.login", check text(account, "id"))]);
    return {token, user: publicAccount(account), idleTimeoutSeconds: 1800, absoluteTimeoutSeconds: 28800};
}

// Authentication: a live server session and current account state are checked on every request.
public isolated function authenticate(string authorization) returns Document|error {
    if !authorization.startsWith("Bearer ") || authorization.length() != 71 {
        return problem(401, "Sign in to continue.");
    }
    Document[] sessions = check find("sessions", {tokenHash: sha256(authorization.substring(7))}, 1);
    if sessions.length() != 1 { return problem(401, "Your session has ended. Sign in again."); }
    Document session = sessions[0];
    if (check integer(session, "lastSeen")) < now() - 1800 || (check integer(session, "createdAt")) < now() - 28800 {
        return problem(401, "Your session has expired. Sign in again.");
    }
    Document[] accounts = check find("accounts", {id: session["userId"], active: true,
        authVersion: session["authVersion"]}, 1);
    if accounts.length() != 1 { return problem(401, "Your session has ended. Sign in again."); }
    check transact([update("sessions", {id: session["id"]}, {lastSeen: now()})]);
    Document actor = accounts[0];
    actor["sessionId"] = session["id"];
    return actor;
}

// Authorization: unknown roles are denied; UI visibility never substitutes for this check.
public isolated function authorize(Document actor, string[] roles) returns error? {
    string role = check text(actor, "role");
    if roles.indexOf(role) is () { return problem(403, "Your account cannot perform this action."); }
}

public isolated function owner(Document actor, Document document) returns error? {
    if document["userId"] != actor["id"] { return problem(403, "This record belongs to another passenger."); }
}

public isolated function logout(Document actor) returns Document|error {
    check transact([remove("sessions", {id: actor["sessionId"]}), audit(actor, "session.logout", check text(actor, "id"))]);
    return {success: true};
}

public isolated function changeProfile(Document actor, Document body) returns Document|error {
    check only(body, ["firstName", "lastName", "phone"]);
    Document fields = {version: (check integer(actor, "version")) + 1};
    foreach string fieldName in body.keys() { fields[fieldName] = check required(body, fieldName, 1, fieldName == "phone" ? 30 : 80); }
    check transact([update("accounts", check guard(actor), fields), audit(actor, "account.profile", check text(actor, "id"))]);
    return publicAccount(check one("accounts", {id: actor["id"]}));
}

public isolated function changeAccount(Document actor, string id, Document body) returns Document|error {
    check authorize(actor, ["SUPER_ADMIN"]);
    check only(body, ["role", "active"]);
    Document account = check one("accounts", {id});
    if id == actor["id"] { return problem(409, "You cannot change your own administrative access."); }
    Document fields = {authVersion: (check integer(account, "authVersion")) + 1,
        version: (check integer(account, "version")) + 1};
    if body.hasKey("role") {
        Role|error checkedRole = (check text(body, "role")).cloneWithType();
        if checkedRole is error { return problem(400, "Choose a valid account role."); }
        Role role = checkedRole;
        fields["role"] = role;
    }
    if body.hasKey("active") {
        json active = body["active"];
        if active !is boolean { return problem(400, "active must be a boolean."); }
        fields["active"] = active;
    }
    // Revocation: changing role or account activity invalidates every earlier session immediately.
    check transact([update("accounts", check guard(account), fields), audit(actor, "account.access", id)]);
    return publicAccount(check one("accounts", {id}));
}

public isolated function deactivateSelf(Document actor) returns Document|error {
    if actor["role"] != "PASSENGER" { return problem(403, "Ask another administrator to deactivate a staff account."); }
    if (check count("bookings", {userId: actor["id"], active: true})) > 0 {
        return problem(409, "Cancel or complete your bookings before deleting your account.");
    }
    check transact([update("accounts", check guard(actor), {active: false,
        authVersion: (check integer(actor, "authVersion")) + 1,
        version: (check integer(actor, "version")) + 1,
        email: identifier() + "@deleted.invalid", firstName: "Deleted", lastName: "Passenger", phone: ""}),
        audit(actor, "account.deactivate", check text(actor, "id"))]);
    return {success: true};
}

public isolated function bootstrapAdmin() returns error? {
    if bootstrapEmail == "" && bootstrapPassword == "" { return; }
    if (check count("accounts", {role: "SUPER_ADMIN"})) > 0 { return; }
    _ = check register({email: bootstrapEmail, password: bootstrapPassword,
        firstName: "Demo", lastName: "Administrator", phone: "+264000000000", role: "SUPER_ADMIN"}, "SUPER_ADMIN");
}
