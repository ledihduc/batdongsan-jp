"""Read model nhật ký hợp nhất — CHỈ ĐỌC.

Bốn nguồn sự thật vẫn nằm nguyên ở bảng gốc; lớp này gom về một dạng:
  admin    → admin_action_logs (backoffice V2)
  legacy   → audit_logs (xuất TT200…, đường cũ)
  change   → change_logs (hợp đồng/hoá đơn/uỷ quyền, gồm lệnh admin_* cũ)
  activity → activity_audit_events (lệnh Activity v2)

Mỗi nguồn nạp tối đa `PER_SOURCE_CAP` dòng mới nhất khớp bộ lọc rồi trộn theo
thời gian (giống work_items). Trang sâu hơn mức đó → `truncated=True`; tổng vẫn
đúng vì đếm bằng COUNT riêng. Không có endpoint ghi.
"""

from __future__ import annotations

import json
import logging
from dataclasses import dataclass
from datetime import datetime
from typing import Any, Callable, Optional

from sqlalchemy.orm import Session

from app import models
from app.observability.redaction import redact_obj
from app.services.admin_v2.core import iso, user_brief

logger = logging.getLogger(__name__)

PER_SOURCE_CAP = 1000
SOURCE_CODES = ("admin", "legacy", "change", "activity")
_MAX_JSON_CHARS = 20_000


@dataclass
class AuditFilter:
    sources: tuple[str, ...] = SOURCE_CODES
    actor_id: Optional[int] = None
    action: str = ""            # tiền tố
    entity_type: str = ""
    entity_id: str = ""
    date_from: Optional[datetime] = None
    date_to: Optional[datetime] = None


def _parse(value: Any) -> Any:
    """Cột Text chứa JSON (change_logs) → dict; hỏng thì giữ chuỗi (cắt ngắn)."""
    if value is None or value == "":
        return None
    if isinstance(value, (dict, list)):
        out = value
    else:
        try:
            out = json.loads(value)
        except (TypeError, ValueError):
            return {"raw": str(value)[:2000]}
    raw = json.dumps(out, ensure_ascii=False, default=str)
    if len(raw) > _MAX_JSON_CHARS:
        return {"truncated": True, "preview": raw[:2000]}
    # Nhật ký cũ có thể chứa SĐT/CCCD/token → che trước khi trả.
    return redact_obj(out)


@dataclass
class _Src:
    code: str
    model: Any
    created: Any                           # cột thời gian
    actor_cols: tuple                      # cột khớp actor_id
    action_col: Any
    entity_type: Callable[[Any], Any]      # hàm(filter value) → điều kiện hoặc None
    entity_id_col: Any
    entity_id_is_int: bool
    to_row: Callable[[Session, Any, dict], dict]


def _admin_row(db: Session, r: models.AdminActionLog, cache: dict) -> dict:
    return {
        "actor": user_brief(db, r.actor_user_id, cache),
        "action": r.action, "entity_type": r.entity_type, "entity_id": r.entity_id,
        "reason": r.reason, "before": _parse(r.before_json), "after": _parse(r.after_json),
        "result": r.result, "request_id": r.request_id,
    }


def _legacy_row(db: Session, r: models.AuditLog, cache: dict) -> dict:
    extra = _parse(r.extra)
    after = {"period": r.period, "success": bool(r.success)}
    if extra is not None:
        after["extra"] = extra
    if r.acted_via_delegation_id:
        after["acted_via_delegation_id"] = r.acted_via_delegation_id
    if r.on_behalf_of_user_id:
        after["on_behalf_of_user_id"] = r.on_behalf_of_user_id
    return {
        "actor": user_brief(db, r.actor_user_id or r.host_id, cache),
        "action": r.action, "entity_type": "host", "entity_id": str(r.host_id),
        "reason": None, "before": None, "after": after,
        "result": "success" if r.success else "failure", "request_id": None,
    }


def _change_row(db: Session, r: models.ChangeLog, cache: dict) -> dict:
    after = _parse(r.after_json)
    reason = after.get("reason") if isinstance(after, dict) and isinstance(after.get("reason"), str) else None
    meta = {}
    if r.on_behalf_of_user_id:
        meta["on_behalf_of"] = user_brief(db, r.on_behalf_of_user_id, cache)
    if r.acted_via_delegation_id:
        meta["acted_via_delegation_id"] = r.acted_via_delegation_id
    return {
        "actor": user_brief(db, r.actor_id, cache),
        "action": r.action, "entity_type": r.entity_type, "entity_id": str(r.entity_id),
        "reason": reason, "before": _parse(r.before_json), "after": after,
        "result": "success", "request_id": None, **({"context": meta} if meta else {}),
    }


def _activity_row(db: Session, r: models.ActivityAuditEvent, cache: dict) -> dict:
    return {
        "actor": user_brief(db, r.actor_user_id, cache),
        "action": r.action, "entity_type": r.target_type, "entity_id": str(r.target_id),
        "reason": None, "before": None, "after": _parse(r.payload),
        "result": "success", "request_id": None,
    }


def _sources() -> dict[str, _Src]:
    A, L, C, E = models.AdminActionLog, models.AuditLog, models.ChangeLog, models.ActivityAuditEvent
    return {
        "admin": _Src("admin", A, A.created_at, (A.actor_user_id,), A.action,
                      lambda v: A.entity_type == v, A.entity_id, False, _admin_row),
        "legacy": _Src("legacy", L, L.created_at, (L.actor_user_id, L.host_id), L.action,
                       lambda v: None if v == "host" else False, L.host_id, True, _legacy_row),
        "change": _Src("change", C, C.created_at, (C.actor_id,), C.action,
                       lambda v: C.entity_type == v, C.entity_id, True, _change_row),
        "activity": _Src("activity", E, E.created_at, (E.actor_user_id,), E.action,
                         lambda v: E.target_type == v, E.target_id, True, _activity_row),
    }


def _query(db: Session, s: _Src, f: AuditFilter):
    """Trả Query đã lọc, hoặc None nếu bộ lọc chắc chắn không khớp nguồn này."""
    from sqlalchemy import or_

    q = db.query(s.model)
    if f.actor_id is not None:
        q = q.filter(or_(*[c == f.actor_id for c in s.actor_cols]))
    if f.action:
        esc = f.action.replace("\\", "\\\\").replace("%", "\\%").replace("_", "\\_")
        q = q.filter(s.action_col.like(esc + "%", escape="\\"))
    if f.entity_type:
        cond = s.entity_type(f.entity_type)
        if cond is False:
            return None
        if cond is not None:
            q = q.filter(cond)
    if f.entity_id:
        if s.entity_id_is_int:
            if not f.entity_id.isdigit():
                return None
            q = q.filter(s.entity_id_col == int(f.entity_id))
        else:
            q = q.filter(s.entity_id_col == f.entity_id)
    if f.date_from is not None:
        q = q.filter(s.created >= f.date_from)
    if f.date_to is not None:
        q = q.filter(s.created <= f.date_to)
    return q


def collect(db: Session, f: AuditFilter, *, offset: int, limit: int) -> tuple[list[dict], int, bool, dict, list[str]]:
    """→ (trang dữ liệu, tổng, truncated, đếm theo nguồn, nguồn lỗi)."""
    srcs = _sources()
    need = min(offset + limit, PER_SOURCE_CAP)
    merged: list[tuple[datetime, str, int, Any]] = []
    counts: dict[str, int] = {}
    failed: list[str] = []
    truncated = False
    for code in f.sources:
        s = srcs.get(code)
        if s is None:
            continue
        try:
            q = _query(db, s, f)
            if q is None:
                counts[code] = 0
                continue
            counts[code] = q.order_by(None).count()
            rows = q.order_by(s.created.desc(), s.model.id.desc()).limit(need).all()
        except Exception as exc:  # noqa: BLE001 — một nguồn hỏng (bảng chưa migrate) không làm trống cả trang
            db.rollback()
            logger.warning("audit source %s failed: %s", code, exc)
            counts[code] = -1
            failed.append(code)
            continue
        if counts[code] > PER_SOURCE_CAP and offset + limit > PER_SOURCE_CAP:
            truncated = True
        for r in rows:
            merged.append((getattr(r, s.created.key) or datetime.min, code, int(r.id), r))
    merged.sort(key=lambda t: (t[0], t[1], t[2]), reverse=True)
    page = merged[offset: offset + limit]
    cache: dict = {}
    data = []
    for created, code, rid, r in page:
        body = srcs[code].to_row(db, r, cache)
        data.append({"id": f"{code}:{rid}", "source": code, **body, "created_at": iso(created)})
    total = sum(v for v in counts.values() if v > 0)
    return data, total, truncated, counts, failed
