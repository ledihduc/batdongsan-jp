"""Backoffice quản trị V2 — mọi endpoint dưới `/api/v2/admin/*`.

Mỗi module một tệp; hạ tầng chung (quyền, nhật ký, envelope, lệnh ghi) ở
`app/services/admin_v2/core.py`. Endpoint cũ (`/api/admin/*`, `/admin/kyc`,
`/api/reels/moderation`…) GIỮ NGUYÊN cho app Flutter.
"""

from fastapi import APIRouter

from app.api.routes.admin_v2 import (
    auth, compliance, content, documents, finance, overview, partners, rentals, staff, system,
)

router = APIRouter()
for _m in (auth, overview, staff, content, partners, rentals, finance, compliance, system, documents):
    router.include_router(_m.router)
