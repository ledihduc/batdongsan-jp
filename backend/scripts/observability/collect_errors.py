#!/usr/bin/env python3
"""
collect_errors.py — Bước 2 của pipeline self-heal: LỌC + GOM lỗi từ log.

Đọc structured JSONL log (storage/logs/app.jsonl + các file rotate), lọc ra
bản ghi lỗi, gom theo fingerprint, xếp hạng theo tần suất, và xuất:
  - error_report.json  (máy đọc — cho selfheal.sh + claude)
  - error_report.md    (người đọc)

State ({last_ts, known fingerprints}) lưu ở .selfheal_state.json để mỗi lần
chạy chỉ xử lý log MỚI và biết cluster nào là "mới xuất hiện".

An toàn: mọi text sample chạy redact lần nữa (defensive) trước khi ghi ra —
report này sẽ được gửi cho Claude.

Usage:
  python scripts/observability/collect_errors.py \
      --logs storage/logs --state storage/logs/.selfheal_state.json \
      --out storage/logs --min-count 1
"""

from __future__ import annotations

import argparse
import glob
import json
import os
import sys
from collections import defaultdict
from typing import Any

# Cho phép import app.observability khi chạy standalone.
_REPO_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
if _REPO_ROOT not in sys.path:
    sys.path.insert(0, _REPO_ROOT)

try:
    from app.observability.fingerprint import compute_fingerprint, normalize_message
    from app.observability.redaction import redact_obj, redact_text
except Exception:  # noqa: BLE001 — fallback nếu chạy ngoài repo
    def redact_text(x):  # type: ignore
        return x

    def redact_obj(x):  # type: ignore
        return x

    def normalize_message(x):  # type: ignore
        return (x or "")[:300]

    def compute_fingerprint(**kw):  # type: ignore
        return "nofp"

_ERROR_LEVELS = {"ERROR", "CRITICAL", "FATAL"}
_ERROR_EVENTS = {"unhandled_exception", "client_error"}


def _is_error(rec: dict[str, Any]) -> bool:
    if rec.get("level") in _ERROR_LEVELS:
        return True
    if rec.get("event") in _ERROR_EVENTS:
        return True
    status = rec.get("status")
    return isinstance(status, int) and status >= 500


def _record_fingerprint(rec: dict[str, Any]) -> str:
    fp = rec.get("fingerprint")
    if isinstance(fp, str) and fp:
        return fp
    return compute_fingerprint(
        exc_type=rec.get("exc_type") or rec.get("error_code") or rec.get("logger"),
        message=rec.get("msg", ""),
        route=rec.get("route") or rec.get("path"),
        top_frame="",
    )


def _iter_log_records(log_dir: str):
    # app.jsonl trước, rồi .1 .2 … (mới → cũ không quan trọng, ta so ts).
    files = [os.path.join(log_dir, "app.jsonl")]
    files += sorted(glob.glob(os.path.join(log_dir, "app.jsonl.*")))
    for path in files:
        if not os.path.exists(path):
            continue
        try:
            with open(path, encoding="utf-8") as f:
                for line in f:
                    line = line.strip()
                    if not line:
                        continue
                    try:
                        yield json.loads(line)
                    except json.JSONDecodeError:
                        continue
        except OSError:
            continue


def collect(log_dir: str, since_ts: str, min_count: int) -> dict[str, Any]:
    groups: dict[str, dict[str, Any]] = defaultdict(
        lambda: {
            "count": 0,
            "first_seen": None,
            "last_seen": None,
            "routes": set(),
            "sources": set(),
            "levels": set(),
            "sample": None,
        }
    )
    max_ts = since_ts
    total_errors = 0

    for rec in _iter_log_records(log_dir):
        ts = rec.get("ts", "")
        if since_ts and ts <= since_ts:
            continue
        if not _is_error(rec):
            continue
        total_errors += 1
        if ts > max_ts:
            max_ts = ts

        fp = _record_fingerprint(rec)
        g = groups[fp]
        g["count"] += 1
        g["first_seen"] = ts if g["first_seen"] is None else min(g["first_seen"], ts)
        g["last_seen"] = ts if g["last_seen"] is None else max(g["last_seen"], ts)
        if rec.get("route"):
            g["routes"].add(rec["route"])
        g["sources"].add(rec.get("source") or "backend")
        g["levels"].add(rec.get("level", "ERROR"))
        if g["sample"] is None:
            g["sample"] = redact_obj(
                {
                    "msg": rec.get("msg"),
                    "exc_type": rec.get("exc_type"),
                    "error_code": rec.get("error_code"),
                    "method": rec.get("method"),
                    "route": rec.get("route") or rec.get("path"),
                    "status": rec.get("status"),
                    "traceback": rec.get("traceback"),
                }
            )

    clusters = []
    for fp, g in groups.items():
        if g["count"] < min_count:
            continue
        clusters.append(
            {
                "fingerprint": fp,
                "count": g["count"],
                "first_seen": g["first_seen"],
                "last_seen": g["last_seen"],
                "routes": sorted(g["routes"]),
                "sources": sorted(g["sources"]),
                "levels": sorted(g["levels"]),
                "title": redact_text(normalize_message(str(g["sample"].get("msg", "")))),
                "sample": g["sample"],
            }
        )
    clusters.sort(key=lambda c: c["count"], reverse=True)
    return {"max_ts": max_ts, "total_errors": total_errors, "clusters": clusters}


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--logs", default="storage/logs")
    ap.add_argument("--state", default="storage/logs/.selfheal_state.json")
    ap.add_argument("--out", default="storage/logs")
    ap.add_argument("--min-count", type=int, default=1)
    ap.add_argument("--reset", action="store_true", help="Bỏ qua state, quét toàn bộ log")
    args = ap.parse_args()

    state = {"last_ts": "", "known": {}}
    if os.path.exists(args.state) and not args.reset:
        try:
            with open(args.state, encoding="utf-8") as f:
                state = json.load(f)
        except (OSError, json.JSONDecodeError):
            pass

    result = collect(args.logs, state.get("last_ts", ""), args.min_count)
    known = state.get("known", {})

    # Đánh dấu cluster mới (chưa từng thấy fingerprint).
    for c in result["clusters"]:
        c["is_new"] = c["fingerprint"] not in known
        prev = known.get(c["fingerprint"], {})
        known[c["fingerprint"]] = {
            "count": prev.get("count", 0) + c["count"],
            "last_seen": c["last_seen"],
        }

    os.makedirs(args.out, exist_ok=True)
    report_path = os.path.join(args.out, "error_report.json")
    with open(report_path, "w", encoding="utf-8") as f:
        json.dump(result, f, ensure_ascii=False, indent=2)

    # Markdown cho người đọc.
    md = [f"# Error report", "", f"- Tổng lỗi (window mới): **{result['total_errors']}**",
          f"- Số cluster: **{len(result['clusters'])}**",
          f"- Mốc thời gian mới nhất: `{result['max_ts']}`", ""]
    for c in result["clusters"]:
        tag = "🆕 " if c["is_new"] else ""
        md.append(f"## {tag}{c['title'] or c['fingerprint']}  ×{c['count']}")
        md.append(f"- fingerprint: `{c['fingerprint']}`  |  levels: {', '.join(c['levels'])}"
                  f"  |  sources: {', '.join(c['sources'])}")
        md.append(f"- routes: {', '.join(c['routes']) or '—'}")
        md.append(f"- last_seen: `{c['last_seen']}`")
        tb = (c["sample"] or {}).get("traceback")
        if tb:
            snippet = "\n".join(str(tb).splitlines()[-6:])
            md.append("```\n" + snippet + "\n```")
        md.append("")
    with open(os.path.join(args.out, "error_report.md"), "w", encoding="utf-8") as f:
        f.write("\n".join(md))

    # Lưu state (chỉ tiến last_ts nếu có log mới).
    if result["max_ts"]:
        state["last_ts"] = result["max_ts"]
    state["known"] = known
    with open(args.state, "w", encoding="utf-8") as f:
        json.dump(state, f, ensure_ascii=False, indent=2)

    new_clusters = sum(1 for c in result["clusters"] if c["is_new"])
    print(json.dumps({
        "total_errors": result["total_errors"],
        "clusters": len(result["clusters"]),
        "new_clusters": new_clusters,
        "report": report_path,
    }))
    # Exit code 10 = có cluster mới (để cron/selfheal biết cần hành động).
    return 10 if new_clusters > 0 else 0


if __name__ == "__main__":
    sys.exit(main())
