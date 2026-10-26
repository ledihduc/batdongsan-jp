"""Tin NHU CẦU — "Cần thuê" / "Cần mua".

  POST   /api/demands          — đăng (cần đăng nhập)
  GET    /api/demands          — danh sách công khai (lọc kind/tỉnh/loại hình)
  GET    /api/demands/mine     — tin của tôi, gồm cả tin đã đóng/hết hạn
  GET    /api/demands/{id}     — chi tiết công khai
  PATCH  /api/demands/{id}     — đóng tin / gia hạn (chỉ chủ tin)

Router MỎNG: mọi nghiệp vụ nằm ở `app/services/demand/`.

Không có endpoint XOÁ: đóng tin (`status='closed'`) là đủ cho người dùng và giữ
được dữ liệu để biết nhu cầu nào từng tồn tại ở khu vực nào — thứ duy nhất có
giá trị khi bên CUNG còn thưa.

THỨ TỰ KHAI BÁO QUAN TRỌNG: `/mine` phải đứng TRƯỚC `/{demand_id}`, nếu không
FastAPI khớp "mine" vào tham số đường dẫn và trả 422.
"""

# KHÔNG dùng `from __future__ import annotations`: chú thích kiểu thành chuỗi
# thì pydantic không giải được thân request (đúng lỗi đã ghi ở `routers/leads.py`).

from fastapi import APIRouter, Depends, HTTPException, Query, Request

from sqlalchemy.orm import Session

from app import auth
from app.database import get_db
from app.domain.demand_post import DemandPost
from app.middleware.rate_limit import limiter
from app.schemas.demand import DemandCreate, DemandResponse, DemandUpdate
from app.services import demand as demand_service

router = APIRouter(prefix="/api/demands", tags=["demands"])


def _tra_danh_sach(db: Session, rows: list[DemandPost]) -> list[DemandResponse]:
    tat_ca_id = [i for r in rows for i in (r.category_ids or [])]
    ten_loai = demand_service.ten_loai_hinh(db, tat_ca_id)
    return [demand_service.to_response(db, r, ten_loai=ten_loai) for r in rows]


@router.post("", status_code=201, response_model=DemandResponse)
@limiter.limit("20/hour")
def create_demand(
    request: Request,
    body: DemandCreate,
    db: Session = Depends(get_db),
    claims: dict = Depends(auth.require_user),
):
    item = demand_service.create_demand(db, int(claims["sub"]), body)
    return demand_service.to_response(db, item)


@router.get("", response_model=list[DemandResponse])
def list_demands(
    kind: str | None = Query(default=None),
    province_code: str | None = Query(default=None),
    category_id: int | None = Query(default=None),
    q: str | None = Query(default=None, max_length=100),
    limit: int = Query(default=20, ge=1, le=50),
    offset: int = Query(default=0, ge=0),
    db: Session = Depends(get_db),
):
    rows = demand_service.list_demands(
        db,
        kind=kind,
        province_code=province_code,
        category_id=category_id,
        query=q,
        limit=limit,
        offset=offset,
    )
    return _tra_danh_sach(db, rows)


@router.get("/mine", response_model=list[DemandResponse])
def my_demands(
    db: Session = Depends(get_db),
    claims: dict = Depends(auth.require_user),
):
    rows = demand_service.list_demands(
        db, user_id=int(claims["sub"]), include_closed=True, limit=50
    )
    return _tra_danh_sach(db, rows)


@router.get("/{demand_id}", response_model=DemandResponse)
def get_demand(demand_id: int, db: Session = Depends(get_db)):
    item = db.get(DemandPost, demand_id)
    if item is None:
        raise HTTPException(status_code=404, detail="Không tìm thấy tin nhu cầu")
    return demand_service.to_response(db, item)


@router.patch("/{demand_id}", response_model=DemandResponse)
def update_demand(
    demand_id: int,
    body: DemandUpdate,
    db: Session = Depends(get_db),
    claims: dict = Depends(auth.require_user),
):
    item = db.get(DemandPost, demand_id)
    if item is None:
        raise HTTPException(status_code=404, detail="Không tìm thấy tin nhu cầu")
    # 404 chứ không 403: người lạ không cần biết tin id này có tồn tại hay không.
    if item.user_id != int(claims["sub"]):
        raise HTTPException(status_code=404, detail="Không tìm thấy tin nhu cầu")

    if body.extend:
        item = demand_service.extend_demand(db, item)
    elif body.status == "closed":
        item = demand_service.close_demand(db, item)
    elif body.status == "open":
        # Mở lại một tin đã hết hạn mà không dời hạn thì nó vẫn ẩn — người dùng
        # bấm xong không thấy gì đổi. Mở lại luôn kèm gia hạn.
        item = demand_service.extend_demand(db, item)
    return demand_service.to_response(db, item)
