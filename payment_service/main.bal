import ballerina/http;
import uth/core;

listener http:Listener api = new(8084);

service /api/v1/payment on api {
    isolated resource function get [string... path](http:Request request) returns http:Response {
        return core:respond("payment", "GET", path, request);
    }
    isolated resource function post [string... path](http:Request request) returns http:Response {
        return core:respond("payment", "POST", path, request);
    }
    isolated resource function put [string... path](http:Request request) returns http:Response {
        return core:respond("payment", "PUT", path, request);
    }
    isolated resource function delete [string... path](http:Request request) returns http:Response {
        return core:respond("payment", "DELETE", path, request);
    }
}

function init() returns error? {
    check core:initializeIndexes();
}
