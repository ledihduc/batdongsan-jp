"""KYC service package — operator individual, business, and owner attestation flows.

Phase 05: Onboarding & KYC Extensions.

Public surface:
    operator_individual_service  — wraps existing host KYC; sets kyc_expires_at.
    operator_business_service    — greenfield business operator KYC.
    owner_attestation_service    — AC-64 sole-ownership, AC-65 legal-rep change, AC-66 disclosure.
    digital_signature/           — FastCA / VinaCA / Stub provider interface.
"""
