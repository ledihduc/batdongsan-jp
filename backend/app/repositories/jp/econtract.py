"""Repository for JpEContract.

Multi-tenant isolation: every list query MUST filter by org_id.
"""

from __future__ import annotations

from typing import Optional

from sqlalchemy.orm import Session

from app.domain.jp.econtract import JpEContract


class JpEContractRepository:
    """Org-scoped CRUD for jp_econtracts."""

    def __init__(self, db: Session) -> None:
        self.db = db

    def get_by_id_org(
        self, econtract_id: int, org_id: str
    ) -> Optional[JpEContract]:
        return (
            self.db.query(JpEContract)
            .filter(
                JpEContract.id == econtract_id,
                JpEContract.org_id == org_id,  # MULTI-TENANT ISOLATION
            )
            .first()
        )

    def get_by_remote_doc_id(
        self, remote_doc_id: str
    ) -> Optional[JpEContract]:
        """Lookup by CloudSign document ID (for webhook correlation)."""
        return (
            self.db.query(JpEContract)
            .filter(JpEContract.remote_doc_id == remote_doc_id)
            .first()
        )

    def get_by_application(
        self, application_id: int, org_id: str
    ) -> Optional[JpEContract]:
        return (
            self.db.query(JpEContract)
            .filter(
                JpEContract.application_id == application_id,
                JpEContract.org_id == org_id,  # MULTI-TENANT ISOLATION
            )
            .first()
        )

    def create(
        self,
        org_id: str,
        application_id: int,
        template_version: Optional[str] = "1.0",
        provider: str = "cloudsign",
    ) -> JpEContract:
        row = JpEContract(
            org_id=org_id,
            application_id=application_id,
            provider=provider,
            template_version=template_version,
            status="draft",
        )
        self.db.add(row)
        self.db.flush()
        return row

    def update_status(
        self,
        econtract: JpEContract,
        status: str,
        remote_doc_id: Optional[str] = None,
        signed_pdf_url: Optional[str] = None,
    ) -> JpEContract:
        econtract.status = status
        if remote_doc_id is not None:
            econtract.remote_doc_id = remote_doc_id
        if signed_pdf_url is not None:
            econtract.signed_pdf_url = signed_pdf_url
        self.db.flush()
        return econtract
