# Chạy bản demo thị trường vn (và quay về jp)

Cùng một image và một DB demo. Đổi thị trường bằng 2 biến shell rồi `up -d`. Không sửa DB (plan 20261027-1102,
Phase 13, T6). Image phải build từ code có Phase 13 (`app/services/vn_search/`): thư mục registry mount từ working tree
nên `registry.vn.yaml` luôn có, image cũ thiếu handler ⇒ bản vn không khởi động. Lần đầu: `DEMO_REGION=vn DEMO_TZ=Asia/Ho_Chi_Minh $DC up -d --build backend`.

`$DC` là lệnh docker compose của bản demo cổng 3010:
`docker compose -f docker-compose.yml -f docker-compose.override.yml -f <compose 3010 ngoài repo>`.
File compose 3010 khai `REGION: ${DEMO_REGION:-jp}` và `DEFAULT_TZ: ${DEMO_TZ:-Asia/Tokyo}`.

## Backend và Flutter phải đổi CÙNG cặp

| Thị trường | Backend | Flutter web |
|---|---|---|
| vn | `DEMO_REGION=vn DEMO_TZ=Asia/Ho_Chi_Minh $DC up -d backend` | `flutter run -d chrome --web-port 5050 --dart-define=API_BASE_URL=http://localhost:3010 --dart-define=REGION=vn` |
| jp (mặc định) | `$DC up -d backend` | như trên với `--dart-define=REGION=jp` |

Biến chỉ đặt cho MỘT lệnh (tiền tố như bảng trên). Đừng `export DEMO_REGION=vn`: khi đó lệnh "về jp" `$DC up -d backend`
vẫn chạy bản vn (kiểm `docker exec ancu365-backend env | rg '^REGION='`; lỡ export thì `unset DEMO_REGION DEMO_TZ`).

Nếu backend và Flutter lệch thị trường, app gọi route của thị trường kia (vd `/api/jp/*` trả 404 ở bản vn).

Đã đổi ngôn ngữ trong app thì trình duyệt còn giữ lựa chọn cũ. Muốn mở bằng ngôn ngữ mặc định của thị trường,
xoá lựa chọn đó trong DevTools Console:
`localStorage.removeItem('app_lang'); location.reload()` (khoá là `app_lang`, không có tiền tố `flutter.` —
`lib/data/services/_session_storage_web.dart`). Kiểm: `Object.keys(localStorage).filter(k => k.includes('app_lang'))` ⇒ `[]`.

## Seed 20 tin demo VN (HCM + Hà Nội)

```bash
$DC exec -T -e REGION=vn -e PYTHONPATH=/app backend python scripts/seed_vn_demo.py          # idempotent
$DC exec -T -e REGION=vn -e PYTHONPATH=/app backend python scripts/seed_vn_demo.py --undo   # gỡ
```

- Lệnh seed chạy được cả khi container đang ở bản jp: `-e REGION=vn` chỉ đổi env của tiến trình seed. Thiếu `REGION=vn` thì lệnh dừng với exit 2.
- Tin demo có tiêu đề kết thúc bằng "(demo)", host là `vn-demo-host@example.invalid`.
- Lệnh `--undo` xoá wishlist trỏ tới tin demo, rồi xoá tin demo và host demo. Loại hình và tin thật giữ nguyên.
- Dữ liệu AI đã ghi (pending, yêu thích qua AI): `$DC exec -T -e PYTHONPATH=/app backend python scripts/ai_actions_undo.py --all --yes`.

## AI ở bản vn

- Bản vn có `/mcp`, `/api/ai/chat` và `/api/ai/actions/*` vì có file `app/ai_capabilities/registry/registry.vn.yaml`. Xoá file này thì bản vn tắt AI.
- Có 3 action: `search_listings`, `get_listing`, `save_favorite`. Ở bản vn không có `request_viewing`.
- Connector MCP giữ nguyên khi đổi thị trường: cùng 2 tool, `initialize.instructions` giống hệt. AI biết thị trường đang chạy khi gọi `get_system_skills`.
- `search_listings` chỉ trả tin VN, kể cả khi DB có tin JP. Tham số `location` được chuẩn hoá trước khi lọc (`vn_location_normalizer.py`: bỏ "TP."/"Thành phố", "Sài Gòn"/"HCM" → "Hồ Chí Minh", "Q1"/"District 1" → "Quận 1"; "Ba Đình, Hà Nội" phải khớp cả hai phần). Mỗi phần khớp đúng tên quận ("Quận 1" không khớp "Quận 10") hoặc khớp một phần tên thành phố.
- Kết quả gửi cho model gồm tiêu đề và mô tả (≤1500 ký tự) nguyên văn, không lọc SĐT/email trong text. Chỉ chạy bản vn trên DB demo (tin seed); chạy trên tin VN thật cần lọc trước.

## 3 lệnh kiểm sau khi đổi sang vn

```bash
curl -s -o /dev/null -w 'jp_route=%{http_code}\n' 'http://localhost:3010/api/jp/stations/search?q=a'   # 404
curl -s -X POST http://localhost:3010/mcp -H 'Content-Type: application/json' \
  -H 'Accept: application/json, text/event-stream' -H 'MCP-Protocol-Version: 2025-06-18' \
  -d '{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"get_system_skills","arguments":{}}}'  # market "vn"
curl -s 'http://localhost:3010/api/houses?limit=100' | python3 -c \
  'import sys,json;d=json.load(sys.stdin);print("jp_houses_in_vn",sum("（デモ）" in x["title"] for x in d["houses"]))'  # 0
```

## Quay về jp

```bash
$DC up -d backend && docker exec ancu365-backend env | rg '^REGION='   # REGION=jp
```
