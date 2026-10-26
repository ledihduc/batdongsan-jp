# CLAUDE.md — ancu365-backend (FastAPI + SQLAlchemy 2.0 + Postgres/PostGIS)

> Chỉ ghi NGUYÊN TẮC ỔN ĐỊNH (không chép bảng chi tiết dễ stale). Bản đồ route/model
> chi tiết: **`docs/ARCHITECTURE.generated.md`** (SINH TỰ ĐỘNG — `python scripts/gen_arch_map.py --write`,
> `check.sh` gate diff). Phương án tái cấu trúc: **`../AI-REFACTOR-PLAN.md`**.

## Định vị nhanh (cho AI)
- **Muốn hiểu 1 cụm → đọc `tests/<cụm>/` TRƯỚC** router/model (192 test = spec sống, chia theo cụm).
- Bản đồ endpoint→hàm & model→table: `docs/ARCHITECTURE.generated.md`.
- God-file có MỤC LỤC ở đầu (grep `MỤC LỤC`): `app/models.py` (53 model), `app/routers/construction.py` (8 resource).

## Kiến trúc — 2 thời kỳ (đang hợp nhất dần)
- 🟢 **CHUẨN ĐÍCH** (Phase 03-10: delegation/kyc/approval/owner_death/commission):
  `app/domain/<c>.py` (model) · `app/repositories/<c>.py` · `app/services/<c>/*.py` (logic) ·
  `app/api/routes/<c>.py` (router MỎNG gọi service) · `app/schemas/<c>.py` (Request/Response).
  **Viết code mới theo pattern này.** Mẫu tham chiếu: `app/services/delegation/`.
- 🔴 **NỢ** (core cũ): `app/models.py` gom hết · router phẳng logic-in-router (construction/reels/social) ·
  `app/helpers.py` grab-bag. Đừng nhân rộng; tái cấu trúc theo AI-REFACTOR-PLAN.

## Luật an toàn (deploy thủ công, KHÔNG có CI chặn)
- Chạy **`./check.sh`** trước deploy. Gate từng báo XANH GIẢ → **đọc kỹ output, tự kiểm tay** khi đổi model/route.
- Migration: additive + nullable + idempotent (inspect trước khi add) + có `downgrade()`. Đánh số tiếp `00NN_<mô tả>`.
- API path & prefix `/api/<resource>` KHÔNG đổi khi refactor. Đổi `models.py`/route → chạy `gen_arch_map.py --write` + commit.
- Deploy backend = MANUAL docker run (KHÔNG docker-compose repo — khác live). Xem `docs/deploy-runbook.md` / memory.
- Giữ role='guest' whitelist ở JWT register; SĐT masked (`phone_masked`) ở view public/RFQ.
</content>
</invoke>
