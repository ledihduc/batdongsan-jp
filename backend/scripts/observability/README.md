# Pipeline observability + tự-sửa-lỗi (self-heal)

Ghi log đầy đủ → lọc lỗi → Claude phân tích + vá → verify staging → deploy
canary + auto-rollback. **Safe-by-default**: không bật cờ thì chỉ phát hiện +
báo cáo, KHÔNG sửa code, KHÔNG deploy.

## Thành phần
| File | Vai trò |
|---|---|
| `app/observability/` | Structured logging (JSON), redaction PII/secret, request middleware, fingerprint lỗi |
| `app/routers/client_logs.py` | Nhận crash/error từ Flutter (`/api/client-logs`) |
| `scripts/observability/collect_errors.py` | Lọc + gom + xếp hạng lỗi từ log → `error_report.{json,md}` |
| `scripts/observability/guardrail_check.py` | Chốt an toàn: chặn diff chạm module nhạy cảm / migration / hạ tầng |
| `scripts/observability/selfheal.sh` | Orchestrator toàn pipeline |
| `scripts/observability/deploy_backend.sh` | Build + recreate container + health-check + **auto-rollback** |
| `scripts/observability/AUTOFIX_POLICY.md` | Chính sách nạp vào prompt Claude ("không đụng dữ liệu thật") |
| `scripts/observability/install_cron.sh` | Cài/gỡ cron định kỳ |

## Luồng
```
collect_errors → [autofix: claude sửa trên branch] → guardrail_check
   → verify (pytest trên staging DB ẩn danh) → [deploy canary + rollback] → audit
```
Kết quả mỗi lần chạy ở `storage/logs/selfheal_runs/<run-id>/`.
Ca cần người duyệt (chạm vùng nhạy cảm / test fail / rollback) ở
`storage/logs/escalations/`.

## Cờ điều khiển (tạo file = bật)
| File | Tác dụng | Mặc định |
|---|---|---|
| `ENABLE_AUTOFIX` | Cho Claude tự sửa code trên branch | TẮT |
| `ENABLE_AUTODEPLOY` | Cho tự deploy prod (canary+rollback) sau khi verify | TẮT |
| `KILLSWITCH` | Tồn tại → dừng ngay mọi thứ | — |

```bash
# Bật tự sửa (vẫn CHƯA deploy — bản vá verify xong nằm ở branch chờ tay):
touch scripts/observability/ENABLE_AUTOFIX
# Bật luôn auto-deploy prod (canary + auto-rollback):
touch scripts/observability/ENABLE_AUTODEPLOY
# Dừng khẩn cấp:
touch scripts/observability/KILLSWITCH
```

## Nguyên tắc "KHÔNG đụng dữ liệu thật" (cưỡng chế bằng cơ chế)
1. Log **redact PII/secret** tại chỗ ghi (email, SĐT, CCCD, số TK, JWT…).
2. Verify chạy trên **DB staging/test ephemeral** — không bao giờ prod DB.
3. `guardrail_check.py` **chặn** mọi diff chạm: migration/schema, `.env`, config,
   auth/KYC/bank/payment/delegation/retention/dispute… → chuyển người duyệt.
4. Deploy có **health-check + auto-rollback**; giữ image `:rollback`.
5. Yêu cầu **cây git sạch** trước khi tự sửa (không trộn thay đổi tay).

## Kích hoạt (thứ tự)
1. **Deploy backend** đã bật logging (để log bắt đầu chảy ra `storage/logs/`):
   ```bash
   bash scripts/observability/deploy_backend.sh
   ```
   (Đây là deploy production — chạy khi bạn đã review.)
2. Cài cron (an toàn, chỉ báo cáo cho tới khi bật cờ):
   ```bash
   bash scripts/observability/install_cron.sh
   ```
3. Theo dõi `storage/logs/error_report.md` vài ngày. Khi tin tưởng:
   `touch ENABLE_AUTOFIX` → rồi `ENABLE_AUTODEPLOY`.

## Chạy tay / kiểm thử
```bash
python3 scripts/observability/collect_errors.py --logs storage/logs   # lọc lỗi
bash scripts/observability/selfheal.sh --dry-run                       # thử luồng, không deploy
```
