import ballerina/http;
import uth/core;

listener http:Listener api = new(8085);

service /api/v1/notification on api {
    resource function get health() returns http:Response {
        http:Response response = new;
        core:Document|error database = core:health();
        if database is error || !brokerReady() {
            response.statusCode = 503;
            response.setJsonPayload({"error": {code: "503", message: "A notification dependency is unavailable."}});
        } else {
            response.setJsonPayload({status: "ready", database: "reachable", broker: "reachable"});
        }
        response.setHeader("Cache-Control", "no-store");
        return response;
    }
    isolated resource function get [string... path](http:Request request) returns http:Response {
        return core:respond("notification", "GET", path, request);
    }
    isolated resource function post [string... path](http:Request request) returns http:Response {
        return core:respond("notification", "POST", path, request);
    }
    isolated resource function put [string... path](http:Request request) returns http:Response {
        return core:respond("notification", "PUT", path, request);
    }
    isolated resource function delete [string... path](http:Request request) returns http:Response {
        return core:respond("notification", "DELETE", path, request);
    }
}

function init() returns error? {
    check core:initializeIndexes();
    check startWorker();
}
