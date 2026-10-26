# ancu365 — Backend

Backend cho app **ancu365** dùng FastAPI + SQLAlchemy + **PostgreSQL (PostGIS)**.

## Stack
- **Python 3.12**
- **FastAPI** — REST + WebSocket
- **SQLAlchemy 2.0** — ORM
- **PostgreSQL 16 + PostGIS** — primary database (via Docker)
- **Alembic** — database migrations
- **JWT HS256** + **bcrypt** — auth

## Setup nhanh (Postgres mode — Local Dev)

### Yêu cầu
- Docker Desktop (hoặc OrbStack)
- Python 3.12+

### Bước 1: Cài Python deps

```bash
python -m venv .venv
source .venv/bin/activate   # macOS/Linux
# hoặc: .\.venv\Scripts\Activate.ps1  (Windows)
pip install -r requirements.txt
```

### Bước 2: Cấu hình

```bash
cp .env.example .env
# Sửa: POSTGRES_PASSWORD, JWT_SECRET
# Nếu chạy uvicorn trực tiếp (không trong Docker): đổi "postgis" → "localhost" và port 5432 → 5433
# DATABASE_URL=postgresql://ancu365:your_pass@localhost:5433/ancu365
```

### Bước 3: Khởi PostGIS

```bash
docker compose up -d postgis
# Chờ healthy (~60 giây lần đầu):
docker compose ps postgis
```

### Bước 4: Chạy migrations

```bash
alembic upgrade head
# Hoặc với PYTHONPATH rõ ràng:
PYTHONPATH=$(pwd) alembic upgrade head
```

Lệnh này tạo tất cả bảng: `users`, `houses`, `bookings`, `categories`, `amenities`, `wishlists`, `reviews`, `notifications`, `chat_messages`, `planning.parcels`, `planning.etl_runs`, `planning.reports`.

Verify:
```bash
psql postgresql://ancu365:your_pass@localhost:5433/ancu365 -c "\dt"
```

### Bước 5: Seed dev data

```bash
python scripts/seed_dev.py
# Idempotent — an toàn chạy nhiều lần
```

### Bước 6: Chạy server

```bash
uvicorn main:app --host 0.0.0.0 --port 3000 --reload
```

Server tại: http://localhost:3000/docs

## Firebase Cloud Messaging

Flutter registers device tokens at:

```text
POST /api/users/me/push-token
DELETE /api/users/me/push-token
```

To send real push from the backend:

```bash
# Store the Admin SDK JSON outside the repo.
mkdir -p ../secrets
cp ~/Downloads/ancu365-firebase-adminsdk-*.json ../secrets/ancu365-firebase-adminsdk.json

# In .env:
NOTIFICATION_PUSH_PROVIDER=firebase
FIREBASE_SERVICE_ACCOUNT_PATH=/run/secrets/ancu365-firebase-adminsdk.json

docker compose build backend
docker compose up -d backend
alembic upgrade head
```

Do not commit Firebase Admin SDK JSON keys. The iOS `GoogleService-Info.plist`
belongs in the Flutter app; the Admin SDK JSON belongs only on the backend/server.

## Migrations

Tạo migration mới sau khi sửa model:

```bash
alembic revision --autogenerate -m "describe_your_change"
# Review file trong alembic/versions/ trước khi apply
alembic upgrade head
```

Rollback:
```bash
alembic downgrade -1   # 1 bước
alembic downgrade base # về 0
```

## Tests

### Smoke tests (Postgres — cần DB chạy)

```bash
SMOKE_DATABASE_URL="postgresql://ancu365:your_pass@localhost:5433/ancu365" \
  pytest tests/test_smoke_postgres.py -v
```

### Planning unit tests (mock DB — không cần Postgres)

```bash
pytest tests/ --ignore=tests/test_smoke_postgres.py -v
```

### Tất cả tests

```bash
SMOKE_DATABASE_URL="postgresql://ancu365:your_pass@localhost:5433/ancu365" \
  pytest tests/ -v
```

## Tài khoản demo (sau khi seed)

| Email | Mật khẩu | Role |
|---|---|---|
| admin@housebooking.com | admin123 | admin |
| host@housebooking.com | host123 | host |
| guest@housebooking.com | guest123 | guest |

## API docs (tự sinh)

- Swagger UI: http://localhost:3000/docs
- ReDoc: http://localhost:3000/redoc

## Tài liệu sản phẩm Ancu365 Japan

Bộ tài liệu giới thiệu web, app, trải nghiệm thị trường Nhật, MCP, AI, automation và AI search nằm tại [`docs/product/japan-market-system/`](docs/product/japan-market-system/README.md).

## Tài khoản demo

| Email | Mật khẩu | Role |
|---|---|---|
| admin@housebooking.com | admin123 | admin |
| host@housebooking.com | host123 | host |
| guest@housebooking.com | guest123 | guest |

## Endpoints chính

| Method | Path | Mục đích |
|---|---|---|
| POST | `/api/auth/login` `/register` `/forgot-password` `/change-password` | Auth |
| GET | `/api/auth/me` | User hiện tại (Bearer token) |
| GET PATCH | `/api/users` `/api/users/:id` | User profile |
| GET | `/api/categories` `/api/amenities` | Danh mục |
| GET POST PUT DELETE | `/api/houses` | CRUD nhà + filter + pagination |
| POST | `/api/houses/:id/close-unit` | Đóng phòng (cho thuê ngoài app) |
| GET POST | `/api/houses/:id/reviews` `/api/reviews` | Đánh giá |
| GET POST PATCH | `/api/bookings` | Booking, status `locked` có side-effect |
| GET POST DELETE | `/api/wishlists` | Yêu thích |
| GET PATCH | `/api/notifications` | Thông báo in-app |
| GET POST PATCH | `/api/chats` | Chat REST |
| WS | `/ws?token=JWT` | Chat realtime |
| POST | `/api/upload` | Upload ảnh base64 |
| GET | `/uploads/:file` | Static serve ảnh |
| GET | `/health` | Health check |

---

## Planning Lookup module (Postgres + PostGIS mode)

Module quy hoạch đất HCMC — dùng PostGIS + Martin tile server.
Chỉ active khi `DATABASE_URL` là `postgresql://...`.

### Quickstart (dev — postgis + martin + backend)

```bash
cp .env.example .env
# Bắt buộc sửa: POSTGRES_PASSWORD, JWT_SECRET
make up          # khởi PostGIS + Martin + backend (Docker Desktop phải chạy)
make migrate     # alembic upgrade head — tạo bảng planning.*
make seed-test   # seed 3 quận: Q1, Q3, Bình Thạnh (~5 phút, WFS phải reachable)
make health      # kiểm tra /api/health + Martin /catalog
```

### Full seed 24 quận HCMC

```bash
make seed    # ~30-60 phút (24 quận, phụ thuộc WFS STNMT uptime)

# Verify trong psql:
docker exec ancu365-postgis psql -U $POSTGRES_USER -d $POSTGRES_DB \
    -c "SELECT district, COUNT(*) FROM planning.parcels GROUP BY district ORDER BY district"
# Mong đợi: ≥ 60,000 rows tổng, 24 quận
```

### Full stack với Nominatim + Nginx (staging/prod)

```bash
make up-full
# Lần đầu: Nominatim tải PBF Vietnam (~307 MB) + import ~40 phút
# Theo dõi: docker compose logs -f nominatim
# Sẵn sàng khi healthcheck pass: curl http://localhost:8080/search?q=ho+chi+minh
```

### Verify Martin tile endpoint

```bash
# Sau khi seed-test thành công:
curl http://localhost:3001/catalog | python3 -m json.tool | grep planning
# Expect: "planning.parcels" trong danh sách

curl -o /tmp/tile.pbf "http://localhost:3001/planning.parcels/13/6688/3892.pbf"
file /tmp/tile.pbf
# Expect: "data" (binary MVT, 5-30 KB)
```

### Troubleshooting

| Triệu chứng | Nguyên nhân | Fix |
|------------|-------------|-----|
| `martin: connection refused` | PostGIS chưa ready | Đợi `make logs \| grep "database system is ready"` |
| `nominatim: OOM` | RAM < 4 GB khi import | Tăng `shm_size: 4g`; VPS ≥ 8 GB RAM |
| `seed fail district X` | WFS STNMT down hoặc timeout | Check `SELECT * FROM planning.etl_runs WHERE status='failed'`; thử lại: `python -m app.services.planning_etl seed --districts "quan-X"` |
| `planning.parcels` rỗng sau seed | Alembic chưa chạy | `make migrate` trước `make seed-test` |
| `Backend: planning module skipped` | `DATABASE_URL` là SQLite | Đổi `DATABASE_URL` sang `postgresql://...` trong `.env` |

## Hot reload

`--reload` mặc định: save file Python là server restart trong ~1 giây.

## Cấu trúc

```
backend/
├── main.py                  # Wire FastAPI app + routers
├── requirements.txt
├── .env                     # Local (đừng commit)
├── .env.example             # Template
├── alembic.ini              # Alembic config
├── alembic/versions/        # Migration history
├── scripts/seed_dev.py      # Dev seed script (idempotent)
├── uploads/                 # Ảnh user upload (đừng commit)
└── app/
    ├── config.py            # Load env
    ├── database.py          # SQLAlchemy engine
    ├── models.py            # 8 ORM models
    ├── helpers.py           # Enrich + push notification
    ├── auth.py              # JWT + bcrypt + Depends
    ├── chat_hub.py          # WebSocket Hub async
    ├── seed.py              # Seed dữ liệu mẫu
    └── routers/
        ├── auth_router.py
        ├── users.py
        ├── catalog.py
        ├── houses.py
        ├── bookings.py
        ├── wishlists.py
        ├── reviews.py
        ├── notifications.py
        ├── chat.py
        └── upload.py
```
