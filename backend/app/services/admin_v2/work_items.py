"""Hộp việc vận hành hợp nhất — read model trên các hàng đợi SẴN CÓ.

Không có bảng "công việc" mới: mỗi nguồn (tin chờ duyệt, báo cáo, cọc chờ xác
minh…) vẫn là nguồn sự thật. Lớp này chỉ gom lại, tính hạn SLA, phủ lên thông
tin điều phối từ `admin_cases` (ai phụ trách, ưu tiên, ghi chú).

Mỗi nguồn khai một `Source`. Thêm hàng đợi mới = thêm một Source.
"""

from __future__ import annotations

import logging
from dataclasses import dataclass
from datetime import datetime, timedelta
from typing import Any, Callable, Optional

from sqlalchemy import inspect as sa_inspect
from sqlalchemy.orm import Session

from app import models
from app.services.admin_v2.core import AdminContext, iso, user_brief, utcnow

logger = logging.getLogger(__name__)

MODULES = {
    "moderation": "Kiểm duyệt",
    "operations": "Vận hành thuê",
    "finance": "Tài chính",
    "compliance": "Tin cậy & pháp lý",
    "partners": "Đối tác",
    "system": "Hệ thống",
}


PRIORITY_ORDER = {"urgent": 0, "high": 1, "normal": 2, "low": 3}

# Mỗi nguồn nạp tối đa chừng này mục mở để xếp SLA toàn cục; vượt thì meta báo
# `truncated` (đếm tổng vẫn chính xác vì đếm bằng COUNT riêng).
PER_SOURCE_CAP = 400


@dataclass
class Source:
    code: str
    label: str
    module: str
    permission: str
    sla_hours: float
    prefix: str
    default_priority: str
    query: Callable[[Session], Any]          # trả Query đã lọc mục MỞ
    created: Callable[[Any], Optional[datetime]]
    title: Callable[[Session, Any], str]
    subtitle: Callable[[Session, Any], str]
    link: Callable[[Any], str]
    people: Callable[[Any], list[int]] = lambda row: []


def _domain():
    from app.domain.operator_business import OperatorBusinessProfile
    from app.domain.owner_death import OwnerDeathCertificate
    from app.domain.service_request import ServiceRequest
    from app.domain.tenant_authority import TenantAuthorityFlag

    return OperatorBusinessProfile, OwnerDeathCertificate, ServiceRequest, TenantAuthorityFlag


def _house_title(db: Session, house_id: Optional[int]) -> str:
    if not house_id:
        return ""
    h = db.get(models.House, house_id)
    return (h.title or "")[:80] if h else ""


def _money(v) -> str:
    try:
        return f"{int(v or 0):,}".replace(",", ".") + " ₫"
    except (TypeError, ValueError):
        return ""


def build_sources() -> list[Source]:
    OBP, ODC, SR, TAF = _domain()
    J = models.RentalJourney
    stalled_cutoff = lambda: utcnow() - timedelta(hours=72)  # noqa: E731
    return [
        Source(
            "listing_review", "Duyệt tin đăng", "moderation", "listings.read", 4, "TIN", "normal",
            lambda db: db.query(models.House).filter(models.House.status == "pending_review"),
            lambda r: r.created_at,
            lambda db, r: (r.title or "Tin đăng")[:80],
            lambda db, r: ", ".join(x for x in (r.district, r.city) if x),
            lambda r: f"/admin/content/listings/{r.id}",
            lambda r: [r.host_id],
        ),
        Source(
            "content_report", "Báo cáo nội dung", "moderation", "content.read", 12, "BC", "high",
            lambda db: db.query(models.ContentReport).filter(
                models.ContentReport.status == "pending", models.ContentReport.kind == "violation"),
            lambda r: r.created_at,
            lambda db, r: f"Báo cáo {('tin' if r.target_type == 'house' else 'bài viết')} #{r.target_id}",
            lambda db, r: (r.reason or "khác") + (f" · {r.detail[:60]}" if r.detail else ""),
            lambda r: f"/admin/content/reports?focus={r.id}",
            lambda r: [r.reporter_id],
        ),
        Source(
            "verification", "Thẩm định sao", "moderation", "content.read", 72, "TD", "low",
            lambda db: db.query(models.VerificationRequest).filter(
                models.VerificationRequest.status.in_(("requested", "inspecting"))),
            lambda r: r.created_at,
            lambda db, r: _house_title(db, r.house_id) or f"Tin #{r.house_id}",
            lambda db, r: "Đang kiểm tra" if r.status == "inspecting" else "Chờ thẩm định",
            lambda r: f"/admin/content/verification?focus={r.id}",
            lambda r: [r.host_id],
        ),
        Source(
            "sale_application", "Hồ sơ Sale", "partners", "partners.read", 48, "SA", "normal",
            lambda db: db.query(models.SaleApplication).filter(
                models.SaleApplication.status.in_(("SUBMITTED", "IN_REVIEW"))),
            lambda r: r.submitted_at or r.created_at,
            lambda db, r: r.full_name or "Hồ sơ Sale",
            lambda db, r: ", ".join(r.service_areas or [])[:80] or "Xin quyền Sale",
            lambda r: f"/admin/partners/sale-applications?focus={r.id}",
            lambda r: [r.applicant_user_id],
        ),
        Source(
            "kyc", "Xác minh KYC", "compliance", "compliance.read", 48, "KYC", "normal",
            lambda db: db.query(OBP).filter(OBP.verification_status == "pending"),
            lambda r: r.created_at,
            lambda db, r: r.business_name or "Hồ sơ doanh nghiệp",
            lambda db, r: f"GPKD {r.business_registration_number}",
            lambda r: f"/admin/compliance/kyc?focus={r.id}",
            lambda r: [r.user_id],
        ),
        Source(
            "dispute", "Tranh chấp", "compliance", "compliance.read", 48, "TC", "high",
            lambda db: db.query(TAF).filter(TAF.status.in_(("pending", "escalated"))),
            lambda r: r.created_at,
            lambda db, r: "Khiếu nại người vận hành không được uỷ quyền",
            lambda db, r: ("Đã leo thang · " if r.status == "escalated" else "") + (r.report_reason or "")[:60],
            lambda r: f"/admin/compliance/disputes?focus={r.id}",
        ),
        Source(
            "owner_death", "Chủ sở hữu mất", "compliance", "compliance.read", 72, "CSM", "high",
            lambda db: db.query(ODC).filter(ODC.verification_status == "pending"),
            lambda r: r.created_at,
            lambda db, r: "Giấy chứng tử chờ xác minh",
            lambda db, r: f"Chủ sở hữu #{getattr(r, 'owner_user_id', '')}",
            lambda r: f"/admin/compliance/owner-death?focus={r.id}",
        ),
        Source(
            "deposit_review", "Đối soát cọc", "finance", "payments.read", 24, "COC", "high",
            lambda db: db.query(models.RentalJourneyPayment).filter(models.RentalJourneyPayment.status == "SUBMITTED"),
            lambda r: r.submitted_at or r.created_at,
            lambda db, r: ("Cọc nền tảng" if r.kind == "APP_DEPOSIT" else "Cọc chủ nhà") + f" · {_money(r.amount)}",
            lambda db, r: f"Hành trình HT-{r.journey_id:05d} · xác minh chứng từ",
            lambda r: f"/admin/rentals/journeys/{r.journey_id}",
            lambda r: [r.submitted_by],
        ),
        Source(
            "journey_stalled", "Hành trình thuê bị kẹt", "operations", "rental_journeys.read", 72, "HT", "normal",
            lambda db: db.query(J).filter(
                J.status.notin_(("COMPLETED", "CANCELLED", "CUSTOMER_DECLINED")), J.updated_at < stalled_cutoff()),
            lambda r: r.updated_at,
            lambda db, r: _house_title(db, r.house_id) or f"Hành trình #{r.id}",
            lambda db, r: f"Đứng ở {r.status} quá 72 giờ",
            lambda r: f"/admin/rentals/journeys/{r.id}",
            lambda r: [r.customer_id, r.sale_id, r.owner_id],
        ),
        Source(
            "reservation_pending", "Booking chờ xác nhận", "operations", "rental_journeys.read", 2, "BK", "normal",
            lambda db: db.query(models.Reservation).filter(models.Reservation.status == "pending"),
            lambda r: getattr(r, "created_at", None),
            lambda db, r: f"{r.guest_name or 'Khách'} · {r.check_in_date}",
            lambda db, r: f"Phòng #{r.room_id} · {r.nights} đêm",
            lambda r: f"/admin/rentals/reservations/{r.id}",
            lambda r: [r.host_id, r.guest_user_id],
        ),
        Source(
            "journey_report", "Báo cáo trong giao dịch", "operations", "rental_journeys.read", 24, "BCG", "high",
            lambda db: db.query(models.RentalJourneyReport).filter(models.RentalJourneyReport.status == "PENDING"),
            lambda r: r.created_at,
            lambda db, r: f"{r.reason_code} · hành trình HT-{r.journey_id:05d}",
            lambda db, r: (r.detail or "")[:80],
            lambda r: f"/admin/rentals/journeys/{r.journey_id}",
            lambda r: [r.reporter_id, r.reported_user_id],
        ),
        Source(
            "lead", "Lead gọi lại", "partners", "partners.read", 24, "LD", "low",
            lambda db: db.query(models.ContactLead).filter(models.ContactLead.status == "new"),
            lambda r: r.created_at,
            lambda db, r: r.name or "Lead",
            lambda db, r: (r.context or r.source or "")[:80],
            lambda r: f"/admin/partners/leads?focus={r.id}",
        ),
        Source(
            "service_request", "Yêu cầu dịch vụ", "partners", "partners.read", 24, "DV", "normal",
            lambda db: db.query(SR).filter(SR.status == "new"),
            lambda r: r.created_at,
            lambda db, r: f"{r.service_slug} · {r.name}",
            lambda db, r: (r.area or r.location_text or "")[:80],
            lambda r: f"/admin/partners/services?focus={r.id}",
        ),
        Source(
            "manual", "Việc tạo tay", "operations", "work_items.read", 24, "CV", "normal",
            lambda db: db.query(models.AdminCase).filter(
                models.AdminCase.source_type == "manual", models.AdminCase.status != "done"),
            lambda r: r.created_at,
            lambda db, r: r.title or f"Công việc #{r.id}",
            lambda db, r: (r.description or "")[:120],
            lambda r: f"/admin/work/manual/{r.id}",
            lambda r: [r.created_by],
        ),
        Source(
            "push_failed", "Thông báo gửi lỗi", "system", "system.read", 24, "PU", "low",
            lambda db: db.query(models.PushOutbox).filter(
                models.PushOutbox.gui_luc.is_(None), models.PushOutbox.so_lan_thu >= 3),
            lambda r: r.tao_luc,
            lambda db, r: (r.title or "Thông báo")[:80],
            lambda db, r: (r.loi_cuoi or "Gửi thất bại")[:80],
            lambda r: "/admin/system/notifications",
            lambda r: [r.user_id],
        ),
    ]


_SOURCES: Optional[list[Source]] = None


def sources() -> list[Source]:
    global _SOURCES
    if _SOURCES is None:
        _SOURCES = build_sources()
    return _SOURCES


def source(code: str) -> Optional[Source]:
    return next((s for s in sources() if s.code == code), None)


def visible_sources(ctx: AdminContext) -> list[Source]:
    return [s for s in sources() if ctx.has(s.permission)]


def ref_code(src: Source, row_id: Any) -> str:
    try:
        return f"{src.prefix}-{int(row_id):05d}"
    except (TypeError, ValueError):
        return f"{src.prefix}-{row_id}"


def _case_map(db: Session, keys: list[tuple[str, str]]) -> dict:
    if not keys:
        return {}
    codes = {k[0] for k in keys}
    ids = {k[1] for k in keys}
    rows = (
        db.query(models.AdminCase)
        .filter(models.AdminCase.source_type.in_(codes), models.AdminCase.source_id.in_(ids))
        .all()
    )
    return {(c.source_type, c.source_id): c for c in rows}


def to_item(db: Session, src: Source, row: Any, case: Optional[models.AdminCase], now: datetime, cache: dict) -> dict:
    created = src.created(row) or now
    due = case.sla_due_at if (case and case.sla_due_at) else created + timedelta(hours=src.sla_hours)
    remaining = (due - now).total_seconds()
    priority = case.priority if case else src.default_priority
    title = subtitle = ""
    try:
        title = src.title(db, row)
        subtitle = src.subtitle(db, row)
    except Exception as exc:  # noqa: BLE001 — một bản ghi dở không được làm hỏng cả hộp việc
        logger.warning("work item render failed %s#%s: %s", src.code, getattr(row, "id", "?"), exc)
    return {
        "id": f"{src.code}:{row.id}",
        "type": src.code,
        "type_label": src.label,
        "module": src.module,
        "module_label": MODULES[src.module],
        "source_id": str(row.id),
        "ref": ref_code(src, row.id),
        "title": title,
        "subtitle": subtitle,
        "link": src.link(row),
        "created_at": iso(created),
        "sla_due_at": iso(due),
        "sla_seconds_remaining": int(remaining),
        "overdue": remaining < 0,
        "priority": priority,
        "case": None if case is None else {
            "id": case.id,
            "status": case.status,
            "assignee": user_brief(db, case.assignee_user_id, cache),
            "internal_note": case.internal_note,
            "version": str(case.version),
            "legal_hold": bool(case.legal_hold),
        },
        "assignee": user_brief(db, case.assignee_user_id, cache) if case else None,
        "people": [p for p in (src.people(row) or []) if p],
    }


def collect(
    db: Session,
    ctx: AdminContext,
    *,
    types: Optional[set[str]] = None,
    module: str = "",
) -> tuple[list[dict], dict[str, int], bool]:
    """Nạp mục mở của mọi nguồn được phép xem. Trả (items, đếm theo loại, truncated)."""
    now = utcnow()
    items: list[dict] = []
    counts: dict[str, int] = {}
    truncated = False
    cache: dict = {}
    for src in visible_sources(ctx):
        if types and src.code not in types:
            continue
        if module and src.module != module:
            continue
        try:
            q = src.query(db)
            counts[src.code] = q.order_by(None).count()
            rows = q.limit(PER_SOURCE_CAP).all()
        except Exception as exc:  # noqa: BLE001 — nguồn lỗi KHÔNG được thành "0 việc"
            db.rollback()
            logger.warning("work item source %s failed: %s", src.code, exc)
            counts[src.code] = -1
            continue
        if counts[src.code] > len(rows):
            truncated = True
        cases = _case_map(db, [(src.code, str(r.id)) for r in rows])
        for r in rows:
            c = cases.get((src.code, str(r.id)))
            # "Xong" chỉ có hiệu lực tới khi nguồn có hoạt động MỚI hơn (vd chứng
            # từ cọc nộp lại sau khi đã xác minh) — khi đó việc tự mở lại.
            if c is not None and c.status == "done":
                touched = src.created(r)
                if touched is None or (c.updated_at and c.updated_at >= touched):
                    continue
                c = None
            items.append(to_item(db, src, r, c, now, cache))
    return items, counts, truncated


def sort_items(items: list[dict]) -> list[dict]:
    return sorted(
        items,
        key=lambda it: (
            0 if it["overdue"] else 1,
            PRIORITY_ORDER.get(it["priority"], 2),
            it["sla_seconds_remaining"],
        ),
    )


def load_row(db: Session, src: Source, source_id: str):
    model = src.query(db).column_descriptions[0]["entity"]
    # Khoá chính có thể là số (tin, cọc…) hoặc chuỗi UUID (tranh chấp, uỷ quyền,
    # chủ sở hữu mất) — ép kiểu theo cột, không mặc định là int.
    pk = sa_inspect(model).primary_key[0]
    try:
        is_int = issubclass(pk.type.python_type, int)
    except NotImplementedError:
        is_int = False
    if is_int:
        try:
            return db.get(model, int(source_id))
        except ValueError:
            return None
    if not source_id or len(source_id) > 64:
        return None
    return db.get(model, source_id)


def collect_done(db: Session, ctx: AdminContext, *, limit: int, offset: int) -> tuple[list[dict], int]:
    """Việc đã đóng (case `done`) thuộc các nguồn mình được xem, mới nhất trước."""
    codes = [s.code for s in visible_sources(ctx)]
    C = models.AdminCase
    q = db.query(C).filter(C.status == "done", C.source_type.in_(codes or ["__none__"]))
    total = q.count()
    rows = q.order_by(C.updated_at.desc()).offset(offset).limit(limit).all()
    now = utcnow()
    cache: dict = {}
    out = []
    for c in rows:
        src = source(c.source_type)
        row = load_row(db, src, c.source_id) if src else None
        if row is None:
            out.append({"id": f"{c.source_type}:{c.source_id}", "type": c.source_type,
                        "type_label": src.label if src else c.source_type, "module": src.module if src else "system",
                        "module_label": MODULES.get(src.module, "") if src else "", "source_id": c.source_id,
                        "ref": ref_code(src, c.source_id) if src else c.source_id, "title": c.title or "(nguồn đã xoá)",
                        "subtitle": "", "link": "/admin/work", "created_at": iso(c.created_at),
                        "sla_due_at": None, "sla_seconds_remaining": 0, "overdue": False, "priority": c.priority,
                        "case": None, "assignee": user_brief(db, c.assignee_user_id, cache), "people": []})
            continue
        it = to_item(db, src, row, c, now, cache)
        it["done_at"] = iso(c.done_at or c.updated_at)
        out.append(it)
    return out, total
