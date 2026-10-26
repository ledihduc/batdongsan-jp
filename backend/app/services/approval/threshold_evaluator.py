"""Threshold evaluator — AC-31b five-threshold check logic (Phase 04).

Determines if an operator action exceeds a delegation's configured thresholds,
requiring owner approval before the action can proceed.

Five thresholds (AC-31b):
  - monthly_spend_threshold_vnd    → mapped to delegation.threshold_monthly_rent_vnd
  - per_transaction_threshold_vnd  → mapped to delegation.threshold_expense_vnd
  - lease_value_threshold_vnd      → derived from monthly_rent × term_months vs threshold
  - lease_duration_threshold_months → mapped to delegation.threshold_term_months
  - tenant_change_threshold_per_quarter → mapped to delegation.threshold_rent_change_pct
    (NOTE: BA uses this column for both rent-change-pct and is repurposed per action_type)

Action types:
  contract_create        → checks lease_value (monthly_rent * term_months) + term_months
  contract_terminate     → ALWAYS requires approval (AC-27) — no threshold gate
  invoice_high_amount    → checks expense vs threshold_expense_vnd
  expense_high_amount    → same as invoice
  rent_change            → checks delta_pct vs threshold_rent_change_pct
  refund_high_amount     → checks amount vs threshold_refund_vnd
  cash_payment           → checks amount vs threshold_expense_vnd; auto-approve if < threshold
  kb04_fast_track        → always requires approval (KB04 carve-out AC-55)
  kb04_pre_file          → always requires approval (KB04 pre-file AC-55b)
  fraud_termination      → always requires approval with fraud_termination_24h SLA (AC-43b)
  threshold_change       → always requires approval (owner must approve own-threshold change)
"""

from __future__ import annotations

import logging
from dataclasses import dataclass
from decimal import Decimal
from typing import Optional

logger = logging.getLogger(__name__)

# Biometric trigger threshold (AC-29b)
BIOMETRIC_THRESHOLD_VND = Decimal("50000000")  # 50M VND


@dataclass
class ThresholdResult:
    """Result of threshold evaluation for an operator action."""

    requires_approval: bool
    reason: str
    sla_class: str  # default_72h | kb04_fast_track_6h | fraud_termination_24h
    requested_amount_vnd: Optional[Decimal]
    requires_biometric: bool


class ThresholdEvaluator:
    """Evaluates whether an operator action requires owner approval.

    Stateless — no DB access. Called from service layer with delegation + payload.
    Caller ensures delegation is active (not paused/terminated).
    """

    def evaluate(
        self,
        action_type: str,
        delegation: object,  # app.domain.delegation.Delegation — avoid circular import
        payload: dict,
    ) -> ThresholdResult:
        """Evaluate if action requires approval based on delegation thresholds.

        Args:
            action_type: one of the action type constants (e.g. 'contract_create')
            delegation: Delegation ORM row with threshold_* columns populated
            payload: dict with action-specific fields for threshold computation

        Returns:
            ThresholdResult with requires_approval + metadata
        """
        # Dispatch to action-specific evaluator
        evaluators = {
            "contract_create": self._eval_contract_create,
            "contract_terminate": self._eval_always_approve,
            "invoice_high_amount": self._eval_invoice_expense,
            "expense_high_amount": self._eval_invoice_expense,
            "rent_change": self._eval_rent_change,
            "refund_high_amount": self._eval_refund,
            "cash_payment": self._eval_cash_payment,
            "kb04_fast_track": self._eval_kb04_fast_track,
            "kb04_pre_file": self._eval_kb04_pre_file,
            "fraud_termination": self._eval_fraud_termination,
            "threshold_change": self._eval_threshold_change,
        }

        evaluator_fn = evaluators.get(action_type)
        if evaluator_fn is None:
            logger.warning(
                "[THRESHOLD] Unknown action_type=%s — defaulting to requires approval",
                action_type,
            )
            return ThresholdResult(
                requires_approval=True,
                reason=f"Unknown action type '{action_type}' — conservative approval required",
                sla_class="default_72h",
                requested_amount_vnd=None,
                requires_biometric=False,
            )

        result = evaluator_fn(delegation, payload)
        # AC-29b: biometric required if amount >= 50M VND
        if result.requested_amount_vnd is not None:
            result = ThresholdResult(
                requires_approval=result.requires_approval,
                reason=result.reason,
                sla_class=result.sla_class,
                requested_amount_vnd=result.requested_amount_vnd,
                requires_biometric=(result.requested_amount_vnd >= BIOMETRIC_THRESHOLD_VND),
            )
        return result

    # ------------------------------------------------------------------
    # Action-specific evaluators
    # ------------------------------------------------------------------

    def _eval_contract_create(self, delegation: object, payload: dict) -> ThresholdResult:
        """AC-24: contract creation — checks lease value + term months."""
        monthly_rent = Decimal(str(payload.get("monthly_rent_vnd", 0)))
        term_months = int(payload.get("term_months", 0))
        lease_value = monthly_rent * term_months

        threshold_monthly = Decimal(str(getattr(delegation, "threshold_monthly_rent_vnd", 0)))
        threshold_months = int(getattr(delegation, "threshold_term_months", 0))

        monthly_exceeded = monthly_rent > threshold_monthly
        months_exceeded = term_months > threshold_months

        if monthly_exceeded or months_exceeded:
            reasons = []
            if monthly_exceeded:
                reasons.append(
                    f"monthly_rent {monthly_rent:,.0f}đ > threshold {threshold_monthly:,.0f}đ"
                )
            if months_exceeded:
                reasons.append(
                    f"term_months {term_months} > threshold {threshold_months}"
                )
            return ThresholdResult(
                requires_approval=True,
                reason="; ".join(reasons),
                sla_class="default_72h",
                requested_amount_vnd=lease_value,
                requires_biometric=False,  # updated by caller
            )

        return ThresholdResult(
            requires_approval=False,
            reason="Within threshold",
            sla_class="default_72h",
            requested_amount_vnd=lease_value,
            requires_biometric=False,
        )

    def _eval_always_approve(self, delegation: object, payload: dict) -> ThresholdResult:
        """AC-27: contract termination always requires approval."""
        return ThresholdResult(
            requires_approval=True,
            reason="Contract termination always requires owner approval (AC-27)",
            sla_class="default_72h",
            requested_amount_vnd=None,
            requires_biometric=False,
        )

    def _eval_invoice_expense(self, delegation: object, payload: dict) -> ThresholdResult:
        """AC-25: invoice/expense — checks amount vs threshold_expense_vnd."""
        amount = Decimal(str(payload.get("amount_vnd", 0)))
        threshold = Decimal(str(getattr(delegation, "threshold_expense_vnd", 0)))

        if amount > threshold:
            return ThresholdResult(
                requires_approval=True,
                reason=f"Amount {amount:,.0f}đ > threshold {threshold:,.0f}đ",
                sla_class="default_72h",
                requested_amount_vnd=amount,
                requires_biometric=False,
            )
        return ThresholdResult(
            requires_approval=False,
            reason="Within expense threshold",
            sla_class="default_72h",
            requested_amount_vnd=amount,
            requires_biometric=False,
        )

    def _eval_rent_change(self, delegation: object, payload: dict) -> ThresholdResult:
        """AC-26: rent change — checks percentage delta vs threshold_rent_change_pct."""
        old_rent = Decimal(str(payload.get("old_monthly_rent_vnd", 0)))
        new_rent = Decimal(str(payload.get("new_monthly_rent_vnd", 0)))
        threshold_pct = Decimal(str(getattr(delegation, "threshold_rent_change_pct", 0)))

        if old_rent <= 0:
            # Cannot compute delta — require approval for safety
            return ThresholdResult(
                requires_approval=True,
                reason="Cannot compute rent change pct: old_rent is 0",
                sla_class="default_72h",
                requested_amount_vnd=new_rent,
                requires_biometric=False,
            )

        delta_pct = ((new_rent - old_rent) / old_rent) * Decimal("100")

        if delta_pct > threshold_pct:
            return ThresholdResult(
                requires_approval=True,
                reason=(
                    f"Rent change {delta_pct:.1f}% > threshold {threshold_pct:.1f}%"
                ),
                sla_class="default_72h",
                requested_amount_vnd=new_rent,
                requires_biometric=False,
            )
        return ThresholdResult(
            requires_approval=False,
            reason=f"Rent change {delta_pct:.1f}% within threshold",
            sla_class="default_72h",
            requested_amount_vnd=new_rent,
            requires_biometric=False,
        )

    def _eval_refund(self, delegation: object, payload: dict) -> ThresholdResult:
        """AC-28: refund — checks amount vs threshold_refund_vnd."""
        amount = Decimal(str(payload.get("amount_vnd", 0)))
        threshold = Decimal(str(getattr(delegation, "threshold_refund_vnd", 0)))

        if amount > threshold:
            return ThresholdResult(
                requires_approval=True,
                reason=f"Refund {amount:,.0f}đ > threshold {threshold:,.0f}đ",
                sla_class="default_72h",
                requested_amount_vnd=amount,
                requires_biometric=False,
            )
        return ThresholdResult(
            requires_approval=False,
            reason="Within refund threshold",
            sla_class="default_72h",
            requested_amount_vnd=amount,
            requires_biometric=False,
        )

    def _eval_cash_payment(self, delegation: object, payload: dict) -> ThresholdResult:
        """AC-32b: cash payment — auto-approve if below threshold AND evidence present.

        Evidence = location + photo provided by operator.
        If amount >= threshold OR no evidence → normal approval flow.
        """
        amount = Decimal(str(payload.get("amount_vnd", 0)))
        threshold = Decimal(str(getattr(delegation, "threshold_expense_vnd", 0)))
        has_location = bool(payload.get("location_lat") and payload.get("location_lng"))
        has_photo = bool(payload.get("photo_url"))

        evidence_present = has_location and has_photo
        amount_within = amount < threshold

        if amount_within and evidence_present:
            return ThresholdResult(
                requires_approval=False,
                reason="Cash payment within threshold with location+photo evidence",
                sla_class="default_72h",
                requested_amount_vnd=amount,
                requires_biometric=False,
            )
        reason_parts = []
        if not amount_within:
            reason_parts.append(f"Amount {amount:,.0f}đ >= threshold {threshold:,.0f}đ")
        if not evidence_present:
            reason_parts.append("Missing location or photo evidence")
        return ThresholdResult(
            requires_approval=True,
            reason="; ".join(reason_parts) if reason_parts else "Cash payment requires approval",
            sla_class="default_72h",
            requested_amount_vnd=amount,
            requires_biometric=False,
        )

    def _eval_kb04_fast_track(self, delegation: object, payload: dict) -> ThresholdResult:
        """AC-55: KB04 always requires approval with 6h fast-track SLA.

        For operator_full preset: approval created with auto-approve (system decides).
        For other presets: owner must approve within 6h.
        Role preset check is done in KB04WorkflowService — here we just flag approval needed.
        """
        return ThresholdResult(
            requires_approval=True,
            reason="KB04 tenant registration always requires owner co-sign (AC-55)",
            sla_class="kb04_fast_track_6h",
            requested_amount_vnd=None,
            requires_biometric=False,
        )

    def _eval_kb04_pre_file(self, delegation: object, payload: dict) -> ThresholdResult:
        """AC-55b: KB04 pre-file — always requires approval (pre-move-in filing)."""
        return ThresholdResult(
            requires_approval=True,
            reason="KB04 pre-file always requires owner approval (AC-55b)",
            sla_class="kb04_fast_track_6h",
            requested_amount_vnd=None,
            requires_biometric=False,
        )

    def _eval_fraud_termination(self, delegation: object, payload: dict) -> ThresholdResult:
        """AC-43b: fraud termination — requires approval with 24h SLA."""
        return ThresholdResult(
            requires_approval=True,
            reason="Fraud termination requires owner approval with 24h SLA (AC-43b)",
            sla_class="fraud_termination_24h",
            requested_amount_vnd=None,
            requires_biometric=False,
        )

    def _eval_threshold_change(self, delegation: object, payload: dict) -> ThresholdResult:
        """Threshold change requires owner approval."""
        return ThresholdResult(
            requires_approval=True,
            reason="Delegation threshold change requires owner approval",
            sla_class="default_72h",
            requested_amount_vnd=None,
            requires_biometric=False,
        )
