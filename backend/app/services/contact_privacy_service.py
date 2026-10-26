"""Central policy for counterparty contact disclosure.

The booking and rental workflows need names to make a schedule understandable,
but a phone/email is a different class of data.  In particular, customer and
owner contact details must not become an accidental shortcut around the Sale
and contract workflow.  Keep that decision in one small service so new API
projections cannot silently reintroduce a leak.

This policy deliberately does not alter legacy tenant/host records for a
currently active tenancy.  It applies to the viewing -> rental journey where
the platform has a Sale-mediated contract record.
"""

from __future__ import annotations

from typing import Optional

from sqlalchemy.orm import Session

from app import models
from app.services import rental_journey_policy as journey_policy


SALE_REQUIRED = "SALE_REQUIRED"
CONTRACT_REQUIRED = "CONTRACT_REQUIRED"
CONTRACT_NOT_FINALIZED = "CONTRACT_NOT_FINALIZED"
CONTACT_AVAILABLE = "CONTACT_AVAILABLE"


def _completed_sale_mediated_journey(
    db: Session,
    *,
    appointment_id: Optional[int] = None,
    customer_id: Optional[int] = None,
    owner_id: Optional[int] = None,
) -> Optional[models.RentalJourney]:
    """Return the finalized mediated contract, never an in-progress draft."""
    query = db.query(models.RentalJourney).filter(
        models.RentalJourney.sale_id.is_not(None),
        models.RentalJourney.status == journey_policy.COMPLETED,
    )
    if appointment_id is not None:
        query = query.filter(models.RentalJourney.appointment_id == appointment_id)
    if customer_id is not None:
        query = query.filter(models.RentalJourney.customer_id == customer_id)
    if owner_id is not None:
        query = query.filter(models.RentalJourney.owner_id == owner_id)
    # The file list is JSON on supported deployments.  Check it in Python so
    # this policy stays portable between SQLite test DBs and PostgreSQL.
    for journey in query.order_by(models.RentalJourney.completed_at.desc()).all():
        if journey.contract_urls:
            return journey
    return None


def access_for_journey(
    db: Session, journey: models.RentalJourney, claims: dict
) -> dict:
    """Return a non-PII decision plus the contacts the viewer may receive.

    Admin can support an incident; the assigned Sale can coordinate the deal.
    Customer and Owner see *only the counterparty* once the Sale-mediated
    contract has documents and has been finalized by the customer.
    """
    viewer_id = claims["sub"]
    role = "admin" if claims.get("role") == "admin" else None
    if role is None:
        if viewer_id == journey.customer_id:
            role = "customer"
        elif viewer_id == journey.owner_id:
            role = "owner"
        elif viewer_id == journey.sale_id:
            role = "sale"
        else:
            # Callers should already have applied object authorization.  Keep
            # the result non-disclosing even if this service is reused.
            return {"available": False, "reason": "NOT_A_PARTICIPANT", "contacts": []}

    sale_mediated = journey.sale_id is not None
    documents_complete = bool(journey.contract_urls)
    finalized = journey.status == journey_policy.COMPLETED
    if role in {"admin", "sale"}:
        allowed = True
        reason = CONTACT_AVAILABLE
    elif not sale_mediated:
        allowed = False
        reason = SALE_REQUIRED
    elif not documents_complete:
        allowed = False
        reason = CONTRACT_REQUIRED
    elif not finalized:
        allowed = False
        reason = CONTRACT_NOT_FINALIZED
    else:
        allowed = True
        reason = CONTACT_AVAILABLE

    contacts: list[dict] = []
    if allowed:
        if role in {"admin", "sale"}:
            participant_ids = (
                ("customer", journey.customer_id),
                ("owner", journey.owner_id),
            )
        elif role == "customer":
            participant_ids = (("owner", journey.owner_id),)
        else:
            participant_ids = (("customer", journey.customer_id),)
        for participant_role, user_id in participant_ids:
            user = db.get(models.User, user_id)
            if user is not None:
                contacts.append(
                    {
                        "role": participant_role,
                        "id": user.id,
                        "name": user.name,
                        "phone": user.phone or "",
                        "email": user.email or "",
                    }
                )

    return {
        "available": allowed,
        "reason": reason,
        "sale_mediated": sale_mediated,
        "documents_complete": documents_complete,
        "contract_finalized": finalized,
        "contacts": contacts,
    }


def can_reveal_for_appointment(
    db: Session,
    *,
    appointment_id: int,
    viewer_id: Optional[int],
    customer_id: int,
    owner_id: Optional[int],
    sale_id: Optional[int],
    is_admin: bool = False,
) -> bool:
    """Whether a raw Customer<->Owner phone is permitted in an appointment.

    Sale/admin retain the operational contact view.  A person looking at their
    own data also keeps their own phone; only *counterparty* disclosure is
    gated here.
    """
    if viewer_id is None or is_admin:
        return False
    if viewer_id == sale_id:
        return True
    if viewer_id not in {customer_id, owner_id}:
        return False
    if owner_id is None:
        return False
    return _completed_sale_mediated_journey(
        db,
        appointment_id=appointment_id,
        customer_id=customer_id,
        owner_id=owner_id,
    ) is not None
