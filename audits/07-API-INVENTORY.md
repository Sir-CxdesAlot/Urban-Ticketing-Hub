# HTTP API inventory

Extracted from all six service source files at baseline `7d56d4e`. Auth below describes code in this repository; it does not assert a deployed gateway exists. Public route discovery and health may intentionally be public. Other missing protection is SEC-01.

| Method | Resource | Source | Explicit passenger JWT validation |
|---|---|---|---|
| GET | `/api/v1/admin/health` | [admin_service/main.bal:111](../admin_service/main.bal#L111) | No |
| POST | `/api/v1/admin/login` | [admin_service/main.bal:124](../admin_service/main.bal#L124) | No |
| POST | `/api/v1/admin/disruptions` | [admin_service/main.bal:192](../admin_service/main.bal#L192) | No |
| GET | `/api/v1/admin/disruptions` | [admin_service/main.bal:243](../admin_service/main.bal#L243) | No |
| PUT | `/api/v1/admin/disruptions/{disruptionId}/status` | [admin_service/main.bal:282](../admin_service/main.bal#L282) | No |
| PUT | `/api/v1/admin/disruptions/{disruptionId}` | [admin_service/main.bal:305](../admin_service/main.bal#L305) | No |
| DELETE | `/api/v1/admin/disruptions/{disruptionId}` | [admin_service/main.bal:367](../admin_service/main.bal#L367) | No |
| GET | `/api/v1/admin/reports/usage` | [admin_service/main.bal:398](../admin_service/main.bal#L398) | No |
| GET | `/api/v1/admin/dashboard` | [admin_service/main.bal:491](../admin_service/main.bal#L491) | No |
| POST | `/api/v1/admin/routes/{routeId}/schedule-update` | [admin_service/main.bal:531](../admin_service/main.bal#L531) | No |
| POST | `/api/v1/admin/admin-users` | [admin_service/main.bal:557](../admin_service/main.bal#L557) | No |
| GET | `/api/v1/admin/admin-users` | [admin_service/main.bal:601](../admin_service/main.bal#L601) | No |
| PUT | `/api/v1/admin/admin-users/{adminId}` | [admin_service/main.bal:660](../admin_service/main.bal#L660) | No |
| DELETE | `/api/v1/admin/admin-users/{adminId}` | [admin_service/main.bal:700](../admin_service/main.bal#L700) | No |
| GET | `/api/v1/notification/health` | [notification_service/main.bal:71](../notification_service/main.bal#L71) | No |
| POST | `/api/v1/notification/notifications` | [notification_service/main.bal:85](../notification_service/main.bal#L85) | No |
| GET | `/api/v1/notification/users/{userId}/notifications` | [notification_service/main.bal:117](../notification_service/main.bal#L117) | No |
| PUT | `/api/v1/notification/notifications/{notificationId}/read` | [notification_service/main.bal:145](../notification_service/main.bal#L145) | No |
| GET | `/api/v1/notification/statistics` | [notification_service/main.bal:166](../notification_service/main.bal#L166) | No |
| GET | `/api/v1/notification/notifications/{notificationId}` | [notification_service/main.bal:211](../notification_service/main.bal#L211) | No |
| PUT | `/api/v1/notification/notifications/{notificationId}` | [notification_service/main.bal:233](../notification_service/main.bal#L233) | No |
| DELETE | `/api/v1/notification/notifications/{notificationId}` | [notification_service/main.bal:279](../notification_service/main.bal#L279) | No |
| POST | `/api/v1/passenger/register` | [passenger_service/main.bal:148](../passenger_service/main.bal#L148) | No |
| POST | `/api/v1/passenger/login` | [passenger_service/main.bal:231](../passenger_service/main.bal#L231) | No |
| GET | `/api/v1/passenger/profile` | [passenger_service/main.bal:298](../passenger_service/main.bal#L298) | Yes |
| GET | `/api/v1/passenger/tickets` | [passenger_service/main.bal:357](../passenger_service/main.bal#L357) | Yes |
| PUT | `/api/v1/passenger/profile` | [passenger_service/main.bal:413](../passenger_service/main.bal#L413) | Yes |
| DELETE | `/api/v1/passenger/profile` | [passenger_service/main.bal:553](../passenger_service/main.bal#L553) | Yes |
| POST | `/api/v1/passenger/tickets` | [passenger_service/main.bal:608](../passenger_service/main.bal#L608) | Yes |
| PUT | `/api/v1/passenger/tickets/{ticketId}` | [passenger_service/main.bal:710](../passenger_service/main.bal#L710) | Yes |
| DELETE | `/api/v1/passenger/tickets/{ticketId}` | [passenger_service/main.bal:797](../passenger_service/main.bal#L797) | Yes |
| GET | `/api/v1/passenger/health` | [passenger_service/main.bal:866](../passenger_service/main.bal#L866) | No |
| GET | `/api/v1/payment/health` | [payment_service/main.bal:73](../payment_service/main.bal#L73) | No |
| POST | `/api/v1/payment/payments` | [payment_service/main.bal:83](../payment_service/main.bal#L83) | No |
| GET | `/api/v1/payment/payments` | [payment_service/main.bal:111](../payment_service/main.bal#L111) | No |
| GET | `/api/v1/payment/payments/{paymentId}` | [payment_service/main.bal:126](../payment_service/main.bal#L126) | No |
| PUT | `/api/v1/payment/payments/{paymentId}` | [payment_service/main.bal:144](../payment_service/main.bal#L144) | No |
| DELETE | `/api/v1/payment/payments/{paymentId}` | [payment_service/main.bal:170](../payment_service/main.bal#L170) | No |
| GET | `/api/v1/payment/passengers/{passengerId}/payments` | [payment_service/main.bal:183](../payment_service/main.bal#L183) | No |
| GET | `/api/v1/payment/statistics` | [payment_service/main.bal:201](../payment_service/main.bal#L201) | No |
| POST | `/api/v1/payment/payments/{paymentId}/refund` | [payment_service/main.bal:242](../payment_service/main.bal#L242) | No |
| GET | `/api/v1/ticketing/health` | [ticketing_service/main.bal:71](../ticketing_service/main.bal#L71) | No |
| POST | `/api/v1/ticketing/tickets` | [ticketing_service/main.bal:81](../ticketing_service/main.bal#L81) | No |
| GET | `/api/v1/ticketing/tickets/{ticketId}` | [ticketing_service/main.bal:116](../ticketing_service/main.bal#L116) | No |
| PUT | `/api/v1/ticketing/tickets/{ticketId}` | [ticketing_service/main.bal:134](../ticketing_service/main.bal#L134) | No |
| DELETE | `/api/v1/ticketing/tickets/{ticketId}` | [ticketing_service/main.bal:155](../ticketing_service/main.bal#L155) | No |
| GET | `/api/v1/ticketing/passengers/{passengerId}/tickets` | [ticketing_service/main.bal:165](../ticketing_service/main.bal#L165) | No |
| PUT | `/api/v1/ticketing/tickets/{ticketId}/validate` | [ticketing_service/main.bal:183](../ticketing_service/main.bal#L183) | No |
| GET | `/api/v1/ticketing/statistics` | [ticketing_service/main.bal:259](../ticketing_service/main.bal#L259) | No |
| POST | `/api/v1/transport/routes` | [transport_service/main.bal:141](../transport_service/main.bal#L141) | No |
| GET | `/api/v1/transport/routes` | [transport_service/main.bal:221](../transport_service/main.bal#L221) | No |
| GET | `/api/v1/transport/routes/{routeId}` | [transport_service/main.bal:290](../transport_service/main.bal#L290) | No |
| PUT | `/api/v1/transport/routes/{routeId}` | [transport_service/main.bal:359](../transport_service/main.bal#L359) | No |
| DELETE | `/api/v1/transport/routes/{routeId}` | [transport_service/main.bal:400](../transport_service/main.bal#L400) | No |
| GET | `/api/v1/transport/trips` | [transport_service/main.bal:417](../transport_service/main.bal#L417) | No |
| POST | `/api/v1/transport/trips` | [transport_service/main.bal:451](../transport_service/main.bal#L451) | No |
| GET | `/api/v1/transport/trips/{tripId}` | [transport_service/main.bal:504](../transport_service/main.bal#L504) | No |
| PUT | `/api/v1/transport/trips/{tripId}` | [transport_service/main.bal:518](../transport_service/main.bal#L518) | No |
| DELETE | `/api/v1/transport/trips/{tripId}` | [transport_service/main.bal:544](../transport_service/main.bal#L544) | No |
| GET | `/api/v1/transport/routes/{routeId}/trips` | [transport_service/main.bal:558](../transport_service/main.bal#L558) | No |
| PUT | `/api/v1/transport/trips/{tripId}/status` | [transport_service/main.bal:591](../transport_service/main.bal#L591) | No |
| GET | `/api/v1/transport/health` | [transport_service/main.bal:680](../transport_service/main.bal#L680) | No |

Total: **62 resources**. This inventory is static; no endpoints were exercised against a live database.

## Event boundaries

| Topic | Producer | Consumer | Contract concerns |
|---|---|---|---|
| `ticket.requests` | No active producer in service source | Ticketing | Duplicate delivery creates a new ticket; different path from passenger purchase |
| `payments.processed` | Payment | Ticketing, notification | Ticketing uses `kafka:DEFAULT_URL`; no payment reconciliation or event deduplication |
| `ticket.validations` | Ticketing | Notification | Write/publish is not atomic; duplicate delivery creates duplicate notices |
| `schedule.updates` | Transport, admin | Notification | Admin status/deletion events omit fields required by the consumer |
