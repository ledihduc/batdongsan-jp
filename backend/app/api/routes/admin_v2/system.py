"""Hệ thống — sức khoẻ, hàng đợi push, job media, cờ tính năng (chỉ đọc),
nhật ký hợp nhất (chỉ đọc), luồng sự kiện realtime (SSE).

Sức khoẻ: mỗi mục có `status` riêng (ok | warn | error | unknown) — một mục
lỗi KHÔNG làm trống cả trang. Không bao giờ trả secret (khoá, token, mật khẩu,
số tài khoản): cờ chỉ gồm boolean + tên nhà cung cấp.
"""

from __future__ import annotations

import asyncio
import json
import logging
import os
import re
import shutil
import time
from collections import Counter
from datetime import datetime, timedelta, timezone
from functools import lru_cache
from pathlib import Path
from typing import Any, Callable, Optional

from fastapi import APIRouter, Depends, Header, Query, Request
from fastapi.responses import StreamingResponse
from pydantic import BaseModel, Field
from sqlalchemy import func, text
from sqlalchemy.orm import Session
from starlette.concurrency import run_in_threadpool

from app import models
from app.config import settings
from app.database import get_db
from app.services.admin_v2 import audit_read, rbac
from app.services.admin_v2.core import (
    AdminContext, CommandResult, PageParams, etag, fail, idempotency_key, if_match, iso, one, page_params,
    paged, paginate, require_permission, run_command, user_brief, utcnow,
)

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/api/v2/admin", tags=["admin-v2-system"])

_REPO_ROOT = Path(__file__).resolve().parents[4]
_STATUS_RANK = {"ok": 0, "unknown": 1, "warn": 2, "error": 3}

PUSH_FAILED_AFTER = 3          # cùng ngưỡng với dashboard/work-items
LOG_TAIL_BYTES = 2 * 1024 * 1024


class ReasonBody(BaseModel):
    reason: str = Field("", max_length=500)


def _worst(*statuses: str) -> str:
    return max(statuses or ("ok",), key=lambda s: _STATUS_RANK.get(s, 1))


def _section(db: Session, fn: Callable[[], dict]) -> dict:
    try:
        out = fn()
        out.setdefault("status", "ok")
        return out
    except Exception as exc:  # noqa: BLE001 — mục hỏng chỉ đỏ mục đó
        try:
            db.rollback()
        except Exception:  # noqa: BLE001
            pass
        logger.warning("health section failed: %s", exc)
        return {"status": "error", "error": type(exc).__name__}


# ═══ Sức khoẻ ════════════════════════════════════════════════════════════════


def _db_ping(db: Session) -> dict:
    t0 = time.perf_counter()
    db.execute(text("SELECT 1"))
    ms = round((time.perf_counter() - t0) * 1000, 1)
    return {"status": "ok" if ms < 200 else "warn", "latency_ms": ms,
            "dialect": db.get_bind().dialect.name}


@lru_cache(maxsize=1)
def _alembic_heads() -> tuple[str, ...]:
    from alembic.config import Config
    from alembic.script import ScriptDirectory

    cfg = Config(str(_REPO_ROOT / "alembic.ini"))
    cfg.set_main_option("script_location", str(_REPO_ROOT / "alembic"))
    return tuple(sorted(ScriptDirectory.from_config(cfg).get_heads()))


def _migrations(db: Session) -> dict:
    from sqlalchemy import inspect as sa_inspect

    # Kiểm bảng trước thay vì SELECT rồi rollback: trên Postgres lỗi SQL làm hỏng
    # cả transaction của request (các mục sau cũng chết theo).
    if not sa_inspect(db.connection()).has_table("alembic_version"):
        return {"status": "warn", "current": [], "heads": None, "detail": "Chưa có bảng alembic_version"}
    current = sorted(r[0] for r in db.execute(text("SELECT version_num FROM alembic_version")).fetchall())
    try:
        heads = list(_alembic_heads())
    except Exception as exc:  # noqa: BLE001
        return {"status": "unknown", "current": current, "heads": None, "detail": f"Không đọc được thư mục migration ({type(exc).__name__})"}
    same = set(current) == set(heads)
    return {"status": "ok" if same else "warn", "current": current, "heads": heads, "up_to_date": same,
            "multiple_heads": len(heads) > 1}


def _disk(label: str, path: str) -> dict:
    p = Path(path)
    if not p.exists():
        return {"label": label, "exists": False, "status": "warn"}
    u = shutil.disk_usage(str(p))
    pct = round(u.used * 100 / u.total, 1) if u.total else 0.0
    return {
        "label": label, "exists": True,
        "total_gb": round(u.total / 1e9, 2), "used_gb": round(u.used / 1e9, 2), "free_gb": round(u.free / 1e9, 2),
        "percent_used": pct, "status": "error" if pct >= 95 else ("warn" if pct >= 85 else "ok"),
    }


def _storage() -> dict:
    from app.services import sensitive_file_service
    from app.services.admin_v2 import documents as docs

    items = [_disk("uploads", settings.upload_dir), _disk("sensitive", str(sensitive_file_service._BASE_DIR))]
    try:
        items.append(_disk("private_documents", str(docs.private_dir())))
    except RuntimeError:
        items.append({"label": "private_documents", "exists": False, "status": "error",
                      "detail": "PRIVATE_DOCUMENTS_DIR nằm trong upload_dir"})
    # Kho riêng chưa tạo (chưa chạy migrate) chỉ là thông tin, không phải sự cố.
    for it in items:
        if it["label"] == "private_documents" and it.get("exists") is False and "detail" not in it:
            it["status"] = "ok"
    return {"status": _worst(*(i["status"] for i in items)), "volumes": items,
            "private_uploads_enforced": bool(getattr(settings, "private_uploads_enforced", False))}


def _push(db: Session) -> dict:
    from app.services.notification.hang_doi_push import SO_LAN_TOI_DA

    P = models.PushOutbox
    pending = db.query(P).filter(P.gui_luc.is_(None))
    queued = pending.filter(P.so_lan_thu < PUSH_FAILED_AFTER).order_by(None).count()
    failed = pending.filter(P.so_lan_thu >= PUSH_FAILED_AFTER).order_by(None).count()
    exhausted = pending.filter(P.so_lan_thu >= SO_LAN_TOI_DA).order_by(None).count()
    oldest = db.query(func.min(P.tao_luc)).filter(P.gui_luc.is_(None), P.so_lan_thu < SO_LAN_TOI_DA).scalar()
    age_min = round((utcnow() - oldest).total_seconds() / 60, 1) if oldest else None
    sent_24h = db.query(func.count(P.id)).filter(P.gui_luc >= utcnow() - timedelta(hours=24)).scalar() or 0
    status = "ok"
    if failed or (age_min is not None and age_min > 30):
        status = "warn"
    return {"status": status, "queued": queued, "failed": failed, "exhausted": exhausted,
            "sent_24h": int(sent_24h), "oldest_queued_at": iso(oldest), "oldest_queued_age_minutes": age_min}


def _tail_jsonl(path: Path, max_bytes: int = LOG_TAIL_BYTES) -> list[dict]:
    """Đọc PHẦN CUỐI tệp JSONL (giới hạn byte), bỏ dòng hỏng. Không bao giờ đọc cả tệp."""
    out: list[dict] = []
    with open(path, "rb") as fh:
        fh.seek(0, os.SEEK_END)
        size = fh.tell()
        fh.seek(max(0, size - max_bytes))
        chunk = fh.read(max_bytes)
    lines = chunk.decode("utf-8", errors="ignore").splitlines()
    if size > max_bytes and lines:
        lines = lines[1:]  # dòng đầu bị cắt giữa chừng
    for ln in lines:
        ln = ln.strip()
        if not ln.startswith("{"):
            continue
        try:
            rec = json.loads(ln)
        except ValueError:
            continue
        if isinstance(rec, dict):
            out.append(rec)
    return out


def _parse_ts(v: Any) -> Optional[datetime]:
    if not isinstance(v, str):
        return None
    try:
        return datetime.strptime(v[:19], "%Y-%m-%dT%H:%M:%S")
    except ValueError:
        return None


def _error_groups(records: list[dict], event: str, since: datetime, keys: tuple[str, ...]) -> dict:
    hits = [r for r in records if r.get("event") == event and (_parse_ts(r.get("ts")) or datetime.min) >= since]
    cnt = Counter(str(r.get("fingerprint") or "—") for r in hits)
    top = []
    for fp, n in cnt.most_common(5):
        last = max((r for r in hits if str(r.get("fingerprint") or "—") == fp), key=lambda r: r.get("ts") or "")
        top.append({"fingerprint": fp, "count": n, "last_seen": last.get("ts"),
                    **{k: (str(last.get(k))[:200] if last.get(k) is not None else None) for k in keys}})
    return {"count_24h": len(hits), "top": top, "status": "warn" if hits else "ok"}


def _logs() -> tuple[dict, dict]:
    path = Path(settings.log_dir) / "app.jsonl"
    if not path.is_file():
        miss = {"status": "unknown", "available": False, "count_24h": None, "top": []}
        return miss, dict(miss)
    records = _tail_jsonl(path)
    since = utcnow() - timedelta(hours=24)
    window = {"available": True, "scanned_records": len(records), "scan_limit_bytes": LOG_TAIL_BYTES}
    server = {**window, **_error_groups(records, "unhandled_exception", since, ("exc_type", "path", "method"))}
    client = {**window, **_error_groups(records, "client_error", since, ("error_code", "route", "platform", "app_version"))}
    return server, client


def _providers() -> dict:
    prod = settings.environment == "production"
    names = {
        "email": settings.notification_email_provider,
        "sms": settings.notification_sms_provider,
        "push": settings.notification_push_provider,
        "digital_signature": settings.digital_signature_provider,
    }
    stub = [k for k, v in names.items() if (v or "stub") == "stub"]
    return {"status": "warn" if (prod and stub) else "ok", "providers": names, "stub_channels": stub,
            "environment": settings.environment}


@router.get("/system/health")
def system_health(
    ctx: AdminContext = Depends(require_permission("system.read")),
    db: Session = Depends(get_db),
):
    sections = {
        "database": _section(db, lambda: _db_ping(db)),
        "migrations": _section(db, lambda: _migrations(db)),
        "storage": _section(db, _storage),
        "push_outbox": _section(db, lambda: _push(db)),
    }
    try:
        server, client = _logs()
    except Exception as exc:  # noqa: BLE001
        logger.warning("health log scan failed: %s", exc)
        server = client = {"status": "error", "error": type(exc).__name__}
    sections["server_errors"] = server
    sections["client_errors"] = client
    sections["notification_providers"] = _section(db, _providers)
    return one({"status": _worst(*(s.get("status", "unknown") for s in sections.values())),
                "checked_at": iso(utcnow()), "sections": sections})


# ═══ Hàng đợi push ═══════════════════════════════════════════════════════════


def _push_state(p: models.PushOutbox) -> str:
    if p.gui_luc is not None:
        return "sent"
    return "failed" if (p.so_lan_thu or 0) >= PUSH_FAILED_AFTER else "queued"


def _push_version(p: models.PushOutbox) -> str:
    return etag(p.id, iso(p.gui_luc), p.so_lan_thu)


def _push_row(db: Session, p: models.PushOutbox, cache: dict) -> dict:
    from app.services.notification.hang_doi_push import SO_LAN_TOI_DA

    return {
        "id": p.id, "user": user_brief(db, p.user_id, cache), "title": p.title, "loai": p.loai,
        "related_id": p.related_id, "state": _push_state(p), "attempts": p.so_lan_thu or 0,
        "exhausted": p.gui_luc is None and (p.so_lan_thu or 0) >= SO_LAN_TOI_DA,
        "last_error": p.loi_cuoi, "created_at": iso(p.tao_luc), "sent_at": iso(p.gui_luc),
        "retryable": p.gui_luc is None and (p.so_lan_thu or 0) > 0,
        "version": _push_version(p),
    }


@router.get("/system/notifications")
def list_notifications(
    state: str = Query("", pattern="^(|queued|sent|failed)$"),
    user_id: Optional[int] = Query(None),
    loai: str = Query("", max_length=50),
    page: PageParams = Depends(page_params),
    ctx: AdminContext = Depends(require_permission("system.read")),
    db: Session = Depends(get_db),
):
    P = models.PushOutbox
    q = db.query(P)
    if state == "sent":
        q = q.filter(P.gui_luc.isnot(None))
    elif state == "failed":
        q = q.filter(P.gui_luc.is_(None), P.so_lan_thu >= PUSH_FAILED_AFTER)
    elif state == "queued":
        q = q.filter(P.gui_luc.is_(None), P.so_lan_thu < PUSH_FAILED_AFTER)
    if user_id is not None:
        q = q.filter(P.user_id == user_id)
    if loai:
        q = q.filter(P.loai == loai)
    rows, total = paginate(q.order_by(P.tao_luc.desc(), P.id.desc()), page)
    cache: dict = {}
    return paged([_push_row(db, p, cache) for p in rows], total=total, page=page)


@router.post("/system/notifications/{push_id}/retry")
def retry_notification(
    push_id: int,
    body: ReasonBody,
    key: str = Depends(idempotency_key),
    expected: Optional[str] = Depends(if_match),
    ctx: AdminContext = Depends(require_permission("settings.manage")),
    db: Session = Depends(get_db),
):
    p = db.get(models.PushOutbox, push_id)
    if p is None:
        raise fail(404, "ADMIN_NOT_FOUND", "Không tìm thấy thông báo")

    def do() -> CommandResult:
        if p.gui_luc is not None:
            raise fail(409, "ADMIN_INVALID_STATE", "Thông báo đã gửi thành công")
        if not p.so_lan_thu:
            raise fail(409, "ADMIN_NOTHING_TO_CHANGE", "Thông báo đang chờ gửi lần đầu")
        before = {"attempts": p.so_lan_thu, "last_error": p.loi_cuoi}
        # Bộ gửi chỉ lấy mục `so_lan_thu < SO_LAN_TOI_DA` → đặt lại về 0 là nó
        # tự thử lại ở vòng kế tiếp. Không gửi trực tiếp từ request.
        p.so_lan_thu = 0
        p.loi_cuoi = None
        db.flush()
        return CommandResult(data=_push_row(db, p, {}), before=before, after={"attempts": 0},
                             event_status="queued")

    return run_command(
        db, ctx, action="push.retry", permission="settings.manage", entity_type="push_outbox", entity_id=push_id,
        key=key, fn=do, reason=body.reason, reason_required=True, expected_version=expected,
        current_version=lambda: _push_version(p), event_type="admin.push.retry",
    )


# ═══ Job media ═══════════════════════════════════════════════════════════════


# ═══ Cờ tính năng (chỉ đọc) ══════════════════════════════════════════════════

_SECRET_KEY = re.compile(
    r"(secret|token|password|passwd|pwd|api_?key|private_?key|credential|salt|account_number|"
    r"account_holder|bank|chat_id|dsn|_url$|_path$|jwt|cors)", re.I)


def feature_flags() -> list[dict]:
    """Chỉ boolean + tên nhà cung cấp. Khoá có dáng bí mật bị loại kể cả khi là bool."""
    out = []
    for k, v in sorted(settings.model_dump().items()):
        if _SECRET_KEY.search(k):
            continue
        if isinstance(v, bool):
            out.append({"key": k, "type": "boolean", "value": v, "group": k.split("_", 1)[0]})
        elif k.endswith("_provider") and isinstance(v, str) and re.fullmatch(r"[a-z0-9_-]{1,30}", v or ""):
            out.append({"key": k, "type": "provider", "value": v, "group": k.split("_", 1)[0]})
    return out


@router.get("/system/flags")
def system_flags(ctx: AdminContext = Depends(require_permission("system.read"))):
    return one(feature_flags(), environment=settings.environment, read_only=True)


# ═══ Nhật ký hợp nhất (chỉ đọc) ═══════════════════════════════════════════════


@router.get("/audit-events")
def audit_events(
    source: str = Query("", max_length=60),
    actor_id: Optional[int] = Query(None),
    action: str = Query("", max_length=80),
    entity_type: str = Query("", max_length=80),
    entity_id: str = Query("", max_length=64),
    date_from: Optional[datetime] = Query(None),
    date_to: Optional[datetime] = Query(None),
    page: PageParams = Depends(page_params),
    ctx: AdminContext = Depends(require_permission("audit.read")),
    db: Session = Depends(get_db),
):
    srcs = tuple(s for s in source.split(",") if s) or audit_read.SOURCE_CODES
    bad = [s for s in srcs if s not in audit_read.SOURCE_CODES]
    if bad:
        raise fail(422, "ADMIN_BAD_FILTER", "Nguồn nhật ký không hợp lệ", {"allowed": list(audit_read.SOURCE_CODES)})
    # Giờ có múi (+07:00 từ FE) → UTC không múi như cột DB.
    naive = lambda d: d.astimezone(timezone.utc).replace(tzinfo=None) if d is not None and d.tzinfo else d  # noqa: E731
    f = audit_read.AuditFilter(sources=srcs, actor_id=actor_id, action=action.strip(),
                               entity_type=entity_type.strip(), entity_id=entity_id.strip(),
                               date_from=naive(date_from), date_to=naive(date_to))
    data, total, truncated, counts, failed = audit_read.collect(db, f, offset=page.offset, limit=page.limit)
    return paged(data, total=total, page=page, truncated=truncated, counts_by_source=counts,
                 partial_error=failed, sources=list(audit_read.SOURCE_CODES))


# ═══ Sự kiện realtime ════════════════════════════════════════════════════════

STREAM_POLL_SECONDS = 3.0
STREAM_HEARTBEAT_SECONDS = 15.0
STREAM_MAX_SECONDS = 300.0
STREAM_BATCH = 200

#: Nhà máy Session cho luồng SSE — mỗi lần poll một Session mới, ngắn hạn.
#: None = `app.database.SessionLocal` (test thay bằng sessionmaker riêng).
session_factory: Optional[Callable[[], Session]] = None


def _factory() -> Callable[[], Session]:
    if session_factory is not None:
        return session_factory
    from app.database import SessionLocal

    return SessionLocal


def event_dict(e: models.AdminEvent) -> dict:
    return {"id": e.id, "event_type": e.event_type, "entity_type": e.entity_type, "entity_id": e.entity_id,
            "status": e.status, "created_at": iso(e.created_at)}


def _fetch_events(db: Session, after: int, limit: int) -> list[dict]:
    E = models.AdminEvent
    rows = db.query(E).filter(E.id > after).order_by(E.id.asc()).limit(limit).all()
    return [event_dict(e) for e in rows]


def _poll(after: int, check: Optional[tuple[int, Optional[str]]]) -> tuple[list[dict], bool]:
    """Một lần poll: Session mới → đọc → đóng ngay (không giữ transaction)."""
    db = _factory()()
    try:
        alive = True
        if check is not None:
            user_id, sid = check
            u = db.get(models.User, user_id)
            alive = bool(u is not None and u.is_active and rbac.permissions_of(db, user_id))
            if alive and sid:
                s = db.get(models.AdminSession, sid)
                alive = s is not None and s.revoked_at is None and s.expires_at > utcnow()
        events = _fetch_events(db, after, STREAM_BATCH) if alive else []
        return events, alive
    finally:
        db.close()


def _sse(ev: dict) -> str:
    return f"id: {ev['id']}\nevent: admin_event\ndata: {json.dumps(ev, ensure_ascii=False)}\n\n"


async def _stream(request: Request, cursor: int, user_id: int, sid: Optional[str]):
    started = last_beat = last_check = time.monotonic()
    yield f"retry: {int(STREAM_POLL_SECONDS * 1000)}\n\n"
    while True:
        if await request.is_disconnected():
            break
        now = time.monotonic()
        if now - started >= STREAM_MAX_SECONDS:
            # Đóng chủ động → client nối lại kèm Last-Event-ID, quyền được kiểm lại.
            yield "event: reconnect\ndata: {}\n\n"
            break
        check = None
        if now - last_check >= STREAM_HEARTBEAT_SECONDS:
            check, last_check = (user_id, sid), now
        try:
            events, alive = await run_in_threadpool(_poll, cursor, check)
        except Exception as exc:  # noqa: BLE001 — DB chập chờn: giữ kết nối, thử lại vòng sau
            logger.warning("admin SSE poll failed: %s", exc)
            events, alive = [], True
        if not alive:
            yield "event: session_ended\ndata: {}\n\n"
            break
        for ev in events:
            cursor = ev["id"]
            yield _sse(ev)
        if now - last_beat >= STREAM_HEARTBEAT_SECONDS:
            last_beat = now
            yield ": ping\n\n"
        await asyncio.sleep(STREAM_POLL_SECONDS)


def _cursor(after: Optional[int], last_event_id: Optional[str]) -> Optional[int]:
    if after is not None:
        return after
    if last_event_id and last_event_id.strip().isdigit():
        return int(last_event_id.strip())
    return None


@router.get("/events/stream")
def events_stream(
    request: Request,
    after: Optional[int] = Query(None, ge=0),
    last_event_id: Optional[str] = Header(None, alias="Last-Event-ID"),
    ctx: AdminContext = Depends(require_permission("dashboard.read")),
    db: Session = Depends(get_db),
):
    cursor = _cursor(after, last_event_id)
    if cursor is None:
        # Kết nối mới không cursor: chỉ nhận sự kiện TỪ BÂY GIỜ, không phát lại lịch sử.
        cursor = int(db.query(func.max(models.AdminEvent.id)).scalar() or 0)
    sid = ctx.session.id if ctx.session else None
    # Kết thúc transaction của request NGAY: luồng sống 5 phút không được giữ
    # kết nối DB (mỗi lần poll tự mở Session riêng).
    db.commit()
    return StreamingResponse(
        _stream(request, cursor, ctx.user_id, sid),
        media_type="text/event-stream",
        headers={"Cache-Control": "no-cache, no-transform", "X-Accel-Buffering": "no", "Connection": "keep-alive"},
    )


@router.get("/events")
def events_since(
    after: Optional[int] = Query(None, ge=0),
    limit: int = Query(100, ge=1, le=500),
    ctx: AdminContext = Depends(require_permission("dashboard.read")),
    db: Session = Depends(get_db),
):
    """Dự phòng khi không dùng được SSE: poll `?after=<id cuối>`.

    Không có `after` → trả `limit` sự kiện MỚI NHẤT (tăng dần) để lấy cursor."""
    E = models.AdminEvent
    if after is None:
        rows = db.query(E).order_by(E.id.desc()).limit(limit).all()
        data = [event_dict(e) for e in reversed(rows)]
        has_more = False
    else:
        data = _fetch_events(db, after, limit + 1)
        has_more = len(data) > limit
        data = data[:limit]
    last = data[-1]["id"] if data else (after or int(db.query(func.max(E.id)).scalar() or 0))
    return one(data, next_after=last, has_more=has_more)
