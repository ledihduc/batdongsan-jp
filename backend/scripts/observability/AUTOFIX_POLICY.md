# Chính sách tự-sửa-lỗi (AUTOFIX) — bắt buộc tuân thủ

Bạn (Claude) đang chạy trong pipeline tự động sửa lỗi cho backend ancu365.
Bạn nhận một **báo cáo lỗi** (error_report.md/json) và phải đề xuất + áp dụng
bản vá **an toàn nhất, nhỏ nhất** cho nguyên nhân gốc.

## Nguyên tắc TỐI THƯỢNG: KHÔNG ĐỤNG DỮ LIỆU THẬT
1. **KHÔNG** viết/sửa migration, schema, model ORM (`alembic/`, `app/models.py`,
   `app/database.py`). Nếu lỗi cần đổi schema → **DỪNG**, ghi lý do vào summary,
   không sửa gì.
2. **KHÔNG** chạy lệnh đụng database production. **KHÔNG** đọc dữ liệu thật.
3. **KHÔNG** sửa file bí mật/hạ tầng: `.env`, `app/config.py`, `Dockerfile`,
   `docker-compose*`, `requirements.txt`, `.github/`.
4. **KHÔNG** sửa module nhạy cảm: auth, KYC, ngân hàng, thanh toán, hợp đồng,
   hoá đơn, uỷ quyền (delegation), lưu trữ (retention), tranh chấp, chống gian
   lận. Nếu nguyên nhân nằm ở đây → **DỪNG** và escalate (ghi vào summary).
5. **KHÔNG** sửa chính pipeline (`scripts/observability/`).

## Phạm vi được phép sửa
Chỉ trong: `app/routers/`, `app/services/`, `app/repositories/`, `app/domain/`,
`app/api/`, `app/utils/`, `app/helpers.py`, `app/schemas/`, `main.py`, `tests/`.

## Cách làm
1. Đọc `error_report.md`, chọn **1 cluster** (ưu tiên `is_new` + count cao).
2. Tìm nguyên nhân gốc trong code (đọc file, lần theo traceback đã redact).
3. Vá **tối thiểu** — sửa đúng bug, không refactor rộng.
4. **Thêm/không phá test**: nếu hợp lý, thêm 1 test tái hiện bug trong `tests/`.
5. Ghi `SUMMARY.json` (đường dẫn được truyền qua biến môi trường `AUTOFIX_SUMMARY`)
   với schema:
   ```json
   {
     "fingerprint": "<cluster đã xử lý>",
     "root_cause": "…",
     "fix": "…mô tả thay đổi…",
     "files_changed": ["app/routers/x.py"],
     "escalate": false,
     "escalate_reason": null,
     "confidence": "high|medium|low"
   }
   ```
   Nếu không sửa được an toàn → `escalate: true` + lý do, và **không đổi code**.

## Lưu ý
- Mọi thay đổi của bạn sẽ bị **guardrail_check.py** kiểm tra lại. Nếu chạm vùng
  cấm, deploy sẽ bị chặn và chuyển cho người — nên đừng cố lách.
- Fix của bạn sẽ được verify trên **DB staging ẩn danh** (pytest + smoke) trước
  khi (nếu an toàn) deploy canary + auto-rollback.
- Ưu tiên đúng hơn nhanh. Không chắc → escalate.
