"""Tests for app/services/actor_context.py (Phase 02).

Covers:
  - ActorContext.effective_owner_id
  - ActorContext.is_acting_on_behalf
  - ActorContext.has_permission
  - ActorContext.is_in_scope (all scope_type variants)
  - build_owner_context (no delegation path)
  - build_operator_context (delegation path)
"""

from __future__ import annotations

import uuid
from dataclasses import FrozenInstanceError
from typing import Optional
from unittest.mock import MagicMock

import pytest

from app.services.actor_context import (
    ActorContext,
    build_operator_context,
    build_owner_context,
)
from app.services.permission_set import (
    CONTRACT_CREATE,
    CONTRACT_READ,
    INVOICE_CREATE,
    BUILDING_READ,
    owner_self_permissions,
    preset_to_permissions,
)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def _make_delegation(
    id: str | None = None,
    owner_id: int = 10,
    operator_id: int = 20,
    status: str = "active",
    role_preset: str = "operator_full",
    scope_type: str = "all",
    scope_target_ids=None,
) -> MagicMock:
    """Build a mock Delegation object for testing."""
    d = MagicMock()
    d.id = id or str(uuid.uuid4())
    d.owner_id = owner_id
    d.operator_id = operator_id
    d.status = status
    d.role_preset = role_preset
    d.scope_type = scope_type
    d.scope_target_ids = scope_target_ids
    return d


# ---------------------------------------------------------------------------
# ActorContext properties
# ---------------------------------------------------------------------------


class TestActorContextProperties:
    def _make_self_ctx(self, actor_user_id: int = 5) -> ActorContext:
        return ActorContext(
            actor_user_id=actor_user_id,
            on_behalf_of_user_id=None,
            delegation_id=None,
            scope_type=None,
            scope_target_building_ids=None,
            permission_set=owner_self_permissions(),
            actor_role="host",
            request_id=str(uuid.uuid4()),
        )

    def _make_delegated_ctx(
        self,
        actor: int = 20,
        owner: int = 10,
        scope_type: str = "all",
        scope_ids: Optional[list[int]] = None,
        role_preset: str = "operator_full",
    ) -> ActorContext:
        return ActorContext(
            actor_user_id=actor,
            on_behalf_of_user_id=owner,
            delegation_id=str(uuid.uuid4()),
            scope_type=scope_type,
            scope_target_building_ids=scope_ids,
            permission_set=preset_to_permissions(role_preset),
            actor_role="operator",
            request_id=str(uuid.uuid4()),
        )

    # effective_owner_id

    def test_effective_owner_id_self_acting(self) -> None:
        ctx = self._make_self_ctx(actor_user_id=7)
        assert ctx.effective_owner_id == 7

    def test_effective_owner_id_delegated(self) -> None:
        ctx = self._make_delegated_ctx(actor=20, owner=10)
        assert ctx.effective_owner_id == 10

    # is_acting_on_behalf

    def test_not_acting_on_behalf_self(self) -> None:
        ctx = self._make_self_ctx()
        assert ctx.is_acting_on_behalf is False

    def test_is_acting_on_behalf_delegated(self) -> None:
        ctx = self._make_delegated_ctx()
        assert ctx.is_acting_on_behalf is True

    # has_permission

    def test_owner_self_has_all_permissions(self) -> None:
        ctx = self._make_self_ctx()
        for action in [CONTRACT_CREATE, INVOICE_CREATE, CONTRACT_READ, BUILDING_READ]:
            assert ctx.has_permission(action) is True

    def test_viewer_has_read_not_write(self) -> None:
        ctx = self._make_delegated_ctx(role_preset="viewer")
        assert ctx.has_permission(CONTRACT_READ) is True
        assert ctx.has_permission(CONTRACT_CREATE) is False

    def test_unknown_action_denied(self) -> None:
        ctx = self._make_delegated_ctx(role_preset="viewer")
        assert ctx.has_permission("fake.nonexistent.action") is False

    # is_in_scope

    def test_self_acting_always_in_scope(self) -> None:
        ctx = self._make_self_ctx()
        assert ctx.is_in_scope(building_id=99) is True

    def test_scope_all_always_in_scope(self) -> None:
        ctx = self._make_delegated_ctx(scope_type="all")
        assert ctx.is_in_scope(building_id=1) is True
        assert ctx.is_in_scope(building_id=9999) is True

    def test_scope_building_list_in_scope(self) -> None:
        ctx = self._make_delegated_ctx(scope_type="building_list", scope_ids=[1, 2, 3])
        assert ctx.is_in_scope(1) is True
        assert ctx.is_in_scope(3) is True

    def test_scope_building_list_out_of_scope(self) -> None:
        ctx = self._make_delegated_ctx(scope_type="building_list", scope_ids=[1, 2, 3])
        assert ctx.is_in_scope(4) is False
        assert ctx.is_in_scope(99) is False

    def test_scope_empty_building_list_always_denied(self) -> None:
        ctx = self._make_delegated_ctx(scope_type="building_list", scope_ids=[])
        assert ctx.is_in_scope(1) is False

    def test_scope_none_ids_means_denied(self) -> None:
        """scope_type=building_list but no IDs → behave as empty list."""
        ctx = self._make_delegated_ctx(scope_type="building_list", scope_ids=None)
        assert ctx.is_in_scope(1) is False

    # Immutability (frozen dataclass)

    def test_context_is_frozen(self) -> None:
        ctx = self._make_self_ctx()
        with pytest.raises((FrozenInstanceError, AttributeError)):
            # Direct attribute assignment must fail on a frozen dataclass.
            ctx.actor_user_id = 999  # type: ignore[misc]


# ---------------------------------------------------------------------------
# build_owner_context
# ---------------------------------------------------------------------------


class TestBuildOwnerContext:
    def test_no_delegation_fields(self) -> None:
        ctx = build_owner_context(actor_user_id=5, actor_role="host")
        assert ctx.on_behalf_of_user_id is None
        assert ctx.delegation_id is None
        assert ctx.scope_type is None
        assert ctx.scope_target_building_ids is None
        assert ctx.is_acting_on_behalf is False

    def test_effective_owner_is_self(self) -> None:
        ctx = build_owner_context(actor_user_id=5, actor_role="host")
        assert ctx.effective_owner_id == 5

    def test_custom_request_id_preserved(self) -> None:
        rid = "my-request-id-123"
        ctx = build_owner_context(actor_user_id=1, actor_role="host", request_id=rid)
        assert ctx.request_id == rid

    def test_auto_request_id_generated(self) -> None:
        ctx = build_owner_context(actor_user_id=1, actor_role="host")
        assert ctx.request_id  # non-empty

    def test_has_full_permissions(self) -> None:
        ctx = build_owner_context(actor_user_id=1, actor_role="host")
        from app.services.permission_set import (
            BUILDING_DELETE, HOST_PROFILE_UPDATE_BANK, AUDIT_EXPORT
        )
        for action in [BUILDING_DELETE, HOST_PROFILE_UPDATE_BANK, AUDIT_EXPORT]:
            assert ctx.has_permission(action) is True


# ---------------------------------------------------------------------------
# build_operator_context
# ---------------------------------------------------------------------------


class TestBuildOperatorContext:
    def test_basic_operator_context(self) -> None:
        d = _make_delegation(owner_id=10, operator_id=20, role_preset="operator_full")
        ctx = build_operator_context(actor_user_id=20, actor_role="operator", delegation=d)
        assert ctx.actor_user_id == 20
        assert ctx.on_behalf_of_user_id == 10
        assert ctx.delegation_id == d.id
        assert ctx.is_acting_on_behalf is True
        assert ctx.effective_owner_id == 10

    def test_scope_all(self) -> None:
        d = _make_delegation(scope_type="all")
        ctx = build_operator_context(actor_user_id=20, actor_role="operator", delegation=d)
        assert ctx.scope_type == "all"
        assert ctx.is_in_scope(1) is True
        assert ctx.is_in_scope(9999) is True

    def test_scope_building_list_parsed(self) -> None:
        d = _make_delegation(scope_type="building_list", scope_target_ids=[5, 6, 7])
        ctx = build_operator_context(actor_user_id=20, actor_role="operator", delegation=d)
        assert ctx.scope_target_building_ids == [5, 6, 7]
        assert ctx.is_in_scope(5) is True
        assert ctx.is_in_scope(8) is False

    def test_scope_string_ids_coerced_to_int(self) -> None:
        """Scope IDs from JSON may be strings — must be coerced to int."""
        d = _make_delegation(scope_type="building_list", scope_target_ids=["1", "2", "3"])
        ctx = build_operator_context(actor_user_id=20, actor_role="operator", delegation=d)
        assert ctx.scope_target_building_ids == [1, 2, 3]

    def test_unknown_preset_raises(self) -> None:
        d = _make_delegation(role_preset="super_admin_unknown")
        with pytest.raises(ValueError, match="Unknown role_preset"):
            build_operator_context(actor_user_id=20, actor_role="operator", delegation=d)

    def test_viewer_preset_permissions(self) -> None:
        d = _make_delegation(role_preset="viewer")
        ctx = build_operator_context(actor_user_id=20, actor_role="operator", delegation=d)
        assert ctx.has_permission(CONTRACT_READ) is True
        assert ctx.has_permission(CONTRACT_CREATE) is False

    def test_scope_none_ids_yields_none(self) -> None:
        """scope_type='all' with scope_target_ids=None → building_ids stays None."""
        d = _make_delegation(scope_type="all", scope_target_ids=None)
        ctx = build_operator_context(actor_user_id=20, actor_role="operator", delegation=d)
        assert ctx.scope_target_building_ids is None
