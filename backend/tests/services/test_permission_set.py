"""Tests for app/services/permission_set.py — permission matrix (Phase 02).

Table-driven: every preset × every declared action tested for grant/deny.
This ensures the matrix stays correct as actions accumulate (CI fails if missing).
"""

from __future__ import annotations

import pytest

from app.services.permission_set import (
    # Presets
    OWNER_VIEW_PERMISSIONS,
    OPERATOR_FULL_PERMISSIONS,
    ACCOUNTANT_PERMISSIONS,
    VIEWER_PERMISSIONS,
    VALID_PRESETS,
    owner_self_permissions,
    preset_to_permissions,
    is_lockdown_blocked,
    is_mutation_action,
    # Action constants
    BUILDING_READ,
    BUILDING_CREATE,
    BUILDING_UPDATE,
    BUILDING_DELETE,
    ROOM_READ,
    ROOM_CREATE,
    ROOM_UPDATE,
    ROOM_DELETE,
    TENANT_READ,
    TENANT_CREATE,
    TENANT_UPDATE,
    CONTRACT_READ,
    CONTRACT_CREATE,
    CONTRACT_UPDATE,
    CONTRACT_TERMINATE,
    INVOICE_READ,
    INVOICE_CREATE,
    INVOICE_RECORD_PAYMENT,
    METER_READING_CREATE,
    SERVICE_FEE_UPDATE,
    REFUND_CREATE,
    KHAIBAO_SUBMIT,
    HOST_PROFILE_UPDATE_BASIC,
    HOST_PROFILE_UPDATE_BANK,
    HOST_PROFILE_UPDATE_CCCD,
    HOST_PROFILE_REVEAL_BANK,
    DELEGATION_READ_OWN,
    DELEGATION_ACCEPT,
    DELEGATION_REJECT,
    DELEGATION_RESIGN,
    DELEGATION_UPDATE_THRESHOLD,
    DELEGATION_UPDATE_SCOPE,
    APPROVAL_READ_OWN_INBOX,
    APPROVAL_DECIDE,
    AUDIT_READ_OWN,
    AUDIT_EXPORT,
    MARKETPLACE_LISTING_UPDATE,
)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def _check(preset: str, action: str, expected: bool) -> None:
    """Assert action grant/deny for a given preset."""
    permissions = preset_to_permissions(preset)
    actual = action in permissions
    assert actual == expected, (
        f"Preset '{preset}' action '{action}': "
        f"expected {'GRANT' if expected else 'DENY'}, got {'GRANT' if actual else 'DENY'}"
    )


# ---------------------------------------------------------------------------
# owner_view preset — READ only (AC-18 owner self-mode while delegated)
# ---------------------------------------------------------------------------


class TestOwnerViewPreset:
    """owner_view: all reads allowed, NO mutations."""

    GRANTED = [
        BUILDING_READ, ROOM_READ, TENANT_READ, CONTRACT_READ, INVOICE_READ,
        DELEGATION_READ_OWN, DELEGATION_ACCEPT, DELEGATION_REJECT, DELEGATION_RESIGN,
        APPROVAL_READ_OWN_INBOX, AUDIT_READ_OWN,
    ]

    DENIED = [
        BUILDING_CREATE, BUILDING_UPDATE, BUILDING_DELETE,
        ROOM_CREATE, ROOM_UPDATE, ROOM_DELETE,
        TENANT_CREATE, TENANT_UPDATE,
        CONTRACT_CREATE, CONTRACT_UPDATE, CONTRACT_TERMINATE,
        INVOICE_CREATE, INVOICE_RECORD_PAYMENT,
        METER_READING_CREATE, SERVICE_FEE_UPDATE, REFUND_CREATE, KHAIBAO_SUBMIT,
        HOST_PROFILE_UPDATE_BASIC, HOST_PROFILE_UPDATE_BANK, HOST_PROFILE_UPDATE_CCCD,
        HOST_PROFILE_REVEAL_BANK,
        DELEGATION_UPDATE_THRESHOLD, DELEGATION_UPDATE_SCOPE,
        APPROVAL_DECIDE, AUDIT_EXPORT,
        MARKETPLACE_LISTING_UPDATE,
    ]

    @pytest.mark.parametrize("action", GRANTED)
    def test_granted(self, action: str) -> None:
        _check("owner_view", action, expected=True)

    @pytest.mark.parametrize("action", DENIED)
    def test_denied(self, action: str) -> None:
        _check("owner_view", action, expected=False)


# ---------------------------------------------------------------------------
# operator_full preset — most mutations allowed (AC-20)
# ---------------------------------------------------------------------------


class TestOperatorFullPreset:
    """operator_full: operational mutations granted; owner-exclusive denied (AC-20)."""

    GRANTED = [
        BUILDING_READ, ROOM_READ, TENANT_READ, CONTRACT_READ, INVOICE_READ,
        ROOM_CREATE, ROOM_UPDATE,
        TENANT_CREATE, TENANT_UPDATE,
        CONTRACT_CREATE, CONTRACT_UPDATE, CONTRACT_TERMINATE,
        INVOICE_CREATE, INVOICE_RECORD_PAYMENT,
        METER_READING_CREATE, SERVICE_FEE_UPDATE, REFUND_CREATE, KHAIBAO_SUBMIT,
        HOST_PROFILE_UPDATE_BASIC, HOST_PROFILE_REVEAL_BANK,
        DELEGATION_READ_OWN, DELEGATION_ACCEPT, DELEGATION_REJECT, DELEGATION_RESIGN,
        APPROVAL_READ_OWN_INBOX, AUDIT_READ_OWN,
        MARKETPLACE_LISTING_UPDATE,
    ]

    DENIED = [
        BUILDING_CREATE, BUILDING_UPDATE, BUILDING_DELETE,
        ROOM_DELETE,
        HOST_PROFILE_UPDATE_BANK, HOST_PROFILE_UPDATE_CCCD,
        DELEGATION_UPDATE_THRESHOLD, DELEGATION_UPDATE_SCOPE,
        APPROVAL_DECIDE, AUDIT_EXPORT,
    ]

    @pytest.mark.parametrize("action", GRANTED)
    def test_granted(self, action: str) -> None:
        _check("operator_full", action, expected=True)

    @pytest.mark.parametrize("action", DENIED)
    def test_denied(self, action: str) -> None:
        _check("operator_full", action, expected=False)


# ---------------------------------------------------------------------------
# accountant preset — financial ops only (AC-21)
# ---------------------------------------------------------------------------


class TestAccountantPreset:
    """accountant: financial ops + reads; no operational changes."""

    GRANTED = [
        BUILDING_READ, ROOM_READ, TENANT_READ, CONTRACT_READ, INVOICE_READ,
        INVOICE_CREATE, INVOICE_RECORD_PAYMENT,
        METER_READING_CREATE, REFUND_CREATE,
        HOST_PROFILE_REVEAL_BANK,
        DELEGATION_READ_OWN, DELEGATION_ACCEPT, DELEGATION_REJECT, DELEGATION_RESIGN,
        APPROVAL_READ_OWN_INBOX, AUDIT_READ_OWN,
    ]

    DENIED = [
        BUILDING_CREATE, BUILDING_UPDATE, BUILDING_DELETE,
        ROOM_CREATE, ROOM_UPDATE, ROOM_DELETE,
        TENANT_CREATE, TENANT_UPDATE,
        CONTRACT_CREATE, CONTRACT_UPDATE, CONTRACT_TERMINATE,
        SERVICE_FEE_UPDATE, KHAIBAO_SUBMIT,
        HOST_PROFILE_UPDATE_BASIC, HOST_PROFILE_UPDATE_BANK, HOST_PROFILE_UPDATE_CCCD,
        DELEGATION_UPDATE_THRESHOLD, DELEGATION_UPDATE_SCOPE,
        APPROVAL_DECIDE, AUDIT_EXPORT,
        MARKETPLACE_LISTING_UPDATE,
    ]

    @pytest.mark.parametrize("action", GRANTED)
    def test_granted(self, action: str) -> None:
        _check("accountant", action, expected=True)

    @pytest.mark.parametrize("action", DENIED)
    def test_denied(self, action: str) -> None:
        _check("accountant", action, expected=False)


# ---------------------------------------------------------------------------
# viewer preset — read-only
# ---------------------------------------------------------------------------


class TestViewerPreset:
    """viewer: read-only (identical to owner_view but separate preset)."""

    GRANTED = [
        BUILDING_READ, ROOM_READ, TENANT_READ, CONTRACT_READ, INVOICE_READ,
        DELEGATION_READ_OWN, DELEGATION_ACCEPT, DELEGATION_REJECT, DELEGATION_RESIGN,
        APPROVAL_READ_OWN_INBOX, AUDIT_READ_OWN,
    ]

    DENIED = [
        BUILDING_CREATE, BUILDING_UPDATE, BUILDING_DELETE,
        ROOM_CREATE, ROOM_UPDATE, ROOM_DELETE,
        TENANT_CREATE, TENANT_UPDATE,
        CONTRACT_CREATE, CONTRACT_UPDATE, CONTRACT_TERMINATE,
        INVOICE_CREATE, INVOICE_RECORD_PAYMENT,
        METER_READING_CREATE, SERVICE_FEE_UPDATE, REFUND_CREATE, KHAIBAO_SUBMIT,
        HOST_PROFILE_UPDATE_BASIC, HOST_PROFILE_UPDATE_BANK, HOST_PROFILE_UPDATE_CCCD,
        HOST_PROFILE_REVEAL_BANK,
        DELEGATION_UPDATE_THRESHOLD, DELEGATION_UPDATE_SCOPE,
        APPROVAL_DECIDE, AUDIT_EXPORT,
        MARKETPLACE_LISTING_UPDATE,
    ]

    @pytest.mark.parametrize("action", GRANTED)
    def test_granted(self, action: str) -> None:
        _check("viewer", action, expected=True)

    @pytest.mark.parametrize("action", DENIED)
    def test_denied(self, action: str) -> None:
        _check("viewer", action, expected=False)


# ---------------------------------------------------------------------------
# preset_to_permissions() error handling
# ---------------------------------------------------------------------------


class TestPresetToPermissions:
    def test_unknown_preset_raises_value_error(self) -> None:
        with pytest.raises(ValueError, match="Unknown role_preset"):
            preset_to_permissions("super_admin")

    def test_returns_frozenset(self) -> None:
        for preset in VALID_PRESETS:
            result = preset_to_permissions(preset)
            assert isinstance(result, frozenset), f"{preset} did not return frozenset"

    def test_frozenset_is_immutable(self) -> None:
        """Regression: permission_set must be immutable (can't accidentally mutate in handler)."""
        perm = preset_to_permissions("operator_full")
        with pytest.raises((AttributeError, TypeError)):
            perm.add("fake.action")  # type: ignore[attr-defined]


# ---------------------------------------------------------------------------
# owner_self_permissions()
# ---------------------------------------------------------------------------


class TestOwnerSelfPermissions:
    def test_includes_owner_exclusive_actions(self) -> None:
        perms = owner_self_permissions()
        for action in [
            BUILDING_CREATE, BUILDING_DELETE, ROOM_DELETE,
            HOST_PROFILE_UPDATE_BANK, HOST_PROFILE_UPDATE_CCCD,
            DELEGATION_UPDATE_THRESHOLD, DELEGATION_UPDATE_SCOPE,
            APPROVAL_DECIDE, AUDIT_EXPORT,
        ]:
            assert action in perms, f"owner_self_permissions missing '{action}'"

    def test_returns_frozenset(self) -> None:
        assert isinstance(owner_self_permissions(), frozenset)


# ---------------------------------------------------------------------------
# is_lockdown_blocked() — AC-43
# ---------------------------------------------------------------------------


class TestIsLockdownBlocked:
    BLOCKED = [
        CONTRACT_CREATE, CONTRACT_TERMINATE, INVOICE_CREATE,
        REFUND_CREATE, KHAIBAO_SUBMIT, SERVICE_FEE_UPDATE,
        MARKETPLACE_LISTING_UPDATE,
    ]
    ALLOWED = [CONTRACT_READ, INVOICE_READ, BUILDING_READ]

    @pytest.mark.parametrize("action", BLOCKED)
    def test_blocked_during_terminating(self, action: str) -> None:
        assert is_lockdown_blocked(action) is True

    @pytest.mark.parametrize("action", ALLOWED)
    def test_allowed_during_terminating(self, action: str) -> None:
        assert is_lockdown_blocked(action) is False


# ---------------------------------------------------------------------------
# is_mutation_action() — AC-18
# ---------------------------------------------------------------------------


class TestIsMutationAction:
    MUTATIONS = [
        ROOM_CREATE, ROOM_UPDATE, TENANT_CREATE, TENANT_UPDATE,
        CONTRACT_CREATE, CONTRACT_UPDATE, CONTRACT_TERMINATE,
        INVOICE_CREATE, INVOICE_RECORD_PAYMENT,
        METER_READING_CREATE, SERVICE_FEE_UPDATE, REFUND_CREATE, KHAIBAO_SUBMIT,
        HOST_PROFILE_UPDATE_BASIC, MARKETPLACE_LISTING_UPDATE,
    ]
    NON_MUTATIONS = [
        BUILDING_READ, ROOM_READ, TENANT_READ, CONTRACT_READ,
        HOST_PROFILE_UPDATE_BANK,   # owner-only → NOT in mutation set (AC-18)
        HOST_PROFILE_UPDATE_CCCD,   # owner-only → NOT in mutation set
    ]

    @pytest.mark.parametrize("action", MUTATIONS)
    def test_is_mutation(self, action: str) -> None:
        assert is_mutation_action(action) is True

    @pytest.mark.parametrize("action", NON_MUTATIONS)
    def test_is_not_mutation(self, action: str) -> None:
        assert is_mutation_action(action) is False
