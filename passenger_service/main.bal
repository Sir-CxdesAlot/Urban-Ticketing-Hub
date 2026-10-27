import ballerina/http;
import uth/core;

listener http:Listener api = new(8081);

service /api/v1/passenger on api {
    isolated resource function get [string... path](http:Request request) returns http:Response {
        return core:respond("passenger", "GET", path, request);
    }
    isolated resource function post [string... path](http:Request request) returns http:Response {
        return core:respond("passenger", "POST", path, request);
    }
    isolated resource function put [string... path](http:Request request) returns http:Response {
        return core:respond("passenger", "PUT", path, request);
    }
    isolated resource function delete [string... path](http:Request request) returns http:Response {
        return core:respond("passenger", "DELETE", path, request);
    }
}

function init() returns error? {
    check core:initializeIndexes();
}
