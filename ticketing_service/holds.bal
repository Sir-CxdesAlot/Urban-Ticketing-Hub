import ballerina/log;
import ballerina/task;
import uth/core;

class HoldExpiryJob {
    *task:Job;

    public function execute() {
        // Fault isolation: holds and unvalidated expired bookings release rides independently of Kafka.
        error? result = trap core:expireHolds();
        if result is error { log:printError("Expired booking holds will be retried."); }
    }
}

function startHoldExpiry() returns error? {
    _ = check task:scheduleJobRecurByFrequency(new HoldExpiryJob(), 2);
}
