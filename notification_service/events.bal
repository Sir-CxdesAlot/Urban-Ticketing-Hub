import ballerina/log;
import ballerina/task;
import ballerinax/kafka;
import uth/core;

configurable string kafkaBootstrapServers = "localhost:9092";
kafka:Producer producer = check new(kafkaBootstrapServers, {
    clientId: "uth-outbox", acks: "all", enableIdempotence: true,
    maxBlock: 5, requestTimeout: 5, additionalProperties: {"delivery.timeout.ms": "10000"}
});
kafka:Consumer consumer = check new(kafkaBootstrapServers, {
    groupId: "uth-notifications-v2", topics: ["uth.events.v2"], autoCommit: false,
    offsetReset: kafka:OFFSET_RESET_EARLIEST, maxPollRecords: 50,
    defaultApiTimeout: 5
});
kafka:Consumer readinessConsumer = check new(kafkaBootstrapServers, {clientId: "uth-readiness", autoCommit: false, defaultApiTimeout: 2});
kafka:AnydataConsumerRecord[] pending = [];

class EventJob {
    // Polymorphism: the scheduler invokes this implementation through the task:Job interface.
    *task:Job;

    public function execute() {
        error? result = trap tick();
        if result is error {
            // Information hiding: worker failures identify the component without logging personal payloads.
            log:printError("Notification worker will retry its pending work.");
        }
    }
}

function tick() returns error? {
    core:Document[] messages = check core:pendingEvents();
    foreach core:Document message in messages {
        kafka:RecordMetadata|kafka:Error published = producer->sendWithMetadata({
            topic: "uth.events.v2", key: (check core:text(message, "id")).toBytes(), value: message.toJsonString().toBytes()
        });
        check core:publicationResult(message, published is kafka:RecordMetadata);
        if published is kafka:Error { break; }
    }
    if pending.length() == 0 { pending = check consumer->poll(1); }
    foreach kafka:AnydataConsumerRecord item in pending {
        anydata value = item.value;
        string sourceId = item.offset.partition.topic + ":" + item.offset.partition.partition.toString() + ":" + item.offset.offset.toString();
        if value !is byte[] {
            check core:quarantine(sourceId, {});
            continue;
        }
        string|error decoded = string:fromBytes(value);
        if decoded is error { check core:quarantine(sourceId, {}); continue; }
        json|error parsed = decoded.fromJsonString();
        if parsed is error { check core:quarantine(sourceId, {}); continue; }
        core:Document|error message = parsed.cloneWithType();
        if message is error { check core:quarantine(sourceId, parsed); continue; }
        error? delivered = core:deliver(message);
        if delivered is error {
            if core:errorStatus(delivered) == 503 || core:errorStatus(delivered) == 409 { return delivered; }
            check core:quarantine(sourceId, message);
        }
    }
    if pending.length() > 0 {
        // At-least-once delivery: acknowledge only after every notification or quarantine record is durable.
        check consumer->'commit();
        pending = [];
    }
}

function startWorker() returns error? {
    _ = check task:scheduleJobRecurByFrequency(new EventJob(), 2);
}

function brokerReady() returns boolean {
    string[]|kafka:Error topics = readinessConsumer->getAvailableTopics(2);
    return topics is string[];
}
