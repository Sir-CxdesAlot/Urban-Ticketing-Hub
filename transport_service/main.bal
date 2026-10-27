import ballerina/http;
import uth/core;

listener http:Listener api = new(8082);

service /api/v1/transport on api {
    isolated resource function get [string... path](http:Request request) returns http:Response {
        return core:respond("transport", "GET", path, request);
    }
    isolated resource function post [string... path](http:Request request) returns http:Response {
        return core:respond("transport", "POST", path, request);
    }
    isolated resource function put [string... path](http:Request request) returns http:Response {
        return core:respond("transport", "PUT", path, request);
    }
    isolated resource function delete [string... path](http:Request request) returns http:Response {
        return core:respond("transport", "DELETE", path, request);
    }
}

function init() returns error? {
    check core:initializeIndexes();
}
