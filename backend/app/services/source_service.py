"""source_service — CRUD cho revenue_sources.

AC-07:
- Không hard-delete nếu source đang được dùng (>= 1 reservation/contract liên kết).
- Archive = soft delete (is_archived=True), vẫn giữ trong báo cáo cũ.
- Unique constraint: UNIQUE(host_id, name) WHERE is_archived=FALSE.
  (SQLAlchemy layer check — DB có full unique constraint nhưng ta check app layer vì
   SQLite không hỗ trợ partial index natively).
- AC-17: source archived → reservation giữ source_id cũ, vẫn group đúng trong báo cáo.
"""

from __future__ import annotations

from datetime import datetime

from fastapi import HTTPException
from sqlalchemy import func
from sqlalchemy.orm import Session

from app import models


def _assert_owner(db: Session, host_id: int, source_id: int) -> models.RevenueSource:
    """IDOR check: source phải thuộc host. Raise 404 nếu không tìm thấy."""
    source = (
        db.query(models.RevenueSource)
        .filter(
            models.RevenueSource.id == source_id,
            models.RevenueSource.host_id == host_id,
        )
        .first()
    )
    if not source:
        raise HTTPException(status_code=404, detail="revenue_source_not_found")
    return source


def _to_dict(source: models.RevenueSource) -> dict:
    return {
        "id": source.id,
        "host_id": source.host_id,
        "name": source.name,
        "color_hex": source.color_hex,
        "is_archived": source.is_archived,
        "created_at": source.created_at.isoformat() if source.created_at else None,
        "updated_at": source.updated_at.isoformat() if source.updated_at else None,
    }


def _check_duplicate_active_name(
    db: Session, host_id: int, name: str, exclude_id: int | None = None
) -> None:
    """Raise 409 nếu tồn tại active source cùng tên (partial unique constraint app-layer)."""
    q = db.query(models.RevenueSource).filter(
        models.RevenueSource.host_id == host_id,
        models.RevenueSource.name == name,
        models.RevenueSource.is_archived.is_(False),
    )
    if exclude_id is not None:
        q = q.filter(models.RevenueSource.id != exclude_id)
    existing = q.first()
    if existing:
        raise HTTPException(
            status_code=409,
            detail=f"revenue_source_name_conflict: '{name}' đã tồn tại (active)",
        )


def list_sources(
    db: Session, host_id: int, include_archived: bool = False
) -> list[dict]:
    """Danh sách sources của host.

    include_archived=False (default): chỉ active sources.
    include_archived=True: cả archived (dùng cho management screen).
    """
    q = db.query(models.RevenueSource).filter(
        models.RevenueSource.host_id == host_id
    )
    if not include_archived:
        q = q.filter(models.RevenueSource.is_archived.is_(False))
    q = q.order_by(models.RevenueSource.name)
    return [_to_dict(s) for s in q.all()]


def create_source(
    db: Session, host_id: int, name: str, color_hex: str
) -> dict:
    """Tạo revenue source mới.

    Validate UNIQUE(host_id, name) WHERE is_archived=FALSE.
    Archived source cùng tên → cho phép (AC-07 edge case).
    """
    if not name or not name.strip():
        raise HTTPException(status_code=400, detail="source_name_required")
    if not color_hex or len(color_hex) != 7 or not color_hex.startswith("#"):
        raise HTTPException(
            status_code=400,
            detail="color_hex phải có định dạng #RRGGBB (7 ký tự)",
        )

    _check_duplicate_active_name(db, host_id, name.strip())

    source = models.RevenueSource(
        host_id=host_id,
        name=name.strip(),
        color_hex=color_hex,
        is_archived=False,
        created_at=datetime.utcnow(),
        updated_at=datetime.utcnow(),
    )
    db.add(source)
    db.flush()
    return _to_dict(source)


def update_source(
    db: Session,
    host_id: int,
    source_id: int,
    name: str | None = None,
    color_hex: str | None = None,
) -> dict:
    """Cập nhật tên/màu source.

    IDOR check. Nếu đổi tên → check không trùng active source khác.
    """
    source = _assert_owner(db, host_id, source_id)

    if name is not None:
        name = name.strip()
        if not name:
            raise HTTPException(status_code=400, detail="source_name_required")
        if name != source.name:
            _check_duplicate_active_name(db, host_id, name, exclude_id=source_id)
        source.name = name

    if color_hex is not None:
        if len(color_hex) != 7 or not color_hex.startswith("#"):
            raise HTTPException(
                status_code=400,
                detail="color_hex phải có định dạng #RRGGBB",
            )
        source.color_hex = color_hex

    source.updated_at = datetime.utcnow()
    db.flush()
    return _to_dict(source)


def archive_source(db: Session, host_id: int, source_id: int) -> dict:
    """Soft delete: set is_archived=True.

    Source vẫn tồn tại trong DB và hiển thị trong báo cáo cũ (AC-17).
    Giải phóng name slot: append suffix '_archived_{id}' để cho phép tạo lại
    source cùng tên (AC-07 edge case: partial unique constraint app-layer).
    """
    source = _assert_owner(db, host_id, source_id)
    if source.is_archived:
        raise HTTPException(
            status_code=400,
            detail="revenue_source_already_archived",
        )
    source.is_archived = True
    # Giải phóng tên để cho phép tạo source mới cùng tên (AC-07 partial unique)
    source.name = f"{source.name}__archived_{source_id}"
    source.updated_at = datetime.utcnow()
    db.flush()
    return _to_dict(source)


def delete_source(db: Session, host_id: int, source_id: int) -> None:
    """Hard delete — chỉ cho phép khi source CHƯA BỀN CÓ reservation/contract.

    AC-07: nếu count > 0 → raise HTTPException(409, "source_in_use").
    """
    source = _assert_owner(db, host_id, source_id)

    # Kiểm tra có reservation/contract liên kết không
    res_count = (
        db.query(func.count(models.Reservation.id))
        .filter(models.Reservation.source_id == source_id)
        .scalar()
    ) or 0

    contract_count = (
        db.query(func.count(models.Contract.id))
        .filter(models.Contract.source_id == source_id)
        .scalar()
    ) or 0

    if int(res_count) + int(contract_count) > 0:
        raise HTTPException(
            status_code=409,
            detail="source_in_use",
        )

    db.delete(source)
    db.flush()


# ── Dual-write helper (Phase 04 wrap-up — un-defer 0017 NOT NULL) ─────────────
# Reservation.source / Contract.source giữ giá trị chuỗi cũ; nay cần thêm FK
# source_id trên mỗi INSERT để migration 0018 có thể enforce NOT NULL.

_SOURCE_LABEL_TO_NAME: dict[str, str] = {
    "direct": "Trực tiếp",
    "marketplace": "Marketplace nội bộ",
    "manual": "Khác",
}
_SOURCE_LABEL_TO_COLOR: dict[str, str] = {
    "direct": "#4CAF50",
    "marketplace": "#2196F3",
    "manual": "#9E9E9E",
}


def resolve_default_source_id(db: Session, host_id: int, source: str) -> int:
    """Map source string → host's RevenueSource.id. Idempotent + auto-create.

    Used by reservation_service / contract_service / marketplace_sync_service
    để dual-write FK source_id. Migration 0012 seed sources cho mọi host
    đang có reservation/contract, nhưng host mới (sau 0012) chưa có →
    helper tự tạo (UNIQUE(host_id, name) → race-safe ở mức ORM).

    source unknown → fallback "Khác".
    """
    name = _SOURCE_LABEL_TO_NAME.get(source, _SOURCE_LABEL_TO_NAME["manual"])
    color = _SOURCE_LABEL_TO_COLOR.get(source, _SOURCE_LABEL_TO_COLOR["manual"])

    existing = (
        db.query(models.RevenueSource.id)
        .filter(
            models.RevenueSource.host_id == host_id,
            models.RevenueSource.name == name,
        )
        .scalar()
    )
    if existing is not None:
        return existing

    now = datetime.utcnow()
    rs = models.RevenueSource(
        host_id=host_id,
        name=name,
        color_hex=color,
        is_archived=False,
        created_at=now,
        updated_at=now,
    )
    db.add(rs)
    db.flush()
    return rs.id
