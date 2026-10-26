"""Maker-checker: thao tác cực nhạy chỉ chạy khi một người KHÁC duyệt.

Vòng đời: DRAFT (người lập còn sửa được) → PENDING (chờ người duyệt độc lập)
→ APPROVED (executor đã chạy) | REJECTED | CANCELLED (người lập thu hồi).

Module nghiệp vụ đăng ký từng loại:

    register("refund_record", permission="payments.refund", label=..., executor=fn,
             describe=fn, validate=fn?, preview=fn?)

- `executor(db, approver_ctx, payload) -> dict` chạy trong transaction của lệnh
  duyệt, KHÔNG commit (run_command commit một lần cùng nhật ký).
- `validate(db, payload) -> payload` chuẩn hoá/kiểm khi tạo/sửa nháp (raise fail()).
- `preview(db, payload) -> [{label, before, after, delta?}]` bảng "dự kiến sau
  khi duyệt" — tính lại MỖI lần xem, nên phản ánh số liệu hiện tại.
"""

from __future__ import annotations

from dataclasses import dataclass
from typing import Callable, Optional

from sqlalchemy.orm import Session

from app import models
from app.services.admin_v2.core import AdminContext, fail, iso, user_brief

STATUSES = ("DRAFT", "PENDING", "APPROVED", "REJECTED", "CANCELLED")


@dataclass
class Kind:
    permission: str
    label: str
    executor: Callable[[Session, AdminContext, dict], dict]
    describe: Callable[[Session, dict], str]
    validate: Optional[Callable[[Session, dict], dict]] = None
    preview: Optional[Callable[[Session, dict], list]] = None
    links: Optional[Callable[[Session, dict], list]] = None


_REGISTRY: dict[str, Kind] = {}


def register(code: str, *, permission: str, label: str, executor, describe, validate=None, preview=None,
             links=None) -> None:
    _REGISTRY[code] = Kind(permission=permission, label=label, executor=executor, describe=describe,
                           validate=validate, preview=preview, links=links)


def kind_of(code: str) -> Kind:
    k = _REGISTRY.get(code)
    if k is None:
        raise fail(422, "ADMIN_UNKNOWN_CHANGE_KIND", "Loại yêu cầu không hỗ trợ")
    return k


def kinds() -> dict[str, Kind]:
    return dict(_REGISTRY)


def create(db: Session, ctx: AdminContext, *, kind: str, payload: dict, reason: str,
           status: str = "PENDING") -> models.AdminChangeRequest:
    k = kind_of(kind)
    if status not in ("DRAFT", "PENDING"):
        raise fail(422, "ADMIN_BAD_STATUS", "Trạng thái yêu cầu không hợp lệ")
    if k.validate:
        payload = k.validate(db, payload)
    row = models.AdminChangeRequest(
        kind=kind, payload=payload, reason=reason, status=status, requested_by=ctx.user_id,
    )
    db.add(row)
    db.flush()
    return row


def version_of(r: models.AdminChangeRequest) -> str:
    from app.services.admin_v2.core import etag

    return etag(r.id, r.status, r.payload, r.reason)


def _steps(r: models.AdminChangeRequest, cache: dict, db: Session) -> list[dict]:
    """Quy trình 4 bước hiển thị ở trang chi tiết."""
    created = {"key": "created", "label": "Tạo yêu cầu", "state": "done",
               "by": user_brief(db, r.requested_by, cache), "at": iso(r.requested_at)}
    if r.status == "DRAFT":
        created = {**created, "label": "Bản nháp", "state": "current"}
    waiting_state = {"DRAFT": "todo", "PENDING": "current"}.get(r.status, "done")
    waiting = {"key": "pending", "label": "Chờ người duyệt", "state": waiting_state, "by": None, "at": None}
    if r.status in ("APPROVED", "REJECTED", "CANCELLED"):
        label = {"APPROVED": "Đã duyệt và ghi nhận", "REJECTED": "Bị từ chối", "CANCELLED": "Người lập đã thu hồi"}[r.status]
        decided = {"key": "decided", "label": label, "state": "done" if r.status == "APPROVED" else "stopped",
                   "by": user_brief(db, r.decided_by, cache), "at": iso(r.decided_at)}
    else:
        decided = {"key": "decided", "label": "Đã duyệt và ghi nhận", "state": "todo", "by": None, "at": None}
    finished = {"key": "finished", "label": "Đã hoàn tất",
                "state": "done" if r.status == "APPROVED" else "todo", "by": None,
                "at": iso(r.decided_at) if r.status == "APPROVED" else None}
    return [created, waiting, decided, finished]


def to_dict(db: Session, r: models.AdminChangeRequest, cache: dict | None = None, *, detail: bool = False) -> dict:
    cache = cache if cache is not None else {}
    k = _REGISTRY.get(r.kind)
    out = {
        "id": r.id,
        "ref": f"PD-{r.id:05d}",
        "kind": r.kind,
        "kind_label": k.label if k else r.kind,
        "summary": k.describe(db, r.payload or {}) if k else "",
        "payload": r.payload,
        "reason": r.reason,
        "status": r.status,
        "requested_by": user_brief(db, r.requested_by, cache),
        "requested_at": iso(r.requested_at),
        "decided_by": user_brief(db, r.decided_by, cache),
        "decided_at": iso(r.decided_at),
        "decision_note": r.decision_note,
        "result": r.result_json,
        "required_permission": k.permission if k else None,
        "version": version_of(r),
    }
    if detail:
        out["steps"] = _steps(r, cache, db)
        preview: list = []
        if k and k.preview and r.status in ("DRAFT", "PENDING"):
            try:
                preview = k.preview(db, r.payload or {})
            except Exception:  # noqa: BLE001 — xem trước lỗi không được chặn trang duyệt
                preview = []
        out["preview"] = preview
        out["links"] = (k.links(db, r.payload or {}) if (k and k.links) else [])
    return out
