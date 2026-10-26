#!/usr/bin/env python3
"""Sinh BẢN ĐỒ route + model TỰ ĐỘNG (chống stale — xem AI-REFACTOR-PLAN §A5).

Chạy trong container backend:
  docker run --rm -e PYTHONPATH=/app -v "$PWD:/app" -w /app ancu365-backend:local \
      python scripts/gen_arch_map.py            # in ra stdout
  ... python scripts/gen_arch_map.py --write    # ghi docs/ARCHITECTURE.generated.md

`check.sh` regenerate rồi diff với file đã commit → FAIL nếu lệch (bản đồ luôn khớp
code, khác các docs map-tay đang stale).
"""
import inspect
import sys
from collections import defaultdict


def route_rows():
    from main import app  # noqa: PLC0415
    rows = []
    for r in app.routes:
        path = getattr(r, "path", None)
        methods = getattr(r, "methods", None)
        if not path or not methods:
            continue
        for m in sorted(methods):
            if m in ("HEAD", "OPTIONS"):
                continue
            endpoint = getattr(r, "endpoint", None)
            mod = getattr(endpoint, "__module__", "?") if endpoint else "?"
            name = getattr(endpoint, "__name__", "?") if endpoint else "?"
            rows.append((path, m, mod, name))
    return sorted(set(rows))


def model_rows():
    import app.models as M  # noqa: PLC0415
    from app.database import Base  # noqa: PLC0415
    out = []
    for nm in dir(M):
        obj = getattr(M, nm)
        if inspect.isclass(obj) and issubclass(obj, Base) and obj is not Base:
            tbl = getattr(obj, "__tablename__", None)
            if tbl:
                out.append((nm, tbl, obj.__module__))
    return sorted(set(out))


def render():
    lines = ["# ARCHITECTURE (SINH TỰ ĐỘNG — đừng sửa tay)",
             "", "> `python scripts/gen_arch_map.py --write`. `check.sh` gate diff.",
             "", "## Endpoints theo router (module)"]
    by_mod = defaultdict(list)
    for path, m, mod, name in route_rows():
        by_mod[mod].append(f"- `{m:6} {path}` → {name}")
    for mod in sorted(by_mod):
        lines.append(f"\n### {mod}")
        lines += by_mod[mod]
    lines += ["", "## Models (class → table → module)"]
    for nm, tbl, mod in model_rows():
        lines.append(f"- `{nm}` → `{tbl}` ({mod})")
    return "\n".join(lines) + "\n"


if __name__ == "__main__":
    out = render()
    if "--write" in sys.argv:
        with open("docs/ARCHITECTURE.generated.md", "w") as f:
            f.write(out)
        print("wrote docs/ARCHITECTURE.generated.md")
    else:
        sys.stdout.write(out)
