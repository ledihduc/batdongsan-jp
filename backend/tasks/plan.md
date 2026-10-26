# Implementation Plan: Rental Journey Backend

## Overview

Add an auditable rental-journey aggregate around the existing viewing appointment and deal modules, keeping current consumers compatible while exposing role-specific work queues for the new customer, sale, and owner interfaces.

## Architecture Decisions

- Keep scheduling in `viewing_appointments`; do not duplicate date/slot conflict logic.
- Add `rental_journeys`, `rental_journey_payments`, `rental_journey_reports`, and `rental_journey_events` as post-view workflow records.
- Centralize state transitions and `availableActions` in a service.
- Reuse authenticated `/api/upload`; journey endpoints store only validated server upload paths.
- Configure the public platform deposit account through environment settings, never source constants.

## Dependency Order

Schema -> ORM -> pure transition policy -> service -> router -> app registration -> integration tests -> migration/deploy.

## Phases

### Foundation

- Define migration and ORM models.
- Add pure policy tests and implementation.

### Customer Slice

- Create journey from viewing result.
- Read list/detail/timeline.
- Submit two proofs and final customer confirmation.

### Sale And Owner Slice

- Sale contract submission.
- Owner deposit acknowledgement.
- Role-specific appointment work queue.

### Trust Slice

- Participant reports, cancellation, dispute state, immutable timeline.
- Security and regression verification.

## Risks And Mitigations

| Risk | Impact | Mitigation |
|---|---|---|
| Existing dirty changes overlap appointment/deal code | High | Add new modules and make minimal additive edits to shared files |
| Duplicate journeys from concurrent requests | High | Unique appointment FK plus IntegrityError translation |
| Sale inflates completed count | High | Customer-only completion and sale ID derived server-side |
| Fake or external proof URL | Medium | Accept only server `/uploads/` paths |
| Migration breaks existing rows | Medium | New nullable/additive tables and idempotent migration checks |

