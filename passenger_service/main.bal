import ballerina/http;
import ballerina/log;
import ballerina/jwt;
import ballerina/crypto;
import ballerina/time;
import ballerina/uuid;
import ballerinax/mongodb;

// MongoDB client configuration
// TEMPORARY FIX: Hardcode values to test configuration loading
configurable string mongoHost = "mongodb";
configurable int mongoPort = 27017;
configurable string databaseName = "ticketing_platform";

mongodb:Client mongoDb = check new ({
    connection: {
        serverAddress: {
            host: "mongodb", // Hardcode the Docker service name
            port: 27017
        }
    }
});

// JWT configuration using HMAC (symmetric key) - simpler for demo/test
final string jwtSecretKey = "windhoek-ticketing-secret-key-for-passenger-service-2024";

jwt:IssuerConfig issuerConfig = {
    username: "passenger_service",
    issuer: "windhoek-ticketing",
    audience: "passengers",
    keyId: "passenger-key",
    customClaims: {"scp": "passenger"},
    expTime: 3600,
    signatureConfig: {
        algorithm: jwt:HS256,
        config: jwtSecretKey
    }
};

jwt:ValidatorConfig validatorConfig = {
    issuer: "windhoek-ticketing",
    audience: "passengers",
    signatureConfig: {
        secret: jwtSecretKey
    }
};

// Helper function to extract and validate JWT token from authorization header
function extractToken(string authorization) returns string|http:Unauthorized {
    if !authorization.startsWith("Bearer ") || authorization.length() <= 7 {
        return <http:Unauthorized>{
            body: {message: "Invalid authorization header"}
        };
    }
    return authorization.substring(7);
}

// Data types
public type User record {|
    string id?;
    string email;
    string password;
    string firstName;
    string lastName;
    string phone;
    time:Utc createdAt;
    time:Utc updatedAt?;
|};

// MongoDB-compatible User type (open record to allow _id and other fields)
public type UserDb record {
    string id;
    string email;
    string password;
    string firstName;
    string lastName;
    string phone;
    // createdAt and updatedAt are omitted - they're time:Utc in DB which doesn't match string type
};

public type UserRegistration record {|
    string email;
    string password;
    string firstName;
    string lastName;
    string phone;
|};

public type LoginRequest record {|
    string email;
    string password;
|};

public type UserUpdate record {|
    string? email?;
    string? firstName?;
    string? lastName?;
    string? phone?;
|};

public type TicketPurchase record {|
    string routeId;
    string ticketType; // SINGLE, MULTIPLE, PASS
    int quantity?;
|};

public type TicketUpdate record {|
    string? status?;
    int? quantity?;
|};

public type UserResponse record {|
    string id;
    string email;
    string firstName;
    string lastName;
    string phone;
|};

public type Ticket record {|
    string id?;
    string userId;
    string routeId;
    string ticketType; // SINGLE, MULTIPLE, PASS
    string status; // CREATED, PAID, VALIDATED, EXPIRED
    decimal price;
    int quantity?;
    string purchaseDate;
    string validFrom?;
    string validUntil?;
    string validatedAt?;
|};

// Service configuration
listener http:Listener httpListener = new(8080);

@http:ServiceConfig {
    cors: {
        allowOrigins: ["*"],
        allowCredentials: false,
        allowHeaders: ["*"],
        allowMethods: ["GET", "POST", "PUT", "DELETE", "OPTIONS"]
    }
}
service /api/v1/passenger on httpListener {
    
    // Register new passenger
    resource function post register(@http:Payload UserRegistration userData) returns UserResponse|http:BadRequest|http:InternalServerError {
        do {
            log:printInfo("Registration endpoint reached");
            log:printInfo("Registration attempt for email: " + userData.email);
            log:printInfo("Phone: " + userData.phone);
            log:printInfo("First name: " + userData.firstName);
            log:printInfo("Last name: " + userData.lastName);
            
            // Validate input data
            if userData.email.trim().length() == 0 || userData.password.trim().length() == 0 || 
               userData.firstName.trim().length() == 0 || userData.lastName.trim().length() == 0 ||
               userData.phone.trim().length() == 0 {
                return <http:BadRequest>{
                    body: {message: "All fields are required"}
                };
            }
            
            // Hash password
            string hashedPassword = crypto:hashSha256(userData.password.toBytes()).toBase16();
            
            string userId = uuid:createType4AsString();
            log:printInfo("Generated user ID: " + userId);
            User newUser = {
                id: userId,
                email: userData.email,
                password: hashedPassword,
                firstName: userData.firstName,
                lastName: userData.lastName,
                phone: userData.phone,
                createdAt: time:utcNow(),
                updatedAt: time:utcNow()
            };
            log:printInfo("Created user object for: " + newUser.email);
            
            // Check if user already exists
            mongodb:Database database = check mongoDb->getDatabase(databaseName);
            mongodb:Collection collection = check database->getCollection("users");
            
            log:printInfo("Checking for existing user with email: " + userData.email);
            
            // Try using count operation instead of findOne to check existence
            int userCount = check collection->countDocuments({"email": userData.email});
            log:printInfo("Found " + userCount.toString() + " users with email: " + userData.email);
            
            if userCount > 0 {
                return <http:BadRequest>{
                    body: {message: "User with this email already exists"}
                };
            }
            
            // Insert new user as map to avoid field mapping issues
            map<json> userDoc = {
                "id": newUser.id,
                "email": newUser.email,
                "password": newUser.password,
                "firstName": newUser.firstName,
                "lastName": newUser.lastName,
                "phone": newUser.phone,
                "createdAt": newUser.createdAt,
                "updatedAt": newUser.updatedAt
            };
            _ = check collection->insertOne(userDoc);
            
            UserResponse response = {
                id: userId,
                email: newUser.email,
                firstName: newUser.firstName,
                lastName: newUser.lastName,
                phone: newUser.phone
            };
            
            log:printInfo("New passenger registered: " + userData.email);
            return response;
            
        } on fail error e {
            log:printError("Error registering passenger: " + e.message());
            return <http:InternalServerError>{
                body: {message: "Registration failed"}
            };
        }
    }
    
    // Login passenger
    resource function post login(@http:Payload LoginRequest loginData) returns record {|string token; UserResponse user;|}|http:Unauthorized|http:InternalServerError {
        do {
            // Hash password for comparison
            string hashedPassword = crypto:hashSha256(loginData.password.toBytes()).toBase16();
            
            // Find user using alternative approach to avoid findOne issues
            mongodb:Database database = check mongoDb->getDatabase(databaseName);
            mongodb:Collection collection = check database->getCollection("users");
            
            log:printInfo("Attempting login for email: " + loginData.email);
            log:printInfo("Hashed password: " + hashedPassword);
            
            // Use aggregation pipeline to avoid potential server-side projection issues
            map<json> matchStage = {"$match": {"email": loginData.email, "password": hashedPassword}};
            map<json> projectStage = {"$project": {"id": 1, "email": 1, "firstName": 1, "lastName": 1, "phone": 1, "createdAt": 1, "password": 1}};
            map<json> limitStage = {"$limit": 1};
            map<json>[] pipeline = [matchStage, projectStage, limitStage];
            stream<map<json>, error?> userStream = check collection->aggregate(pipeline);
            map<json>[] users = check from map<json> u in userStream select u;
            check userStream.close();
            if users.length() == 0 {
                return <http:Unauthorized>{
                    body: {message: "Invalid credentials"}
                };
            }
            map<json> user = users[0];
            
            // Generate JWT token (simplified approach)
            map<json> userClaims = {
                "scp": "passenger",
                "sub": user["id"].toString(),
                "email": user["email"],
                "role": "passenger"
            };
            
            jwt:IssuerConfig userIssuerConfig = {
                username: issuerConfig.username,
                issuer: issuerConfig.issuer,
                audience: issuerConfig.audience,
                keyId: issuerConfig.keyId,
                expTime: issuerConfig.expTime,
                signatureConfig: issuerConfig.signatureConfig,
                customClaims: userClaims
            };
            
            string token = check jwt:issue(userIssuerConfig);
            
            UserResponse userResponse = {
                id: user["id"].toString(),
                email: user["email"].toString(),
                firstName: user["firstName"].toString(),
                lastName: user["lastName"].toString(),
                phone: user["phone"].toString()
            };
            
            log:printInfo("Passenger logged in: " + user["email"].toString());
            return {token: token, user: userResponse};
            
        } on fail error e {
            log:printError("Error during login: " + e.message());
            return <http:InternalServerError>{
                body: {message: "Login failed"}
            };
        }
    }
    
    // Get user profile (protected)
    resource function get profile(http:RequestContext ctx, @http:Header string authorization) returns UserResponse|http:Unauthorized|http:InternalServerError {
        do {
            // Extract and validate JWT token
            string|http:Unauthorized tokenResult = extractToken(authorization);
            if tokenResult is http:Unauthorized {
                return tokenResult;
            }
            string token = <string>tokenResult;

            jwt:Payload|jwt:Error payload = jwt:validate(token, validatorConfig);
            
            if payload is jwt:Error {
                return <http:Unauthorized>{
                    body: {message: "Invalid token"}
                };
            }
            
            jwt:Payload jwtPayload = <jwt:Payload>payload;
            string? userId = jwtPayload.sub;
            
            if userId is string {
                // Get user details using typed stream
                mongodb:Database database = check mongoDb->getDatabase(databaseName);
                mongodb:Collection collection = check database->getCollection("users");
                
                map<json> filter = {"id": userId};
                stream<UserDb, error?> userStream = check collection->find(filter);
                UserDb[] userArray = check from UserDb user in userStream select user;
                
                if userArray.length() > 0 {
                    UserDb user = userArray[0];
                    UserResponse response = {
                        id: user.id,
                        email: user.email,
                        firstName: user.firstName,
                        lastName: user.lastName,
                        phone: user.phone
                    };
                    return response;
                }
            }
            
            return <http:Unauthorized>{
                body: {message: "User not found"}
            };
            
        } on fail error e {
            log:printError("Error getting profile: " + e.message());
            return <http:InternalServerError>{
                body: {message: "Profile retrieval failed"}
            };
        }
    }
    
    // Get user's tickets
    // NOTE: Return raw JSON documents instead of attempting a typed conversion to avoid
    // conversion errors when DB documents contain nulls or numeric formats that don't
    // round-trip cleanly into the `Ticket` ballerina type. The CLI and test scripts
    // expect JSON, so returning json[] is acceptable and more robust.
    resource function get tickets(http:RequestContext ctx, @http:Header string authorization) returns json[]|http:Unauthorized|http:InternalServerError {
        do {
            // Extract and validate JWT token
            string|http:Unauthorized tokenResult = extractToken(authorization);
            if tokenResult is http:Unauthorized {
                return tokenResult;
            }
            string token = <string>tokenResult;

            jwt:Payload|jwt:Error payload = jwt:validate(token, validatorConfig);

            if payload is jwt:Error {
                return <http:Unauthorized>{
                    body: {message: "Invalid token"}
                };
            }

            jwt:Payload jwtPayload = <jwt:Payload>payload;
            string? userId = jwtPayload.sub;

            if userId is string {
                // Get user's tickets as raw JSON documents to avoid typed conversion issues
                mongodb:Database database = check mongoDb->getDatabase(databaseName);
                mongodb:Collection collection = check database->getCollection("tickets");

                map<json> matchStage = {"$match": {"userId": userId}};
                // Explicit $project to include only known fields and avoid empty-field errors
                map<json> projectStage = {"$project": {"_id": 0, "id": 1, "userId": 1, "routeId": 1, "ticketType": 1, "status": 1, "price": 1, "quantity": 1, "purchaseDate": 1, "validFrom": 1, "validUntil": 1, "validatedAt": 1}};
                map<json>[] pipeline = [matchStage, projectStage];
                log:printInfo("Querying tickets with aggregation pipeline (with explicit $project) for user: " + userId);
                stream<map<json>, error?> ticketsStream = check collection->aggregate(pipeline);
                map<json>[] ticketDocs = check from map<json> t in ticketsStream select t;
                check ticketsStream.close();

                log:printInfo("Retrieved " + ticketDocs.length().toString() + " ticket(s) for user: " + userId);
                return ticketDocs;
            }

            return <http:Unauthorized>{
                body: {message: "Invalid user"}
            };

        } on fail error e {
            log:printError("Error getting tickets: " + e.message());
            return <http:InternalServerError>{
                body: {message: "Ticket retrieval failed"}
            };
        }
    }

    /// Updates the authenticated user's profile information.
    ///
    /// + ctx - HTTP request context
    /// + authorization - JWT authorization header (Bearer token)
    /// + updateData - The fields to update for the user profile
    /// + return - Updated user response or error
    resource function put profile(http:RequestContext ctx, @http:Header string authorization, @http:Payload UserUpdate updateData) returns UserResponse|http:Unauthorized|http:BadRequest|http:InternalServerError {
        do {
            // Extract and validate JWT token
            string|http:Unauthorized tokenResult = extractToken(authorization);
            if tokenResult is http:Unauthorized {
                return tokenResult;
            }
            string token = <string>tokenResult;

            jwt:Payload|jwt:Error payload = jwt:validate(token, validatorConfig);

            if payload is jwt:Error {
                return <http:Unauthorized>{
                    body: {message: "Invalid token"}
                };
            }

            jwt:Payload jwtPayload = <jwt:Payload>payload;
            string? userId = jwtPayload.sub;

            if userId is string {
                // Validate update data
                if updateData?.email is string && (<string>updateData?.email).trim().length() == 0 {
                    return <http:BadRequest>{
                        body: {message: "Email cannot be empty"}
                    };
                }
                if updateData?.firstName is string && (<string>updateData?.firstName).trim().length() == 0 {
                    return <http:BadRequest>{
                        body: {message: "First name cannot be empty"}
                    };
                }
                if updateData?.lastName is string && (<string>updateData?.lastName).trim().length() == 0 {
                    return <http:BadRequest>{
                        body: {message: "Last name cannot be empty"}
                    };
                }
                if updateData?.phone is string && (<string>updateData?.phone).trim().length() == 0 {
                    return <http:BadRequest>{
                        body: {message: "Phone cannot be empty"}
                    };
                }

                // Check if email is already taken by another user
                if updateData?.email is string {
                    mongodb:Database database = check mongoDb->getDatabase(databaseName);
                    mongodb:Collection collection = check database->getCollection("users");

                    map<json> emailFilter = {"email": updateData?.email, "id": {"$ne": userId}};
                    int emailCount = check collection->countDocuments(emailFilter);

                    if emailCount > 0 {
                        return <http:BadRequest>{
                            body: {message: "Email is already taken by another user"}
                        };
                    }
                }

                // Build update document from the provided updateData
                map<json> updateFields = {};
                
                if updateData?.email is string {
                    updateFields["email"] = updateData?.email;
                }
                if updateData?.firstName is string {
                    updateFields["firstName"] = updateData?.firstName;
                }
                if updateData?.lastName is string {
                    updateFields["lastName"] = updateData?.lastName;
                }
                if updateData?.phone is string {
                    updateFields["phone"] = updateData?.phone;
                }
                
                // Add updatedAt timestamp as string (MongoDB compatible)
                updateFields["updatedAt"] = time:utcToString(time:utcNow());

                // Only proceed if there are fields to update
                if updateFields.length() == 0 {
                    return <http:BadRequest>{
                        body: {message: "No valid fields provided for update"}
                    };
                }

                // Update user profile using updateOne with set operator
                mongodb:Database database = check mongoDb->getDatabase(databaseName);
                mongodb:Collection collection = check database->getCollection("users");

                map<json> filter = {"id": userId};
                
                // Use set operator without $ prefix
                mongodb:Update update = {"set": updateFields};
                mongodb:UpdateResult result = check collection->updateOne(filter, update);

                if result.matchedCount == 0 {
                    return <http:Unauthorized>{
                        body: {message: "User not found"}
                    };
                }

                // Get updated user data
                stream<UserDb, error?> userStream = check collection->find(filter);
                UserDb[] userArray = check from UserDb user in userStream select user;

                if userArray.length() > 0 {
                    UserDb user = userArray[0];
                    UserResponse response = {
                        id: user.id,
                        email: user.email,
                        firstName: user.firstName,
                        lastName: user.lastName,
                        phone: user.phone
                    };

                    log:printInfo("User profile updated: " + userId);
                    return response;
                }

                return <http:InternalServerError>{
                    body: {message: "Failed to retrieve updated profile"}
                };
            }

            return <http:Unauthorized>{
                body: {message: "Invalid user"}
            };

        } on fail error e {
            log:printError("Error updating profile: " + e.message());
            return <http:InternalServerError>{
                body: {message: "Profile update failed: " + e.message()}
            };
        }
    }

    /// Deletes the authenticated user's account.
    ///
    /// + ctx - HTTP request context
    /// + authorization - JWT authorization header (Bearer token)
    /// + return - Success message or error
    resource function delete profile(http:RequestContext ctx, @http:Header string authorization) returns json|http:Unauthorized|http:InternalServerError {
        do {
            // Extract and validate JWT token
            string|http:Unauthorized tokenResult = extractToken(authorization);
            if tokenResult is http:Unauthorized {
                return tokenResult;
            }
            string token = <string>tokenResult;

            jwt:Payload|jwt:Error payload = jwt:validate(token, validatorConfig);

            if payload is jwt:Error {
                return <http:Unauthorized>{
                    body: {message: "Invalid token"}
                };
            }

            jwt:Payload jwtPayload = <jwt:Payload>payload;
            string? userId = jwtPayload.sub;

            if userId is string {
                mongodb:Database database = check mongoDb->getDatabase(databaseName);
                mongodb:Collection collection = check database->getCollection("users");

                map<json> filter = {"id": userId};
                mongodb:DeleteResult result = check collection->deleteOne(filter);

                if result.deletedCount == 0 {
                    return <http:Unauthorized>{
                        body: {message: "User not found"}
                    };
                }

                log:printInfo("User account deleted: " + userId);
                return {"success": true, "message": "Account deleted successfully"};
            }

            return <http:Unauthorized>{
                body: {message: "Invalid user"}
            };

        } on fail error e {
            log:printError("Error deleting account: " + e.message());
            return <http:InternalServerError>{
                body: {message: "Account deletion failed"}
            };
        }
    }

    /// Purchases a new ticket for the authenticated user.
    ///
    /// + ctx - HTTP request context
    /// + authorization - JWT authorization header (Bearer token)
    /// + ticketData - The ticket purchase details
    /// + return - Created ticket or error
    resource function post tickets(http:RequestContext ctx, @http:Header string authorization, @http:Payload TicketPurchase ticketData) returns Ticket|http:Unauthorized|http:BadRequest|http:InternalServerError {
        do {
            // Extract and validate JWT token
            string|http:Unauthorized tokenResult = extractToken(authorization);
            if tokenResult is http:Unauthorized {
                return tokenResult;
            }
            string token = <string>tokenResult;

            jwt:Payload|jwt:Error payload = jwt:validate(token, validatorConfig);

            if payload is jwt:Error {
                return <http:Unauthorized>{
                    body: {message: "Invalid token"}
                };
            }

            jwt:Payload jwtPayload = <jwt:Payload>payload;
            string? userId = jwtPayload.sub;

            if userId is string {
                // Validate ticket data
                if ticketData.ticketType != "SINGLE" && ticketData.ticketType != "MULTIPLE" && ticketData.ticketType != "PASS" {
                    return <http:BadRequest>{
                        body: {message: "Invalid ticket type. Must be SINGLE, MULTIPLE, or PASS"}
                    };
                }

                if ticketData.ticketType == "MULTIPLE" && (ticketData?.quantity is () || ticketData?.quantity < 1) {
                    return <http:BadRequest>{
                        body: {message: "Quantity is required for MULTIPLE tickets"}
                    };
                }

                // Calculate price (simplified pricing logic)
                decimal price = 0.0;
                if ticketData.ticketType == "SINGLE" {
                    price = 25.0; // Base price for single ticket
                } else if ticketData.ticketType == "MULTIPLE" {
                    price = 20.0 * <decimal>(ticketData?.quantity ?: 1); // Discounted price per ticket
                } else if ticketData.ticketType == "PASS" {
                    price = 150.0; // Monthly pass price
                }

                string ticketId = uuid:createType4AsString();
                time:Utc now = time:utcNow();

                Ticket newTicket = {
                    id: ticketId,
                    userId: userId,
                    routeId: ticketData.routeId,
                    ticketType: ticketData.ticketType,
                    status: "CREATED",
                    price: price,
                    quantity: ticketData?.quantity,
                    purchaseDate: time:utcToString(now),
                    validFrom: time:utcToString(now),
                    validUntil: ticketData.ticketType == "PASS" ? time:utcToString(time:utcAddSeconds(now, 2592000)) : time:utcToString(time:utcAddSeconds(now, 86400)) // 30 days for pass, 24 hours for others
                };

                // Save ticket to database
                mongodb:Database database = check mongoDb->getDatabase(databaseName);
                mongodb:Collection collection = check database->getCollection("tickets");

                map<json> ticketDoc = {
                    "id": newTicket.id,
                    "userId": newTicket.userId,
                    "routeId": newTicket.routeId,
                    "ticketType": newTicket.ticketType,
                    "status": newTicket.status,
                    "price": newTicket.price,
                    "quantity": newTicket.quantity,
                    "purchaseDate": newTicket.purchaseDate,
                    "validFrom": newTicket.validFrom,
                    "validUntil": newTicket.validUntil
                };

                _ = check collection->insertOne(ticketDoc);

                log:printInfo("Ticket purchased: " + ticketId + " for user: " + userId);
                return newTicket;
            }

            return <http:Unauthorized>{
                body: {message: "Invalid user"}
            };

        } on fail error e {
            log:printError("Error purchasing ticket: " + e.message());
            return <http:InternalServerError>{
                body: {message: "Ticket purchase failed"}
            };
        }
    }

    /// Updates an existing ticket for the authenticated user.
    ///
    /// + ctx - HTTP request context
    /// + authorization - JWT authorization header (Bearer token)
    /// + ticketId - The unique identifier of the ticket to update
    /// + updateData - The fields to update for the ticket
    /// + return - Success message or error
    resource function put tickets/[string ticketId](http:RequestContext ctx, @http:Header string authorization, @http:Payload TicketUpdate updateData) returns json|http:Unauthorized|http:BadRequest|http:InternalServerError {
        do {
            // Extract and validate JWT token
            string|http:Unauthorized tokenResult = extractToken(authorization);
            if tokenResult is http:Unauthorized {
                return tokenResult;
            }
            string token = <string>tokenResult;

            jwt:Payload|jwt:Error payload = jwt:validate(token, validatorConfig);

            if payload is jwt:Error {
                return <http:Unauthorized>{
                    body: {message: "Invalid token"}
                };
            }

            jwt:Payload jwtPayload = <jwt:Payload>payload;
            string? userId = jwtPayload.sub;

            if userId is string {
                // Validate update data
                if updateData?.status is string && updateData?.status != "CREATED" && updateData?.status != "PAID" && updateData?.status != "VALIDATED" && updateData?.status != "EXPIRED" {
                    return <http:BadRequest>{
                        body: {message: "Invalid status. Must be CREATED, PAID, VALIDATED, or EXPIRED"}
                    };
                }

                // Build update document
                map<json> updateFields = {};
                if updateData?.status is string {
                    updateFields["status"] = updateData?.status;
                }
                if updateData?.quantity is int {
                    updateFields["quantity"] = updateData?.quantity;
                }

                if updateFields.length() == 0 {
                    return <http:BadRequest>{
                        body: {message: "No fields provided for update"}
                    };
                }

                // Update ticket (ensure user owns the ticket)
                mongodb:Database database = check mongoDb->getDatabase(databaseName);
                mongodb:Collection collection = check database->getCollection("tickets");

                map<json> filter = {"id": ticketId, "userId": userId};
                
                // Use set operator without $ prefix
                mongodb:Update update = {"set": updateFields};
                mongodb:UpdateResult result = check collection->updateOne(filter, update);

                if result.matchedCount == 0 {
                    return <http:BadRequest>{
                        body: {message: "Ticket not found or access denied"}
                    };
                }

                if result.matchedCount == 0 {
                    return <http:BadRequest>{
                        body: {message: "Ticket not found or access denied"}
                    };
                }

                log:printInfo("Ticket updated: " + ticketId + " for user: " + userId);
                return {"success": true, "message": "Ticket updated successfully"};
            }

            return <http:Unauthorized>{
                body: {message: "Invalid user"}
            };

        } on fail error e {
            log:printError("Error updating ticket: " + e.message());
            return <http:InternalServerError>{
                body: {message: "Ticket update failed"}
            };
        }
    }

    /// Cancels/deletes a ticket for the authenticated user.
    ///
    /// + ctx - HTTP request context
    /// + authorization - JWT authorization header (Bearer token)
    /// + ticketId - The unique identifier of the ticket to cancel
    /// + return - Success message or error
    resource function delete tickets/[string ticketId](http:RequestContext ctx, @http:Header string authorization) returns json|http:Unauthorized|http:BadRequest|http:InternalServerError {
        do {
            // Extract and validate JWT token
            string|http:Unauthorized tokenResult = extractToken(authorization);
            if tokenResult is http:Unauthorized {
                return tokenResult;
            }
            string token = <string>tokenResult;

            jwt:Payload|jwt:Error payload = jwt:validate(token, validatorConfig);

            if payload is jwt:Error {
                return <http:Unauthorized>{
                    body: {message: "Invalid token"}
                };
            }

            jwt:Payload jwtPayload = <jwt:Payload>payload;
            string? userId = jwtPayload.sub;

            if userId is string {
                // Delete ticket (ensure user owns the ticket and it's not validated)
                mongodb:Database database = check mongoDb->getDatabase(databaseName);
                mongodb:Collection collection = check database->getCollection("tickets");

                // Check if ticket is already validated (can't cancel validated tickets)
                map<json> checkFilter = {"id": ticketId, "userId": userId};
                stream<Ticket, error?> checkStream = check collection->find(checkFilter);
                Ticket[] ticketArray = check from Ticket ticket in checkStream select ticket;

                if ticketArray.length() == 0 {
                    return <http:BadRequest>{
                        body: {message: "Ticket not found or access denied"}
                    };
                }

                Ticket ticket = ticketArray[0];
                if ticket.status == "VALIDATED" {
                    return <http:BadRequest>{
                        body: {message: "Cannot cancel a validated ticket"}
                    };
                }

                // Delete the ticket
                mongodb:DeleteResult result = check collection->deleteOne(checkFilter);

                if result.deletedCount == 0 {
                    return <http:BadRequest>{
                        body: {message: "Ticket not found or access denied"}
                    };
                }

                log:printInfo("Ticket cancelled: " + ticketId + " for user: " + userId);
                return {"success": true, "message": "Ticket cancelled successfully"};
            }

            return <http:Unauthorized>{
                body: {message: "Invalid user"}
            };

        } on fail error e {
            log:printError("Error cancelling ticket: " + e.message());
            return <http:InternalServerError>{
                body: {message: "Ticket cancellation failed"}
            };
        }
    }
    
    // Health check
    resource function get health() returns string|error {
        // Light-touch DB check to ensure collection is accessible
        mongodb:Database database = check mongoDb->getDatabase(databaseName);
        mongodb:Collection collection = check database->getCollection("users");
        _ = check collection->countDocuments({});
        return "Passenger Service is running";
    }
}

public function main() returns error? {
    log:printInfo("Passenger Service started on port 8080");
}
