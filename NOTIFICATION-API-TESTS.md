# Notification API verification

Use the [OpenAPI contract](docs/openapi.json) and `uth.ps1 test -Suite integration` / `browser`.

Each authenticated user reads only their own paginated `/api/v1/notification/notifications`. `POST /notifications/{id}/read` changes that user's notification; `DELETE /notifications/{id}` removes it. Managers/super administrators queue announcements with `POST /broadcasts`.

Events are stored in the same MongoDB transaction as the originating business change, published with broker acknowledgement, and consumed with manual offset commits. A unique event/recipient delivery record prevents duplicates. Broadcasts create separate notification/read state for each recipient. Invalid events are quarantined in `delivery_failures`; a super administrator can inspect and retry them.

The integration suite stops/restarts Kafka while paying for a ticket, then checks durable recovery. This is separate from loopback helper tests, which cannot prove Kafka behavior.
