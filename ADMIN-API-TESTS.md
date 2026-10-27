# Staff API verification

The old unauthenticated admin endpoints have been replaced. Use the [OpenAPI contract](docs/openapi.json), `uth.ps1 test -Suite integration`, and `uth.ps1 test -Suite browser`.

- Login through `/api/v1/passenger/login` with the same account model used by passengers. `/api/v1/admin/login` accepts staff credentials only.
- Super administrators create staff with `POST /api/v1/admin/accounts`, change access with `PUT /accounts/{id}`, and read account, audit, pending-event, and failed-delivery lists.
- Managers and super administrators manage transport and read `/reports` and `/operators`.
- Operators use `/assigned-trips` and `/api/v1/ticketing/bookings?tripId=...`; only the assigned operator or an authorized manager can validate a booking.
- Every request requires a live bearer session. Cross-role access, role forgery, session revocation, and concurrent validation are integration-test assertions.

Generated credentials remain in ignored local files. Never copy tokens or passwords into this document or test output.
