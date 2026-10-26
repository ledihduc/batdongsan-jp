"""Chứng từ riêng tư — đăng ký nguồn, phân giải TỪ DB, ký URL ngắn hạn.

Vì sao:
  - Hợp đồng, ảnh cọc, CCCD, giấy chứng tử… đang nằm ở `/uploads` (mount tĩnh,
    ai có link là xem được) hoặc kho nhạy cảm. Màn quản trị KHÔNG được phát
    đường dẫn thô: client chỉ gửi (source_type, source_id, field, index), server
    tự đọc giá trị trong hàng DB rồi mới tìm ra tệp. Không có đường nào để
    client đưa vào một path tuỳ ý.
  - URL xem là token ký (typ="doc", 300s) gắn với tham chiếu + người ký. Mỗi
    lần ký/mở đều ghi nhật ký (`document.sign` / `document.open`).

Ba kiểu lưu trữ:
  - ``legacy``    giá trị dạng `/uploads/<tên>`; nếu tên đã đăng ký trong
                  `private_documents` (đã chép vào kho riêng) thì đọc từ kho riêng.
  - ``sensitive`` đường dẫn tương đối trong kho `sensitive_file_service`.
  - ``cccd``      đường dẫn tuyệt đối trong `storage/cccd` (cccd_storage).
"""

from __future__ import annotations

import mimetypes
import os
import re
import secrets
from dataclasses import dataclass, field
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Any, Callable, Optional

from jose import ExpiredSignatureError, JWTError, jwt
from sqlalchemy.orm import Session

from app import models
from app.config import settings

TOKEN_TTL_SECONDS = 300
TOKEN_TYP = "doc"

_REPO_ROOT = Path(__file__).resolve().parents[3]
_SAFE_NAME = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._-]{0,199}$")
# Chỉ những loại này được hiển thị inline; còn lại ép tải về dạng nhị phân
# (chặn HTML/SVG tải lên rồi chạy script trong origin quản trị).
_INLINE_TYPES = ("image/jpeg", "image/png", "image/webp", "image/gif", "application/pdf",
                 "video/mp4", "video/webm", "video/quicktime")


class DocumentError(Exception):
    """Lỗi nghiệp vụ khi phân giải chứng từ — route đổi sang mã HTTP."""

    def __init__(self, status: int, code: str, message: str):
        super().__init__(message)
        self.status = status
        self.code = code
        self.message = message


# ── Thư mục kho riêng ─────────────────────────────────────────────────────────


def private_dir() -> Path:
    """Kho riêng: env PRIVATE_DOCUMENTS_DIR, mặc định `<repo>/storage/private_documents`.

    Từ chối nếu nằm TRONG upload_dir — khi đó nó bị mount tĩnh và mất hết ý nghĩa.
    """
    raw = os.getenv("PRIVATE_DOCUMENTS_DIR") or str(_REPO_ROOT / "storage" / "private_documents")
    p = Path(raw).resolve()
    up = Path(settings.upload_dir).resolve()
    if p == up or up in p.parents:
        raise RuntimeError("PRIVATE_DOCUMENTS_DIR không được nằm trong upload_dir (bị phục vụ tĩnh)")
    return p


def private_path(object_key: str) -> Path:
    base = private_dir()
    p = (base / object_key).resolve()
    if base not in p.parents:
        raise DocumentError(400, "ADMIN_DOC_BAD_KEY", "Khoá chứng từ không hợp lệ")
    return p


def legacy_name(value: Any) -> Optional[str]:
    """`/uploads/abc.jpg` hoặc `https://host/uploads/abc.jpg` → `abc.jpg`.

    Giá trị khác (link ngoài, path lạ, có `..`) → None: không phải tệp của ta.
    """
    if not isinstance(value, str):
        return None
    v = value.strip().split("?", 1)[0].split("#", 1)[0]
    if "/uploads/" not in v:
        return None
    name = v.rsplit("/uploads/", 1)[1]
    if "/" in name or "\\" in name or ".." in name or not _SAFE_NAME.match(name):
        return None
    return name


# ── Danh mục nguồn ────────────────────────────────────────────────────────────


@dataclass(frozen=True)
class FieldSpec:
    label: str
    category: str               # contract | deposit_proof | kyc | death_certificate | business_license | payment_proof | other
    storage: str                # legacy | sensitive | cccd
    is_list: bool = False
    reason_required: bool = False


@dataclass(frozen=True)
class SourceSpec:
    code: str
    label: str
    loader: Callable[[Session, str], Any]
    fields: dict[str, FieldSpec]
    permissions: tuple[str, ...]           # có MỘT trong các quyền này là được ký
    participants: Callable[[Session, Any], set[int]] = field(default=lambda db, row: set())
    owner: Callable[[Any], Optional[int]] = field(default=lambda row: None)


def _loader(model: Any, *, int_key: bool = True):
    """Nạp hàng theo khoá. `model` có thể là chuỗi 'module.Class' (nạp muộn,
    tránh import vòng với app.domain)."""

    def load(db: Session, sid: str):
        m = model
        if isinstance(m, str):
            mod, _, name = m.rpartition(".")
            m = getattr(__import__(mod, fromlist=[name]), name)
        try:
            key = int(sid) if int_key else str(sid)
        except (TypeError, ValueError):
            return None
        return db.get(m, key)

    return load


def _journey_people(db: Session, journey_id: Optional[int]) -> set[int]:
    j = db.get(models.RentalJourney, journey_id) if journey_id else None
    return {x for x in ((j.customer_id, j.sale_id, j.owner_id) if j else ()) if x}


def _ids(*xs) -> set[int]:
    return {int(x) for x in xs if x}


SOURCES: dict[str, SourceSpec] = {
    "rental_journey": SourceSpec(
        "rental_journey", "Hợp đồng hành trình thuê", _loader(models.RentalJourney),
        {"contract_urls": FieldSpec("Hợp đồng", "contract", "legacy", is_list=True)},
        ("rental_documents.read",),
        lambda db, r: _ids(r.customer_id, r.sale_id, r.owner_id),
        lambda r: r.owner_id,
    ),
    "rental_journey_payment": SourceSpec(
        "rental_journey_payment", "Chứng từ cọc", _loader(models.RentalJourneyPayment),
        {"proof_urls": FieldSpec("Ảnh chứng từ cọc", "deposit_proof", "legacy", is_list=True)},
        ("rental_documents.read", "payments.read"),
        lambda db, r: _journey_people(db, r.journey_id) | _ids(r.submitted_by),
        lambda r: r.submitted_by,
    ),
    "rental_journey_report": SourceSpec(
        "rental_journey_report", "Bằng chứng báo cáo giao dịch", _loader(models.RentalJourneyReport),
        {"evidence_urls": FieldSpec("Bằng chứng", "other", "legacy", is_list=True)},
        ("rental_documents.read",),
        lambda db, r: _ids(r.reporter_id),
        lambda r: r.reporter_id,
    ),
    "sale_application": SourceSpec(
        "sale_application", "Hồ sơ xin làm Sale", _loader(models.SaleApplication),
        # Hồ sơ Sale thường kèm ảnh giấy tờ tuỳ thân → coi như KYC, bắt buộc lý do.
        {"evidence_urls": FieldSpec("Giấy tờ minh chứng", "kyc", "legacy", is_list=True, reason_required=True)},
        ("partners.read", "compliance.read"),
        lambda db, r: _ids(r.applicant_user_id),
        lambda r: r.applicant_user_id,
    ),
    "platform_payment": SourceSpec(
        "platform_payment", "Chứng từ thanh toán", _loader(models.PlatformPayment),
        {"evidence_urls": FieldSpec("Chứng từ chuyển khoản", "payment_proof", "legacy", is_list=True)},
        ("payments.read",),
        lambda db, r: _ids(r.payer_user_id),
        lambda r: r.payer_user_id,
    ),
    "contract": SourceSpec(
        "contract", "Hợp đồng thuê", _loader(models.Contract),
        {
            "damage_photos": FieldSpec("Ảnh hư hỏng", "contract", "legacy", is_list=True),
            "handover_photos": FieldSpec("Ảnh bàn giao", "contract", "legacy", is_list=True),
        },
        ("rental_documents.read",),
        lambda db, r: _ids(r.host_id),
        lambda r: r.host_id,
    ),
    "operator_business_profile": SourceSpec(
        "operator_business_profile", "KYC doanh nghiệp",
        _loader("app.domain.operator_business.OperatorBusinessProfile"),
        {
            "gpkd_document_path": FieldSpec("Giấy phép kinh doanh", "business_license", "sensitive", reason_required=True),
            "legal_representative_cccd_front_path": FieldSpec("CCCD người đại diện (mặt trước)", "kyc", "sensitive", reason_required=True),
            "legal_representative_cccd_back_path": FieldSpec("CCCD người đại diện (mặt sau)", "kyc", "sensitive", reason_required=True),
            # eKYC chủ nhà (mig 0140): đối chiếu chân dung với ảnh CCCD.
            "legal_representative_selfie_path": FieldSpec("Ảnh chân dung (eKYC)", "kyc", "sensitive", reason_required=True),
        },
        ("compliance.read", "partners.read"),
        lambda db, r: _ids(r.user_id),
        lambda r: r.user_id,
    ),
    "owner_death_certificate": SourceSpec(
        "owner_death_certificate", "Hồ sơ chủ sở hữu mất",
        _loader("app.domain.owner_death.OwnerDeathCertificate", int_key=False),
        {
            "death_certificate_path": FieldSpec("Giấy chứng tử", "death_certificate", "sensitive", reason_required=True),
            "notarized_poa_path": FieldSpec("Uỷ quyền công chứng của người thừa kế", "death_certificate", "sensitive", reason_required=True),
        },
        ("compliance.read",),
        lambda db, r: _ids(r.submitted_by_user_id, r.executor_user_id),
        lambda r: r.owner_user_id,
    ),
    "delegation": SourceSpec(
        "delegation", "Giấy uỷ quyền vận hành",
        _loader("app.domain.delegation.Delegation", int_key=False),
        {"poa_document_path": FieldSpec("Giấy uỷ quyền", "contract", "sensitive", reason_required=True)},
        ("compliance.read",),
        lambda db, r: _ids(r.owner_id, r.operator_id),
        lambda r: r.owner_id,
    ),
    "tenant": SourceSpec(
        "tenant", "CCCD người thuê", _loader(models.Tenant),
        {
            "cccd_front_path": FieldSpec("CCCD (mặt trước)", "kyc", "cccd", reason_required=True),
            "cccd_back_path": FieldSpec("CCCD (mặt sau)", "kyc", "cccd", reason_required=True),
        },
        ("rental_documents.read", "compliance.read"),
        lambda db, r: _ids(r.host_id),
        lambda r: r.host_id,
    ),
}


def source_spec(source_type: str) -> SourceSpec:
    spec = SOURCES.get(source_type)
    if spec is None:
        raise DocumentError(422, "ADMIN_DOC_BAD_SOURCE", "Loại nguồn chứng từ không hỗ trợ")
    return spec


# ── Phân giải ─────────────────────────────────────────────────────────────────


@dataclass
class ResolvedDoc:
    source_type: str
    source_id: str
    field: str
    index: int
    spec: FieldSpec
    storage: str                 # legacy | private | sensitive | cccd
    ref: str                     # giá trị trong DB / object_key — KHÔNG trả ra API
    filename: str
    private_document_id: Optional[int] = None
    row: Any = None

    @property
    def content_type(self) -> str:
        return mimetypes.guess_type(self.filename)[0] or "application/octet-stream"


def _values(row: Any, fname: str, fs: FieldSpec) -> list:
    v = getattr(row, fname, None)
    if fs.is_list:
        return [x for x in (v or []) if x] if isinstance(v, (list, tuple)) else []
    return [v] if v else []


def load_source(db: Session, source_type: str, source_id: str) -> tuple[SourceSpec, Any]:
    spec = source_spec(source_type)
    row = spec.loader(db, str(source_id))
    if row is None:
        raise DocumentError(404, "ADMIN_NOT_FOUND", "Không tìm thấy bản ghi chứa chứng từ")
    return spec, row


def resolve(db: Session, source_type: str, source_id: str, field_name: str, index: int = 0) -> ResolvedDoc:
    """Tìm tệp CHỈ từ giá trị trong hàng DB. Client không bao giờ đưa path."""
    spec, row = load_source(db, source_type, source_id)
    fs = spec.fields.get(field_name)
    if fs is None:
        raise DocumentError(422, "ADMIN_DOC_BAD_FIELD", "Trường chứng từ không hợp lệ cho nguồn này")
    vals = _values(row, field_name, fs)
    idx = int(index or 0)
    if idx < 0 or idx >= len(vals):
        raise DocumentError(404, "ADMIN_DOC_NOT_FOUND", "Không có chứng từ ở vị trí này")
    raw = vals[idx]
    base = dict(source_type=source_type, source_id=str(source_id), field=field_name, index=idx, spec=fs, row=row)

    if fs.storage == "legacy":
        name = legacy_name(raw)
        if name is None:
            raise DocumentError(422, "ADMIN_DOC_EXTERNAL", "Chứng từ không nằm trong kho của hệ thống")
        reg = db.query(models.PrivateDocument).filter_by(legacy_upload_name=name).first()
        if reg is not None:
            return ResolvedDoc(storage="private", ref=reg.object_key, filename=name,
                               private_document_id=reg.id, **base)
        return ResolvedDoc(storage="legacy", ref=name, filename=name, **base)
    if not isinstance(raw, str) or "\x00" in raw:
        raise DocumentError(404, "ADMIN_DOC_NOT_FOUND", "Chứng từ không hợp lệ")
    return ResolvedDoc(storage=fs.storage, ref=raw, filename=os.path.basename(raw) or "document", **base)


def describe(source_type: str, row: Any) -> list[dict]:
    """Danh sách chứng từ của một hàng, cho màn chi tiết. KHÔNG có đường dẫn."""
    spec = SOURCES.get(source_type)
    if spec is None or row is None:
        return []
    out: list[dict] = []
    for fname, fs in spec.fields.items():
        for i, v in enumerate(_values(row, fname, fs)):
            internal = fs.storage != "legacy" or legacy_name(v) is not None
            out.append({
                "source_type": source_type,
                "source_id": str(row.id),
                "field": fname,
                "index": i,
                "label": fs.label + (f" #{i + 1}" if fs.is_list else ""),
                "category": fs.category,
                "reason_required": fs.reason_required,
                "private": True,
                "signable": internal,
            })
    return out


def read_bytes_or_path(db: Session, doc: ResolvedDoc, *, actor_id: int, reason: str,
                       ip: Optional[str]) -> tuple[Optional[Path], Optional[bytes]]:
    """Trả (path, None) cho tệp đọc trực tiếp, (None, bytes) cho kho có service riêng.

    Kho nhạy cảm/CCCD đi qua service gốc để nó tự ghi `cccd_access_logs`.
    """
    if doc.storage == "legacy":
        base = Path(settings.upload_dir).resolve()
        p = (base / doc.ref).resolve()
        if base not in p.parents or not p.is_file():
            raise DocumentError(404, "ADMIN_DOC_FILE_MISSING", "Tệp chứng từ không còn trên máy chủ")
        return p, None
    if doc.storage == "private":
        p = private_path(doc.ref)
        if not p.is_file():
            raise DocumentError(404, "ADMIN_DOC_FILE_MISSING", "Tệp chứng từ không còn trong kho riêng")
        return p, None
    if doc.storage == "sensitive":
        from app.services import sensitive_file_service

        try:
            return None, sensitive_file_service.read_file(doc.ref, actor_id, reason or "admin-v2", db=db, ip_address=ip)
        except (FileNotFoundError, ValueError):
            raise DocumentError(404, "ADMIN_DOC_FILE_MISSING", "Tệp chứng từ không còn trong kho nhạy cảm")
    if doc.storage == "cccd":
        from app.services import cccd_storage

        try:
            return None, cccd_storage.read_cccd(doc.ref, actor_id, db, ip_address=ip)
        except (FileNotFoundError, PermissionError):
            raise DocumentError(404, "ADMIN_DOC_FILE_MISSING", "Tệp CCCD không còn trong kho")
    raise DocumentError(500, "ADMIN_DOC_BAD_STORAGE", "Kiểu lưu trữ không hỗ trợ")


def safe_content_type(doc: ResolvedDoc) -> tuple[str, bool]:
    """(content_type, inline?) — loại lạ ép thành octet-stream tải về."""
    ct = doc.content_type
    if ct in _INLINE_TYPES:
        return ct, True
    return "application/octet-stream", False


# ── Token ─────────────────────────────────────────────────────────────────────


def sign_token(*, actor_id: int, audience: str, doc: ResolvedDoc, sign_log_id: Optional[int],
               permission: Optional[str]) -> tuple[str, datetime]:
    now = datetime.now(timezone.utc)
    exp = now + timedelta(seconds=TOKEN_TTL_SECONDS)
    payload = {
        "typ": TOKEN_TYP,
        "sub": str(actor_id),
        "aud": audience,            # admin | app
        "src": doc.source_type,
        "sid": doc.source_id,
        "fld": doc.field,
        "idx": doc.index,
        "lid": sign_log_id,
        "prm": permission,
        "jti": secrets.token_urlsafe(9),
        "iat": int(now.timestamp()),
        "exp": int(exp.timestamp()),
    }
    return jwt.encode(payload, settings.jwt_secret, algorithm="HS256"), exp.replace(tzinfo=None)


def verify_doc_token(token: str) -> dict:
    """Giải token xem chứng từ. Hết hạn → 410, sai → 401."""
    if not token or len(token) > 2048:
        raise DocumentError(401, "ADMIN_DOC_TOKEN_INVALID", "Liên kết xem chứng từ không hợp lệ")
    try:
        claims = jwt.decode(token, settings.jwt_secret, algorithms=["HS256"],
                            options={"verify_aud": False})
    except ExpiredSignatureError:
        raise DocumentError(410, "ADMIN_DOC_TOKEN_EXPIRED", "Liên kết xem chứng từ đã hết hạn. Mở lại từ màn chi tiết.")
    except JWTError:
        raise DocumentError(401, "ADMIN_DOC_TOKEN_INVALID", "Liên kết xem chứng từ không hợp lệ")
    if claims.get("typ") != TOKEN_TYP or claims.get("aud") not in ("admin", "app"):
        raise DocumentError(401, "ADMIN_DOC_TOKEN_INVALID", "Liên kết xem chứng từ không hợp lệ")
    return claims


def download_url(token: str) -> str:
    return f"/api/v2/admin/documents/download/{token}"


def exists(doc: ResolvedDoc) -> bool:
    """Kiểm tệp còn không — KHÔNG đọc nội dung (không phát sinh nhật ký đọc)."""
    try:
        if doc.storage == "legacy":
            base = Path(settings.upload_dir).resolve()
            p = (base / doc.ref).resolve()
            return base in p.parents and p.is_file()
        if doc.storage == "private":
            return private_path(doc.ref).is_file()
        if doc.storage == "sensitive":
            from app.services import sensitive_file_service

            return sensitive_file_service._safe_path(doc.ref).is_file()
        if doc.storage == "cccd":
            from app.services import cccd_storage

            return cccd_storage._is_path_inside_cccd_dir(doc.ref) and os.path.isfile(doc.ref)
    except (ValueError, OSError, DocumentError, RuntimeError):
        return False
    return False


def is_participant(db: Session, source_type: str, row: Any, user_id: int) -> bool:
    spec = SOURCES.get(source_type)
    if spec is None:
        return False
    try:
        return int(user_id) in spec.participants(db, row)
    except Exception:  # noqa: BLE001 — hàng dở dang thì coi như không phải người trong cuộc
        return False
