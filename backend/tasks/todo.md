# Rental Journey Backend Tasks

- [x] Task 1: Add policy tests and state/action policy
  - Acceptance: invalid transitions fail; sale/owner never receive final-confirm action.
  - Verify: `pytest -q tests/test_rental_journey_policy.py`.
  - Files: `tests/test_rental_journey_policy.py`, `app/services/rental_journey_policy.py`.

- [x] Task 2: Add additive schema and ORM models
  - Acceptance: four new tables, unique journey per appointment, indexed participant/status queries.
  - Verify: `alembic upgrade head` on the staging database.
  - Files: one Alembic revision, `app/models/sale.py`.

- [x] Task 3: Add customer journey API slice
  - Acceptance: customer records result, lists/reads own journey, submits proofs, and alone can complete after gates pass.
  - Verify: focused PostgreSQL API tests.
  - Files: router, service, schemas, tests.

- [x] Task 4: Add sale/owner API slice
  - Acceptance: assigned sale uploads contract; owner acknowledges receipt; unrelated users receive 404.
  - Verify: focused PostgreSQL API tests.
  - Files: same router/service/schemas/tests.

- [x] Task 5: Add reports, cancellation, and timeline
  - Acceptance: participants can report; target is validated; event history is ordered and immutable through API.
  - Verify: focused PostgreSQL API tests.
  - Files: same router/service/schemas/tests.

- [x] Task 6: Add role work queue and register routes
  - Acceptance: customer/sale/owner can query only appointments in their scope with date/status filters.
  - Verify: endpoint smoke tests and OpenAPI route inspection.
  - Files: `app/routers/viewing_appointments.py`, `main.py`, tests.

- [x] Checkpoint: deploy staging
  - Run focused tests and backend suite.
  - Apply migration, restart backend, verify health and OpenAPI endpoints.
  - Result: 14 focused tests and 13 existing deal tests pass; migration is at head and public health is healthy.
  - Residual: 6 pre-existing viewing helper tests fail because their mocks reject the existing `RoomKenh` query.
