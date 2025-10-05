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
    time:Utc purchaseDate;
    time:Utc validFrom?;
    time:Utc validUntil?;
    time:Utc validatedAt?;
|};

// Service configuration
listener http:Listener httpListener = new(8080);

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
            // Validate JWT token
            string token = authorization.substring(7); // Remove "Bearer " prefix
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
    resource function get tickets(http:RequestContext ctx, @http:Header string authorization) returns Ticket[]|http:Unauthorized|http:InternalServerError {
        do {
            // Validate JWT token
            string token = authorization.substring(7);
            jwt:Payload|jwt:Error payload = jwt:validate(token, validatorConfig);
            
            if payload is jwt:Error {
                return <http:Unauthorized>{
                    body: {message: "Invalid token"}
                };
            }
            
            jwt:Payload jwtPayload = <jwt:Payload>payload;
            string? userId = jwtPayload.sub;
            
            if userId is string {
                // Get user's tickets
                mongodb:Database database = check mongoDb->getDatabase(databaseName);
                mongodb:Collection collection = check database->getCollection("tickets");
                
                stream<Ticket, error?> tickets = check collection->find({userId: userId});
                Ticket[] ticketArray = check from Ticket ticket in tickets select ticket;
                
                log:printInfo("Retrieved tickets for user: " + userId);
                return ticketArray;
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
