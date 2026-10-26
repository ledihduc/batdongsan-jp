#!/usr/bin/env python3
"""Snapshot TẬP BẢNG của ORM metadata (gate an toàn cho tái cấu trúc models — §B1).

Vì sao: khi tách app/models.py thành package theo domain (§C1), nếu `__init__.py`
QUÊN import 1 submodule, các bảng của nó BIẾN MẤT khỏi Base.metadata → Alembic
autogenerate sẽ sinh DROP TABLE thật. `alembic check` lại nhiễu (schema-qualify
quirk). Snapshot này KHÔNG cần DB, KHÔNG autogenerate — chỉ liệt kê tên bảng đã
đăng ký; `check.sh` diff với bản commit → FAIL ngay nếu thiếu (hoặc thừa) bảng.

  python scripts/gen_model_tables.py            # in stdout
  python scripts/gen_model_tables.py --write     # ghi docs/model_tables.txt
"""
import sys

# Import mọi nguồn đăng ký model (giống alembic/env.py) — KHÔNG import main (khỏi DB).
from app.database import Base  # noqa: E402
import app.models  # noqa: E402,F401 — registers Base subclasses (public)
import app.domain  # noqa: E402,F401 — registers domain models (delegation/kyc/...)


def render() -> str:
    names = sorted(Base.metadata.tables.keys())
    header = f"# ORM metadata tables (Base.metadata) — {len(names)} bảng. SINH TỰ ĐỘNG.\n"
    return header + "\n".join(names) + "\n"


if __name__ == "__main__":
    out = render()
    if "--write" in sys.argv:
        with open("docs/model_tables.txt", "w") as f:
            f.write(out)
        print(f"wrote docs/model_tables.txt ({out.count(chr(10)) - 1} tables)")
    else:
        sys.stdout.write(out)
