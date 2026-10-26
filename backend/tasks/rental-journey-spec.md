# Spec: Rental Journey API

## Objective

Build the backend contract for the customer, sale, and owner rental journey shown in the approved UI storyboards. The journey begins with an existing viewing appointment and ends only after the customer confirms the rental. Sale and owner actions can advance preparation, but cannot mark a rental completed on behalf of the customer.

## Existing Foundation

- FastAPI, SQLAlchemy, Alembic, PostgreSQL.
- `viewing_appointments` already owns booking, rescheduling, and seller approval.
- `deals` already records sale credit and blocks sale self-confirmation.
- `/api/upload` already authenticates uploads and validates image/PDF content. Journey APIs only accept server-issued `/uploads/...` paths and do not add another upload surface.

## State Machine

`WAITING_VIEWING` -> `VIEWING_COMPLETED` -> `CUSTOMER_INTERESTED` -> `CONTRACT_READY` -> `DEPOSITS_PENDING` -> `CUSTOMER_CONFIRMATION_PENDING` -> `COMPLETED`

Terminal or exceptional states: `CUSTOMER_DECLINED`, `CANCELLED`, `DISPUTED`.

Rules:

- A journey is created at most once for a viewing appointment.
- Only the appointment customer can submit interested/not interested and final confirmation.
- Only the assigned sale can submit or replace the contract evidence.
- Only the customer can submit payment proofs.
- The owner can acknowledge receipt of the owner deposit.
- Final customer confirmation requires contract evidence plus both deposit proofs.
- Sale and owner cannot set `COMPLETED`.
- Any participant can report another participant; reports force the journey to `DISPUTED` unless already completed.
- Every accepted mutation appends an immutable event.

## API Contract

- `GET /api/rental-journeys?view=customer|sale|owner&status=&page=&pageSize=`
- `GET /api/rental-journeys/{id}`
- `POST /api/rental-journeys/from-appointment/{appointmentId}/viewing-result`
- `PUT /api/rental-journeys/{id}/contract`
- `PUT /api/rental-journeys/{id}/payments/{APP_DEPOSIT|OWNER_DEPOSIT}/proof`
- `POST /api/rental-journeys/{id}/payments/OWNER_DEPOSIT/acknowledge`
- `POST /api/rental-journeys/{id}/confirm`
- `POST /api/rental-journeys/{id}/cancel`
- `POST /api/rental-journeys/{id}/reports`
- `GET /api/rental-journeys/{id}/events`
- `GET /api/rental-journeys/payment-account`
- `GET /api/viewing-appointments/work-queue?view=customer|sale|owner&date=&status=`

All detail responses include `availableActions`; clients render commands from this server-owned list instead of duplicating authorization rules.

## Validation And Security

- Participant IDs are derived from the appointment and room/listing ownership.
- Unauthorized or unrelated resource access returns 404 to reduce ID enumeration.
- Evidence accepts 1-10 relative upload paths matching `/uploads/<safe filename>`.
- Text fields are trimmed and length-limited by Pydantic schemas.
- Amounts are integer VND, non-negative, and computed from the total deposit when initialized.
- State transitions are checked in one service and protected by row locks on PostgreSQL.
- Timeline events record actor, transition, and safe metadata without secrets.

## Testing Strategy

- Unit tests for transition policy, available actions, and upload-path validation.
- PostgreSQL integration tests for authorization, idempotent creation, proof gates, reports, and customer-only completion.
- Focused tests run before the full backend suite.

## Boundaries

- Always: preserve existing appointment/deal APIs, validate at routes, derive participants server-side, append audit events.
- Ask first: payment gateway integration, automatic bank reconciliation, external e-signature vendor.
- Never: accept sale credit IDs from clients, expose another user's journey, let sale/owner complete a rental, store bank credentials or card data.

## Success Criteria

- The three role dashboards can be built without mocked workflow data.
- Every storyboard command maps to an authenticated API action.
- Invalid role and invalid transition attempts return deterministic 404/409/422 responses.
- A journey reaches `COMPLETED` only through the customer confirmation endpoint after all required evidence exists.
- Existing booking and deal tests remain green.

