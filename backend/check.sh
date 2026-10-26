#!/usr/bin/env bash
# Cổng kiểm trước khi deploy — chạy TẤT CẢ những gì có thể bắt lỗi sớm.
#
# Vì sao có tệp này: dự án deploy thủ công bằng `docker run`, không có CI chặn
# commit hỏng. Một lệnh chạy được trước mỗi lần deploy giải quyết phần lớn giá
# trị của CI mà không cần dựng hạ tầng cho quy trình chưa tồn tại.
#
#   ./check.sh          # đầy đủ (backend + frontend + build)
#   (chạy từ ancu365-backend/, tự tìm ancu365-app/ ở thư mục cha)
#   ./check.sh --quick  # bỏ qua build web (~80s) — dùng khi lặp nhanh
#   ./check.sh --be     # chỉ backend
#   ./check.sh --fe     # chỉ frontend
#
# Mã thoát ≠ 0 nếu BẤT KỲ bước nào hỏng → cắm được vào cron/CI.

set -uo pipefail

# Script sống trong repo ancu365-backend nhưng kiểm CẢ HAI dự án — hai repo
# nằm cạnh nhau dưới cùng thư mục cha. Không có repo gốc chung để đặt nó.
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BE="$ROOT/ancu365-backend"
FE="$ROOT/ancu365-app"
FLUTTER_IMG="ghcr.io/cirruslabs/flutter:stable"

QUICK=0; RUN_BE=1; RUN_FE=1
for a in "$@"; do
  case "$a" in
    --quick) QUICK=1 ;;
    --be) RUN_FE=0 ;;
    --fe) RUN_BE=0 ;;
    -h|--help) sed -n '2,16p' "$0"; exit 0 ;;
    *) echo "Tham số lạ: $a"; exit 2 ;;
  esac
done

FAILED=()
step() { printf '\n\033[1m━━ %s\033[0m\n' "$1"; }
ok()   { printf '  \033[32m✓\033[0m %s\n' "$1"; }
bad()  { printf '  \033[31m✗\033[0m %s\n' "$1"; FAILED+=("$1"); }

# ── Backend ───────────────────────────────────────────────────────────────────
if [ "$RUN_BE" = 1 ]; then
  step "Backend — cú pháp Python"
  if docker run --rm -v "$BE:/app" -w /app ancu365-backend:local \
       python -m compileall -q app main.py >/dev/null 2>&1; then
    ok "compileall"
  else
    bad "compileall — có tệp Python lỗi cú pháp"
  fi

  step "Backend — test (1500+ test, ~3 phút)"
  if docker run --rm --network faceconst_default -e PYTHONPATH=/app \
       --env-file "$BE/.env" -v "$BE:/app" -w /app ancu365-backend:local \
       python -m pytest tests/ -q -p no:cacheprovider 2>&1 | tail -3; then
    ok "pytest"
  else
    bad "pytest — có test đỏ"
  fi

  step "Backend — tập bảng ORM còn khớp (CHẶN — chống mất bảng khi tách models §C)"
  # Gate CỨNG, tin cậy (khác alembic check còn nhiễu): snapshot tên bảng đăng ký
  # trên Base.metadata, KHÔNG cần DB/autogenerate. Bắt ngay lỗi "tách models quên
  # import 1 domain → bảng biến mất khỏi metadata → autogenerate DROP TABLE".
  if docker run --rm -e PYTHONPATH=/app -v "$BE:/app" -w /app ancu365-backend:local \
       bash -lc "python scripts/gen_model_tables.py >/tmp/mt.new 2>/dev/null && \
                 diff -q docs/model_tables.txt /tmp/mt.new" >/dev/null 2>&1; then
    ok "tập bảng metadata khớp snapshot"
  else
    bad "docs/model_tables.txt LỆCH (mất/thừa bảng?) — kiểm: diff <(python scripts/gen_model_tables.py) docs/model_tables.txt; nếu ĐÚNG ý → gen_model_tables.py --write rồi commit"
  fi

  step "Backend — migration khớp model (alembic check, CẢNH BÁO)"
  # env.py đã sửa: mặc định chỉ so schema 'public' (planning opt-in qua
  # ALEMBIC_INCLUDE_PLANNING=1) → nhiễu giảm mạnh (50→~4). Vẫn còn vài quirk
  # autogenerate (báo "added table" cho bảng ĐÃ CÓ) nên GIỮ mức cảnh báo; gate
  # CỨNG về mất bảng là bước "tập bảng ORM" ở trên.
  if docker run --rm --network faceconst_default -e PYTHONPATH=/app \
       --env-file "$BE/.env" -v "$BE:/app" -w /app ancu365-backend:local \
       alembic check >/dev/null 2>&1; then
    ok "alembic check — model và migration đồng bộ"
  else
    printf '  \033[33m!\033[0m alembic báo lệch — kiểm thật: alembic check 2>&1 | grep -iE "added column|remove"\n'
  fi

  step "Backend — bản đồ ARCHITECTURE.generated.md còn khớp route/model (chống stale)"
  # Regenerate rồi diff với bản đã commit. Khác các docs map-tay (đang stale):
  # cổng này FAIL khi thêm/xoá endpoint/model mà quên chạy gen_arch_map.py --write.
  # KHÔNG nuốt stderr của gen_arch_map.py. Trước đây `2>/dev/null` biến MỌI lỗi
  # chạy script (vd DATABASE_URL trỏ DB đã bị gỡ — `import main` cần DB thật)
  # thành thông báo "LỆCH", nên cổng đỏ liên miên vì lý do chẳng liên quan tới
  # bản đồ. Đỏ oan lâu ngày thì người ta thôi không đọc nữa.
  # Phân biệt "script chết" với "bản đồ lệch". Bản cũ gộp cả hai vào một thông
  # báo "LỆCH" (do `2>/dev/null` + `&&`), nên khi DATABASE_URL trỏ vào DB đã bị
  # gỡ thì cổng đỏ liên miên vì lý do chẳng liên quan — đỏ oan lâu ngày thì
  # người ta thôi không đọc nữa.
  # Bắt theo MÃ THOÁT, đừng bắt theo stderr: script in log JSON ra stderr ngay
  # cả khi chạy đúng.
  ARCH_LOG=$(mktemp)
  if docker run --rm --network faceconst_default -e PYTHONPATH=/app \
       --env-file "$BE/.env" -v "$BE:/app" -w /app ancu365-backend:local \
       bash -lc "python scripts/gen_arch_map.py >/tmp/arch.new && \
                 cp /tmp/arch.new /app/.arch.new" >"$ARCH_LOG" 2>&1; then
    if diff -q "$BE/docs/ARCHITECTURE.generated.md" "$BE/.arch.new" >/dev/null 2>&1; then
      ok "bản đồ khớp code"
    else
      bad "ARCHITECTURE.generated.md LỆCH — chạy: python scripts/gen_arch_map.py --write rồi commit"
    fi
  else
    bad "gen_arch_map.py KHÔNG CHẠY ĐƯỢC (không phải bản đồ lệch) — $(grep -iE "Error|FATAL" "$ARCH_LOG" | tail -1)"
  fi
  rm -f "$ARCH_LOG" "$BE/.arch.new"
fi

# ── Frontend ──────────────────────────────────────────────────────────────────
if [ "$RUN_FE" = 1 ]; then
  # web/ LÀ NỘI DUNG CÔNG KHAI: `flutter build web` copy mọi thứ trong đó ra
  # build/web/, mà build/web là bind-mount đang phục vụ thẳng ra Internet.
  # Sự cố đã xảy ra (26/07/2026): tài liệu điều tra nội bộ để ở web/design/ nên
  # lên public kèm cổng nội bộ 3010, lệnh curl endpoint admin và email một người
  # dùng thật — robots.txt lại Allow:/ nên còn cho phép index.
  # Cổng này CHẶN deploy khi có tệp lạ lọt vào web/. Thêm asset hợp lệ thì khai
  # báo vào WEB_ALLOW bên dưới — bắt buộc phải cố ý, không lọt vào im lặng.
  step "Frontend — web/ không chứa tệp lạ (CHẶN — chống lộ tài liệu nội bộ)"
  WEB_ALLOW="web/favicon.png
web/firebase-messaging-sw.js
web/icons/Icon-192.png
web/icons/Icon-512.png
web/icons/Icon-maskable-192.png
web/icons/Icon-maskable-512.png
web/index.html
web/manifest.json
web/sqflite_sw.js
web/sqlite3.wasm"
  WEB_FOUND="$(cd "$FE" && find web -type f | sort)"
  WEB_EXTRA="$(comm -23 <(printf '%s\n' "$WEB_FOUND") <(printf '%s\n' "$WEB_ALLOW" | sort))"
  if [ -z "$WEB_EXTRA" ]; then
    ok "web/ chỉ có asset đã khai báo"
  else
    bad "web/ có tệp lạ — SẼ PHÁT HÀNH RA INTERNET nếu deploy"
    printf '%s\n' "$WEB_EXTRA" | sed 's/^/    • /'
    printf '    → chuyển tài liệu nội bộ sang docs/, hoặc khai báo vào WEB_ALLOW trong check.sh\n'
  fi

  step "Frontend — analyze + test$([ "$QUICK" = 1 ] && echo '' || echo ' + build')"
  # pub get PHẢI chạy cùng container: pub cache nằm trong container, tách ra sẽ
  # lỗi "No such file or directory" cho vector_math.
  # BUILD_CMD luôn là một lệnh hợp lệ (không phải mảnh "&& ..." nối vào dòng
  # trước) — kiểu nối cũ tạo dòng mở đầu bằng '&&' và bash báo lỗi cú pháp,
  # nên bước build THỰC TẾ chưa từng chạy.
  BUILD_CMD="true"
  [ "$QUICK" = 0 ] && BUILD_CMD="echo '--- build ---'; flutter build web --release"
  if docker run --rm -v "$FE:/app" -w /app "$FLUTTER_IMG" bash -lc "
        flutter pub get >/dev/null 2>&1 || exit 1
        echo '--- analyze ---'; flutter analyze lib/ 2>&1 | tail -3
        # analyze CHỈ để tham khảo: repo còn 251 cảnh báo info có sẵn nên bắt
        # nó chặn deploy sẽ khiến cổng đỏ vĩnh viễn.
        echo '--- test ---'; flutter test 2>&1 | tee /tmp/fe-test.log |
            grep -E 'All tests|Some tests' | tail -1
        # Đọc kết quả từ log chứ không từ mã thoát của pipeline: mã thoát đó là
        # của 'tail' nên LUÔN bằng 0 — cổng từng báo xanh dù test đỏ.
        grep -q 'All tests passed' /tmp/fe-test.log || exit 1
        $BUILD_CMD
      " 2>&1 | sed 's/^/  /'; then
    ok "flutter"
  else
    bad "flutter — analyze/test/build hỏng"
  fi
fi

# ── Nguồn dữ liệu ngoài (cảnh báo, KHÔNG chặn) ────────────────────────────────
step "Nguồn quy hoạch (chỉ cảnh báo)"
if python3 "$BE/scripts/probe_planning_sources.py" >/dev/null 2>&1; then
  ok "nguồn chính còn sống"
else
  printf '  \033[33m!\033[0m nguồn quy hoạch trong config không phản hồi (đã biết, không chặn deploy)\n'
fi

# ── Kết luận ──────────────────────────────────────────────────────────────────
printf '\n'
if [ ${#FAILED[@]} -eq 0 ]; then
  printf '\033[32m━━ TẤT CẢ ĐẠT — deploy được\033[0m\n'
  exit 0
fi
printf '\033[31m━━ %d BƯỚC HỎNG — ĐỪNG deploy:\033[0m\n' "${#FAILED[@]}"
printf '   • %s\n' "${FAILED[@]}"
exit 1
