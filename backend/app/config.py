from typing import Literal

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    port: int = 3000
    database_url: str = "sqlite:///./urbannest.db"
    jwt_secret: str = "urbannest-dev-secret-change-me"
    token_ttl_hours: int = 168
    upload_dir: str = "./uploads"
    app_base_url: str = "http://localhost:3000"
    # The app opens this page with a short-lived ticket in a URL fragment—not a JWT.
    sale_application_web_url: str = ""
    environment: str = "development"  # "production" → ẩn stack trace trong error handler

    # Activity/Management V2 rollout. Read và write tách riêng để app mới có
    # thể dùng dashboard read-only trước khi command canonical sẵn sàng.
    # COHORT là danh sách user id phân cách bằng dấu phẩy; rỗng = mọi user khi
    # flag tổng đã bật. Mặc định đều tắt để deploy code không tự đổi giao diện.
    management_v2_enabled: bool = False
    management_v2_writes_enabled: bool = False
    management_v2_cohort_user_ids: str = ""
    viewing_v2_enabled: bool = False
    viewing_v2_writes_enabled: bool = False
    sale_crm_v2_enabled: bool = False
    sale_crm_v2_writes_enabled: bool = False
    stay_v2_enabled: bool = False
    stay_v2_writes_enabled: bool = False
    money_ledger_v2_enabled: bool = False
    short_stay_inventory_v2_enabled: bool = False
    buy_sell_v2_enabled: bool = False

    # Tài khoản nhận 50% cọc của nền tảng. Để trống thì API trả is_configured=false;
    # không đặt số tài khoản thật trong source hoặc migration.
    platform_bank_name: str = ""
    platform_bank_account_number: str = ""
    platform_bank_account_holder: str = ""
    platform_bank_transfer_prefix: str = "ANCU"

    # ── Observability / structured logging ─────────────────────────────────────
    log_dir: str = "./storage/logs"
    log_level: str = "INFO"
    # Salt để hash user-id trong log (không lưu id thô). Đặt qua env ở prod.
    log_hash_salt: str = "ancu365-log-salt"
    # Client (Flutter) error reporting: bật/tắt endpoint /api/client-logs.
    client_logs_enabled: bool = True

    # Chứng từ riêng tư đã chép vào kho riêng (private_documents) thì `/uploads`
    # trả 404 đúng các tên đó. TẮT mặc định: bật sau khi chạy
    # scripts/migrate_private_uploads.py --apply và app đã chuyển sang signed URL.
    private_uploads_enforced: bool = False

    # ── Buyer tools (Phase 1 quick-wins — vô hại, mặc định BẬT) ────────────────
    loan_calculator_enabled: bool = True  # POST /api/tools/loan-calculator
    compare_enabled: bool = True          # GET  /api/tools/compare

    # ── Sao chất lượng nhà trọ (pivot mảng thuê) ───────────────────────────────
    quality_rating_enabled: bool = True
    # Đơn giá thuê tham chiếu VND/m²/tháng để gợi ý giá (v1; v2 dùng trung vị khu vực).
    quality_base_rate_per_m2: int = 150000

    # Chỉ người ĐÃ Ở mới được review (chống review ảo). Default OFF — bật sau khi
    # xác thực liên kết dữ liệu thuê↔user đầy đủ. Tự-review LUÔN bị chặn (không cờ).
    # Cổng chống bơm sao: chỉ người đã xem nhà / đã chốt giao dịch mới đánh
    # giá được. BẬT mặc định từ 05/09/2026 — trước đó tắt, và API để ngỏ cho
    # bất kỳ ai chấm bất kỳ tin nào.
    review_requires_stay: bool = True

    # Luồng thẩm định chất lượng (Phase 2). Admin đóng vai thẩm định viên (slice 1).
    verification_enabled: bool = True

    # Phân loại khách quan tâm (lead segmentation) cho chủ nhà.
    leads_enabled: bool = True

    # Báo yêu cầu dịch vụ cho admin qua Telegram. Rỗng = tắt (tính năng đặt dịch
    # vụ vẫn chạy, chỉ mất lớp báo tin). Xem app/services/notification/telegram_service.py.
    telegram_bot_token: str = ""
    telegram_admin_chat_id: str = ""
    industrial_re_enabled: bool = False           # BĐS công nghiệp

    # CORS — prod: set domain cụ thể qua env BACKEND_CORS_ORIGINS
    backend_cors_origins: list[str] = ["*"]

    # Planning / PostGIS settings (chỉ dùng khi DATABASE_URL là Postgres)
    # Default = public OSM Nominatim (1 req/s policy). Tự host:
    # set NOMINATIM_URL env → http://nominatim-internal:8080.
    nominatim_url: str = "https://nominatim.openstreetmap.org"
    martin_url: str = "http://localhost:3001"
    wfs_base_url: str = "https://geodata-stnmt.tphcm.gov.vn/geoserver/ows"
    wfs_request_delay_s: int = 2
    etl_contact_email: str = "ops@ancu365.vn"
    # ── Phase 08: Notification channels (email + SMS) ──────────────────────────
    # Provider selection: "stub" (default, v0) | "ses" | "esms"
    # Swap to real providers once vendor contracts are signed (pre-launch gate).
    notification_email_provider: str = "stub"
    notification_sms_provider: str = "stub"
    notification_push_provider: str = "stub"
    firebase_service_account_path: str = ""
    google_application_credentials: str = ""

    # AWS SES config (required when notification_email_provider="ses")
    ses_region: str = "ap-southeast-1"
    ses_from_email: str = "noreply@ancu365.com"

    # eSMS.vn config (required when notification_sms_provider="esms")
    esms_api_key: str = ""
    esms_secret_key: str = ""

    # ── Phase 05: Digital signature vendor (AS-14 / TL-7) ──────────────────────
    # Provider selection: "stub" (default, v0) | "fastca" | "vinaca"
    # Swap to real provider once AS-14 vendor contract is signed (pre-launch gate).
    # FastCA is primary; VinaCA is fallback per TL-7.
    digital_signature_provider: str = "stub"

    # FastCA credentials (required when digital_signature_provider="fastca")
    fastca_api_key: str = ""
    fastca_api_secret: str = ""

    # VinaCA credentials (required when digital_signature_provider="vinaca")
    vinaca_api_key: str = ""
    vinaca_api_secret: str = ""

    # Zone code bị coi là rủi ro quy hoạch (cảnh báo US-06)
    # TODO: verify với TNMT — code tạm dựa trên tài liệu quy hoạch HCMC 2030
    risky_zone_codes: list[str] = ["DGT", "CXP", "DCC", "DXH"]

    # Bounding box toàn Việt Nam: (south, west, north, east) — WGS84
    # Phục vụ tra cứu quy hoạch 63 tỉnh.
    vn_bbox_full: tuple[float, float, float, float] = (8.0, 102.0, 23.5, 110.0)

    # ── Japan market (Phase 02) — provider mock flag ────────────────────────────
    # True (default): all payment/eSign/conference adapters return mock payloads.
    # Set to False in production after configuring OrgProviderConfig per org.
    use_mock_providers: bool = True

    # ── Japan market (Phase 00) ──────────────────────────────────────────────────
    # region: thị trường đang phục vụ. 'vn' = Việt Nam (mặc định); 'jp' = Nhật Bản.
    # VN-only routers (construction, planning, sale) trả 404 khi region='jp'.
    # JP-only routes trả 404 khi region='vn'.
    region: Literal["vn", "jp"] = "vn"
    # default_tz: múi giờ mặc định cho app (ISO tz string).
    # VN mặc định: 'Asia/Ho_Chi_Minh'. JP mặc định: 'Asia/Tokyo'.
    default_tz: str = "Asia/Ho_Chi_Minh"

    # ── Geo-search (tìm theo địa danh / tỉnh-thành / quanh đây) ────────────────
    # Feature flag: bật sau khi migration 0037 + backfill toạ độ hoàn tất.
    # Tắt (default) → /api/houses/search-nearby ẩn (404) và nhánh nearby của
    # /api/houses bị bỏ qua (fallback về text search). Cho phép deploy code trước.
    geo_search_enabled: bool = False

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=False,
        extra="ignore",
    )


settings = Settings()

# Hard-fail if running outside development with the default placeholder secret.
_DEFAULT_JWT_SECRET = "urbannest-dev-secret-change-me"
if settings.environment != "development" and settings.jwt_secret == _DEFAULT_JWT_SECRET:
    raise RuntimeError(
        "JWT_SECRET must be set to a non-default value when ENVIRONMENT != 'development'. "
        "Set the JWT_SECRET env var before starting the app."
    )
