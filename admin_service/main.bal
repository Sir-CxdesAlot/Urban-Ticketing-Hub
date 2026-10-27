import ballerina/http;
import uth/core;

listener http:Listener api = new(8086);

service /api/v1/admin on api {
    isolated resource function get [string... path](http:Request request) returns http:Response {
        return core:respond("admin", "GET", path, request);
    }
    isolated resource function post [string... path](http:Request request) returns http:Response {
        return core:respond("admin", "POST", path, request);
    }
    isolated resource function put [string... path](http:Request request) returns http:Response {
        return core:respond("admin", "PUT", path, request);
    }
    isolated resource function delete [string... path](http:Request request) returns http:Response {
        return core:respond("admin", "DELETE", path, request);
    }
}

function init() returns error? {
    check core:initializeIndexes();
    check core:bootstrapAdmin();
}
