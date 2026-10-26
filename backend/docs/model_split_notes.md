# Ghi chú tách app/models.py (§C1) — dữ liệu đo từ §B2

## FK (đo bằng probe, 2026-07):
- **`users` = HUB**: 40 FK trỏ tới. Mọi domain đều tham chiếu `users.id`.
- Hub phụ: rooms(6), contracts(4), tenants(3), invoices(3), delegations(3), buildings(2).
- FK CHÉO module hiện chỉ ở `app/domain/*` (delegation 7, tenant_authority 4, owner_death 4,
  bank_account_reveal_log 3, operator_business 3). Toàn bộ `models.py` đang là 1 module.

## Hệ quả cho cách tách (an toàn):
1. SQLAlchemy resolve FK theo **tên bảng dạng string** lúc mapper-config → tách models.py
   thành nhiều file KHÔNG gây lỗi thứ tự MIỄN LÀ `app/models/__init__.py` import ĐỦ mọi
   submodule (để mọi class đăng ký lên cùng `Base.metadata`).
2. Sẹo FK-né hiện có (`models.py` cũ dòng 77-82, 440-442, 1087-1089) là do FK CHÉO Base↔domain
   (2 Base khác nhau) — KHÔNG phát sinh thêm khi tách trong CÙNG Base.
3. **Gate an toàn**: `scripts/gen_model_tables.py` + `check.sh` (bước "tập bảng ORM") diff
   `docs/model_tables.txt` → FAIL NGAY nếu quên import 1 submodule (bảng biến mất). Chạy sau
   MỖI file tách. Đây là lưới an toàn thay cho `alembic check` (còn nhiễu autogenerate).

## Thứ tự tách đề xuất (ít phụ thuộc → nhiều):
preferences → reels → social → construction → khai_bao → homestay → billing → audit →
host → rental → messaging → listing → **core (users) cuối** (hub, nhiều thứ import).
Mỗi bước: cắt nhóm sang `app/models/<domain>.py`, thêm import vào `__init__.py`, chạy gate.
</content>
</invoke>
