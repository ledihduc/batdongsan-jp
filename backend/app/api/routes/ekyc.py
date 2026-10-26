"""eKYC chủ nhà — xem `app/services/ekyc_chu_nha.py`.

POST /api/ekyc/link          (đăng nhập)  tạo link làm eKYC trên thiết bị khác
GET  /api/ekyc/ho-so         hồ sơ nháp / trạng thái
PUT  /api/ekyc/thong-tin     họ tên · số CCCD · tên + số giấy phép kinh doanh
POST /api/ekyc/anh/{loai}    cccd_truoc · cccd_sau · chan_dung · gpkd (base64)
POST /api/ekyc/nop           nộp → hàng đợi KYC của admin

Mọi đường trừ /link nhận HOẶC đăng nhập thường HOẶC header `X-Ekyc-Token`
(token trong link) — token chỉ mở đúng hồ sơ eKYC của người tạo link.
"""

from typing import Optional

from fastapi import APIRouter, Depends, Header, HTTPException, Request
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from app import auth, models
from app.database import get_db
from app.services import ekyc_chu_nha as svc

router = APIRouter(prefix="/api/ekyc", tags=["ekyc"])


def _nguoi(
    request: Request,
    db: Session = Depends(get_db),
    x_ekyc_token: Optional[str] = Header(default=None),
) -> int:
    if x_ekyc_token:
        uid = svc.nguoi_cua_token(db, x_ekyc_token)
        # Tài khoản bị khoá thì link cũng chết theo — tự kiểm (không dựa vào
        # hàm riêng của auth vì bản đang chạy có thể chưa có).
        u = db.get(models.User, uid)
        if u is None or u.is_active is False:
            raise HTTPException(403, "Tài khoản đã bị khoá hoặc vô hiệu hoá")
        return uid
    return int(auth.require_user(auth.optional_user(request), db)["sub"])


class ThongTinVao(BaseModel):
    ho_ten: str = Field(max_length=300)
    #: Bỏ trống = giữ số đã khai (server chỉ lưu dạng băm, không trả lại được).
    so_cccd: str = Field(default="", max_length=20)
    ten_kinh_doanh: str = Field(max_length=300)
    so_gpkd: str = Field(max_length=60)


class AnhVao(BaseModel):
    anh_base64: str = Field(min_length=10, max_length=15_000_000)


@router.post("/link", status_code=201)
def tao_link(claims: dict = Depends(auth.require_user), db: Session = Depends(get_db)):
    return svc.tao_link(db, int(claims["sub"]))


@router.get("/ho-so")
def xem(uid: int = Depends(_nguoi), db: Session = Depends(get_db)):
    return svc.xem(db, uid)


@router.put("/thong-tin")
def thong_tin(body: ThongTinVao, uid: int = Depends(_nguoi), db: Session = Depends(get_db)):
    return svc.luu_thong_tin(
        db, uid, ho_ten=body.ho_ten, so_cccd=body.so_cccd,
        ten_kinh_doanh=body.ten_kinh_doanh, so_gpkd=body.so_gpkd,
    )


@router.post("/anh/{loai}")
def anh(loai: str, body: AnhVao, uid: int = Depends(_nguoi), db: Session = Depends(get_db)):
    return svc.luu_anh(db, uid, loai, body.anh_base64)


@router.post("/nop")
def nop(uid: int = Depends(_nguoi), db: Session = Depends(get_db)):
    return svc.nop(db, uid)
