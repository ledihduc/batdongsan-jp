"""UrbanNest backend — FastAPI + SQLAlchemy + SQLite.

Chạy:
    uvicorn main:app --host 0.0.0.0 --port 3000 --reload

API contract giữ y với backend Go/Node để Flutter không cần đổi.
"""

import logging
import os
import sys

# Ép stdout/stderr ra UTF-8 để in được tiếng Việt trên console Windows (cp1252)
try:
    sys.stdout.reconfigure(encoding="utf-8")
    sys.stderr.reconfigure(encoding="utf-8")
except Exception:
    pass

from datetime import datetime, timezone

from fastapi import Depends, FastAPI
from fastapi.exceptions import RequestValidationError
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from slowapi import _rate_limit_exceeded_handler
from slowapi.errors import RateLimitExceeded
from sqlalchemy import text
from sqlalchemy.orm import Session
from starlette.exceptions import HTTPException as StarletteHTTPException

from app.config import settings
from app.core.deps.require_region import require_region
from app.observability.logging_config import setup_logging

# Khởi tạo structured logging TRƯỚC khi import/khởi tạo phần còn lại của app,
# để mọi log startup cũng đi qua JSON + redaction.
setup_logging()

from app.database import SessionLocal, engine, get_db
from app.middleware.error_handler import (
    http_exception_handler,
    unhandled_exception_handler,
    validation_handler,
)
from app.middleware.rate_limit import limiter
from app.routers import (
    admin_houses,
    auth_router,
    catalog,
    chat,
    money_ledger_v2,
    host_room,
    hosts_public,
    basemap_tiles,
    guest_reservation,
    houses,
    notifications,
    upload,
    users,
)
from app.seed import run as seed_run

# ── DB schema bootstrap ───────────────────────────────────────────────────────
# Postgres: schema do alembic quản lý (chạy `alembic upgrade head`).
# SQLite (dev local): alembic migration baseline dùng cú pháp Postgres → fallback
# metadata.create_all() để tạo bảng nhanh.
#
# Lưu ý: create_all() CHỈ tạo bảng mới, KHÔNG alter table có sẵn. Nếu model thêm
# cột mới (vd marketplace_integration), DB SQLite cũ sẽ bị drift → 500 silent.
# Drift check bên dưới fail-fast với hướng dẫn fix.
if settings.database_url.startswith("sqlite"):
    from app.database import Base
    # Import delegation domain models to register them on Base.metadata before create_all.
    # app.models (imported transitively via routers) registers core models.
    # app.domain registers delegation domain tables (operator_business_profiles, delegations, etc.)
    import app.domain  # noqa: F401 — registers delegation ORM classes onto Base.metadata
    Base.metadata.create_all(bind=engine)

    # ── SQLite schema drift check ─────────────────────────────────────────────
    from sqlalchemy import inspect as _sa_inspect
    _inspector = _sa_inspect(engine)
    _drift_report: list[str] = []
    # Dùng .tables.values() thay vì .sorted_tables để tránh SAWarning
    # về FK cycle houses↔rooms (do marketplace_integration).
    for _table in Base.metadata.tables.values():
        if not _inspector.has_table(_table.name):
            _drift_report.append(f"  - missing TABLE: {_table.name}")
            continue
        _db_cols = {c["name"] for c in _inspector.get_columns(_table.name)}
        _model_cols = {c.name for c in _table.columns}
        _missing = _model_cols - _db_cols
        if _missing:
            _drift_report.append(
                f"  - table '{_table.name}' missing COLUMNS: {sorted(_missing)}"
            )
    if _drift_report:
        _msg = (
            "\n"
            "╔══════════════════════════════════════════════════════════════════╗\n"
            "║  SQLITE SCHEMA DRIFT DETECTED                                    ║\n"
            "╠══════════════════════════════════════════════════════════════════╣\n"
            f"{chr(10).join(_drift_report)}\n"
            "╠══════════════════════════════════════════════════════════════════╣\n"
            "║  Nguyên nhân: create_all() chỉ tạo bảng MỚI, không ALTER bảng    ║\n"
            "║  cũ khi model thêm cột.                                          ║\n"
            "║                                                                  ║\n"
            "║  Fix nhanh (dev mode, mất seed data — sẽ tự re-seed):            ║\n"
            "║    1. Stop uvicorn (Ctrl-C hoặc kill)                            ║\n"
            "║    2. mv urbannest.db urbannest.db.bak                           ║\n"
            "║    3. Restart uvicorn — create_all() + seed chạy lại sạch        ║\n"
            "║                                                                  ║\n"
            "║  Hoặc chuyển sang Postgres (khuyến nghị, không bị drift):        ║\n"
            "║    DATABASE_URL=postgresql://... trong .env                      ║\n"
            "║    docker compose up -d postgis && alembic upgrade head          ║\n"
            "╚══════════════════════════════════════════════════════════════════╝\n"
        )
        raise RuntimeError(_msg)

# ── Seed dev data (idempotent — safe to call on every startup) ────────────────
with SessionLocal() as db:
    seed_run(db)

os.makedirs(settings.upload_dir, exist_ok=True)

app = FastAPI(title="UrbanNest API")

# ── Rate limiter (slowapi) ────────────────────────────────────────────────────
app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)

# ── Error handlers ────────────────────────────────────────────────────────────
app.add_exception_handler(RequestValidationError, validation_handler)
app.add_exception_handler(StarletteHTTPException, http_exception_handler)
# Catch-all cho uncaught exceptions — đảm bảo 500 đi qua CORS middleware,
# tránh tình huống browser thấy "no Access-Control-Allow-Origin" khi backend crash.
app.add_exception_handler(Exception, unhandled_exception_handler)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.backend_cors_origins,
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ── Request context + structured request logging ──────────────────────────────
# Thêm SAU CORS để CORS bọc ngoài cùng (preflight vẫn qua trước khi log).
from app.observability.middleware import RequestContextMiddleware  # noqa: E402

app.add_middleware(RequestContextMiddleware, hash_salt=settings.log_hash_salt)

# Cổng chứng từ riêng: TẮT mặc định (PRIVATE_UPLOADS_ENFORCED) → y hệt StaticFiles.
from app.services.private_uploads import GatedUploadsStaticFiles  # noqa: E402

app.mount("/uploads", GatedUploadsStaticFiles(directory=settings.upload_dir), name="uploads")

# Client (Flutter) error reporting → cùng JSONL sink cho pipeline self-heal.
from app.routers import client_logs as _client_logs_router  # noqa: E402, PLC0415

app.include_router(_client_logs_router.router)

# Buyer tools (loan calculator + so sánh BĐS) — Phase 1 quick-wins.
from app.routers import tools as _tools_router  # noqa: E402, PLC0415

app.include_router(_tools_router.router)

# Sao chất lượng nhà trọ (pivot mảng thuê).
from app.routers import quality_rating as _quality_router  # noqa: E402, PLC0415

app.include_router(_quality_router.router)

# Luồng thẩm định chất lượng (Phase 2).
from app.routers import verification as _verification_router  # noqa: E402, PLC0415

app.include_router(_verification_router.router)

# Sở thích người dùng (khảo sát phân loại — redesign v2 P1).
from app.routers import preferences as _preferences_router  # noqa: E402, PLC0415

app.include_router(_preferences_router.router)

# Lead 'gọi lại' nhẹ (thu Tên+SĐT không cần login) — redesign v2.
from app.routers import leads as _leads_router  # noqa: E402, PLC0415

app.include_router(_leads_router.router)

# Chặn người dùng (Apple 1.2 — UGC).
from app.routers import blocks as _blocks_router  # noqa: E402, PLC0415

app.include_router(_blocks_router.router)

# Dịch vụ nhà cửa (Sửa điện · Thông tắc · Vệ sinh…) — cụm ĐỘC LẬP, không còn
# treo lên hạ tầng thi công.
from app.api.routes import services as _services_router  # noqa: E402, PLC0415

app.include_router(_services_router.router)

# Tin NHU CẦU (Cần thuê / Cần mua) — bảng riêng, KHÔNG phải một loại của houses.
from app.api.routes import demand as _demand_router  # noqa: E402, PLC0415

app.include_router(_demand_router.router)

# Tìm kiếm hợp nhất toàn hệ thống (header search).
from app.routers import search as _search_router  # noqa: E402, PLC0415

app.include_router(_search_router.router)


@app.get("/health")
@app.get("/healthz")
def health():
    """Liveness probe — không touch DB, dùng cho frontend pre-WS check + k8s.

    Trả thông tin tối thiểu: status + timestamp để client biết là response
    tươi (không phải cached). Không leak version/host info.
    """
    return {"status": "ok", "ts": datetime.now(timezone.utc).isoformat()}


@app.get("/api/health")
def api_health(db: Session = Depends(get_db)):
    """Health check với DB connectivity. Dùng cho uptime-kuma monitoring."""
    db.execute(text("SELECT 1"))
    return {"status": "healthy", "ts": datetime.now(timezone.utc).isoformat()}


# REST routers
app.include_router(auth_router.router)
app.include_router(users.router)
app.include_router(houses.router)
app.include_router(catalog.router)
app.include_router(admin_houses.router)
app.include_router(notifications.router)
app.include_router(chat.router)
app.include_router(upload.router)
app.include_router(hosts_public.router)
app.include_router(basemap_tiles.router)
app.include_router(money_ledger_v2.router)
app.include_router(host_room.router)
app.include_router(guest_reservation.router)

# Delegation lifecycle API (Phase 03)
from app.api.routes.delegation import router as delegation_router  # noqa: PLC0415, E402
app.include_router(delegation_router)

# KYC + onboarding extensions (Phase 05)
from app.api.routes.kyc import router as kyc_router  # noqa: PLC0415, E402
app.include_router(kyc_router)

# Approval workflow + KB04 carve-out (Phase 04)
from app.api.routes.approval import router as approval_router  # noqa: PLC0415, E402
app.include_router(approval_router)

# eKYC chủ nhà (mig 0140): CCCD + chân dung + GPKD, link làm trên thiết bị khác.
from app.api.routes.ekyc import router as ekyc_router  # noqa: PLC0415, E402
app.include_router(ekyc_router)

# Existing record-only commission reports (P09). This router was fully tested
# but previously not mounted in the real app, making its contract unreachable.
from app.api.routes.commission import router as commission_router  # noqa: PLC0415, E402
app.include_router(commission_router)

# Owner death workflow + admin retention (Phase 06)
from app.api.routes.owner_death import router as owner_death_router  # noqa: PLC0415, E402
from app.api.routes.admin_retention import router as admin_retention_router  # noqa: PLC0415, E402
app.include_router(owner_death_router)
app.include_router(admin_retention_router)

# Admin dashboard + actions + disputes (Phase 10)
from app.api.routes.admin_dashboard import router as admin_dashboard_router  # noqa: PLC0415, E402
from app.api.routes.admin_delegations import router as admin_delegations_router  # noqa: PLC0415, E402
from app.api.routes.admin_disputes import router as admin_disputes_router  # noqa: PLC0415, E402
app.include_router(admin_dashboard_router)
app.include_router(admin_delegations_router)
app.include_router(admin_disputes_router)

# Backoffice quản trị V2 (/api/v2/admin/*) — RBAC + nhật ký + hộp việc.
from app.api.routes.admin_v2 import router as admin_v2_router  # noqa: PLC0415, E402
app.include_router(admin_v2_router)
# Chứng từ riêng tư cho NGƯỜI THAM GIA (app thường) — /api/v2/documents/*.
from app.api.routes.admin_v2.documents import public_router as documents_public_router  # noqa: PLC0415, E402
app.include_router(documents_public_router)
with SessionLocal() as _db:
    try:
        from app.services.admin_v2.rbac import ensure_catalog  # noqa: PLC0415

        ensure_catalog(_db)
        _db.commit()
    except Exception as _exc:  # noqa: BLE001 — bảng chưa migrate thì app vẫn lên
        _db.rollback()
        logging.getLogger(__name__).warning("admin_v2 ensure_catalog skipped: %s", _exc)

# JP市場 (Japan market) — Phase 00 foundation routes.
# JP-only: gate behind require_region('jp') so VN clients see 404.
from app.api.routes.jp.address import router as jp_address_router  # noqa: PLC0415, E402
app.include_router(
    jp_address_router,
    dependencies=[Depends(require_region("jp"))],
)

# JP市場 — Phase 01 chintai routes (listings, viewings, applications, reviews).
# All routers already include require_region('jp') at router level; duplicate dep here
# as defense-in-depth so even if a router forgets, this wrapper catches it.
from app.api.routes.jp.listings import router as jp_listings_router  # noqa: PLC0415, E402
from app.api.routes.jp.viewings import router as jp_viewings_router  # noqa: PLC0415, E402
from app.api.routes.jp.applications import router as jp_applications_router  # noqa: PLC0415, E402
from app.api.routes.jp.application_reviews import router as jp_reviews_router  # noqa: PLC0415, E402
app.include_router(jp_listings_router, dependencies=[Depends(require_region("jp"))])
app.include_router(jp_viewings_router, dependencies=[Depends(require_region("jp"))])
app.include_router(jp_applications_router, dependencies=[Depends(require_region("jp"))])
app.include_router(jp_reviews_router, dependencies=[Depends(require_region("jp"))])

# JP市場 — Phase 02 transactions routes (payments, invoices, consent, DSR, IT重説, eContract).
from app.api.routes.jp.payments import router as jp_payments_router  # noqa: PLC0415, E402
from app.api.routes.jp.webhooks_komoju import router as jp_webhooks_komoju_router  # noqa: PLC0415, E402
from app.api.routes.jp.invoices import router as jp_invoices_router  # noqa: PLC0415, E402
from app.api.routes.jp.consent import router as jp_consent_router  # noqa: PLC0415, E402
from app.api.routes.jp.me import router as jp_me_router  # noqa: PLC0415, E402
from app.api.routes.jp.it_sessions import router as jp_it_sessions_router  # noqa: PLC0415, E402
from app.api.routes.jp.econtracts import router as jp_econtracts_router  # noqa: PLC0415, E402
from app.api.routes.jp.webhooks_cloudsign import router as jp_webhooks_cloudsign_router  # noqa: PLC0415, E402
app.include_router(jp_payments_router, dependencies=[Depends(require_region("jp"))])
app.include_router(jp_webhooks_komoju_router, dependencies=[Depends(require_region("jp"))])
app.include_router(jp_invoices_router, dependencies=[Depends(require_region("jp"))])
app.include_router(jp_consent_router, dependencies=[Depends(require_region("jp"))])
app.include_router(jp_me_router, dependencies=[Depends(require_region("jp"))])
app.include_router(jp_it_sessions_router, dependencies=[Depends(require_region("jp"))])
app.include_router(jp_econtracts_router, dependencies=[Depends(require_region("jp"))])
app.include_router(jp_webhooks_cloudsign_router, dependencies=[Depends(require_region("jp"))])

# JP市場 — Phase 03 Scale routes (renewals, deposit settlements, admin KPIs).
from app.api.routes.jp.renewals import router as jp_renewals_router  # noqa: PLC0415, E402
from app.api.routes.jp.deposit_settlements import router as jp_deposit_settlements_router  # noqa: PLC0415, E402
from app.api.routes.jp.admin_kpi import router as jp_admin_kpi_router  # noqa: PLC0415, E402
app.include_router(jp_renewals_router, dependencies=[Depends(require_region("jp"))])
app.include_router(jp_deposit_settlements_router, dependencies=[Depends(require_region("jp"))])
app.include_router(jp_admin_kpi_router, dependencies=[Depends(require_region("jp"))])

# JP市場 — Phase 04 Launch: compliance evidence endpoint (admin-only, JP-gated).
from app.api.routes.jp.compliance import router as jp_compliance_router  # noqa: PLC0415, E402
app.include_router(jp_compliance_router, dependencies=[Depends(require_region("jp"))])

# Trang HTML dựng sẵn cho công cụ tìm kiếm (/tin, /sitemap.xml, /robots.txt).
# App Flutter web dùng CanvasKit nên bot chỉ thấy tài liệu rỗng — xem app/routers/seo.py.
from app.routers import seo  # noqa: PLC0415, E402
app.include_router(seo.router)

# WebSocket
app.include_router(chat.ws_router)


_jp_scheduler = None


@app.on_event("startup")
async def startup():
    global _jp_scheduler  # noqa: PLW0603
    print(f"UrbanNest backend (FastAPI) đang lắng nghe http://localhost:{settings.port}")
    from app.core.jp_scheduler_gate import should_start_jp_scheduler  # noqa: PLC0415

    if should_start_jp_scheduler(settings.region, settings.jp_scheduler_enabled):
        from apscheduler.schedulers.background import BackgroundScheduler  # noqa: PLC0415
        from app.services.renewal.cron import start_renewal_cron  # noqa: PLC0415
        from app.services.privacy.deletion_cron import start_deletion_cron  # noqa: PLC0415

        _jp_scheduler = BackgroundScheduler(timezone="Asia/Tokyo")
        start_renewal_cron(_jp_scheduler)
        start_deletion_cron(_jp_scheduler)
        _jp_scheduler.start()


@app.on_event("shutdown")
async def shutdown():
    global _jp_scheduler  # noqa: PLW0603
    if _jp_scheduler is not None and _jp_scheduler.running:
        _jp_scheduler.shutdown(wait=False)
        _jp_scheduler = None
    # Proxy tile nền giữ một client httpx dùng chung (connection pool) suốt
    # vòng đời app — đóng lại để không rò socket khi tắt.
    from app.services.basemap_tile_proxy import aclose as dong_client_tile  # noqa: PLC0415
    await dong_client_tile()
