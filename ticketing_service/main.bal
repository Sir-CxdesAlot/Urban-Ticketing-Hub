import ballerina/http;
import uth/core;

listener http:Listener api = new(8083);

service /api/v1/ticketing on api {
    isolated resource function get [string... path](http:Request request) returns http:Response {
        return core:respond("ticketing", "GET", path, request);
    }
    isolated resource function post [string... path](http:Request request) returns http:Response {
        return core:respond("ticketing", "POST", path, request);
    }
    isolated resource function put [string... path](http:Request request) returns http:Response {
        return core:respond("ticketing", "PUT", path, request);
    }
    isolated resource function delete [string... path](http:Request request) returns http:Response {
        return core:respond("ticketing", "DELETE", path, request);
    }
}

function init() returns error? {
    check core:initializeIndexes();
    check startHoldExpiry();
}
