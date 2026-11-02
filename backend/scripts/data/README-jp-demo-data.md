# Dữ liệu demo JP (Tokyo)

**Dữ liệu demo tự soạn — KHÔNG phải bản 駅データ.jp có license.** Chỉ dùng cho demo/PoC.

| File | Nội dung | Nạp bằng |
|---|---|---|
| `jp_stations_tokyo_seed.csv` | 51 dòng ga Tokyo (6 tuyến), định dạng tương thích 駅データ.jp. Mã `line_cd`/`station_cd` tự đặt, toạ độ **gần đúng** (4 chữ số thập phân). | `python scripts/import_jp_stations.py --csv scripts/data/jp_stations_tokyo_seed.csv` |
| `jp_listings_tokyo_demo.json` | 36 tin thuê `published`, tiêu đề/mô tả tiếng Nhật, mô tả kết thúc `（デモデータ）`, địa chỉ chỉ tới 丁目 (không số nhà). | `python scripts/seed_jp_demo.py` (REGION=jp; `--undo` để gỡ) |

- Một ga nằm trên nhiều tuyến có nhiều dòng (vd 渋谷: 山手線, 銀座線, 東急東横線, 京王井の頭線) — đúng mô hình 駅データ.jp.
- 7 tin có tiền tố tag (`[SBY-OK1]`, `[SBY-NG-RENT]`, `[EBS-NG-STATION]`…) là **tin kiểm thử** cho bộ lọc `max_rent=150000 & 1LDK & 渋谷 & 徒歩≤10分`: 3 tin khớp, 4 tin trượt đúng 1 điều kiện. Đừng đổi giá/間取り/ga/phút đi bộ của 7 tin này.
- Host demo `jp-demo-host@example.invalid`: không SĐT, mật khẩu ngẫu nhiên không lưu ⇒ không đăng nhập được.
- Toạ độ/mã ga sai chỉ ảnh hưởng bản đồ; tìm kiếm dựa trên tên ga.
- Khoá idempotent của tin = (host demo, `title`). Đổi `title` trong JSON ⇒ chạy `--undo` trước rồi seed lại, nếu không tin tiêu đề cũ vẫn `published`.
- Bật `DEMO_MARKET_SCOPE=true` mà chưa seed ⇒ bản jp trả feed/loại hình RỖNG (không lỗi, không log) — seed trước khi demo.
