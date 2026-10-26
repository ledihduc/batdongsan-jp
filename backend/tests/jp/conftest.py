"""pytest conftest for tests/jp/ — JP market foundation tests.

Isolated from the root conftest (which requires PostGIS + full app import).
Uses minimal in-process setup — no DB, no planning module.

Environment patching must happen before any app.* import.
"""

from __future__ import annotations

import os
import sys

# ── Set env BEFORE any app import ────────────────────────────────────────────
os.environ["DATABASE_URL"] = "postgresql://localhost/fake_test"
os.environ["JWT_SECRET"] = "test-secret-xyz-never-use-in-prod"
os.environ.setdefault("REGION", "vn")
os.environ.setdefault("DEFAULT_TZ", "Asia/Ho_Chi_Minh")

# Purge any cached app modules (in case root conftest already loaded them).
_TO_PURGE = [k for k in sys.modules if k.startswith(("app", "main"))]
for _k in _TO_PURGE:
    del sys.modules[_k]
