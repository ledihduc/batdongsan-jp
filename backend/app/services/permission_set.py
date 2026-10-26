"""Permission matrix for Owner-Operator Delegation (Phase 02).

Defines 4 preset roles per BA v4 §3, AC-19/20/21.
Each preset maps to a frozenset of action strings — immutable by design
so no handler can accidentally mutate permissions at runtime.

Source of truth: phase-02-permission-and-actor-context.md § Permission matrix.
"""

from __future__ import annotations

from typing import Final


# ---------------------------------------------------------------------------
# Action registry
# ---------------------------------------------------------------------------
# Each constant names a permission action.  Callers reference these constants
# rather than raw strings to avoid typos.

# building
BUILDING_READ: Final = "building.read"
BUILDING_CREATE: Final = "building.create"
BUILDING_UPDATE: Final = "building.update"
BUILDING_DELETE: Final = "building.delete"

# room
ROOM_READ: Final = "room.read"
ROOM_CREATE: Final = "room.create"
ROOM_UPDATE: Final = "room.update"
ROOM_DELETE: Final = "room.delete"

# tenant
TENANT_READ: Final = "tenant.read"
TENANT_CREATE: Final = "tenant.create"
TENANT_UPDATE: Final = "tenant.update"

# contract
CONTRACT_READ: Final = "contract.read"
CONTRACT_CREATE: Final = "contract.create"
CONTRACT_UPDATE: Final = "contract.update"
CONTRACT_TERMINATE: Final = "contract.terminate"

# invoice
INVOICE_READ: Final = "invoice.read"
INVOICE_CREATE: Final = "invoice.create"
INVOICE_RECORD_PAYMENT: Final = "invoice.record_payment"

# meter reading
METER_READING_CREATE: Final = "meter_reading.create"

# service fee
SERVICE_FEE_UPDATE: Final = "service_fee.update"

# refund
REFUND_CREATE: Final = "refund.create"

# khai bao
KHAIBAO_SUBMIT: Final = "khaibao.submit"

# host profile
HOST_PROFILE_UPDATE_BASIC: Final = "host_profile.update_basic"
HOST_PROFILE_UPDATE_BANK: Final = "host_profile.update_bank"
HOST_PROFILE_UPDATE_CCCD: Final = "host_profile.update_cccd"
HOST_PROFILE_REVEAL_BANK: Final = "host_profile.reveal_bank"

# delegation self-management (operators can read/accept/reject/resign their own)
DELEGATION_READ_OWN: Final = "delegation.read_own"
DELEGATION_ACCEPT: Final = "delegation.accept"
DELEGATION_REJECT: Final = "delegation.reject"
DELEGATION_RESIGN: Final = "delegation.resign"
DELEGATION_UPDATE_THRESHOLD: Final = "delegation.update_threshold"
DELEGATION_UPDATE_SCOPE: Final = "delegation.update_scope"

# approval
APPROVAL_READ_OWN_INBOX: Final = "approval.read_own_inbox"
APPROVAL_DECIDE: Final = "approval.decide"

# audit
AUDIT_READ_OWN: Final = "audit.read_own"
AUDIT_EXPORT: Final = "audit.export"

# marketplace
MARKETPLACE_LISTING_UPDATE: Final = "marketplace.listing.update"

# ---------------------------------------------------------------------------
# Preset definitions
# ---------------------------------------------------------------------------

# All READ actions shared across every preset (AC-19 mandates all presets can read).
_READ_ACTIONS: frozenset[str] = frozenset(
    [
        BUILDING_READ,
        ROOM_READ,
        TENANT_READ,
        CONTRACT_READ,
        INVOICE_READ,
        DELEGATION_READ_OWN,
        DELEGATION_ACCEPT,
        DELEGATION_REJECT,
        DELEGATION_RESIGN,
        APPROVAL_READ_OWN_INBOX,
        AUDIT_READ_OWN,
    ]
)

# owner_view — read-only mirror of what owner sees (AC-18 self mode when delegated).
# NO mutation actions.
OWNER_VIEW_PERMISSIONS: Final[frozenset[str]] = _READ_ACTIONS

# operator_full — can perform most operational mutations (AC-20).
# Excludes owner-only actions: building.create/update/delete, room.delete,
# host_profile.update_bank/cccd, delegation.update_threshold/scope, approval.decide, audit.export.
OPERATOR_FULL_PERMISSIONS: Final[frozenset[str]] = _READ_ACTIONS | frozenset(
    [
        ROOM_CREATE,
        ROOM_UPDATE,
        TENANT_CREATE,
        TENANT_UPDATE,
        CONTRACT_CREATE,
        CONTRACT_UPDATE,
        CONTRACT_TERMINATE,
        INVOICE_CREATE,
        INVOICE_RECORD_PAYMENT,
        METER_READING_CREATE,
        SERVICE_FEE_UPDATE,
        REFUND_CREATE,
        KHAIBAO_SUBMIT,
        HOST_PROFILE_UPDATE_BASIC,
        HOST_PROFILE_REVEAL_BANK,
        MARKETPLACE_LISTING_UPDATE,
    ]
)

# accountant — can handle financials but not operational changes (AC-21).
ACCOUNTANT_PERMISSIONS: Final[frozenset[str]] = _READ_ACTIONS | frozenset(
    [
        INVOICE_CREATE,
        INVOICE_RECORD_PAYMENT,
        METER_READING_CREATE,
        REFUND_CREATE,
        HOST_PROFILE_REVEAL_BANK,
    ]
)

# viewer — read-only (stricter subset; no delegation self-service mutation).
VIEWER_PERMISSIONS: Final[frozenset[str]] = _READ_ACTIONS


# ---------------------------------------------------------------------------
# Preset registry
# ---------------------------------------------------------------------------

_PRESET_MAP: Final[dict[str, frozenset[str]]] = {
    "owner_view": OWNER_VIEW_PERMISSIONS,
    "operator_full": OPERATOR_FULL_PERMISSIONS,
    "accountant": ACCOUNTANT_PERMISSIONS,
    "viewer": VIEWER_PERMISSIONS,
}

# All valid preset names — used for validation.
VALID_PRESETS: Final[frozenset[str]] = frozenset(_PRESET_MAP.keys())


def preset_to_permissions(role_preset: str) -> frozenset[str]:
    """Return the permission frozenset for a given role_preset name.

    Raises ValueError for unknown presets so misconfigured delegations fail fast.
    """
    if role_preset not in _PRESET_MAP:
        raise ValueError(
            f"Unknown role_preset '{role_preset}'. "
            f"Valid presets: {sorted(VALID_PRESETS)}"
        )
    return _PRESET_MAP[role_preset]


# ---------------------------------------------------------------------------
# Owner self-acting — full access (legacy path, AC-47/48)
# ---------------------------------------------------------------------------

def owner_self_permissions() -> frozenset[str]:
    """Full permission set for owner acting without delegation.

    The owner self-acting path does NOT use the permission matrix — this returns
    a sentinel frozenset that has_permission() always resolves to True for
    backward-compatibility with existing require_host endpoints.
    Exposed here so ActorContext can store a typed value.
    """
    # Combine all action strings from every preset + owner-exclusive actions.
    _all: set[str] = set()
    for perm_set in _PRESET_MAP.values():
        _all.update(perm_set)
    _all.update(
        [
            BUILDING_CREATE,
            BUILDING_UPDATE,
            BUILDING_DELETE,
            ROOM_DELETE,
            HOST_PROFILE_UPDATE_BANK,
            HOST_PROFILE_UPDATE_CCCD,
            DELEGATION_UPDATE_THRESHOLD,
            DELEGATION_UPDATE_SCOPE,
            APPROVAL_DECIDE,
            AUDIT_EXPORT,
        ]
    )
    return frozenset(_all)


# ---------------------------------------------------------------------------
# Lockdown (AC-43) — which actions are BLOCKED during terminating phase
# ---------------------------------------------------------------------------

# Tier 1 — BLOCKED outright during 30d termination lockdown.
_LOCKDOWN_BLOCKED_ACTIONS: Final[frozenset[str]] = frozenset(
    [
        CONTRACT_CREATE,
        CONTRACT_TERMINATE,
        INVOICE_CREATE,
        REFUND_CREATE,
        KHAIBAO_SUBMIT,
        SERVICE_FEE_UPDATE,
        MARKETPLACE_LISTING_UPDATE,
    ]
)


def is_lockdown_blocked(action: str) -> bool:
    """True if action is in the BLOCKED tier during delegation terminating phase (AC-43)."""
    return action in _LOCKDOWN_BLOCKED_ACTIONS


# ---------------------------------------------------------------------------
# Mutation detection — used for AC-18 owner-self-mutate block
# ---------------------------------------------------------------------------

# State-changing actions that the operator can ALSO perform (so they are
# meaningful to block for the owner while delegation is active).
# Reads are never in this set.
_MUTATION_ACTIONS: Final[frozenset[str]] = frozenset(
    [
        ROOM_CREATE,
        ROOM_UPDATE,
        ROOM_DELETE,
        TENANT_CREATE,
        TENANT_UPDATE,
        CONTRACT_CREATE,
        CONTRACT_UPDATE,
        CONTRACT_TERMINATE,
        INVOICE_CREATE,
        INVOICE_RECORD_PAYMENT,
        METER_READING_CREATE,
        SERVICE_FEE_UPDATE,
        REFUND_CREATE,
        KHAIBAO_SUBMIT,
        HOST_PROFILE_UPDATE_BASIC,
        MARKETPLACE_LISTING_UPDATE,
    ]
)


def is_mutation_action(action: str) -> bool:
    """True if action is state-changing on an entity the operator could also touch.

    Bank/CCCD/tax updates are owner-only → NOT in mutation set → owner block
    does NOT apply (AC-18 only restricts overlapping actions).
    """
    return action in _MUTATION_ACTIONS
