#!/usr/bin/env python3
"""Eval chat AI đa ngôn ngữ (plan 20261027-1102 Phase 08, AC8; Phase 13 truyền --data bản vn).

Chỉ stdlib, chạy trên host với backend đang chạy. Mỗi câu: POST /api/ai/chat với
`lang = lang_ui`; đạt khi có `run_action` đúng action + mọi tham số kỳ vọng khớp VÀ câu trả
lời đúng ngôn ngữ. Luật khớp: số so bằng · mảng so tập · chuỗi kỳ vọng là list ⇒ giá trị thực
phải chứa (không phân biệt hoa thường) một phần tử · `station_name` khớp tên Nhật HOẶC
`station_id` thuộc kết quả `GET /api/jp/stations/search?q=<tên>`. Thoát 1 nếu dưới ngưỡng.

  python3 scripts/eval_ai_chat_multilang.py --base-url http://localhost:3010 --out report.md
"""

from __future__ import annotations

import argparse
import json
import pathlib
import re
import sys
import urllib.error
import urllib.parse
import urllib.request

DEFAULT_DATA = pathlib.Path(__file__).parent / "data" / "ai_chat_eval_multilang.json"
_PLACEHOLDER = re.compile(r"\{([A-Z0-9-]+)\}")
_HIRAGANA = re.compile(r"[ぁ-ゖ]")
_VI_MARKS = re.compile(r"[ăâđêôơưàáạảãằắặẳẵầấậẩẫèéẹẻẽềếệểễìíịỉĩòóọỏõồốộổỗờớợởỡùúụủũừứựửữỳýỵỷỹ]", re.I)
_WORD = r"[0-9A-Za-z\u00C0-\u024F\u1E00-\u1EFF]"  # chữ số + Latin/Việt (không gồm CJK)
_EN_WORDS = re.compile(r"\b(the|listing|listings|rent|station|walk|yen|found)\b", re.I)


def _http(method: str, url: str, body: dict | None = None, timeout: float = 90.0):
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(url, data=data, method=method, headers={"Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:  # noqa: S310 — URL do người chạy truyền
            status, raw = resp.status, resp.read()
    except urllib.error.HTTPError as exc:
        status, raw = exc.code, exc.read()
    try:
        return status, json.loads(raw or b"{}")
    except ValueError:  # body HTML (nginx 429/504) ⇒ ca đó trượt, không làm chết cả lượt eval
        return status, {}


def _listing_ids_by_prefix(base: str) -> dict[str, int]:
    _, body = _http("GET", f"{base}/api/jp/listings?page_size=50")
    out = {}
    for item in body.get("items", []):
        m = re.match(r"\[([A-Z0-9-]+)\]", item.get("title") or "")
        if m:
            out.setdefault(m.group(1), item["listing_id"])
    return out


def _station_ids(base: str, name: str, cache: dict) -> set[int]:
    if name not in cache:
        _, body = _http("GET", f"{base}/api/jp/stations/search?q={urllib.parse.quote(name)}")
        cache[name] = {s["id"] for s in body} if isinstance(body, list) else set()
    return cache[name]


def _fill(value, ids: dict[str, int]):
    if isinstance(value, str):
        m = _PLACEHOLDER.fullmatch(value)
        if m:
            return ids.get(m.group(1), -1)
        return _PLACEHOLDER.sub(lambda mm: str(ids.get(mm.group(1), -1)), value)
    return value


def _value_ok(expected, actual) -> bool:
    if isinstance(expected, list) and expected and all(isinstance(e, str) for e in expected) and isinstance(actual, str):
        # Ranh giới chỉ theo chữ số + chữ Latin/Việt: "Quận 10" KHÔNG khớp "Quận 1" (Phase 13 QA F2),
        # còn CJK không có ranh giới từ ⇒ "中目黒" vẫn khớp "中目黒駅" (code review M1).
        return any(re.search(rf"(?<!{_WORD}){re.escape(e)}(?!{_WORD})", actual, re.IGNORECASE) for e in expected)
    if isinstance(expected, list):
        return isinstance(actual, list) and set(map(str, expected)) == set(map(str, actual))
    if isinstance(expected, (int, float)) and not isinstance(expected, bool):
        return isinstance(actual, (int, float)) and float(actual) == float(expected)
    return isinstance(actual, str) and str(expected).lower() in actual.lower()


def _params_ok(base: str, expect: dict, actual: dict, cache: dict) -> bool:
    for key, exp in expect.items():
        if key == "station_name":
            by_name = isinstance(actual.get("station_name"), str) and exp in actual["station_name"]
            if not (by_name or actual.get("station_id") in _station_ids(base, exp, cache)):
                return False
        elif not _value_ok(exp, actual.get(key)):
            return False
    return True


def _lang_ok(reply: str, lang: str) -> bool:
    if lang == "ja":
        return bool(_HIRAGANA.search(reply))
    if lang == "vi":
        return bool(_VI_MARKS.search(reply))
    return not _HIRAGANA.search(reply) and bool(_EN_WORDS.search(reply))


def run_case(base: str, case: dict, ids: dict[str, int], cache: dict) -> dict:
    q = _fill(case["q"], ids)
    expect_params = {k: _fill(v, ids) for k, v in case["expect"]["params"].items()}
    status, body = _http("POST", f"{base}/api/ai/chat",
                         {"messages": [{"role": "user", "content": q}], "lang": case["lang_ui"]})
    calls = [c for c in body.get("tool_calls", []) if c.get("name") == "run_action"]
    action_ok = any(
        (c.get("arguments") or {}).get("action") == case["expect"]["action"]
        and _params_ok(base, expect_params, (c.get("arguments") or {}).get("params") or {}, cache)
        for c in calls
    )
    reply = body.get("reply", "")
    lang_ok = status == 200 and _lang_ok(reply, case["reply_lang"])
    used = [f"{(c.get('arguments') or {}).get('action')} {json.dumps((c.get('arguments') or {}).get('params'), ensure_ascii=False)}"
            for c in calls]
    return {"q": q, "reply_lang": case["reply_lang"], "status": status, "action_ok": action_ok,
            "lang_ok": lang_ok, "model": body.get("model"), "pass": action_ok and lang_ok, "used": used, "reply": reply[:80].replace("\n", " ")}


def _report(results: list[dict], model: str, thresholds: dict) -> tuple[str, bool]:
    ja = [r for r in results if r["reply_lang"] == "ja"]
    other = [r for r in results if r["reply_lang"] != "ja"]
    ja_n, other_n = sum(r["pass"] for r in ja), sum(r["pass"] for r in other)
    ok = ja_n >= thresholds["ja"][0] and other_n >= thresholds["en+vi"][0]
    lines = [f"# Eval chat AI đa ngôn ngữ — model `{model}`", "",
             "| # | lang | HTTP | action | ngôn ngữ | đạt | câu hỏi | action đã gọi | trả lời (80 ký tự) |",
             "|---|---|---|---|---|---|---|---|---|"]
    for i, r in enumerate(results, 1):
        lines.append(f"| {i} | {r['reply_lang']} | {r['status']} | {'✓' if r['action_ok'] else '✗'} | "
                     f"{'✓' if r['lang_ok'] else '✗'} | {'✓' if r['pass'] else '✗'} | {r['q']} | "
                     f"{'<br>'.join(r['used']) or '—'} | {r['reply'].replace('|', '/')} |")
    lines += ["", f"ja {ja_n}/{len(ja)} (ngưỡng {thresholds['ja'][0]}) · en+vi {other_n}/{len(other)} "
              f"(ngưỡng {thresholds['en+vi'][0]}) · {'ĐẠT' if ok else 'CHƯA ĐẠT'}"]
    return "\n".join(lines) + "\n", ok


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--base-url", default="http://localhost:3010")
    ap.add_argument("--data", type=pathlib.Path, default=DEFAULT_DATA)
    ap.add_argument("--out", type=pathlib.Path, required=True)
    args = ap.parse_args()
    data = json.loads(args.data.read_text(encoding="utf-8"))
    base = args.base_url.rstrip("/")
    ids, cache = _listing_ids_by_prefix(base), {}
    results = [run_case(base, c, ids, cache) for c in data["cases"]]
    model = next((r["model"] for r in results if r.get("model")), "?")
    text, ok = _report(results, model, data["thresholds"])
    args.out.write_text(text, encoding="utf-8")
    print(text)
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
