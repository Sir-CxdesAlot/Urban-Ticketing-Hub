package uth;

import com.mongodb.MongoException;
import com.mongodb.ReadConcern;
import com.mongodb.TransactionOptions;
import com.mongodb.WriteConcern;
import com.mongodb.client.ClientSession;
import com.mongodb.client.MongoClient;
import com.mongodb.client.MongoClients;
import com.mongodb.client.MongoCollection;
import com.mongodb.client.MongoDatabase;
import com.mongodb.client.model.IndexOptions;
import com.mongodb.client.model.CountOptions;
import com.mongodb.client.model.UpdateOptions;
import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.ConcurrentHashMap;
import org.bson.Document;

/** Generic persistence boundary; all permissions and ticket rules belong to Ballerina. */
public final class MongoStore {
    // OOP / encapsulation: connection pooling and transaction sessions stay inside this adapter.
    private static final ConcurrentHashMap<String, MongoClient> CLIENTS = new ConcurrentHashMap<>();
    private static final TransactionOptions TRANSACTION = TransactionOptions.builder()
            .readConcern(ReadConcern.SNAPSHOT).writeConcern(WriteConcern.MAJORITY).build();

    private MongoStore() { }

    public static String randomToken() {
        byte[] bytes = new byte[32];
        new java.security.SecureRandom().nextBytes(bytes);
        return java.util.HexFormat.of().formatHex(bytes);
    }

    public static String execute(String uri, String database, String input) {
        try {
            MongoClient client = CLIENTS.computeIfAbsent(uri, MongoClients::create);
            MongoDatabase db = client.getDatabase(database).withWriteConcern(WriteConcern.MAJORITY);
            Document command = Document.parse(input);
            Object result = switch (command.getString("op")) {
                case "ping" -> db.runCommand(new Document("ping", 1)).get("ok");
                case "find" -> find(db, command);
                case "count" -> collection(db, command).countDocuments(filter(command),
                        new CountOptions().maxTime(5, java.util.concurrent.TimeUnit.SECONDS));
                case "aggregate" -> collection(db, command).aggregate(command.getList("pipeline", Document.class))
                        .maxTime(5, java.util.concurrent.TimeUnit.SECONDS).into(new ArrayList<>());
                case "index" -> collection(db, command).createIndex(command.get("keys", Document.class),
                        new IndexOptions().unique(command.getBoolean("unique", false)));
                case "transaction" -> {
                    // ACID: snapshot reads and majority writes commit the entire batch or roll it back.
                    try (ClientSession session = client.startSession()) {
                        yield session.withTransaction(() -> apply(db, session, command), TRANSACTION);
                    }
                }
                default -> throw new IllegalArgumentException("Unsupported database operation");
            };
            return new Document("ok", true).append("data", result).toJson();
        } catch (Conflict failure) {
            return failure("CONFLICT");
        } catch (MongoException failure) {
            return failure(failure.getCode() == 11000 ? "CONFLICT" : "DATABASE_UNAVAILABLE");
        } catch (RuntimeException failure) {
            // Information hiding: never return connection strings, credentials, or driver stack traces.
            return failure("DATABASE_ERROR");
        }
    }

    private static List<Document> find(MongoDatabase db, Document command) {
        // Time: an index-supported filter is approximately O(log N + skipped + returned records).
        return collection(db, command).find(filter(command)).projection(new Document("_id", 0))
                .sort(command.get("sort", new Document("id", 1)))
                .skip(Math.max(0, command.getInteger("skip", 0)))
                .limit(Math.min(1000, Math.max(1, command.getInteger("limit", 100))))
                .maxTime(5, java.util.concurrent.TimeUnit.SECONDS).into(new ArrayList<>());
    }

    private static Object apply(MongoDatabase db, ClientSession session, Document command) {
        List<Document> changes = command.getList("changes", Document.class);
        if (changes.size() > 1000) throw new IllegalArgumentException("Batch is too large");
        for (Document change : changes) {
            MongoCollection<Document> collection = collection(db, change);
            long matched = switch (change.getString("op")) {
                case "insert" -> {
                    collection.insertOne(session, change.get("document", Document.class));
                    yield 1;
                }
                case "update" -> collection.updateOne(session, filter(change), change.get("update", Document.class),
                        new UpdateOptions().upsert(change.getBoolean("upsert", false))).getMatchedCount();
                case "delete" -> collection.deleteOne(session, filter(change)).getDeletedCount();
                default -> throw new IllegalArgumentException("Unsupported transaction operation");
            };
            // Optimistic concurrency control: a failed version/ownership guard aborts every write.
            if (change.containsKey("expected") && matched != change.getInteger("expected")) throw new Conflict();
        }
        return true;
    }

    private static MongoCollection<Document> collection(MongoDatabase database, Document command) {
        String name = command.getString("collection");
        if (name == null || !name.matches("[a-z_]{1,40}")) throw new IllegalArgumentException("Invalid collection");
        return database.getCollection(name);
    }

    private static Document filter(Document command) {
        return command.get("filter", new Document());
    }

    private static String failure(String code) {
        return new Document("ok", false).append("code", code).toJson();
    }

    private static final class Conflict extends RuntimeException { }
}
